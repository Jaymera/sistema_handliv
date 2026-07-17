from __future__ import annotations

import logging
from datetime import datetime, timezone

import pandas as pd
from sqlalchemy import select

from app.config import settings
from app.domain.decision_engine import decide
from app.infrastructure.cache import cache
from app.infrastructure.database.models import (
    Asset,
    AssetFundamental,
    NewsArticle,
    Score,
    ScoreWeights,
)
from app.infrastructure.database.session import SessionLocal
from app.infrastructure.providers.market_data import provider as market_data
from app.infrastructure.queue.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(name="app.infrastructure.queue.tasks.compute_scores.compute_all_scores")
def compute_all_scores() -> int:
    """Recompute scores for all active assets after price/news fetch. Stores the result
    in DB + writes a Redis cache key for the API to consume."""
    db = SessionLocal()
    try:
        assets = db.scalars(select(Asset).where(Asset.is_active == True)).all()  # noqa: E712
        weights_row = db.scalar(select(ScoreWeights).where(ScoreWeights.is_active == True))  # noqa: E712
        weights = {
            "technical": float(weights_row.technical_weight) if weights_row else 0.40,
            "valuation": float(weights_row.valuation_weight) if weights_row else 0.35,
            "sentiment": float(weights_row.sentiment_weight) if weights_row else 0.25,
        }
        n = 0
        for asset in assets:
            try:
                bars = market_data.fetch_history(asset.symbol, timeframe="1d", period="6mo")
                if not bars:
                    continue
                df = pd.DataFrame(bars)
                df["close"] = pd.to_numeric(df["close"], errors="coerce")
                df["high"] = pd.to_numeric(df["high"], errors="coerce")
                df["low"] = pd.to_numeric(df["low"], errors="coerce")
                df["open"] = pd.to_numeric(df["open"], errors="coerce")
                df["volume"] = pd.to_numeric(df["volume"], errors="coerce")
                df = df.dropna(subset=["close", "high", "low"]).reset_index(drop=True)

                info = market_data.fetch_info(asset.symbol)
                quote = market_data.fetch_quote(asset.symbol)
                last_price = quote.get("last_price") if quote else None

                fundamentals = db.scalar(
                    select(AssetFundamental)
                    .where(AssetFundamental.asset_id == asset.id)
                    .order_by(AssetFundamental.snapshot_date.desc())
                )
                if fundamentals is not None:
                    for k in ("pe_ratio", "pb_ratio", "dividend_yield", "roe", "debt_to_equity"):
                        if getattr(fundamentals, k) is not None:
                            info[k] = float(getattr(fundamentals, k))

                articles = db.scalars(
                    select(NewsArticle)
                    .where(NewsArticle.asset_id == asset.id)
                    .order_by(NewsArticle.published_at.desc())
                    .limit(20)
                ).all()
                sentiments = [float(a.sentiment_score) for a in articles if a.sentiment_score is not None]

                result = decide(df, info, last_price, sentiments, weights)

                score_row = Score(
                    asset_id=asset.id,
                    timeframe="1d",
                    technical_score=result.technical.value,
                    valuation_score=result.valuation.value,
                    sentiment_score=result.sentiment.value,
                    final_score=result.final_score,
                    buyer_strength=result.buyer_strength,
                    seller_strength=result.seller_strength,
                    confidence=result.confidence,
                    trend=result.trend,
                    horizon=result.horizon,
                    weights_json=weights,
                    inputs_log_json=result.inputs_log,
                    calculated_at=datetime.now(timezone=True),
                )
                db.add(score_row)
                db.commit()

                cache.set_json(
                    f"score:{asset.symbol}:1d",
                    {"final_score": score_row.final_score, "calculated_at": score_row.calculated_at.isoformat()},
                    ttl_seconds=86400,
                )
                n += 1
            except Exception as exc:
                logger.exception("Failed score for %s: %s", asset.symbol, exc)
                db.rollback()
        logger.info("compute_scores: %d assets processed", n)
        return n
    finally:
        db.close()