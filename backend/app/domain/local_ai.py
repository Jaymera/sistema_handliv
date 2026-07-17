from __future__ import annotations

from typing import Any

from app.domain.decision_engine import DecisionResult


def explain_score(result: DecisionResult, asset_symbol: str) -> str:
    """Deterministic PT-BR explanation of the decision engine output.
    No LLM/token needed. Pure rule-based text composition."""
    parts: list[str] = []
    parts.append(
        f"Score composto do ativo {asset_symbol}: {result.final_score}/100 "
        f"(técnica {result.technical.value}, valuation {result.valuation.value}, "
        f"sentimento {result.sentiment.value})."
    )

    if result.final_score >= 70:
        parts.append("Indicação dominante de COMPRA: indicadores técnicos, valuation e sentimento convergem positivamente.")
    elif result.final_score >= 55:
        parts.append("Indicação moderada de compra, com ressalvas. Existem sinais divergentes; avalie contexto macro.")
    elif result.final_score <= 30:
        parts.append("Indicação dominante de VENDA: pressão vendedora superior à força compradora.")
    elif result.final_score <= 45:
        parts.append("Indicação moderada de venda. Cuidado com breakeouts de baixa.")
    else:
        parts.append("Indicação NEUTRA: força compradora e vendedora equilibradas. Aguarde confirmação de tendência.")

    parts.append(
        f"Força compradora {result.buyer_strength}/100 vs. força vendedora {result.seller_strength}/100; "
        f"confiança {result.confidence}/100; tendência {result.trend} em horizonte {result.horizon}."
    )
    return " ".join(parts)


def explain_indicators(technical_inputs: dict[str, Any]) -> str:
    """Render natural language summary of indicator votes. Deterministic."""
    votes = technical_inputs.get("votes", {})
    if not votes:
        return "Indicadores técnicos indisponíveis (dados insuficientes)."
    buys = [k for k, v in votes.items() if v > 0]
    sells = [k for k, v in votes.items() if v < 0]
    neutrals = [k for k, v in votes.items() if v == 0]
    lines: list[str] = []
    if buys:
        lines.append("Apontando PARA cima: " + ", ".join(sorted(buys)) + ".")
    if sells:
        lines.append("Apontando PARA baixo: " + ", ".join(sorted(sells)) + ".")
    if neutrals:
        lines.append("Neutros: " + ", ".join(sorted(neutrals)) + ".")
    return " ".join(lines)


def summarize_news(articles: list[dict[str, Any]]) -> str:
    """Compose a PT-BR summary sentence from sentiment-tagged articles.
    Deterministic — no LLM. Falls back to a simple statistics sentence if no articles.
    """
    if not articles:
        return "Sem notícias recentes para este ativo."
    pos = sum(1 for a in articles if a.get("sentiment_label") == "positive")
    neg = sum(1 for a in articles if a.get("sentiment_label") == "negative")
    neut = len(articles) - pos - neg
    titles_preview = "; ".join(a.get("title", "")[:90] for a in articles[:3])
    summary = (
        f"{len(articles)} notícias recentes: {pos} positivas, {neg} negativas, {neut} neutras. "
        f"Destaques: {titles_preview}."
    )
    return summary