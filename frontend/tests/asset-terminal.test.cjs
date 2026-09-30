const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.join(__dirname, '..');
const route = fs.readFileSync(path.join(root, 'app/asset/[symbol].tsx'), 'utf8');
const panel = fs.existsSync(path.join(root, 'src/features/asset-terminal/AssetTerminal.tsx'))
  ? fs.readFileSync(path.join(root, 'src/features/asset-terminal/AssetTerminal.tsx'), 'utf8') : '';
const visual = fs.existsSync(path.join(root, 'src/features/asset-terminal/visuals.tsx'))
  ? fs.readFileSync(path.join(root, 'src/features/asset-terminal/visuals.tsx'), 'utf8') : '';
test('same API, symbol-scoped query and watchlist mutation', () => {
  assert.match(route, /assetsApi\.liveAnalysis\(sym\)/);
  assert.match(route, /queryKey:\s*\["live-analysis", sym\]/);
  assert.match(route, /watchlistApi\.(list|add|remove)/);
});
test('every field returned by current live analysis remains represented', () => {
  const source = panel + visual;
  const fields = ['symbol','name','market','currency','sector','industry','last_price',
    'price_history','trade_date','close','final_score','buyer_strength','seller_strength',
    'confidence','trend','horizon','technical','valuation','sentiment','recommendation',
    'recommendation_color','rsi','ema20','ema50','macd','macd_signal','pe_ratio','pb_ratio',
    'dividend_yield','roe','debt_to_equity','revenue_growth','technical_votes',
    'ai_explanation','indicators_explanation','news_summary','news_items',
    'title','summary','url','source','published_at','sentiment_label','sentiment_score'];
  for (const field of fields) assert.match(source, new RegExp('\\b' + field + '\\b'), field);
});
test('no fake timeframes, support/resistance or synthetic market flow', () => {
  assert.doesNotMatch(panel + visual, /\b(S1|S2|R1|R2|order flow|market flow|M5|M15|H4|D1)\b/i);
});
test('missing sentiment is labeled instead of rendered as a numeric meter', () => {
  assert.match(panel, /item\.value == null \? 'Sem notícias' : item\.value/);
  assert.match(panel, /item\.value != null \? <Meter/);
});
