from app.infrastructure.queue.tasks.fetch_news import _match_asset


class Asset:
    def __init__(self, symbol, name):
        self.symbol, self.name = symbol, name
        self.id = symbol


def test_generic_ticker_does_not_match_company_substring():
    assets = [Asset('GOLD', 'Barrick Gold')]
    by_symbol = {a.symbol: a for a in assets}
    assert _match_asset('Goldman Sachs reports profit', by_symbol) is None
    assert _match_asset('Barrick Gold reports profit', by_symbol) == assets[0].id


def test_symbol_and_company_names_are_detected():
    assets = [Asset('MULT3.SA', 'Multiplan'), Asset('BABA', 'Alibaba Group ADR')]
    by_symbol = {a.symbol: a for a in assets}
    assert _match_asset('MULT3 levanta R$ 300 milhões', by_symbol) == assets[0].id
    assert _match_asset('Alibaba anuncia oferta', by_symbol) == assets[1].id
