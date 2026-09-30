const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const mt4 = fs.readFileSync(path.join(__dirname, '..', 'HandlivPanel.mq4'), 'utf8');
const mt5 = fs.readFileSync(path.join(__dirname, '..', '..', 'ea_mt5', 'HandlivPanel.mq5'), 'utf8');
function body(source, signature) {
  const start = source.indexOf(signature);
  assert.notEqual(start, -1, `Missing ${signature}`);
  const open = source.indexOf('{', start);
  let depth = 0;
  for (let i = open; i < source.length; i++) {
    if (source[i] === '{') depth++;
    if (source[i] === '}' && --depth === 0) return source.slice(open + 1, i);
  }
  throw Error(`Unclosed ${signature}`);
}
test('orders use the requested symbol, not the chart symbol', () => {
  for (const side of ['Buy', 'Sell']) {
    assert.match(body(mt5, `bool Execute${side}(`), new RegExp(`trade\\.${side}\\([^;]*\\bsymbol\\s*,`));
    assert.match(body(mt4, `bool Execute${side}(`), new RegExp(`OrderSend\\(\\s*symbol\\s*,\\s*OP_${side.toUpperCase()}\\b`));
  }
});
test('MT4 selects remote symbol before requesting quote', () => {
  const poll = body(mt4, 'void PollCommands()');
  assert.match(poll, /SymbolSelect\(symbol, true\)/);
  for (const side of ['Buy', 'Sell']) {
    const send = body(mt4, `bool Execute${side}(`);
    assert.ok(send.indexOf('SymbolSelect(symbol, true)') >= 0 &&
      send.indexOf('SymbolSelect(symbol, true)') < send.indexOf('MarketInfo(symbol,'));
  }
});
test('successful empty polling changes initial connection status', () => {
  const poll = body(mt4, 'void PollCommands()');
  assert.match(poll, /if\(!HttpGet\(url, resp\)\)/);
  const afterSuccess = poll.slice(poll.indexOf('if(!HttpGet(url, resp))'));
  assert.match(afterSuccess, /g_status\s*=\s*"Conectado"/);
});
test('timer schedule progresses without server ticks', () => {
  const timer = body(mt4, 'void OnTimer()');
  assert.match(timer, /TimeLocal\(\)/);
  assert.doesNotMatch(timer, /TimeCurrent\(\)/);
});
test('no pending MT4 orders in open-position count or closed-trade win/loss', () => {
  const stats = body(mt4, 'void SendStats()');
  assert.doesNotMatch(stats, /OrdersTotal\(\)\s*\)/);
  assert.match(stats, /OpenPositionsCount\(\)/);
  assert.match(body(mt4, 'void CountWinLoss('), /OrderType\(\)\s*!=\s*OP_BUY/);
  assert.match(body(mt4, 'double HistoryProfit('), /OrderType\(\)\s*!=\s*OP_BUY/);
});
test('POST excludes any trailing NUL byte from the JSON body', () => {
  const post = body(mt4, 'bool HttpPost(');
  assert.match(post, /post\[size\s*-\s*1\]\s*==\s*0/);
  assert.match(post, /size--/);
  assert.ok(post.indexOf('size--') < post.indexOf('WebRequest("POST"'));
  assert.match(post, /ArrayResize\(post,\s*size\)/);
});
test('MT4 uses custom-header WebRequest overload, not cookie/referer overload', () => {
  const get = body(mt4, 'bool HttpGet(');
  const post = body(mt4, 'bool HttpPost(');
  assert.match(post, /WebRequest\("POST",\s*url,\s*headers,\s*HTTP_TIMEOUT,\s*post,\s*result,\s*resultHeaders\)/);
  assert.match(get, /WebRequest\("GET",\s*url,\s*headers,\s*HTTP_TIMEOUT,\s*post,\s*result,\s*resultHeaders\)/);
  assert.match(post, /Content-Type: application\/json/);
});
test('POST failure captures safe validation detail and keeps failure visible', () => {
  const post = body(mt4, 'bool HttpPost(');
  assert.ok(post.indexOf('response = CharArrayToString(result') < post.indexOf('if(code == -1 || code >= 400)'));
  assert.match(post, /JsonGetString\(response, "type"\)/);
  assert.match(post, /JsonGetString\(response, "msg"\)/);
  assert.match(post, /g_status\s*=\s*"POST HTTP "/);
  assert.doesNotMatch(post, /Print\([^;]*\bjson\b/);
});
test('endpoint and payload keys remain shared with MT5', () => {
  const endpoints = s => [...s.matchAll(/\/mt5\/ea\/(?:commands|results|stats)/g)].map(x => x[0]).sort();
  assert.deepEqual(endpoints(mt4), endpoints(mt5));
  const payloadKeys = s => [...s.matchAll(/\\"([a-z_]+)\\":/g)].map(x => x[1]).sort();
  assert.deepEqual(payloadKeys(mt4), payloadKeys(mt5));
});
