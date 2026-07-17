from __future__ import annotations

import uuid
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.domain.local_ai import explain_indicators, explain_score, summarize_news
from app.infrastructure.cache import cache
from app.infrastructure.database.models import (
    Asset,
    AssetFundamental,
    AssetPrice,
    NewsArticle,
    Score,
)
from app.infrastructure.database.session import get_db
from app.infrastructure.providers.market_data import provider as market_data

router = APIRouter()


def _get_asset_by_symbol(db: Session, symbol: str) -> Asset:
    sym = symbol.upper()
    asset = db.scalar(select(Asset).where(Asset.symbol == sym))
    if asset is None and sym == "PETR4":
        asset = db.scalar(select(Asset).where(Asset.symbol == "PETR4.SA"))
    if asset is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "asset not found")
    return asset


@router.get("/assets")
def list_assets(
    q: str | None = None,
    market: str | None = None,
    type: str | None = None,
    page: int = Query(1, ge=1),
    limit: int = Query(20, le=100),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    stmt = select(Asset).where(Asset.is_active == True)  # noqa: E712
    if q:
        q_upper = q.upper()
        stmt = stmt.where(or_(Asset.symbol.ilike(f"%{q_upper}%"), Asset.name.ilike(f"%{q_upper}%")))
    if market:
        stmt = stmt.where(Asset.market == market.upper())
    if type:
        stmt = stmt.where(Asset.asset_type == type.lower())

    from sqlalchemy import func
    count_stmt = select(func.count()).select_from(Asset).where(Asset.is_active == True)  # noqa: E712
    if q:
        q_upper = q.upper()
        count_stmt = count_stmt.where(or_(Asset.symbol.ilike(f"%{q_upper}%"), Asset.name.ilike(f"%{q_upper}%")))
    if market:
        count_stmt = count_stmt.where(Asset.market == market.upper())
    if type:
        count_stmt = count_stmt.where(Asset.asset_type == type.lower())
    total = db.scalar(count_stmt) or 0

    items = list(db.scalars(stmt.offset((page - 1) * limit).limit(limit)).all())
    return {
        "items": [
            {
                "id": a.id,
                "symbol": a.symbol,
                "display_symbol": a.display_symbol,
                "name": a.name,
                "market": a.market.value,
                "asset_type": a.asset_type.value,
                "currency": a.currency,
                "logo_url": a.logo_url,
            }
            for a in items
        ],
        "total": total,
        "page": page,
        "limit": limit,
    }


@router.get("/assets/{symbol}")
def get_asset(symbol: str, db: Session = Depends(get_db)) -> dict[str, Any]:
    asset = _get_asset_by_symbol(db, symbol)
    fund = db.scalar(
        select(AssetFundamental).where(AssetFundamental.asset_id == asset.id).order_by(AssetFundamental.snapshot_date.desc())
    )
    score = db.scalar(select(Score).where(Score.asset_id == asset.id).order_by(Score.calculated_at.desc()))
    quote_cached = cache.get_json(f"quote:{asset.symbol}") or {}
    return {
        "id": asset.id,
        "symbol": asset.symbol,
        "name": asset.name,
        "market": asset.market.value,
        "currency": asset.currency,
        "sector": asset.sector,
        "industry": asset.industry,
        "fundamentals": {
            "pe_ratio": float(fund.pe_ratio) if fund and fund.pe_ratio else None,
            "pb_ratio": float(fund.pb_ratio) if fund and fund.pb_ratio else None,
            "dividend_yield": float(fund.dividend_yield) if fund and fund.dividend_yield else None,
            "roe": float(fund.roe) if fund and fund.roe else None,
            "margin": float(fund.margin) if fund and fund.margin else None,
            "revenue_growth": float(fund.revenue_growth) if fund and fund.revenue_growth else None,
            "debt_to_equity": float(fund.debt_to_equity) if fund and fund.debt_to_equity else None,
            "dcf_intrinsic_value": float(fund.dcf_intrinsic_value) if fund and fund.dcf_intrinsic_value else None,
            "sub_score_valuation": fund.sub_score_valuation if fund else None,
        },
        "last_price": quote_cached,
        "score": {
            "final_score": score.final_score if score else None,
            "calculated_at": score.calculated_at.isoformat() if score else None,
        },
    }


@router.get("/assets/{symbol}/price")
def get_price_history(
    symbol: str,
    timeframe: str = "1d",
    period: str = "1mo",
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    asset = _get_asset_by_symbol(db, symbol)
    cache_key = f"price:{asset.symbol}:{timeframe}:{period}"
    cached = cache.get_json(cache_key)
    if cached:
        return cached
    bars = market_data.fetch_history(asset.symbol, timeframe=timeframe, period=period)
    payload = {"symbol": asset.symbol, "timeframe": timeframe, "bars": bars}
    cache.set_json(cache_key, payload, ttl_seconds=21600)
    return payload


@router.get("/assets/{symbol}/fundamentals")
def get_fundamentals(symbol: str, db: Session = Depends(get_db)) -> dict[str, Any]:
    asset = _get_asset_by_symbol(db, symbol)
    info_cached = cache.get_json(f"info:{asset.symbol}")
    if info_cached:
        return info_cached
    info = market_data.fetch_info(asset.symbol)
    cache.set_json(f"info:{asset.symbol}", info, ttl_seconds=86400)
    return info


@router.get("/assets/{symbol}/indicators")
def get_indicators(symbol: str, timeframe: str = "1d", period: str = "6mo", db: Session = Depends(get_db)) -> dict[str, Any]:
    asset = _get_asset_by_symbol(db, symbol)
    bars = market_data.fetch_history(asset.symbol, timeframe=timeframe, period=period)
    if not bars:
        return {"symbol": asset.symbol, "indicators": {}}
    import pandas as pd
    import pandas_ta as ta  # type: ignore

    df = pd.DataFrame(bars)
    df["close"] = pd.to_numeric(df["close"], errors="coerce")
    out: dict[str, Any] = {}
    try:
        out["rsi"] = float(ta.rsi(df["close"], length=14).iloc[-1])
    except Exception:
        pass
    try:
        out["ema20"] = float(ta.ema(df["close"], length=20).iloc[-1])
        out["ema50"] = float(ta.ema(df["close"], length=50).iloc[-1])
    except Exception:
        pass
    try:
        macd = ta.macd(df["close"]).iloc[-1]
        out["macd"] = {"macd": float(macd["MACD_12_26_9"]), "signal": float(macd["MACDs_12_26_9"])}
    except Exception:
        pass
    return {"symbol": asset.symbol, "indicators": out}


@router.get("/assets/{symbol}/news")
def get_news(symbol: str, page: int = 1, limit: int = 20, db: Session = Depends(get_db)) -> dict[str, Any]:
    asset = _get_asset_by_symbol(db, symbol)
    stmt = (
        select(NewsArticle)
        .where(NewsArticle.asset_id == asset.id)
        .order_by(NewsArticle.published_at.desc())
    )
    items = list(db.scalars(stmt.offset((page - 1) * limit).limit(limit)).all())
    return {
        "items": [
            {
                "id": n.id,
                "title": n.title,
                "summary": n.summary,
                "url": n.url,
                "source": n.source,
                "language": n.language,
                "sentiment": {"label": n.sentiment_label.value if n.sentiment_label else None, "score": float(n.sentiment_score) if n.sentiment_score else None},
                "published_at": n.published_at.isoformat(),
            }
            for n in items
        ]
    }


@router.get("/assets/{symbol}/score")
def get_score(symbol: str, db: Session = Depends(get_db)) -> dict[str, Any]:
    asset = _get_asset_by_symbol(db, symbol)
    score = db.scalar(select(Score).where(Score.asset_id == asset.id).order_by(Score.calculated_at.desc()))
    if score is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "score not computed yet")
    articles = list(db.scalars(select(NewsArticle).where(NewsArticle.asset_id == asset.id).order_by(NewsArticle.published_at.desc()).limit(5)).all())
    summary_full = summarize_news([{"title": a.title, "sentiment_label": a.sentiment_label.value if a.sentiment_label else None} for a in articles])
    explanation = explain_score(_DecisionResultAdapter(score), asset.symbol)
    indicators_explanation = explain_indicators(score.inputs_log_json.get("technical") if score.inputs_log_json else {})
    return {
        "final_score": score.final_score,
        "buyer_strength": score.buyer_strength,
        "seller_strength": score.seller_strength,
        "confidence": score.confidence,
        "trend": score.trend.value if score.trend else None,
        "horizon": score.horizon.value if score.horizon else None,
        "subscores": {
            "technical": score.technical_score,
            "valuation": score.valuation_score,
            "sentiment": score.sentiment_score,
        },
        "ai_explanation": explanation,
        "indicators_explanation": indicators_explanation,
        "news_summary": summary_full,
        "calculated_at": score.calculated_at.isoformat(),
    }


@router.get("/assets/{symbol}/live-analysis")
def live_analysis(symbol: str, db: Session = Depends(get_db)) -> dict[str, Any]:
    """Compute a live analysis (score, indicators, fundamentals, recommendation) on the fly."""
    asset = _get_asset_by_symbol(db, symbol)

    # --- Market data ---
    bars = market_data.fetch_history(asset.symbol, timeframe="1d", period="6mo")
    import pandas as pd
    df = pd.DataFrame(bars) if bars else pd.DataFrame()
    if not df.empty and "close" in df.columns:
        df["close"] = pd.to_numeric(df["close"], errors="coerce")

    # --- Fundamentals ---
    info_raw = market_data.fetch_info(asset.symbol) or {}
    info = {
        "pe_ratio": _to_float(info_raw.get("pe_ratio")),
        "pb_ratio": _to_float(info_raw.get("pb_ratio")),
        "dividend_yield": _to_float(info_raw.get("dividend_yield")),
        "roe": _to_float(info_raw.get("roe")),
        "debt_to_equity": _to_float(info_raw.get("debt_to_equity")),
        "revenue_growth": _to_float(info_raw.get("revenue_growth")),
    }
    last_price = float(df["close"].iloc[-1]) if not df.empty and "close" in df.columns else None

    # --- Decision engine ---
    from app.domain.decision_engine import decide
    from app.domain.local_ai import explain_score, explain_indicators, summarize_news

    # Try DB articles first, then fetch from yfinance live
    articles = list(db.scalars(
        select(NewsArticle).where(NewsArticle.asset_id == asset.id).order_by(NewsArticle.published_at.desc()).limit(10)
    ).all())

    db_article_titles = [{"title": a.title, "sentiment_label": a.sentiment_label.value if a.sentiment_label else None} for a in articles]
    db_sentiments = [float(a.sentiment_score) for a in articles if a.sentiment_score is not None]

    # Fetch live news from yfinance
    live_news = market_data.fetch_news(asset.symbol, limit=10)

    # Analyze sentiment of live news
    news_items_with_sentiment: list[dict[str, Any]] = []
    live_sentiments: list[float] = []
    try:
        from vaderSentiment.vaderSentiment import SentimentIntensityAnalyzer
        sia = SentimentIntensityAnalyzer()
    except Exception:
        sia = None

    for n in live_news:
        text = (n.get("title") or "") + " " + (n.get("summary") or "")
        label = None
        score = None
        if sia and text.strip():
            compound = sia.polarity_scores(text)["compound"]
            score = compound
            if compound >= 0.05:
                label = "positive"
            elif compound <= -0.05:
                label = "negative"
            else:
                label = "neutral"
            live_sentiments.append(compound)
        news_items_with_sentiment.append({
            "title": n.get("title", ""),
            "summary": n.get("summary"),
            "url": n.get("url", ""),
            "source": n.get("source", ""),
            "published_at": n.get("published_at", ""),
            "sentiment_label": label,
            "sentiment_score": score,
        })

    # Combine: prefer live news (with sentiment), fallback to DB
    all_news = news_items_with_sentiment if news_items_with_sentiment else db_article_titles
    all_sentiments = live_sentiments if live_sentiments else db_sentiments

    # Latest news = highest weight (2x) in sentiment calculation
    if all_sentiments:
        latest = all_sentiments[0]
        sentiment_scores = [latest] * 2 + all_sentiments[1:]
    else:
        sentiment_scores = []

    # Fetch weights from DB (or default)
    from app.infrastructure.database.models import ScoreWeights
    sw = db.scalar(select(ScoreWeights).where(ScoreWeights.is_active == True))  # noqa: E712
    weights = {
        "technical": float(sw.technical_weight) if sw else 0.40,
        "valuation": float(sw.valuation_weight) if sw else 0.35,
        "sentiment": float(sw.sentiment_weight) if sw else 0.25,
    }

    result = decide(df, info, last_price, sentiment_scores, weights)

    # --- News ---
    news_items = all_news

    # --- Technical indicators (exposed) ---
    indicators: dict[str, Any] = {}
    if not df.empty and len(df) >= 14:
        try:
            import pandas_ta as ta  # type: ignore
            indicators["rsi"] = float(ta.rsi(df["close"], length=14).iloc[-1])
        except Exception:
            pass
        try:
            indicators["ema20"] = float(ta.ema(df["close"], length=20).iloc[-1]) if len(df) >= 20 else None
            indicators["ema50"] = float(ta.ema(df["close"], length=50).iloc[-1]) if len(df) >= 50 else None
        except Exception:
            pass
        try:
            macd_row = ta.macd(df["close"]).iloc[-1]
            indicators["macd"] = float(macd_row["MACD_12_26_9"])
            indicators["macd_signal"] = float(macd_row["MACDs_12_26_9"])
        except Exception:
            pass

    # Recommendation text
    if result.final_score >= 70:
        recommendation = "COMPRA FORTE"
        recommendation_color = "green"
    elif result.final_score >= 55:
        recommendation = "COMPRA MODERADA"
        recommendation_color = "lime"
    elif result.final_score >= 45:
        recommendation = "NEUTRO"
        recommendation_color = "amber"
    elif result.final_score >= 30:
        recommendation = "VENDA MODERADA"
        recommendation_color = "orange"
    else:
        recommendation = "VENDA FORTE"
        recommendation_color = "red"

    return {
        "symbol": asset.symbol,
        "name": asset.name,
        "market": asset.market.value,
        "currency": asset.currency,
        "sector": info_raw.get("sector") or asset.sector,
        "industry": info_raw.get("industry") or asset.industry,
        "last_price": last_price,
        "fundamentals": info,
        "indicators": indicators,
        "score": {
            "final_score": result.final_score,
            "buyer_strength": result.buyer_strength,
            "seller_strength": result.seller_strength,
            "confidence": result.confidence,
            "trend": result.trend,
            "horizon": result.horizon,
            "subscores": {
                "technical": result.technical.value,
                "valuation": result.valuation.value,
                "sentiment": result.sentiment.value,
            },
        },
        "recommendation": recommendation,
        "recommendation_color": recommendation_color,
        "ai_explanation": explain_score(result, asset.symbol),
        "indicators_explanation": explain_indicators(result.technical.inputs),
        "news_summary": summarize_news(news_items),
        "news_items": news_items_with_sentiment[:5],
        "technical_votes": result.technical.inputs.get("votes", {}),
        "price_history": bars[-30:] if bars else [],
    }


def _to_float(v: Any) -> float | None:
    if v is None:
        return None
    try:
        return float(v)
    except (ValueError, TypeError):
        return None


class _DecisionResultAdapter:
    """Adapter to expose to domain.local_ai.explain_score a duck-typed result row."""

    def __init__(self, score: Score) -> None:
        self.final_score = score.final_score or 0
        self.buyer_strength = score.buyer_strength or 0
        self.seller_strength = score.seller_strength or 0
        self.confidence = score.confidence or 0
        self.trend = score.trend.value if score.trend else "sideways"
        self.horizon = score.horizon.value if score.horizon else "medium"

        class _S:
            def __init__(self, v: int | None) -> None:
                self.value = v or 0
                self.inputs = {}

        self.technical = _S(score.technical_score)
        self.valuation = _S(score.valuation_score)
        self.sentiment = _S(score.sentiment_score)