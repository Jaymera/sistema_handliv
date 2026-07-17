from __future__ import annotations

import logging
from datetime import date, datetime, timezone
from decimal import Decimal
from typing import Any

import yfinance as yf

logger = logging.getLogger(__name__)


class YFinanceProvider:
    """Thin wrapper around `yfinance` Ticker to fetch OHLCV + fundamentals + news metadata."""

    def fetch_history(self, symbol: str, timeframe: str = "1d", period: str = "1mo") -> list[dict[str, Any]]:
        try:
            ticker = yf.Ticker(symbol)
            hist = ticker.history(period=period, interval=timeframe)
        except Exception as exc:  # yfinance raises a lot of weird things
            logger.exception("yfinance history failed for %s: %s", symbol, exc)
            return []
        if hist.empty:
            return []

        # Normalize index to UTC datetime and convert to records
        hist.index = hist.index.tz_convert("UTC")
        bars: list[dict[str, Any]] = []
        for idx, row in hist.iterrows():
            bars.append(
                {
                    "trade_date": idx.date().isoformat(),
                    "open": float(row.get("Open")) if row.get("Open") else None,
                    "high": float(row.get("High")) if row.get("High") else None,
                    "low": float(row.get("Low")) if row.get("Low") else None,
                    "close": float(row.get("Close")) if row.get("Close") else None,
                    "volume": int(row.get("Volume")) if row.get("Volume") else None,
                }
            )
        return bars

    def fetch_info(self, symbol: str) -> dict[str, Any]:
        try:
            ticker = yf.Ticker(symbol)
            info = ticker.info or {}
        except Exception as exc:
            logger.exception("yfinance info failed for %s: %s", symbol, exc)
            return {}
        return {
            "name": info.get("longName") or info.get("shortName") or symbol,
            "sector": info.get("sector"),
            "industry": info.get("industry"),
            "currency": info.get("currency") or "USD",
            "pe_ratio": _to_decimal(info.get("trailingPE")),
            "pb_ratio": _to_decimal(info.get("priceToBook")),
            "dividend_yield": _to_decimal(info.get("dividendYield")),
            "roe": _to_decimal(info.get("returnOnEquity")),
            "margin": _to_decimal(info.get("profitMargins")),
            "revenue_growth": _to_decimal(info.get("revenueGrowth")),
            "debt_to_equity": _to_decimal(info.get("debtToEquity")),
            "logo_url": info.get("logo_url"),
        }

    def fetch_quote(self, symbol: str) -> dict[str, Any] | None:
        try:
            ticker = yf.Ticker(symbol)
            fast = ticker.fast_info
            return {
                "last_price": float(fast.last_price),
                "previous_close": float(fast.previous_close),
                "market_cap": float(fast.market_cap) if fast.market_cap else None,
                "currency": fast.currency,
                "fetched_at": datetime.now(timezone=True).isoformat(),
            }
        except Exception as exc:
            logger.exception("yfinance quote failed for %s: %s", symbol, exc)
            return None

    def fetch_news(self, symbol: str, limit: int = 10) -> list[dict[str, Any]]:
        """Fetch recent news for an asset via yfinance."""
        try:
            ticker = yf.Ticker(symbol)
            raw = ticker.news or []
        except Exception as exc:
            logger.exception("yfinance news failed for %s: %s", symbol, exc)
            return []
        items = []
        for entry in raw[:limit]:
            content = entry.get("content", {}) if isinstance(entry, dict) else {}
            title = content.get("title") or entry.get("title", "") if isinstance(entry, dict) else ""
            summary = content.get("summary") or content.get("description") or ""
            url = ""
            if content.get("canonicalUrl"):
                url = content["canonicalUrl"].get("url", "")
            elif content.get("clickThroughUrl"):
                url = content["clickThroughUrl"].get("url", "")
            provider = content.get("provider", {}).get("displayName", "Yahoo") if content.get("provider") else "Yahoo"
            pub = content.get("pubDate") or entry.get("pubDate", "")
            items.append({
                "title": title[:512],
                "summary": summary[:2000] if summary else None,
                "url": url,
                "source": provider,
                "published_at": pub,
            })
        return items


def _to_decimal(v: Any) -> Decimal | None:
    if v is None:
        return None
    try:
        return Decimal(str(v))
    except Exception:
        return None


provider = YFinanceProvider()