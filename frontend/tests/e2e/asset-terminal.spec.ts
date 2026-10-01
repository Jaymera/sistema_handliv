import { expect, test } from '@playwright/test';

// Isolated browser fixtures ONLY. No fixture quote/news/engine is shipped in the app.
const fixture = (symbol: string, price: number) => ({
  symbol, name: `Ativo ${symbol}`, market: 'B3', currency: 'BRL', sector: 'Energia', industry: 'Petróleo', last_price: price,
  fundamentals: { pe_ratio: 6.12, pb_ratio: 1.34, dividend_yield: 0.08, roe: 0.17, debt_to_equity: 0.45, revenue_growth: 0.06 },
  indicators: { rsi: 63.2, ema20: 31.5, ema50: 29.8, macd: 0.4, macd_signal: 0.2 },
  score: { final_score: 72, buyer_strength: 64, seller_strength: 36, confidence: 81, trend: 'up', horizon: 'medium',
    subscores: { technical: 78, valuation: 69, sentiment: 66 } },
  recommendation: 'COMPRA FORTE', recommendation_color: 'green',
  ai_explanation: 'TEXTO INTEGRAL DA ANÁLISE A SER PRESERVADO SEM RESUMO.',
  indicators_explanation: 'LEITURA ORIGINAL DOS INDICADORES SEM CORTES.',
  news_summary: 'RESUMO ORIGINAL DAS NOTÍCIAS.', sentiment_sample_count: 1,
  news_items: [{ title: 'Título completo da notícia', summary: 'Resumo sem truncar.', url: 'https://example.org/article',
    source: 'Fonte', published_at: '2026-09-29', sentiment_label: 'positive', sentiment_score: 0.42 }],
  technical_votes: { RSI: 1, MACD: -1, EMA: 0 },
  price_history: Array.from({ length: 12 }, (_, i) => ({ trade_date: `2026-09-${String(i + 1).padStart(2, '0')}`, close: price - 3 + i * 0.25 })),
});

test('asset workspace preserves every analysis field across tabs, changes windows and switches assets', async ({ page, isMobile }) => {
  const errors: string[] = [];
  page.on('pageerror', e => errors.push(String(e)));
  page.on('console', msg => { if (msg.type() === 'error') errors.push(msg.text()); });
  let price = 35.12, calls = 0;
  await page.route('**/api/v1/assets/*/live-analysis', async route => {
    calls++;
    const symbol = decodeURIComponent(new URL(route.request().url()).pathname.split('/').at(-2)!);
    await route.fulfill({ json: fixture(symbol, symbol === 'VALE3' ? 61.88 : price) });
  });
  await page.route('**/api/v1/watchlist', route => route.fulfill({ json: [] }));
  await page.route('**/api/v1/assets?*', route => route.fulfill({json:{items:[{symbol:'VALE3',name:'Vale',market:'B3'}],total:1,page:1,limit:12}}));
  await page.goto('/asset/PETR4');
  await expect(page.getByText('HANDLIV / ASSET WORKSPACE', {exact:true})).toBeVisible();
  await expect(page.getByText('Ativo PETR4', {exact:true})).toBeVisible();
  for (const text of ['BRL 35.12', 'Score composto / 100', '72.0', 'COMPRA FORTE', 'Força compradora / vendedora', '64.0 / 36.0',
    'Tendência / horizonte', 'up / medium', '81%', 'Técnica', 'Valuation', 'Sentimento', '78.0', '69.0', '66.0',
    'RSI · 14','EMA · 20','EMA · 50','MACD · sinal','TEXTO INTEGRAL DA ANÁLISE A SER PRESERVADO SEM RESUMO.']) {
    await expect(page.getByText(text,{exact:true}).first()).toBeVisible();
  }
  await page.getByRole('tab',{name:'Fundamentos',exact:true}).click();
  for (const text of ['P/L','P/VPA','Dividend yield','ROE','Dívida / patrimônio','Crescimento de receita','6.12','1.34','8.00%','17.00%','0.45','6.00%']) {
    await expect(page.getByText(text,{exact:true}).first()).toBeVisible();
  }
  await page.getByRole('tab',{name:'Técnica',exact:true}).click();
  for (const text of ['VOTOS E EXPLICAÇÃO DO MOTOR','RSI','MACD','EMA','LEITURA ORIGINAL DOS INDICADORES SEM CORTES.']) {
    await expect(page.getByText(text,{exact:true}).first()).toBeVisible();
  }
  await expect(page.getByText('Acima',{exact:true})).toHaveCount(3);
  await page.getByRole('tab',{name:'Notícias',exact:true}).click();
  for (const text of ['RESUMO ORIGINAL DAS NOTÍCIAS.','Título completo da notícia','Resumo sem truncar.','Fonte','positive · 0.42','29/09/2026']) {
    await expect(page.getByText(text,{exact:true}).first()).toBeVisible();
  }
  await page.getByRole('button',{name:'Fonte',exact:true}).click();
  await expect(page.getByText('Título completo da notícia',{exact:true})).toBeVisible();
  await page.getByRole('tab',{name:'Gráfico',exact:true}).click();
  await page.getByRole('button',{name:'5 pregões',exact:true}).click();
  await expect(page.getByText('5 pregões',{exact:true})).toBeVisible();
  await expect(page.getByText('HISTÓRICO DE FECHAMENTO · 5 PREGÕES',{exact:true})).toBeVisible();
  await page.getByRole('tab',{name:'Evidências',exact:true}).click();
  await expect(page.getByText('12 pregões válidos',{exact:true})).toBeVisible();
  await expect(page.getByText(/Confiança do motor, não probabilidade de lucro/)).toBeVisible();
  price = 36.49;
  await page.getByRole('button', { name: 'Atualizar análise' }).click();
  await expect(page.getByText(/BRL 36\.49/).first()).toBeVisible();
  await page.getByRole('button',{name:'Selecionar outro ativo'}).click();
  await page.getByRole('textbox',{name:'Buscar ticker ou empresa'}).fill('VALE');
  await page.getByRole('button',{name:'Analisar VALE3',exact:true}).click();
  await expect(page.getByText('Ativo VALE3',{exact:true})).toBeVisible();
  await expect(page.getByText(/BRL 61\.88/).first()).toBeVisible();
  expect(calls).toBeGreaterThanOrEqual(3);
  const dimensions = await page.evaluate(() => ({ scroll: document.documentElement.scrollWidth, viewport: window.innerWidth }));
  expect(dimensions.scroll).toBeLessThanOrEqual(dimensions.viewport + (isMobile ? 2 : 5));
  if (process.env.HANDLIV_CAPTURE_UI === '1') {
    await page.waitForTimeout(900);
    const path = require('node:path');
    await page.screenshot({ path: path.join(process.env.LOCALAPPDATA!, 'Temp', `handliv-quant-${isMobile ? 'mobile' : 'desktop'}.png`), fullPage: true });
  }
  expect(errors).toEqual([]);
});

test('unscored news and absent inputs are not neutral, probabilities or invented technical factors', async ({page}) => {
  const data = fixture('BTC', 0);
  const missing = {...data,last_price:null,indicators:{},fundamentals:{},price_history:[],sentiment_sample_count:0,
    score:{...data.score,confidence:null},news_items:[{...data.news_items[0],sentiment_score:null,sentiment_label:null,published_at:'invalid'}]};
  await page.route('**/api/v1/assets/*/live-analysis',route=>route.fulfill({json:missing}));
  await page.route('**/api/v1/watchlist',route=>route.fulfill({json:[]}));
  await page.goto('/asset/BTC');
  await expect(page.getByText('Sem amostra verificável para apresentar uma medição.')).toBeVisible();
  await expect(page.getByText('Par de valores indisponível')).toHaveCount(3);
  await expect(page.getByText('Histórico de preços indisponível.')).toBeVisible();
  await page.getByRole('tab',{name:'Notícias',exact:true}).click();
  await expect(page.getByText('Não classificado · Pontuação indisponível',{exact:true})).toBeVisible();
  await expect(page.getByText('Invalid Date',{exact:true})).toHaveCount(0);
});

test('news retains label-only polarities and measured neutral without inventing unclassified scores', async ({page}) => {
  const data = fixture('PETR4', 35);
  const news = [
    {...data.news_items[0], title:'Positive label-only fixture', sentiment_label:'positive', sentiment_score:null},
    {...data.news_items[0], title:'Negative label-only fixture', sentiment_label:'negative', sentiment_score:null},
    {...data.news_items[0], title:'Measured neutral fixture', sentiment_label:'neutral', sentiment_score:0},
    {...data.news_items[0], title:'Unclassified fixture', sentiment_label:null, sentiment_score:null},
  ];
  await page.route('**/api/v1/assets/*/live-analysis', route => route.fulfill({json:{
    ...data, sentiment_sample_count:1,
    score:{...data.score,subscores:{...data.score.subscores,sentiment:50}}, news_items:news,
  }}));
  await page.route('**/api/v1/watchlist',route=>route.fulfill({json:[]}));
  await page.goto('/asset/PETR4');
  await page.getByRole('tab',{name:'Notícias',exact:true}).click();
  for (const text of ['positive · Pontuação indisponível', 'negative · Pontuação indisponível',
    'neutral · 0.00', 'Não classificado · Pontuação indisponível']) {
    await expect(page.getByText(text,{exact:true})).toBeVisible();
  }
  await expect(page.getByText(/Classificação textual das notícias; não prevê a direção do preço/)).toBeVisible();
});
