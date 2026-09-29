"""Regression: saved articles must be visible when the live news provider is empty."""
import ast
from datetime import datetime, timezone
from decimal import Decimal
from enum import Enum
from pathlib import Path
from types import SimpleNamespace
from typing import Any
import unittest

SOURCE = Path(__file__).resolve().parents[1] / 'app/presentation/routers/assets.py'


def load_helper():
    tree = ast.parse(SOURCE.read_text(encoding='utf-8'))
    helper = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == '_visible_news_items')
    namespace = {'Any': Any}
    exec(compile(ast.Module(body=[helper], type_ignores=[]), str(SOURCE), 'exec'), namespace)
    return namespace['_visible_news_items']


class NewsFallbackTests(unittest.TestCase):
    def test_live_news_is_preferred_without_modifying_items(self):
        live = [{'title': 'Ao vivo', 'url': 'https://example.com/live', 'sentiment_score': 0.3}]
        self.assertEqual(load_helper()(live, []), live[:5])

    def test_saved_news_is_shown_when_live_source_returns_nothing(self):
        class Label(Enum):
            positive = 'positive'
        published = datetime(2026, 9, 29, tzinfo=timezone.utc)
        article = SimpleNamespace(title='Notícia real', summary='Texto integral', source='RSS',
                                  url='https://example.com/saved', published_at=published,
                                  sentiment_label=Label.positive, sentiment_score=Decimal('0.3200'))
        self.assertEqual(load_helper()([], [article]), [{
            'title': 'Notícia real', 'summary': 'Texto integral', 'source': 'RSS',
            'url': 'https://example.com/saved', 'published_at': published.isoformat(),
            'sentiment_label': 'positive', 'sentiment_score': 0.32,
        }])

    def test_no_news_remains_empty_not_fabricated(self):
        self.assertEqual(load_helper()([], []), [])


if __name__ == '__main__':
    unittest.main()
