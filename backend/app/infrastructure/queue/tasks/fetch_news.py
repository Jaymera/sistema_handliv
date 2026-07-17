from __future__ import annotations

import logging
from datetime import datetime, timezone

import feedparser
from sqlalchemy import select

from app.domain.constants import RSS_SOURCES
from app.infrastructure.database.models import Asset, NewsArticle, RSSSource
from app.infrastructure.database.session import SessionLocal
from app.infrastructure.queue.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(name="app.infrastructure.queue.tasks.fetch_news.fetch_all_news")
def fetch_all_news() -> int:
    """Fetch news from all active RSS sources and persist articles.
    Sentiment analysis is deferred to a follow-up pass (uses local NLP libs lazily)."""
    db = SessionLocal()
    try:
        seen_urls = set(db.scalars(select(NewsArticle.url)).all())
        assets_by_symbol = {a.symbol: a for a in db.scalars(select(Asset)).all()}

        sources = db.scalars(select(RSSSource).where(RSSSource.is_active == True)).all()  # noqa: E712
        if not sources:
            for src in RSS_SOURCES:
                db.add(RSSSource(**src))
            db.commit()
            sources = db.scalars(select(RSSSource).where(RSSSource.is_active == True)).all()  # noqa: E712

        n = 0
        for src in sources:
            try:
                parsed = feedparser.parse(src.feed_url)
                for entry in parsed.entries[:20]:
                    url = (entry.get("link") or "").strip()
                    if not url or url in seen_urls:
                        continue
                    seen_urls.add(url)
                    title = (entry.get("title") or "").strip()[:512]
                    pub = entry.get("published_parsed")
                    published_at = datetime(*pub[:6], tzinfo=timezone.utc) if pub else datetime.now(timezone.utc)
                    asset_id = _match_asset(title, assets_by_symbol)

                    db.add(
                        NewsArticle(
                            asset_id=asset_id,
                            source=src.name,
                            url=url,
                            title=title,
                            language=src.language,
                            published_at=published_at,
                            fetched_at=datetime.now(timezone.utc),
                        )
                    )
                    n += 1
            except Exception as exc:
                logger.exception("Failed RSS %s: %s", src.feed_url, exc)
                db.rollback()
        db.commit()
        logger.info("fetch_news: %d articles added", n)
        return n
    finally:
        db.close()


def _match_asset(title: str, assets_by_symbol: dict[str, Asset]) -> object | None:
    title_upper = title.upper()
    for symbol, asset in assets_by_symbol.items():
        display = symbol.replace(".SA", "").upper()
        if display and display in title_upper:
            return asset.id
    return None