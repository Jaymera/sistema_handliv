from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.infrastructure.database.models import Plan, Subscription, SubscriptionStatus, User
from app.infrastructure.database.session import get_db
from app.presentation.deps.auth import get_current_user

router = APIRouter()

PRODUCT_BY_CODE = {
    "free": "prod_UyC28wT66ZpiCK",
    "start": "prod_UyC1XCU8KwqfR0",
    "ultimate": "prod_SWU1b4w9asl9Ed",
}


@router.post("/subscriptions/checkout")
def create_checkout(plan_code: str, interval: str = "monthly", user: User = Depends(get_current_user)) -> dict:
    if plan_code == "free":
        return {"checkout_url": None, "message": "Plano Free não precisa de pagamento"}
    product_id = PRODUCT_BY_CODE.get(plan_code)
    if not product_id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "invalid plan")
    try:
        import stripe

        stripe.api_key = settings.stripe_secret_key.get_secret_value()
        # Find recurring price for this product
        prices = stripe.Price.list(product=product_id, active=True, recurring=True)
        if not prices.data:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "no price found for product")
        if interval == "yearly":
            price = next((p for p in prices.data if p.recurring and p.recurring.interval == "year"), prices.data[0])
        else:
            price = next((p for p in prices.data if p.recurring and p.recurring.interval == "month"), prices.data[0])

        session = stripe.checkout.Session.create(
            mode="subscription",
            line_items=[{"price": price.id, "quantity": 1}],
            success_url="https://app.handliv.com/billing?status=success",
            cancel_url="https://app.handliv.com/billing?status=cancel",
            client_reference_id=str(user.id),
            metadata={"user_id": str(user.id), "plan_code": plan_code},
        )
        return {"checkout_url": session.url}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, str(exc)) from exc


@router.post("/subscriptions/webhook")
async def stripe_webhook(request: Request, db: Session = Depends(get_db)) -> dict:
    payload = await request.body()
    sig = request.headers.get("Stripe-Signature", "")
    try:
        import stripe

        stripe.api_key = settings.stripe_secret_key.get_secret_value()
        event = stripe.Webhook.construct_event(payload, sig, "whsec_xxx")
    except Exception as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc)) from exc

    event_type = event["type"]
    data = event["data"]["object"]

    if event_type == "checkout.session.completed":
        user_id = data.get("metadata", {}).get("user_id")
        plan_code = data.get("metadata", {}).get("plan_code")
        sub_id = data.get("subscription")
        customer_id = data.get("customer")
        if user_id and plan_code:
            plan = db.scalar(select(Plan).where(Plan.code == plan_code))
            user = db.get(User, user_id)
            if plan and user:
                sub = db.scalar(select(Subscription).where(Subscription.user_id == user.id))
                if not sub:
                    sub = Subscription(user_id=user.id, plan_id=plan.id)
                    db.add(sub)
                sub.plan_id = plan.id
                sub.stripe_customer_id = customer_id
                sub.stripe_subscription_id = sub_id
                sub.status = SubscriptionStatus.ACTIVE
                sub.current_period_end = datetime.now(timezone.utc)
                db.commit()

    elif event_type in ("invoice.paid", "invoice.payment_succeeded"):
        sub_id = data.get("subscription")
        if sub_id:
            sub = db.scalar(select(Subscription).where(Subscription.stripe_subscription_id == sub_id))
            if sub:
                sub.status = SubscriptionStatus.ACTIVE
                period_end = data.get("current_period_end") or data.get("lines", {}).get("data", [{}])[0].get("period", {}).get("end")
                if period_end:
                    sub.current_period_end = datetime.fromtimestamp(period_end, tz=timezone.utc)
                db.commit()

    elif event_type in ("invoice.payment_failed", "customer.subscription.deleted"):
        sub_id = data.get("subscription") or data.get("id")
        if sub_id:
            sub = db.scalar(select(Subscription).where(Subscription.stripe_subscription_id == sub_id))
            if sub:
                sub.status = SubscriptionStatus.PAST_DUE if event_type == "invoice.payment_failed" else SubscriptionStatus.CANCELED
                db.commit()

    return {"status": "ok", "event": event_type}


@router.post("/subscriptions/portal")
def create_portal(user: User = Depends(get_current_user)) -> dict:
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
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, str(exc)) from exc


@router.get("/subscriptions/me")
def my_subscription(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    sub = db.scalar(select(Subscription).where(Subscription.user_id == user.id))
    if not sub:
        # Free plan
        plan = db.scalar(select(Plan).where(Plan.code == "free"))
        return {
            "plan": {"code": "free", "name": "Free", "limits": plan.limits_json if plan else {}},
            "status": "active",
            "current_period_end": None,
            "cancel_at_period_end": False,
        }
    return {
        "plan": {"code": sub.plan.code, "name": sub.plan.name, "limits": sub.plan.limits_json},
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


def check_user_plan(db: Session, user: User) -> dict:
    """Verifica o plano do usuário. Retorna {code, limits, status, payment_ok}."""
    sub = db.scalar(select(Subscription).where(Subscription.user_id == user.id))
    if not sub:
        plan = db.scalar(select(Plan).where(Plan.code == "free"))
        return {"code": "free", "limits": plan.limits_json if plan else {}, "status": "active", "payment_ok": True}
    payment_ok = sub.status in (SubscriptionStatus.ACTIVE, SubscriptionStatus.TRIALING)
    if sub.status == SubscriptionStatus.PAST_DUE:
        payment_ok = False
    return {"code": sub.plan.code, "limits": sub.plan.limits_json, "status": sub.status.value, "payment_ok": payment_ok}