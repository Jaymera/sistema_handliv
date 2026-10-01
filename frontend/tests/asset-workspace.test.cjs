require('./register-typescript.cjs');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const file = path.join(__dirname, '../src/features/asset-terminal/workspace.ts');
const model = fs.existsSync(file) ? require(file) : {};

test('normalizes actual calendar sessions, sorts and deduplicates without fabricating prices', () => {
  assert.equal(typeof model.dailySessions, 'function', 'daily session normalizer is implemented');
  assert.deepEqual(model.dailySessions([
    {trade_date:'2026-09-30',close:12},{trade_date:'2026-09-28',close:10},
    {trade_date:'2026-09-30',close:13},{trade_date:'2026-02-30',close:50},
    {trade_date:'bad',close:999},{trade_date:'2026-09-29',close:NaN},
    {trade_date:'2026-09-27',close:0},
  ]),[{trade_date:'2026-09-28',close:10},{trade_date:'2026-09-30',close:13}]);
});

test('selected window reports observed change and close range, never intraday range', () => {
  assert.equal(typeof model.windowEvidence, 'function');
  const bars = [10, 12, 9, 15].map((close,i)=>({trade_date:`2026-09-${25+i}`,close}));
  assert.deepEqual(model.windowEvidence(bars, 3), {
    sessions: bars.slice(-3), count:3, firstDate:'2026-09-26', lastDate:'2026-09-28',
    change:3, changePct:25, minClose:9, maxClose:15,
  });
  assert.equal(model.windowEvidence(bars.slice(0,1), 5).changePct, null);
  assert.equal(model.windowEvidence([], 5).minClose, null);
});

test('factor summary compares returned pairs without calling ordering a crossover', () => {
  assert.equal(typeof model.factorEvidence, 'function');
  const result = model.factorEvidence({last_price:110,indicators:{ema20:100,ema50:105,macd:2,macd_signal:1,rsi:75}});
  assert.deepEqual(result.map(r=>r.state), ['above','below','above','overbought']);
  assert.ok(result.every(r=>r.available));
  assert.equal(model.factorEvidence({last_price:null,indicators:{ema20:100}})[0].available,false);
  assert.equal(model.factorEvidence({last_price:100,indicators:{ema20:100,ema50:100,macd:NaN}})[1].state,'equal');
});

test('display evidence rejects invalid dates, missing confidence and unscored sentiment', () => {
  assert.equal(typeof model.displayEvidence, 'function');
  assert.deepEqual(model.displayEvidence({score:{confidence:NaN,subscores:{sentiment:50}},sentiment_sample_count:0}),
    {confidence:null,sentiment:null,latestNewsDate:null});
  assert.deepEqual(model.displayEvidence({score:{confidence:80,subscores:{sentiment:60}},sentiment_sample_count:3,
    news_items:[{published_at:'2026-09-29T20:00:00Z'},{published_at:'invalid'}]}),
    {confidence:80,sentiment:60,latestNewsDate:'29/09/2026'});
  assert.equal(model.displayEvidence({score:{confidence:101,subscores:{sentiment:50}}}).sentiment,null);
});

test('impossible publication dates cannot become evidence through JavaScript date rollover', () => {
  assert.equal(model.displayEvidence({news_items:[{published_at:'2026-02-30T12:00:00Z'}]}).latestNewsDate,null);
  assert.equal(model.displayEvidence({news_items:[{published_at:'2026-02-30'}]}).latestNewsDate,null);
  assert.equal(model.displayEvidence({news_items:[{published_at:'2024-02-29T23:30:00-03:00'}]}).latestNewsDate,'29/02/2024');
});
