"""Durable per-favorite rules and unique strong-signal epochs."""
import uuid
from datetime import datetime
from decimal import Decimal
from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, Numeric, String, UniqueConstraint
from sqlalchemy.dialects.mysql import CHAR
from sqlalchemy.orm import Mapped, mapped_column
from app.infrastructure.database.base import Base, TimestampMixin


def new_id():
    return str(uuid.uuid4())


class MT5AutomationRule(Base, TimestampMixin):
    __tablename__ = 'mt5_automation_rules'
    __table_args__ = (UniqueConstraint('user_id', 'account_id', 'asset_id', name='uq_automation_rule'),)
    id: Mapped[str] = mapped_column(CHAR(36, charset='ascii'), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(CHAR(36, charset='ascii'), ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    account_id: Mapped[str] = mapped_column(CHAR(36, charset='ascii'), ForeignKey('mt5_accounts.id', ondelete='CASCADE'), nullable=False)
    asset_id: Mapped[str] = mapped_column(CHAR(36, charset='ascii'), ForeignKey('assets.id', ondelete='CASCADE'), nullable=False)
    symbol: Mapped[str] = mapped_column(String(32), nullable=False)
    broker_symbol: Mapped[str] = mapped_column(String(32), nullable=False)
    direction: Mapped[str] = mapped_column(String(4), default='both', nullable=False)
    volume: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    sl_atr_multiplier: Mapped[Decimal] = mapped_column(Numeric(4, 2), default=Decimal('2.00'), server_default='2.00', nullable=False)
    tp_atr_multiplier: Mapped[Decimal] = mapped_column(Numeric(4, 2), default=Decimal('3.00'), server_default='3.00', nullable=False)
    enabled: Mapped[bool] = mapped_column(Boolean, default=False, server_default='0', nullable=False)
    initialized: Mapped[bool] = mapped_column(Boolean, default=False, server_default='0', nullable=False)
    ready: Mapped[bool] = mapped_column(Boolean, default=False, server_default='0', nullable=False)
    generation: Mapped[int] = mapped_column(Integer, default=0, server_default='0', nullable=False)
    last_signal: Mapped[str | None] = mapped_column(String(32))
    last_status: Mapped[str | None] = mapped_column(String(64))


class MT5AutomationEvent(Base, TimestampMixin):
    __tablename__ = 'mt5_automation_events'
    __table_args__ = (UniqueConstraint('rule_id', 'generation', name='uq_automation_event'),)
    id: Mapped[str] = mapped_column(CHAR(36, charset='ascii'), primary_key=True, default=new_id)
    rule_id: Mapped[str] = mapped_column(CHAR(36, charset='ascii'), ForeignKey('mt5_automation_rules.id', ondelete='CASCADE'), nullable=False)
    generation: Mapped[int] = mapped_column(Integer, nullable=False)
    signal: Mapped[str] = mapped_column(String(32), nullable=False)
