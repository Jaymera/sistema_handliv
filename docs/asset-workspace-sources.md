# Asset workspace: source reuse and data boundary

## Supplied originals inspected

User expressly authorized using both supplied local codebases. Existing Expo / React Native Web + FastAPI architecture, API contracts and decision engine remain in place.

| Source | License inspected | Original files inspected | Incorporation |
|---|---|---|---|
| `C:/Users/USER/Downloads/OpenTerminal-main/OpenTerminal-main` | MIT, copyright 2026 OpenTerminalUI Contributors | `frontend/src/pages/StockDetail.tsx`, `frontend/src/shared/chart/chartUtils.ts`, `frontend/src/components/analysis/TechnicalsPanel.tsx`, `frontend/src/hooks/useStockData.ts` | **Concrete algorithm adaptation** of `chartPointsToBars` (lines 40–69) into Handliv `frontend/src/features/asset-terminal/workspace.ts::dailySessions`: finite-value rejection, keyed Map last-valid-record deduplication and chronological output sorting. Converted OHLC/time inputs to actual Handliv `trade_date` + daily `close`; added strict real-calendar validation and positive-close checks. No zero-volume fallback, numeric coercion of absent values, OHLC synthesis or realtime engine copied. StockDetail's selected-ticker + section-tab + observed-chart-window interaction is adapted to Expo primitives, not its DOM renderer or streaming subscriptions. The inspected TechnicalsPanel/useStockData are scaffolds; they were **not** incorporated. |
| `C:/Users/USER/Downloads/OpenStock-main/OpenStock-main` | GNU AGPL-3.0 | `components/stocks/StockHeader.tsx`, `StockLivePrice.tsx`, `StockSentimentCard.tsx` | **Conceptual interaction/layout reuse only**: compact symbol/name + quote header, responsive metric tiles, source/coverage summary followed by source rows. Original React Native implementation in `AssetTerminal.tsx`. No literal OpenStock source, CSS, icons, logos, market-fetching code, sentiment algorithm or branded assets incorporated. In particular no fixed four-source coverage denominator, buzz/bullish percentages, Finnhub/TradingView widgets or assumed live quote was imported. |

**Copied verbatim:** no third-party application component or asset. MIT license notice below retained for the adapted OpenTerminal algorithm. OpenStock authorization is acknowledged; conceptual reuse rather than unnecessary Next.js/AGPL component copying preserves the project's existing renderer and dependency graph. This document records provenance, not legal advice.

## Actual new functionality

- Asset-scoped workspace with Overview / Chart / Technicals / Fundamentals / News / Evidence tabs; all existing indicator, fundamental, score, vote and explanation fields remain accessible.
- Inline ticker/company lookup against the existing real `/assets` catalog; watchlist selection when no search is entered. Symbol selection still uses the existing asset route and symbol-scoped query.
- Selectable last 5 / 10 / 30 **returned daily sessions**, deduplicated and sorted; observed change, lowest/highest **close**, dates and actual returned sample size. One session cannot produce a change; empty history cannot produce price statistics.
- Technical pair evidence: close vs EMA20, EMA20 vs EMA50, MACD vs signal, RSI bands. Values are returned backend indicators, not new client indicator calculations. Ordering is explicitly **not a crossover event**.
- News source filters; displayed article counts and measurable article scores remain separate from total backend sentiment sample count. Missing sample cannot be displayed as neutral sentiment.
- Markets supports actual backend asset-type enum filters, cards/list selection, class/currency metadata and explicit retryable catalog errors.

## Financial truth / freshness

Inspected backend `app/presentation/routers/assets.py::live_analysis`: `last_price` is `df.close.iloc[-1]` from `fetch_history(timeframe="1d", period="6mo")`, **not** a live tick; returned history is the last 30 bars while indicator calculation may use a longer base. Scores, votes, recommendation and confidence remain those returned by the existing backend. Confidence is labeled an engine score, not probability of profit.

This endpoint does not return provider identity, quote-delay minutes, calculation timestamp or fiscal period. The header and Evidence tab say these are not informed, rather than assigning yfinance/freshness based only on implementation details. Returned closing-session date and valid article publication dates are shown; impossible calendar dates are rejected. Device clock does not imply a market is open/closed. No backend change, order action, new trading engine, commit or deployment was performed.

## Checks and preview capture

Pure model tests were added using red → green runs for session normalization, selected-window statistics, factor comparisons, confidence/sample guards and invalid publication dates. Structural UI tests guard the new section/window contract. Previous field-preservation test now reads the actual workspace helper too, and sentiment protection checks real behavior instead of obsolete JSX variable names.

Run in `frontend`:

```
node --test tests/asset-workspace.test.cjs tests/asset-workspace-ui.test.cjs tests/asset-terminal.test.cjs tests/analysis-evidence.test.cjs tests/market-workspace.test.cjs
npm run typecheck
```

The existing `tests/e2e/asset-terminal.spec.ts` now genuinely clicks each tab and asserts all prior underlying fields/texts, switches observation window, filters news and selects another ticker through the picker. It also verifies unavailable history/indicators and unscored news. Its isolated fixture responses are **test-only**, not evidence of current market prices. Integration export / browser execution are coordinated by the parent agent.

On an integration preview running the exported frontend, use:

```
HANDLIV_CAPTURE_UI=1 npx playwright test tests/e2e/asset-terminal.spec.ts
```

Capture files: `%LOCALAPPDATA%/Temp/handliv-quant-desktop.png` and `handliv-quant-mobile.png` (Playwright isolated financial fixtures, clearly not live market evidence). For real-data screenshots sign in to the ordinary local app yourself, open Markets, search/select an available ticker, and capture Overview / Technicals / News / Evidence at desktop and mobile widths. No credential entry is automated by this change.

## OpenTerminal MIT notice (adapted normalization algorithm)

MIT License

Copyright (c) 2026 OpenTerminalUI Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
