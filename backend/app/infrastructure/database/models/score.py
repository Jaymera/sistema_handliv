from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from enum import StrEnum

from sqlalchemy import JSON, Boolean, DateTime, Enum, ForeignKey, Integer, Numeric, String, Text, text
from sqlalchemy.dialects.mysql import CHAR
from sqlalchemy.orm import Mapped, mapped_column

from app.infrastructure.database.base import Base


def _uuid() -> uuid.UUID:
    return uuid.uuid4()


class Trend(StrEnum):
    UP = "up"
    DOWN = "down"
    SIDEWAYS = "sideways"


class Horizon(StrEnum):
    SHORT = "short"
    MEDIUM = "medium"
    LONG = "long"


class Score(Base):
    __tablename__ = "scores"

    id: Mapped[uuid.UUID] = mapped_column(CHAR(36, charset="ascii"), primary_key=True, default=_uuid)
    asset_id: Mapped[uuid.UUID] = mapped_column(
        CHAR(36, charset="ascii"), ForeignKey("assets.id", ondelete="CASCADE"), nullable=False
    )
    timeframe: Mapped[str] = mapped_column(String(8), default="1d", nullable=False)
    technical_score: Mapped[int | None] = mapped_column(Integer, nullable=True)
    valuation_score: Mapped[int | None] = mapped_column(Integer, nullable=True)
    sentiment_score: Mapped[int | None] = mapped_column(Integer, nullable=True)
    final_score: Mapped[int | None] = mapped_column(Integer, nullable=True)
    buyer_strength: Mapped[int | None] = mapped_column(Integer, nullable=True)
    seller_strength: Mapped[int | None] = mapped_column(Integer, nullable=True)
    confidence: Mapped[int | None] = mapped_column(Integer, nullable=True)
    trend: Mapped[Trend | None] = mapped_column(Enum(Trend), nullable=True)
    horizon: Mapped[Horizon | None] = mapped_column(Enum(Horizon), nullable=True)
    weights_json: Mapped[dict] = mapped_column(JSON, default=dict, nullable=False)
    inputs_log_json: Mapped[dict] = mapped_column(JSON, default=dict, nullable=False)
    calculated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)


class ScoreWeights(Base):
    __tablename__ = "score_weights"

    id: Mapped[uuid.UUID] = mapped_column(CHAR(36, charset="ascii"), primary_key=True, default=_uuid)
    name: Mapped[str] = mapped_column(String(64), nullable=False)
    technical_weight: Mapped[Decimal] = mapped_column(Numeric(5, 4), nullable=False, default=Decimal("0.4000"))
    valuation_weight: Mapped[Decimal] = mapped_column(Numeric(5, 4), nullable=False, default=Decimal("0.3500"))
    sentiment_weight: Mapped[Decimal] = mapped_column(Numeric(5, 4), nullable=False, default=Decimal("0.2500"))
    min_confidence: Mapped[int] = mapped_column(Integer, default=50, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)