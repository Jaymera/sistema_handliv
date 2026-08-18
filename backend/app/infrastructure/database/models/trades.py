from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import DateTime, ForeignKey, Integer, Numeric, String, Text, UniqueConstraint, text
from sqlalchemy.dialects.mysql import CHAR
from sqlalchemy.orm import Mapped, mapped_column

from app.infrastructure.database.base import Base, TimestampMixin


def _uuid() -> uuid.UUID:
    return uuid.uuid4()


class TradeRecord(Base, TimestampMixin):
    __tablename__ = "trade_records"

    id: Mapped[uuid.UUID] = mapped_column(CHAR(36, charset="ascii"), primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        CHAR(36, charset="ascii"), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    asset_symbol: Mapped[str] = mapped_column(String(32), nullable=False)
    result_pct: Mapped[Decimal] = mapped_column(Numeric(8, 2), nullable=False)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)


class MT5Command(Base, TimestampMixin):
    """Comando do painel web (comprar/vender/fechar) para ser executado pelo EA no MT5."""

    __tablename__ = "mt5_commands"

    id: Mapped[uuid.UUID] = mapped_column(CHAR(36, charset="ascii"), primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        CHAR(36, charset="ascii"), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    account_number: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    action: Mapped[str] = mapped_column(String(10), nullable=False)  # buy | sell | close
    symbol: Mapped[str | None] = mapped_column(String(32), nullable=True)
    volume: Mapped[Decimal | None] = mapped_column(Numeric(10, 2), nullable=True)
    status: Mapped[str] = mapped_column(String(16), nullable=False, default="pending", index=True)
    # pending -> sent -> executed | failed
    result_message: Mapped[str | None] = mapped_column(Text, nullable=True)
    sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    executed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class MT5AccountStats(Base, TimestampMixin):
    """Snapshot das estatísticas da conta MT5 reportadas pelo EA HandlivPanel (DD, P/L, win rate)."""

    __tablename__ = "mt5_account_stats"
    __table_args__ = (UniqueConstraint("account_number", name="uq_mt5_stats_account"),)

    id: Mapped[uuid.UUID] = mapped_column(CHAR(36, charset="ascii"), primary_key=True, default=_uuid)
    account_number: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    login: Mapped[str] = mapped_column(String(64), nullable=False, default="")
    currency: Mapped[str] = mapped_column(String(16), nullable=False, default="USD")
    equity: Mapped[Decimal] = mapped_column(Numeric(16, 2), nullable=False, default=0)
    balance: Mapped[Decimal] = mapped_column(Numeric(16, 2), nullable=False, default=0)
    margin: Mapped[Decimal] = mapped_column(Numeric(16, 2), nullable=False, default=0)
    margin_level: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False, default=0)
    floating_pl: Mapped[Decimal] = mapped_column(Numeric(16, 2), nullable=False, default=0)
    dd_percent: Mapped[Decimal] = mapped_column(Numeric(8, 2), nullable=False, default=0)
    profit_day: Mapped[Decimal] = mapped_column(Numeric(16, 2), nullable=False, default=0)
    profit_week: Mapped[Decimal] = mapped_column(Numeric(16, 2), nullable=False, default=0)
    profit_month: Mapped[Decimal] = mapped_column(Numeric(16, 2), nullable=False, default=0)
    profit_total: Mapped[Decimal] = mapped_column(Numeric(16, 2), nullable=False, default=0)
    win_trades: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    loss_trades: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    total_trades: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    open_positions: Mapped[int] = mapped_column(Integer, nullable=False, default=0)