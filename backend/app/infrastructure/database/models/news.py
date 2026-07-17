from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from enum import StrEnum

from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, Integer, String, Text, text, Numeric
from sqlalchemy.dialects.mysql import CHAR
from sqlalchemy.orm import Mapped, mapped_column

from app.infrastructure.database.base import Base


def _uuid() -> uuid.UUID:
    return uuid.uuid4()


class SentimentLabel(StrEnum):
    POSITIVE = "positive"
    NEUTRAL = "neutral"
    NEGATIVE = "negative"


class NewsArticle(Base):
    __tablename__ = "news_articles"

    id: Mapped[uuid.UUID] = mapped_column(CHAR(36, charset="ascii"), primary_key=True, default=_uuid)
    asset_id: Mapped[uuid.UUID | None] = mapped_column(
        CHAR(36, charset="ascii"), ForeignKey("assets.id", ondelete="SET NULL"), nullable=True, index=True
    )
    source: Mapped[str] = mapped_column(String(64), nullable=False)
    url: Mapped[str] = mapped_column(String(512), unique=True, nullable=False)
    title: Mapped[str] = mapped_column(String(512), nullable=False)
    summary: Mapped[str | None] = mapped_column(Text, nullable=True)
    language: Mapped[str] = mapped_column(String(8), default="pt-BR", nullable=False)
    published_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    sentiment_label: Mapped[SentimentLabel | None] = mapped_column(Enum(SentimentLabel), nullable=True)
    sentiment_score: Mapped[Decimal | None] = mapped_column(Numeric(6, 4), nullable=True)
    fetched_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=text("CURRENT_TIMESTAMP"), nullable=False
    )


class RSSSource(Base):
    __tablename__ = "rss_sources"

    id: Mapped[uuid.UUID] = mapped_column(CHAR(36, charset="ascii"), primary_key=True, default=_uuid)
    name: Mapped[str] = mapped_column(String(64), nullable=False)
    feed_url: Mapped[str] = mapped_column(String(512), unique=True, nullable=False)
    language: Mapped[str] = mapped_column(String(8), default="pt-BR", nullable=False)
    market: Mapped[str | None] = mapped_column(String(32), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=text("CURRENT_TIMESTAMP"), nullable=False
    )