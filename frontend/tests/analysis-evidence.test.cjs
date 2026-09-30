require('./register-typescript.cjs');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { analysisEvidence } = require('../src/features/asset-terminal/evidence.ts');

test('coverage comes only from dated daily bars and measured article scores', () => {
  const result = analysisEvidence({
    price_history: [{trade_date:'2026-09-26',close:11},{trade_date:'2026-09-29',close:12}],
    news_items: [
      {source:'Jornal A',sentiment_score:0.8},
      {source:'Jornal B',sentiment_score:null},
      {source:'Jornal A',sentiment_score:0.4},
    ],
    indicators: {rsi:45,ema20:null}, fundamentals:{pe_ratio:12,roe:null},
  });
  assert.equal(result.priceDate,'29/09/2026');
  assert.equal(result.priceBars,2);
  assert.equal(result.dailyChange,1);
  assert.ok(Math.abs(result.dailyChangePct - 100/11) < 0.0001);
  assert.equal(result.newsCount,3);
  assert.equal(result.measuredNews,2);
  assert.equal(result.newsSources,2);
  assert.equal(result.technicalCount,1);
  assert.equal(result.fundamentalsCount,1);
});

test('daily comparison uses two distinct valid dated closes and never an intraday quote', () => {
  const result=analysisEvidence({price_history:[
    {trade_date:'2026-09-29',close:108},{trade_date:'2026-09-28',close:100},
    {trade_date:'2026-09-29',close:108},{trade_date:'bad-date',close:999},
  ]});
  assert.equal(result.dailyChange,8);
  assert.equal(result.dailyChangePct,8);
  assert.equal(analysisEvidence({price_history:[{trade_date:'2026-09-28',close:0},{trade_date:'2026-09-29',close:10}]}).dailyChangePct,null);
  assert.equal(analysisEvidence({price_history:[{trade_date:'2026-09-29',close:10}]}).dailyChange,null);
});

test('missing data remains explicitly unavailable, not fresh or measured', () => {
  const result=analysisEvidence({price_history:[],news_items:[{source:'',sentiment_score:null}],indicators:{rsi:NaN},fundamentals:{pe_ratio:null}});
  assert.equal(result.priceDate,null);
  assert.equal(result.dailyChange,null);
  assert.equal(result.dailyChangePct,null);
  assert.equal(result.measuredNews,0);
  assert.equal(result.newsSources,0);
  assert.equal(result.technicalCount,0);
});
