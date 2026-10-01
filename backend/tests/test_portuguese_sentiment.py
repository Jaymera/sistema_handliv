from pathlib import Path
import importlib.util

spec = importlib.util.spec_from_file_location('news_sentiment', Path(__file__).resolve().parents[1] / 'app/domain/news_sentiment.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

def test_portuguese_news_with_clear_direction_has_real_score():
    score, label = module.analyze_news_text('Bolsas fecham em queda com tensão geopolítica', language='pt-BR')
    assert score is not None and score < 0 and label == 'negative'
    score, label = module.analyze_news_text('Empresa anuncia crescimento e lucro recorde', language='pt-BR')
    assert score is not None and score > 0 and label == 'positive'

def test_supported_portuguese_factual_news_retains_measured_lexical_neutral():
    # The supported-language text was analyzed; zero is not a missing observation.
    assert module.analyze_news_text('Companhia convoca assembleia de acionistas', language='pt-BR') == (0, 'neutral')
    assert module.analyze_news_text('Multiplan levanta R$ 300 milhões via CRIs', language='pt-BR') == (0, 'neutral')

def test_language_fallback_detects_portuguese_market_headline():
    score, _ = module.analyze_news_text('Bolsas da Ásia fecham em queda')
    assert score is not None and score < 0
