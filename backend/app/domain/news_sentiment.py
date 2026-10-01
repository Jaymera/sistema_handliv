"""Sentiment derived exclusively from existing article text or stored scores."""
from __future__ import annotations

import re
from typing import Any

from vaderSentiment.vaderSentiment import SentimentIntensityAnalyzer


_PT_TERMS = {
    "queda": -2.5, "quedas": -2.5, "cai": -2, "caem": -2, "recuo": -2,
    "recua": -2, "perda": -2, "perdas": -2, "prejuízo": -3, "prejuizo": -3,
    "crise": -2, "tensão": -1.5, "tensao": -1.5, "dívida": -1,
    "divida": -1, "despenca": -3, "corte": -1.5, "demissões": -2,
    "demissoes": -2, "alta": 2, "sobe": 2, "sobem": 2, "avança": 2,
    "avanca": 2, "ganho": 1.5, "ganhos": 1.5, "lucro": 1,
    "crescimento": 2, "crescem": 2, "cresce": 2, "recorde": 2,
    "valorização": 2, "valorizacao": 2, "supera": 1.5,
}
# Structural language evidence, not additional positive/negative lexicon entries.
_PT_HINTS = {
    "em", "com", "para", "ações", "acoes", "bolsas", "fecham", "empresa",
    "anuncia", "lucro", "queda", "alta", "preço", "preco", "aviação", "aviacao",
    "outubro", "recebe", "pagamento", "novas", "parcelas", "subsídio", "subsidio",
}
_EN_HINTS = {"company", "publishes", "quarterly", "report", "announces", "shares", "earnings", "meeting", "board"}


def analyze_news_text(title: str | None, summary: str | None = None, language: str | None = None) -> tuple[float | None, str | None]:
    text = " ".join(part for part in (title, summary) if part and part.strip())
    if not text:
        return None, None
    words = re.findall(r"[^\W\d_]+", text.lower(), flags=re.UNICODE)
    if not words:
        return None, None
    language = (language or "").strip().lower()
    word_set = set(words)
    if re.match(r"^(pt|portuguese|português)(?:$|[-_\s(])", language) or len(word_set & _PT_HINTS) >= 2:
        signals = [_PT_TERMS[word] for word in words if word in _PT_TERMS]
        score = round(sum(signals) / (sum(abs(value) for value in signals) + 1), 4)
    else:
        analyzer = SentimentIntensityAnalyzer()
        score = analyzer.polarity_scores(text)["compound"]
        # A zero compound is a measurement only with language or lexicon evidence.
        english_evidence = (
            re.match(r"^(en|english)(?:$|[-_\s(])", language)
            or len(word_set & _EN_HINTS) >= 2
            or any(word in analyzer.lexicon for word in words)
        )
        if score == 0 and not english_evidence:
            return None, None
    label = "positive" if score >= 0.05 else "negative" if score <= -0.05 else "neutral"
    return score, label


def article_sentiment(article: Any) -> tuple[float | None, str | None]:
    if article.sentiment_score is None:
        return analyze_news_text(article.title, article.summary, getattr(article, "language", None))
    score = float(article.sentiment_score)
    label = "positive" if score >= 0.05 else "negative" if score <= -0.05 else "neutral"
    return score, label


def sentiment_samples(articles: list[Any]) -> list[float]:
    return [score for article in articles if (score := article_sentiment(article)[0]) is not None]
