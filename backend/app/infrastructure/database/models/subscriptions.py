from __future__ import annotations

import uuid
from datetime import datetime
from enum import StrEnum

from sqlalchemy import JSON, Boolean, DateTime, Enum, ForeignKey, Integer, String, text
from sqlalchemy.dialects.mysql import CHAR
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.infrastructure.database.base import Base, TimestampMixin
from app.infrastructure.database.models.users import User


def _uuid() -> uuid.UUID:
    return uuid.uuid4()


class PlanCode(StrEnum):
    FREE = "free"
    PRO = "pro"
    PREMIUM = "premium"


class Plan(Base, TimestampMixin):
    __tablename__ = "plans"

    id: Mapped[uuid.UUID] = mapped_column(CHAR(36, charset="ascii"), primary_key=True, default=_uuid)
    code: Mapped[str] = mapped_column(String(32), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(64), nullable=False)
    stripe_price_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    price_monthly_cents: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    price_yearly_cents: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    limits_json: Mapped[dict] = mapped_column(JSON, default=dict, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    subscriptions: Mapped[list[Subscription]] = relationship(back_populates="plan")


class SubscriptionStatus(StrEnum):
    ACTIVE = "active"
    PAST_DUE = "past_due"
    CANCELED = "canceled"
    TRIALING = "trialing"


class Subscription(Base, TimestampMixin):
    __tablename__ = "subscriptions"

    id: Mapped[uuid.UUID] = mapped_column(CHAR(36, charset="ascii"), primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        CHAR(36, charset="ascii"), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False, index=True
    )
    plan_id: Mapped[uuid.UUID] = mapped_column(
        CHAR(36, charset="ascii"), ForeignKey("plans.id"), nullable=False
    )
    stripe_customer_id: Mapped[str | None] = mapped_column(String(128), nullable=True, index=True)
    stripe_subscription_id: Mapped[str | None] = mapped_column(String(128), nullable=True, index=True)
    status: Mapped[SubscriptionStatus] = mapped_column(
        Enum(SubscriptionStatus), default=SubscriptionStatus.ACTIVE, nullable=False
    )
    current_period_end: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    cancel_at_period_end: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    user: Mapped[User] = relationship(back_populates="subscriptions")
    plan: Mapped[Plan] = relationship(back_populates="subscriptions")


class PaymentEvent(Base):
    __tablename__ = "payment_events"

    id: Mapped[uuid.UUID] = mapped_column(CHAR(36, charset="ascii"), primary_key=True, default=_uuid)
    subscription_id: Mapped[uuid.UUID | None] = mapped_column(
        CHAR(36, charset="ascii"), ForeignKey("subscriptions.id", ondelete="SET NULL"), nullable=True
    )
    stripe_event_id: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    event_type: Mapped[str] = mapped_column(String(64), nullable=False)
    payload_json: Mapped[dict] = mapped_column(JSON, default=dict, nullable=False)
    processed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=text("CURRENT_TIMESTAMP"), nullable=False
    )