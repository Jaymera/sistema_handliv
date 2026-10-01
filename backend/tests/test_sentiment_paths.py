"""Regression at the live/scheduled score boundaries, with offline real article text."""
from datetime import datetime, timezone
from types import SimpleNamespace

from app.presentation.routers import assets
from app.infrastructure.queue.tasks import compute_scores


def saved(title):
    return SimpleNamespace(title=f'ABCD {title}', summary=None, sentiment_score=None, sentiment_label=None,
                           source='RSS', url='https://example.org/article',
                           published_at=datetime(2026, 9, 29, tzinfo=timezone.utc))


class DB:
    def __init__(self, articles):
        self.articles = articles
        self.rows = []

    def scalar(self, query):
        return None

    def scalars(self, query):
        return SimpleNamespace(all=lambda: self.articles)

    def add(self, row):
        self.rows.append(row)

    def commit(self):
        pass

    def close(self):
        pass


def setup_live(monkeypatch, db, symbol='ABCD', name='ABCD'):
    asset = SimpleNamespace(id='asset-1', symbol=symbol, name=name, market=SimpleNamespace(value='us'),
                            currency='USD', sector=None, industry=None)
    monkeypatch.setattr(assets, '_get_asset_by_symbol', lambda *_: asset)
    monkeypatch.setattr(assets.market_data, 'fetch_history', lambda *a, **k: [])
    monkeypatch.setattr(assets.market_data, 'fetch_info', lambda *a: {})
    monkeypatch.setattr(assets.market_data, 'fetch_news', lambda *a, **k: [])
    return assets.live_analysis(symbol, db=db, user=SimpleNamespace(role=SimpleNamespace(value='super_admin')))


def test_live_scores_saved_unscored_real_article(monkeypatch):
    response = setup_live(monkeypatch, DB([saved('Excellent profit growth')]))
    assert response['score']['subscores']['sentiment'] > 50
    assert response['news_items'][0]['sentiment_score'] > 0
    assert response['sentiment_sample_count'] == 1


def test_live_neutral_article_is_a_measured_sample(monkeypatch):
    response = setup_live(monkeypatch, DB([saved('Company publishes the quarterly report')]))
    assert response['score']['subscores']['sentiment'] == 50
    assert response['news_items'][0]['sentiment_score'] == 0
    assert response['news_items'][0]['sentiment_label'] == 'neutral'
    assert response['sentiment_sample_count'] == 1


def test_live_without_any_news_exposes_no_sentiment_measurement(monkeypatch):
    response = setup_live(monkeypatch, DB([]))
    assert response['score']['subscores']['sentiment'] is None
    assert response['sentiment_sample_count'] == 0
    assert 'sem notícias' in response['ai_explanation'].lower()


def test_unrelated_historical_article_does_not_create_gold_sentiment(monkeypatch):
    article = saved('Goldman Sachs prevê crescimento')
    article.title = 'Goldman Sachs prevê crescimento'
    response = setup_live(monkeypatch, DB([article]), symbol='GOLD', name='Barrick Gold')
    assert response['score']['subscores']['sentiment'] is None
    assert response['news_items'] == []


def test_scheduled_scores_saved_unscored_real_article(monkeypatch):
    asset = SimpleNamespace(id='asset-1', symbol='ABCD')
    db = DB([saved('Terrible loss')])
    db.scalars = lambda query: SimpleNamespace(all=lambda: [asset] if 'assets' in str(query) else db.articles)
    monkeypatch.setattr(compute_scores, 'SessionLocal', lambda: db)
    bars = [{'open': 10, 'high': 11, 'low': 9, 'close': 10, 'volume': 100}]
    monkeypatch.setattr(compute_scores.market_data, 'fetch_history', lambda *a, **k: bars)
    monkeypatch.setattr(compute_scores.market_data, 'fetch_info', lambda *a: {})
    monkeypatch.setattr(compute_scores.market_data, 'fetch_quote', lambda *a: {})
    monkeypatch.setattr(compute_scores.cache, 'set_json', lambda *a, **k: None)
    assert compute_scores.compute_all_scores.run() == 1
    assert db.rows[0].sentiment_score < 50


def test_scheduled_neutral_article_stores_measured_midpoint(monkeypatch):
    asset = SimpleNamespace(id='asset-1', symbol='ABCD')
    db = DB([saved('Petrobras recebe pagamento de novas parcelas de subsídio da gasolina e do diesel')])
    db.scalars = lambda query: SimpleNamespace(all=lambda: [asset] if 'assets' in str(query) else db.articles)
    monkeypatch.setattr(compute_scores, 'SessionLocal', lambda: db)
    bars = [{'open': 10, 'high': 11, 'low': 9, 'close': 10, 'volume': 100}]
    monkeypatch.setattr(compute_scores.market_data, 'fetch_history', lambda *a, **k: bars)
    monkeypatch.setattr(compute_scores.market_data, 'fetch_info', lambda *a: {})
    monkeypatch.setattr(compute_scores.market_data, 'fetch_quote', lambda *a: {})
    monkeypatch.setattr(compute_scores.cache, 'set_json', lambda *a, **k: None)
    assert compute_scores.compute_all_scores.run() == 1
    assert db.rows[0].sentiment_score == 50


def test_scheduled_without_articles_stores_missing_measurement(monkeypatch):
    asset = SimpleNamespace(id='asset-1', symbol='ABCD')
    db = DB([])
    db.scalars = lambda query: SimpleNamespace(all=lambda: [asset] if 'assets' in str(query) else [])
    monkeypatch.setattr(compute_scores, 'SessionLocal', lambda: db)
    bars = [{'open': 10, 'high': 11, 'low': 9, 'close': 10, 'volume': 100}]
    monkeypatch.setattr(compute_scores.market_data, 'fetch_history', lambda *a, **k: bars)
    monkeypatch.setattr(compute_scores.market_data, 'fetch_info', lambda *a: {})
    monkeypatch.setattr(compute_scores.market_data, 'fetch_quote', lambda *a: {})
    monkeypatch.setattr(compute_scores.cache, 'set_json', lambda *a, **k: None)
    assert compute_scores.compute_all_scores.run() == 1
    assert db.rows[0].sentiment_score is None
