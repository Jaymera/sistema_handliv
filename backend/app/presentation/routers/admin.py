from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.infrastructure.cache import cache
from app.infrastructure.database.models import AppLog, AuditLog, Plan, User
from app.infrastructure.database.session import get_db
from app.presentation.deps.auth import require_super_admin

router = APIRouter()


class ScoreWeightsUpdate(BaseModel):
    technical_weight: float | None = None
    valuation_weight: float | None = None
    sentiment_weight: float | None = None
    min_confidence: int | None = None


@router.get("/users")
def list_users(q: str = "", page: int = 1, limit: int = 100, admin=Depends(require_super_admin), db: Session = Depends(get_db)) -> dict:
    from app.infrastructure.database.models import Subscription, SubscriptionStatus

    stmt = select(User).where(User.deleted_at.is_(None))
    if q:
        q_upper = q.upper()
        stmt = stmt.where(User.email.ilike(f"%{q_upper}%") | User.name.ilike(f"%{q_upper}%"))
    users = db.scalars(stmt.offset((page - 1) * limit).limit(limit)).all()
    items = []
    for u in users:
        sub = db.scalar(select(Subscription).where(Subscription.user_id == u.id))
        plan_code = sub.plan.code if sub and sub.plan else "free"
        plan_name = sub.plan.name if sub and sub.plan else "Free"
        sub_status = sub.status.value if sub else "active"
        items.append({
            "id": u.id,
            "name": u.name,
            "email": u.email,
            "is_active": u.is_active,
            "role": u.role.value,
            "plan_code": plan_code,
            "plan_name": plan_name,
            "subscription_status": sub_status,
            "created_at": u.created_at.isoformat() if u.created_at else None,
            "last_login_at": u.last_login_at.isoformat() if u.last_login_at else None,
        })
    return {"items": items}


class UserPatch(BaseModel):
    is_active: bool | None = None
    plan_code: str | None = None
    reset_password: str | None = None  # new password (plaintext, hashed before saving)


@router.patch("/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
def update_user(user_id: uuid.UUID, payload: UserPatch, admin=Depends(require_super_admin), db: Session = Depends(get_db)) -> None:
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "user not found")
    if payload.is_active is not None:
        user.is_active = payload.is_active
    if payload.reset_password:
        from app.domain.security import hash_password

        user.password_hash = hash_password(payload.reset_password)
    if payload.plan_code is not None:
        from app.infrastructure.database.models import Plan, Subscription, SubscriptionStatus

        plan = db.scalar(select(Plan).where(Plan.code == payload.plan_code))
        if plan is None:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "plan not found")
        sub = db.scalar(select(Subscription).where(Subscription.user_id == user.id))
        if sub is None:
            sub = Subscription(user_id=user.id, plan_id=plan.id, status=SubscriptionStatus.ACTIVE)
            db.add(sub)
        else:
            sub.plan_id = plan.id
    db.commit()


@router.get("/logs")
def list_logs(level: str | None = None, source: str | None = None, page: int = 1, limit: int = 50, admin=Depends(require_super_admin), db: Session = Depends(get_db)) -> dict:
    from app.infrastructure.database.models import LogLevel, LogSource

    stmt = select(AppLog).order_by(AppLog.created_at.desc())
    if level:
        stmt = stmt.where(AppLog.level == LogLevel(level))
    if source:
        stmt = stmt.where(AppLog.source == LogSource(source))
    rows = db.scalars(stmt.offset((page - 1) * limit).limit(limit)).all()
    return {
        "items": [
            {"id": r.id, "level": r.level.value, "source": r.source.value, "message": r.message, "context": r.context_json, "created_at": r.created_at.isoformat()}
            for r in rows
        ]
    }


@router.post("/cache/invalidate", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
def invalidate_cache(pattern: str = "*", admin=Depends(require_super_admin)) -> None:
    cache.invalidate_pattern(pattern)


@router.get("/metrics")
def metrics(admin=Depends(require_super_admin), db: Session = Depends(get_db)) -> dict:
    from app.infrastructure.database.models import Subscription, Backtest, FileDownload

    mau = db.scalar(select(User).where(User.last_login_at.is_not(None))) or 0
    return {
        "mau_estimate": len(db.scalars(select(User).where(User.last_login_at.is_not(None))).all()),
        "total_users": len(db.scalars(select(User).where(User.deleted_at.is_(None))).all()),
        "active_subscriptions": len(db.scalars(select(Subscription).where(Subscription.status == "active")).all()),
        "total_backtests": len(db.scalars(select(Backtest)).all()),
        "files_downloaded": len(db.scalars(select(FileDownload)).all()),
    }


@router.get("/score-weights")
def get_weights(db: Session = Depends(get_db), admin=Depends(require_super_admin)) -> dict:
    from app.infrastructure.database.models import ScoreWeights

    active = db.scalar(select(ScoreWeights).where(ScoreWeights.is_active == True))  # noqa: E712
    if not active:
        return {"technical_weight": 0.40, "valuation_weight": 0.35, "sentiment_weight": 0.25, "min_confidence": 50}
    return {
        "id": active.id,
        "technical_weight": float(active.technical_weight),
        "valuation_weight": float(active.valuation_weight),
        "sentiment_weight": float(active.sentiment_weight),
        "min_confidence": active.min_confidence,
    }


@router.put("/score-weights", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
def update_weights(payload: ScoreWeightsUpdate, admin=Depends(require_super_admin), db: Session = Depends(get_db)) -> None:
    from app.infrastructure.database.models import ScoreWeights
    from decimal import Decimal

    active = db.scalar(select(ScoreWeights).where(ScoreWeights.is_active == True))  # noqa: E712
    if active is None:
        active = ScoreWeights(name="default", is_active=True)
        db.add(active)
    if payload.technical_weight is not None:
        active.technical_weight = Decimal(str(payload.technical_weight))
    if payload.valuation_weight is not None:
        active.valuation_weight = Decimal(str(payload.valuation_weight))
    if payload.sentiment_weight is not None:
        active.sentiment_weight = Decimal(str(payload.sentiment_weight))
    if payload.min_confidence is not None:
        active.min_confidence = payload.min_confidence
    db.commit()
    cache.invalidate_pattern("score:*")


@router.get("/plans")
def admin_list_plans(admin=Depends(require_super_admin), db: Session = Depends(get_db)) -> dict:
    return {"items": [{"id": p.id, "code": p.code, "name": p.name, "stripe_price_id": p.stripe_price_id, "price_monthly_cents": p.price_monthly_cents} for p in db.scalars(select(Plan)).all()]}


class PlanPatch(BaseModel):
    name: str | None = None
    stripe_price_id: str | None = None
    price_monthly_cents: int | None = None
    is_active: bool | None = None


@router.patch("/plans/{plan_id}", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
def admin_patch_plan(plan_id: uuid.UUID, payload: PlanPatch, admin=Depends(require_super_admin), db: Session = Depends(get_db)) -> None:
    p = db.get(Plan, plan_id)
    if p is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "plan not found")
    if payload.name is not None:
        p.name = payload.name
    if payload.stripe_price_id is not None:
        p.stripe_price_id = payload.stripe_price_id
    if payload.price_monthly_cents is not None:
        p.price_monthly_cents = payload.price_monthly_cents
    if payload.is_active is not None:
        p.is_active = payload.is_active
    db.commit()