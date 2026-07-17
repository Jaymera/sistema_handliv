from __future__ import annotations

import logging
from datetime import datetime, timezone

from sqlalchemy import select

from app.config import settings
from app.infrastructure.database.models import Asset, AssetPrice
from app.infrastructure.database.session import SessionLocal
from app.infrastructure.providers.market_data import provider as market_data
from app.infrastructure.queue.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(name="app.infrastructure.queue.tasks.fetch_prices.fetch_all_prices")
def fetch_all_prices() -> int:
    """Fetch latest OHLCV for all active assets and update DB. Returns count of assets processed."""
    db = SessionLocal()
    try:
        assets = db.scalars(select(Asset).where(Asset.is_active == True)).all()  # noqa: E712
        n = 0
        for asset in assets:
            try:
                bars = market_data.fetch_history(asset.symbol, timeframe="1d", period="1mo")
                upserted = 0
                for bar in bars:
                    trade_date_obj = datetime.strptime(bar["trade_date"], "%Y-%m-%d").date()
                    existing = db.scalar(
                        select(AssetPrice).where(
                            AssetPrice.asset_id == asset.id,
                            AssetPrice.trade_date == trade_date_obj,
                            AssetPrice.timeframe == "1d",
                        )
                    )
                    if existing is None:
                        db.add(
                            AssetPrice(
                                asset_id=asset.id,
                                trade_date=trade_date_obj,
                                timeframe="1d",
                                open=bar["open"],
                                high=bar["high"],
                                low=bar["low"],
                                close=bar["close"],
                                volume=bar["volume"],
                                fetched_at=datetime.now(timezone=True),
                            )
                        )
                        upserted += 1
                    else:
                        existing.open = bar["open"]
                        existing.high = bar["high"]
                        existing.low = bar["low"]
                        existing.close = bar["close"]
                        existing.volume = bar["volume"]
                        existing.fetched_at = datetime.now(timezone=True)
                db.commit()
                n += 1
            except Exception as exc:
                logger.exception("Failed to fetch prices for %s: %s", asset.symbol, exc)
                db.rollback()
        logger.info("fetch_prices: %d assets processed", n)
        from app.infrastructure.queue.tasks.compute_scores import compute_all_scores
        compute_all_scores.delay()
        return n
    finally:
        db.close()