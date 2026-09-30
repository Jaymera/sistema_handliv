"""Conservative title relevance for RSS articles associated with a specific asset."""
import re


def matches_asset_title(title: str, symbol: str, name: str | None) -> bool:
    text = title.upper()
    company = (name or '').split()
    anchor = company[0].upper() if company else ''
    display = symbol.removesuffix('.SA').upper()
    anchor_match = len(anchor) >= 5 and bool(re.search(rf'(?<!\w){re.escape(anchor)}(?!\w)', text))
    ticker_match = bool(display) and bool(re.search(rf'(?<!\w){re.escape(display)}(?!\w)', text))
    # A word-sized ticker in the company name (GOLD, META, ...) is not
    # sufficient alone to establish that a generic story is about the stock.
    generic_name_ticker = len(company) >= 2 and display.isalpha() and display in [part.upper() for part in company]
    return bool(anchor_match or (ticker_match and not generic_name_ticker))
