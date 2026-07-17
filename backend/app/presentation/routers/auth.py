from __future__ import annotations

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.domain.security import (
    create_access_token,
    decode_access_token,
    decode_password_reset_token,
    generate_password_reset_token,
    generate_refresh_token,
    hash_password,
    hash_token,
    verify_password,
)
from app.infrastructure.database.models import (
    PasswordReset,
    RefreshToken,
    Subscription,
    SubscriptionStatus,
    User,
)
from app.infrastructure.database.session import get_db
from app.infrastructure.providers.email import send_email
from app.presentation.deps.auth import get_current_user
from app.presentation.schemas.auth import (
    AuthResponse,
    LoginRequest,
    LogoutRequest,
    PasswordForgotRequest,
    PasswordResetRequest,
    RefreshRequest,
    RegisterRequest,
    UpdateProfileRequest,
    UserWithPlan,
)

router = APIRouter()


def _plan_payload(db: Session, user: User) -> dict | None:
    sub = db.scalar(
        select(Subscription).where(
            Subscription.user_id == user.id,
            Subscription.status.in_([SubscriptionStatus.ACTIVE, SubscriptionStatus.TRIALING]),
        )
    )
    if not sub:
        return {"code": "free", "name": "Free", "limits": {}, "active": True}
    return {
        "code": sub.plan.code,
        "name": sub.plan.name,
        "limits": sub.plan.limits_json,
        "active": True,
        "current_period_end": sub.current_period_end.isoformat() if sub.current_period_end else None,
    }


def _emit_tokens(db: Session, user: User, device_info: str | None = None) -> tuple[str, str]:
    access = create_access_token(subject=str(user.id), extra={"role": user.role.value})
    raw_refresh = generate_refresh_token()
    expires_at = datetime.now(timezone.utc) + timedelta(days=settings.refresh_token_expire_days)
    db.add(
        RefreshToken(
            user_id=user.id,
            token_hash=hash_token(raw_refresh),
            device_info=device_info,
            expires_at=expires_at,
        )
    )
    return access, raw_refresh


@router.post("/auth/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
def register(payload: RegisterRequest, db: Session = Depends(get_db)) -> AuthResponse:
    existing = db.scalar(select(User).where(User.email == payload.email.lower()))
    if existing is not None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "email already registered")
    user = User(
        name=payload.name,
        email=payload.email.lower(),
        phone=payload.phone,
        password_hash=hash_password(payload.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    access, refresh = _emit_tokens(db, user, device_info="register")
    db.commit()
    return AuthResponse(
        user=UserWithPlan(
            id=user.id,
            name=user.name,
            email=user.email,
            phone=user.phone,
            role=user.role,
            locale=user.locale,
            theme=user.theme,
            force_password_change=user.force_password_change,
            plan=_plan_payload(db, user),
        ),
        access_token=access,
        refresh_token=refresh,
        force_password_change=user.force_password_change,
    )


@router.post("/auth/login", response_model=AuthResponse)
def login(payload: LoginRequest, request: Request, db: Session = Depends(get_db)) -> AuthResponse:
    user = db.scalar(select(User).where(User.email == payload.email.lower()))
    if user is None or not verify_password(payload.password, user.password_hash or ""):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "invalid credentials")
    if not user.is_active or user.deleted_at is not None:
        raise HTTPException(status.HTTP_423_LOCKED, "account suspended")
    user.last_login_at = datetime.now(timezone.utc)
    access, refresh = _emit_tokens(db, user, device_info=request.headers.get("user-agent"))
    db.commit()
    return AuthResponse(
        user=UserWithPlan(
            id=user.id,
            name=user.name,
            email=user.email,
            phone=user.phone,
            role=user.role,
            locale=user.locale,
            theme=user.theme,
            force_password_change=user.force_password_change,
            plan=_plan_payload(db, user),
        ),
        access_token=access,
        refresh_token=refresh,
        force_password_change=user.force_password_change,
    )


@router.post("/auth/refresh", response_model=AuthResponse)
def refresh(payload: RefreshRequest, db: Session = Depends(get_db)) -> AuthResponse:
    token_row = db.scalar(select(RefreshToken).where(RefreshToken.token_hash == hash_token(payload.refresh_token)))
    if token_row is None or token_row.revoked_at is not None or token_row.expires_at < datetime.now(timezone.utc):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "invalid refresh token")
    user = db.get(User, token_row.user_id)
    if user is None or not user.is_active or user.deleted_at is not None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "user inactive")
    token_row.revoked_at = datetime.now(timezone.utc)
    access, new_refresh = _emit_tokens(db, user)
    db.commit()
    return AuthResponse(
        user=UserWithPlan(
            id=user.id,
            name=user.name,
            email=user.email,
            phone=user.phone,
            role=user.role,
            locale=user.locale,
            theme=user.theme,
            force_password_change=user.force_password_change,
            plan=_plan_payload(db, user),
        ),
        access_token=access,
        refresh_token=new_refresh,
        force_password_change=user.force_password_change,
    )


@router.post("/auth/logout", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
def logout(payload: LogoutRequest, db: Session = Depends(get_db)) -> None:
    token_row = db.scalar(select(RefreshToken).where(RefreshToken.token_hash == hash_token(payload.refresh_token)))
    if token_row is not None and token_row.revoked_at is None:
        token_row.revoked_at = datetime.now(timezone.utc)
        db.commit()


@router.post("/auth/password/forgot", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
async def password_forgot(payload: PasswordForgotRequest, db: Session = Depends(get_db)) -> None:
    user = db.scalar(select(User).where(User.email == payload.email.lower(), User.deleted_at.is_(None)))
    # always 204 (do not leak whether email exists)
    if user is None:
        return
    raw_token = generate_password_reset_token()
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=settings.password_reset_expire_minutes)
    db.add(PasswordReset(user_id=user.id, token_hash=hash_token(raw_token), expires_at=expires_at))
    db.commit()
    link = f"https://app.handliv.com/reset?token={raw_token}"
    body = (
        f"<p>Olá {user.name},</p>"
        f"<p>Recebemos sua solicitação para redefinir a senha. Clique no link abaixo (válido por "
        f"{settings.password_reset_expire_minutes} minutos):</p>"
        f"<p><a href=\"{link}\">{link}</a></p>"
        f"<p>Se não foi você, ignore este email.</p>"
    )
    await send_email(user.email, "Redefinição de senha Handliv", body)


@router.post("/auth/password/reset", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
def password_reset(payload: PasswordResetRequest, db: Session = Depends(get_db)) -> None:
    row = db.scalar(select(PasswordReset).where(PasswordReset.token_hash == decode_password_reset_token(payload.token)))
    if row is None or row.used_at is not None or row.expires_at < datetime.now(timezone.utc):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "invalid or expired token")
    user = db.get(User, row.user_id)
    if user is None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "user not found")
    user.password_hash = hash_password(payload.new_password)
    if user.force_password_change:
        user.force_password_change = False
    row.used_at = datetime.now(timezone.utc)
    db.commit()


@router.get("/auth/me")
def me(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    return {
        "id": user.id,
        "name": user.name,
        "email": user.email,
        "phone": user.phone,
        "role": user.role.value,
        "locale": user.locale,
        "theme": user.theme,
        "force_password_change": user.force_password_change,
        "plan": _plan_payload(db, user),
    }


@router.patch("/auth/me")
def update_profile(
    payload: UpdateProfileRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    if payload.name is not None:
        user.name = payload.name
    if payload.phone is not None:
        user.phone = payload.phone
    if payload.locale is not None:
        user.locale = payload.locale
    if payload.theme is not None:
        user.theme = payload.theme
    db.commit()
    db.refresh(user)
    return {
        "id": user.id,
        "name": user.name,
        "email": user.email,
        "phone": user.phone,
        "role": user.role.value,
        "locale": user.locale,
        "theme": user.theme,
    }


@router.delete("/auth/me", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
def soft_delete_me(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> None:
    user.deleted_at = datetime.now(timezone.utc)
    user.is_active = False
    db.commit()