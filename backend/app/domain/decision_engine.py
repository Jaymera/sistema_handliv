from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
from typing import Any

import pandas as pd
import pandas_ta as ta  # type: ignore


@dataclass
class SubScore:
    value: int  # 0-100
    inputs: dict[str, Any]


@dataclass
class DecisionResult:
    technical: SubScore
    valuation: SubScore
    sentiment: SubScore
    final_score: int
    buyer_strength: int
    seller_strength: int
    confidence: int
    trend: str
    horizon: str
    inputs_log: dict[str, Any]


def _clamp(v: float) -> int:
    return max(0, min(100, int(round(v))))


def compute_technical(df: pd.DataFrame) -> SubScore:
    """Vote on a set of indicators. Each indicator votes Buy (+1), Sell (-1) or Neutral (0).
    Score = (buy - sell) / (abs_total) normalized 0-100, plus baseline 50.
    """
    if df.empty or len(df) < 30:
        return SubScore(50, {"reason": "not enough data"})

    votes: dict[str, int] = {}

    try:
        rsi = ta.rsi(df["close"], length=14).iloc[-1]
        votes["rsi"] = 1 if rsi < 30 else (-1 if rsi > 70 else 0)
    except Exception:
        pass

    try:
        macd = ta.macd(df["close"]).iloc[-1]
        votes["macd"] = 1 if macd["MACD_12_26_9"] > macd["MACDs_12_26_9"] else -1
    except Exception:
        pass

    try:
        ema_fast = ta.ema(df["close"], length=20).iloc[-1]
        ema_slow = ta.ema(df["close"], length=50).iloc[-1]
        votes["ema_cross"] = 1 if ema_fast > ema_slow else -1
    except Exception:
        pass

    try:
        adx = ta.adx(df["high"], df["low"], df["close"]).iloc[-1]
        votes["adx_trend"] = 1 if adx["ADX_14"] > 25 and adx["DMP_14"] > adx["DMN_14"] else (-1 if adx["ADX_14"] > 25 else 0)
    except Exception:
        pass

    try:
        stoch = ta.stoch(df["high"], df["low"], df["close"]).iloc[-1]
        votes["stoch"] = 1 if stoch["STOCHk_14_3_3"] < 20 else (-1 if stoch["STOCHk_14_3_3"] > 80 else 0)
    except Exception:
        pass

    try:
        bb = ta.bbands(df["close"]).iloc[-1]
        votes["bollinger"] = 1 if df["close"].iloc[-1] < bb["BBL_20_2.0"] else (-1 if df["close"].iloc[-1] > bb["BBU_20_2.0"] else 0)
    except Exception:
        pass

    try:
        supertrend = ta.supertrend(df["high"], df["low"], df["close"]).iloc[-1]
        votes["supertrend"] = 1 if supertrend["SUPERTs_7_3.0"] is not None else -1
    except Exception:
        pass

    buy = sum(1 for v in votes.values() if v > 0)
    sell = sum(1 for v in votes.values() if v < 0)
    total = len(votes) or 1
    score = 50 + 50 * (buy - sell) / total
    return SubScore(_clamp(score), {"votes": votes, "buy": buy, "sell": sell, "total": total})


def compute_valuation(info: dict[str, Any], price: float | None) -> SubScore:
    """Valuation sub-score 0-100 based on multiples + (optional) DCF intrinsic."""
    score = 50
    inputs: dict[str, Any] = {}

    pe = info.get("pe_ratio")
    if pe is not None and pe > 0:
        inputs["pe"] = pe
        if pe < 10:
            score += 15
        elif pe < 20:
            score += 8
        elif pe < 35:
            score -= 5
        else:
            score -= 12

    pb = info.get("pb_ratio")
    if pb is not None and pb > 0:
        inputs["pb"] = pb
        if pb < 1:
            score += 12
        elif pb < 2:
            score += 5
        elif pb > 5:
            score -= 8

    dy = info.get("dividend_yield")
    if dy is not None and dy > 0:
        inputs["dividend_yield"] = dy
        if dy > 0.06:
            score += 10
        elif dy > 0.03:
            score += 4

    roe = info.get("roe")
    if roe is not None:
        inputs["roe"] = roe
        if roe > 0.15:
            score += 10
        elif roe > 0.08:
            score += 4
        else:
            score -= 5

    debt = info.get("debt_to_equity")
    if debt is not None:
        inputs["debt_to_equity"] = debt
        if debt < 0.5:
            score += 6
        elif debt > 2:
            score -= 8

    return SubScore(_clamp(score), inputs)


def compute_sentiment(articles_sentiments: list[float]) -> SubScore:
    """Average of per-article sentiment scores in [-1,1] scaled to 0-100."""
    if not articles_sentiments:
        return SubScore(50, {"reason": "no articles"})
    avg = sum(articles_sentiments) / len(articles_sentiments)
    return SubScore(_clamp(50 + 50 * avg), {"avg": avg, "sample": len(articles_sentiments)})


def decide(
    df: pd.DataFrame,
    info: dict[str, Any],
    last_price: float | None,
    articles_sentiments: list[float],
    weights: dict[str, float],
) -> DecisionResult:
    technical = compute_technical(df)
    valuation = compute_valuation(info, last_price)
    sentiment = compute_sentiment(articles_sentiments)

    t_w = weights.get("technical", 0.40)
    v_w = weights.get("valuation", 0.35)
    s_w = weights.get("sentiment", 0.25)
    final = technical.value * t_w + valuation.value * v_w + sentiment.value * s_w

    buyer_strength = _clamp((technical.value + sentiment.value) / 2)
    seller_strength = _clamp(100 - buyer_strength)
    confidence = _clamp(min(technical.value, valuation.value, sentiment.value) if articles_sentiments else sentiment.value * 0.5 + technical.value * 0.5)

    if final >= 65:
        trend = "up"
        horizon = "medium"
    elif final <= 35:
        trend = "down"
        horizon = "short"
    else:
        trend = "sideways"
        horizon = "medium"

    log = {
        "technical": technical.inputs,
        "valuation": valuation.inputs,
        "sentiment": sentiment.inputs,
        "weights": weights,
        "last_price": last_price,
    }
    return DecisionResult(
        technical=technical,
        valuation=valuation,
        sentiment=sentiment,
        final_score=_clamp(final),
        buyer_strength=buyer_strength,
        seller_strength=seller_strength,
        confidence=confidence,
        trend=trend,
        horizon=horizon,
        inputs_log=log,
    )