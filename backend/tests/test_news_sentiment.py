"""Real article text is the sole input to sentiment scoring."""
from decimal import Decimal
from types import SimpleNamespace

from app.domain.news_sentiment import article_sentiment, sentiment_samples


def article(title, summary=None, sentiment_score=None):
    return SimpleNamespace(title=title, summary=summary, sentiment_score=sentiment_score)


def test_unscored_saved_article_uses_its_actual_title():
    score, label = article_sentiment(article('Excellent profit growth'))
    assert score > 0
    assert label == 'positive'


def test_existing_score_is_not_overwritten_by_reanalysis():
    assert article_sentiment(article('Excellent profit growth', sentiment_score=Decimal('-0.6000'))) == (-0.6, 'negative')


def test_empty_article_is_not_an_observation():
    assert article_sentiment(article(' ', '')) == (None, None)
    assert sentiment_samples([article(' ', '')]) == []


def test_sentiment_samples_use_only_real_articles():
    scores = sentiment_samples([article('Terrible loss'), article('Excellent profit growth')])
    assert len(scores) == 2
    assert scores[0] < 0 < scores[1]
