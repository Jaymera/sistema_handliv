from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal
from enum import StrEnum

from sqlalchemy import JSON, BigInteger, Date, DateTime, Enum, ForeignKey, Integer, String, text, Numeric
from sqlalchemy.dialects.mysql import CHAR
from sqlalchemy.orm import Mapped, mapped_column

from app.infrastructure.database.base import Base, TimestampMixin


def _uuid() -> uuid.UUID:
    return uuid.uuid4()


class BacktestStatus(StrEnum):
    QUEUED = "queued"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"


class Backtest(Base, TimestampMixin):
    __tablename__ = "backtests"

    id: Mapped[uuid.UUID] = mapped_column(CHAR(36, charset="ascii"), primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        CHAR(36, charset="ascii"), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    asset_id: Mapped[uuid.UUID] = mapped_column(
        CHAR(36, charset="ascii"), ForeignKey("assets.id", ondelete="CASCADE"), nullable=False
    )
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date] = mapped_column(Date, nullable=False)
    timeframe: Mapped[str] = mapped_column(String(8), default="1d", nullable=False)
    strategy_config_json: Mapped[dict] = mapped_column(JSON, default=dict, nullable=False)
    total_return_pct: Mapped[Decimal | None] = mapped_column(Numeric(12, 4), nullable=True)
    sharpe: Mapped[Decimal | None] = mapped_column(Numeric(10, 4), nullable=True)
    sortino: Mapped[Decimal | None] = mapped_column(Numeric(10, 4), nullable=True)
    max_drawdown_pct: Mapped[Decimal | None] = mapped_column(Numeric(12, 4), nullable=True)
    win_rate: Mapped[Decimal | None] = mapped_column(Numeric(8, 4), nullable=True)
    profit_factor: Mapped[Decimal | None] = mapped_column(Numeric(12, 4), nullable=True)
    num_trades: Mapped[int | None] = mapped_column(Integer, nullable=True)
    equity_curve_json: Mapped[list] = mapped_column(JSON, default=list, nullable=False)
    drawdown_curve_json: Mapped[list] = mapped_column(JSON, default=list, nullable=False)
    status: Mapped[BacktestStatus] = mapped_column(
        Enum(BacktestStatus), default=BacktestStatus.QUEUED, nullable=False
    )
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    error: Mapped[str | None] = mapped_column(String(512), nullable=True)


class BacktestTrade(Base):
    __tablename__ = "backtest_trades"

    id: Mapped[uuid.UUID] = mapped_column(CHAR(36, charset="ascii"), primary_key=True, default=_uuid)
    backtest_id: Mapped[uuid.UUID] = mapped_column(
        CHAR(36, charset="ascii"), ForeignKey("backtests.id", ondelete="CASCADE"), nullable=False, index=True
    )
    entry_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    exit_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    side: Mapped[str] = mapped_column(String(8), nullable=False)
    entry_price: Mapped[Decimal] = mapped_column(Numeric(18, 6), nullable=False)
    exit_price: Mapped[Decimal | None] = mapped_column(Numeric(18, 6), nullable=True)
    quantity: Mapped[Decimal] = mapped_column(Numeric(18, 6), nullable=False)
    pnl: Mapped[Decimal | None] = mapped_column(Numeric(18, 6), nullable=True)