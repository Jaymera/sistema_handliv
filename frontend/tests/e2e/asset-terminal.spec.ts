import { expect, test } from '@playwright/test';

// Isolated browser fixture ONLY; no demo data or test endpoint is shipped to the app.
const fixture = (symbol: string, price: number) => ({
  symbol, name: `Ativo ${symbol}`, market: 'B3', currency: 'BRL', sector: 'Energia', industry: 'Petróleo', last_price: price,
  fundamentals: { pe_ratio: 6.12, pb_ratio: 1.34, dividend_yield: 0.08, roe: 0.17, debt_to_equity: 0.45, revenue_growth: 0.06 },
  indicators: { rsi: 63.2, ema20: 31.5, ema50: 29.8, macd: 0.4, macd_signal: 0.2 },
  score: { final_score: 72, buyer_strength: 64, seller_strength: 36, confidence: 81, trend: 'up', horizon: 'medium',
    subscores: { technical: 78, valuation: 69, sentiment: 66 } },
  recommendation: 'COMPRA FORTE', recommendation_color: 'green',
  ai_explanation: 'TEXTO INTEGRAL DA ANÁLISE A SER PRESERVADO SEM RESUMO.',
  indicators_explanation: 'LEITURA ORIGINAL DOS INDICADORES SEM CORTES.',
  news_summary: 'RESUMO ORIGINAL DAS NOTÍCIAS.',
  news_items: [{ title: 'Título completo da notícia', summary: 'Resumo sem truncar.', url: 'https://example.org/article',
    source: 'Fonte', published_at: '2026-09-29', sentiment_label: 'positive', sentiment_score: 0.42 }],
  technical_votes: { RSI: 1, MACD: -1, EMA: 0 },
  price_history: Array.from({ length: 12 }, (_, i) => ({ trade_date: `2026-09-${String(i + 1).padStart(2, '0')}`, close: price - 3 + i * 0.25 })),
});

test('asset terminal preserves content, switches assets and refreshes analysis without console errors', async ({ page, isMobile }) => {
  const errors: string[] = [];
  page.on('pageerror', e => errors.push(String(e)));
  page.on('console', msg => { if (msg.type() === 'error') errors.push(msg.text()); });
  let price = 35.12, calls = 0;
  await page.route('**/api/v1/assets/*/live-analysis', async route => {
    calls++;
    const symbol = decodeURIComponent(new URL(route.request().url()).pathname.split('/').at(-2)!);
    await route.fulfill({ json: fixture(symbol, symbol === 'VALE3' ? 61.88 : price) });
  });
  await page.route('**/api/v1/watchlist', async route => {
    await route.fulfill({ json: [] });
  });
  await page.goto('/asset/PETR4');
  await expect(page.getByText('HANDLIV / QUANT ANALYTICS')).toBeVisible();
  await expect(page.getByText('Ativo PETR4')).toBeVisible();
  for (const text of ['35.12', 'P/L', 'P/VPA', 'Dividend Yield', 'ROE', 'Dívida / Patrimônio', 'Cresc. receita',
    'RSI · 14', 'EMA · 20', 'EMA · 50', 'MACD · sinal', 'COMPOSITE SCORE', 'COMPRA FORTE', 'FORÇA COMPRADORA',
    'FORÇA VENDEDORA', 'TÉCNICA', 'VALUATION', 'SENTIMENTO', 'VOTOS DOS INDICADORES', 'TENDÊNCIA / HORIZONTE',
    'TEXTO INTEGRAL DA ANÁLISE A SER PRESERVADO SEM RESUMO.', 'LEITURA ORIGINAL DOS INDICADORES SEM CORTES.',
    'RESUMO ORIGINAL DAS NOTÍCIAS.', 'Título completo da notícia', 'Resumo sem truncar.', 'Fonte', 'positive']) {
    await expect(page.getByText(text, { exact: text.length > 12 }).first()).toBeVisible();
  }
  price = 36.49;
  await page.getByRole('button', { name: 'Atualizar análise' }).click();
  await expect(page.getByText(/BRL 36\.49/).first()).toBeVisible();
  await page.goto('/asset/VALE3');
  await expect(page.getByText('Ativo VALE3')).toBeVisible();
  await expect(page.getByText(/BRL 61\.88/).first()).toBeVisible();
  expect(calls).toBeGreaterThanOrEqual(3);
  // No horizontal overflow on mobile; desktop uses the denser multi-column grid.
  const dimensions = await page.evaluate(() => ({ scroll: document.documentElement.scrollWidth, viewport: window.innerWidth }));
  expect(dimensions.scroll).toBeLessThanOrEqual(dimensions.viewport + (isMobile ? 2 : 5));
  if (process.env.HANDLIV_CAPTURE_UI === '1') {
    await page.waitForTimeout(900);
    const path = require('node:path');
    await page.screenshot({ path: path.join(process.env.LOCALAPPDATA!, 'Temp', `handliv-quant-${isMobile ? 'mobile' : 'desktop'}.png`), fullPage: true });
  }
  expect(errors).toEqual([]);
});
