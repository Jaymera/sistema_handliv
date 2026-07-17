from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal
from enum import StrEnum

from sqlalchemy import JSON, BigInteger, Boolean, Date, DateTime, Enum, ForeignKey, Integer, Numeric, String, Text, text
from sqlalchemy.dialects.mysql import CHAR
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.infrastructure.database.base import Base, TimestampMixin


def _uuid() -> uuid.UUID:
    return uuid.uuid4()


class Market(StrEnum):
    B3 = "B3"
    NYSE = "NYSE"
    NASDAQ = "NASDAQ"
    FOREX = "FOREX"
    CRYPTO = "CRYPTO"
    COMMODITY = "COMMODITY"


class AssetType(StrEnum):
    STOCK = "stock"
    FII = "fii"
    ETF = "etf"
    BDR = "bdr"
    REIT = "reit"
    FOREX = "forex"
    CRYPTO = "crypto"
    COMMODITY = "commodity"


class Asset(Base, TimestampMixin):
    __tablename__ = "assets"

    id: Mapped[uuid.UUID] = mapped_column(CHAR(36, charset="ascii"), primary_key=True, default=_uuid)
    symbol: Mapped[str] = mapped_column(String(32), unique=True, nullable=False, index=True)
    display_symbol: Mapped[str] = mapped_column(String(32), nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    market: Mapped[Market] = mapped_column(Enum(Market, values_callable=lambda x: [e.value for e in x]), nullable=False, index=True)
    asset_type: Mapped[AssetType] = mapped_column(Enum(AssetType, values_callable=lambda x: [e.value for e in x]), nullable=False)
    sector: Mapped[str | None] = mapped_column(String(64), nullable=True)
    industry: Mapped[str | None] = mapped_column(String(64), nullable=True)
    currency: Mapped[str] = mapped_column(String(8), nullable=False)
    logo_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)


class AssetPrice(Base):
    __tablename__ = "asset_prices"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    asset_id: Mapped[uuid.UUID] = mapped_column(
        CHAR(36, charset="ascii"), ForeignKey("assets.id", ondelete="CASCADE"), nullable=False
    )
    trade_date: Mapped[date] = mapped_column(Date, nullable=False)
    timeframe: Mapped[str] = mapped_column(String(8), nullable=False, default="1d")
    open: Mapped[Decimal | None] = mapped_column(Numeric(18, 6), nullable=True)
    high: Mapped[Decimal | None] = mapped_column(Numeric(18, 6), nullable=True)
    low: Mapped[Decimal | None] = mapped_column(Numeric(18, 6), nullable=True)
    close: Mapped[Decimal | None] = mapped_column(Numeric(18, 6), nullable=True)
    volume: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    fetched_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=text("CURRENT_TIMESTAMP"), nullable=False
    )


class AssetFundamental(Base):
    __tablename__ = "asset_fundamentals"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    asset_id: Mapped[uuid.UUID] = mapped_column(
        CHAR(36, charset="ascii"), ForeignKey("assets.id", ondelete="CASCADE"), nullable=False
    )
    snapshot_date: Mapped[date] = mapped_column(Date, nullable=False)
    pe_ratio: Mapped[Decimal | None] = mapped_column(Numeric(12, 4), nullable=True)
    pb_ratio: Mapped[Decimal | None] = mapped_column(Numeric(12, 4), nullable=True)
    dividend_yield: Mapped[Decimal | None] = mapped_column(Numeric(8, 4), nullable=True)
    roe: Mapped[Decimal | None] = mapped_column(Numeric(8, 4), nullable=True)
    margin: Mapped[Decimal | None] = mapped_column(Numeric(8, 4), nullable=True)
    revenue_growth: Mapped[Decimal | None] = mapped_column(Numeric(8, 4), nullable=True)
    debt_to_equity: Mapped[Decimal | None] = mapped_column(Numeric(12, 4), nullable=True)
    dcf_intrinsic_value: Mapped[Decimal | None] = mapped_column(Numeric(18, 6), nullable=True)
    sub_score_valuation: Mapped[int | None] = mapped_column(Integer, nullable=True)
    payload_json: Mapped[dict] = mapped_column(JSON, default=dict, nullable=False)
    fetched_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=text("CURRENT_TIMESTAMP"), nullable=False
    )