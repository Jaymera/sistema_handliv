from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.infrastructure.database.models import Subscription, User
from app.infrastructure.database.session import get_db
from app.presentation.deps.auth import get_current_user

router = APIRouter()


def _get_or_create_active_subscription(db: Session, user: User) -> Subscription | None:
    return db.scalar(select(Subscription).where(Subscription.user_id == user.id))


@router.post("/subscriptions/checkout")
def create_checkout(plan_code: str, interval: str = "monthly", user: User = Depends(get_current_user)) -> dict:
    if settings.stripe_secret_key.get_secret_value():
        try:
            import stripe

            stripe.api_key = settings.stripe_secret_key.get_secret_value()
            price_id = {
                "free": settings.stripe_price_free,
                "pro": settings.stripe_price_pro,
                "premium": settings.stripe_price_premium,
            }.get(plan_code)
            if not price_id:
                raise HTTPException(status.HTTP_400_BAD_REQUEST, "invalid plan")
            session = stripe.checkout.Session.create(
                mode="subscription",
                line_items=[{"price": price_id, "quantity": 1}],
                success_url="https://app.handliv.com/billing?status=success",
                cancel_url="https://app.handliv.com/billing?status=cancel",
                client_reference_id=str(user.id),
            )
            return {"checkout_url": session.url}
        except Exception as exc:
            raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, str(exc)) from exc
    return {"checkout_url": "https://app.handliv.com/billing?status=success"}


@router.post("/subscriptions/portal")
def create_portal(user: User = Depends(get_current_user)) -> dict:
    if settings.stripe_secret_key.get_secret_value():
        try:
            import stripe

            stripe.api_key = settings.stripe_secret_key.get_secret_value()
            customer = stripe.Customer.list(email=user.email).data
            if not customer:
                raise HTTPException(status.HTTP_400_BAD_REQUEST, "no stripe customer")
            portal = stripe.billing_portal.Session.create(
                customer=customer[0].id,
                return_url="https://app.handliv.com/profile",
            )
            return {"portal_url": portal.url}
        except Exception as exc:
            raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, str(exc)) from exc
    return {"portal_url": "https://app.handliv.com/profile"}


@router.get("/subscriptions/me")
def my_subscription(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    sub = db.scalar(select(Subscription).where(Subscription.user_id == user.id))
    if not sub:
        return {"plan": {"code": "free"}, "status": "active", "current_period_end": None, "cancel_at_period_end": False}
    return {
        "plan": {"code": sub.plan.code, "name": sub.plan.name},
        "status": sub.status.value,
        "current_period_end": sub.current_period_end.isoformat() if sub.current_period_end else None,
        "cancel_at_period_end": sub.cancel_at_period_end,
    }


@router.delete("/subscriptions/me", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
def cancel_subscription(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> None:
    sub = db.scalar(select(Subscription).where(Subscription.user_id == user.id))
    if sub is None:
        return
    sub.cancel_at_period_end = True
    db.commit()