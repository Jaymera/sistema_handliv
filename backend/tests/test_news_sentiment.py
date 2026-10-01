"""Real article text is the sole input to sentiment scoring."""
from decimal import Decimal
from types import SimpleNamespace

import pytest

from app.domain.news_sentiment import analyze_news_text, article_sentiment, sentiment_samples


@pytest.mark.parametrize('language', ['en', 'EN-us', 'en_GB', 'english', 'English (US)'])
def test_explicit_english_neutral_text_is_measured(language):
    assert analyze_news_text('Company publishes the quarterly report', language=language) == (0, 'neutral')


@pytest.mark.parametrize('language', [None, 'pt', 'pt-BR', 'pt_PT', 'Portuguese', 'Português (Brasil)'])
@pytest.mark.parametrize('title', [
    'Petrobras eleva preço do querosene de aviação em outubro',
    'Petrobras recebe pagamento de novas parcelas de subsídio da gasolina e do diesel',
])
def test_portuguese_neutral_live_headline_is_measured(title, language):
    assert analyze_news_text(title, language=language) == (0, 'neutral')


def test_inferred_english_neutral_text_is_measured():
    assert analyze_news_text('Company publishes the quarterly report') == (0, 'neutral')


@pytest.mark.parametrize('title,language', [('success chaos', None), ('Empresa anuncia alta e cai', 'pt-BR')])
def test_balanced_lexical_signals_are_measured_zero(title, language):
    assert analyze_news_text(title, language=language) == (0, 'neutral')


@pytest.mark.parametrize('language', [None, 'en-US', 'pt-BR'])
@pytest.mark.parametrize('title', [None, '', ' \t\n', '...!?', '1234 50.00', '___'])
def test_nonlexical_input_is_unavailable(title, language):
    assert analyze_news_text(title, language=language) == (None, None)


@pytest.mark.parametrize('language', [None, 'fr', 'de', 'enough', 'ptolemy'])
@pytest.mark.parametrize('title', ['La réunion aura lieu demain', 'Sitzung findet morgen statt', '会议将于明天举行', 'quarterly quarterly'])
def test_unknown_text_without_polarity_evidence_is_unavailable(title, language):
    assert analyze_news_text(title, language=language) == (None, None)


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


def test_measured_neutral_articles_count_as_samples():
    headlines = [
        article('Company publishes the quarterly report'),
        article('Petrobras eleva preço do querosene de aviação em outubro'),
        article('Petrobras recebe pagamento de novas parcelas de subsídio da gasolina e do diesel'),
        article('success chaos'),
    ]
    assert sentiment_samples(headlines + [article(''), article('La réunion aura lieu demain')]) == [0, 0, 0, 0]


@pytest.mark.parametrize('score,label', [(-0.05, 'negative'), (0, 'neutral'), (0.0499, 'neutral'), (0.05, 'positive')])
def test_stored_score_thresholds_are_preserved(score, label):
    assert article_sentiment(article('', sentiment_score=Decimal(str(score)))) == (score, label)


def test_sentiment_samples_use_only_real_articles():
    scores = sentiment_samples([article('Terrible loss'), article('Excellent profit growth')])
    assert len(scores) == 2
    assert scores[0] < 0 < scores[1]
