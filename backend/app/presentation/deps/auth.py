from __future__ import annotations

import uuid
from typing import Any

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.domain.security import decode_access_token
from app.infrastructure.database.models import Plan, Subscription, SubscriptionStatus, User
from app.infrastructure.database.session import get_db

bearer = HTTPBearer(auto_error=True)


def _user_plan_payload(db: Session, user: User) -> dict[str, Any] | None:
    sub = db.scalar(
        select(Subscription).where(
            Subscription.user_id == user.id,
            Subscription.status.in_([SubscriptionStatus.ACTIVE, SubscriptionStatus.TRIALING]),
        )
    )
    if not sub:
        plan = db.scalar(select(Plan).where(Plan.code == "free"))
        if plan is None:
            return None
        return {"code": "free", "name": plan.name, "limits": plan.limits_json, "active": True}
    return {
        "code": sub.plan.code,
        "name": sub.plan.name,
        "limits": sub.plan.limits_json,
        "active": True,
        "current_period_end": sub.current_period_end.isoformat() if sub.current_period_end else None,
    }


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
) -> User:
    payload = decode_access_token(credentials.credentials)
    if payload.get("type") != "access":
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "invalid token type")
    user_id = payload.get("sub")
    try:
        user_uuid = uuid.UUID(str(user_id))
    except (TypeError, ValueError) as exc:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "invalid subject") from exc
    user = db.get(User, user_uuid)
    if user is None or not user.is_active or user.deleted_at is not None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "user not found or inactive")
    return user


def require_super_admin(user: User = Depends(get_current_user)) -> User:
    if user.role.value != "super_admin":
        raise HTTPException(status.HTTP_403_FORBIDDEN, "admin only")
    return user


def current_user_with_plan(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> User:
    # lazily attach plan payload for response builders
    user._plan_payload = _user_plan_payload(db, user)  # type: ignore[attr-defined]
    return user