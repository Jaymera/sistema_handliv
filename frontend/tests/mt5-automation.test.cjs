const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require('typescript');
require.extensions['.ts'] = (module, filename) => module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, esModuleInterop: true, target: ts.ScriptTarget.ES2020 } }).outputText, filename);
test('MT5 automation mounts only for current, available stats account and Ultimate', () => {
  const screen = fs.readFileSync(require('node:path').join(__dirname, '../app/(tabs)/mt5.tsx'), 'utf8');
  assert.match(screen, /active && !sLoading && !sError/);
  assert.match(screen, /isUltimate \? <AutomationControls key=\{active.id\} account=\{active\}/);
});
test('API exposes account-scoped automation GET and symbol-encoded PUT only', async () => {
  const Module = require('node:module');
  const original = Module._load;
  Module._load = function (name, ...args) {
    if (name === 'expo-constants') return { expoConfig: { extra: { API_BASE_URL: 'http://localhost:9876/api/v1' } } };
    if (name === 'react-native') return { Platform: { select: () => '/api/v1' } };
    if (name === '@/state/authStore') return { useAuthStore: { getState: () => ({ accessToken: null }) } };
    return original.call(this, name, ...args);
  };
  const calls = []; const oldFetch = global.fetch;
  global.fetch = async (url, init) => { calls.push([url, init]); return { ok: true, status: 200, json: async () => ({ items: [] }) }; };
  try {
    const { mt5AutomationApi } = require('../src/api/client.ts');
    assert.ok(mt5AutomationApi, 'automation configuration API is missing');
    await mt5AutomationApi.list('account & 1');
    assert.equal(calls[0][0], 'http://localhost:9876/api/v1/mt5/automation?account_id=account%20%26%201');
    const body = { account_id: 'a', broker_symbol: 'WIN$N', direction: 'sell', volume: '0.10', enabled: false };
    await mt5AutomationApi.save('EUR/USD', body);
    assert.equal(calls[1][0], 'http://localhost:9876/api/v1/mt5/automation/EUR%2FUSD');
    assert.equal(calls[1][1].method, 'PUT');
    assert.deepEqual(JSON.parse(calls[1][1].body), body);
  } finally { Module._load = original; global.fetch = oldFetch; }
});
test('mandatory SL/TP ATR14 H1 multipliers reject invalid or naked protection', () => {
  const { validateAutomation } = require('../src/features/mt5-automation/model.ts');
  const draft = { broker_symbol: 'EURUSD.a', volume: '0.10', direction: 'buy', sl_atr_multiplier: '2.00', tp_atr_multiplier: '3.00' };
  assert.equal(validateAutomation(draft), null);
  for (const field of ['sl_atr_multiplier', 'tp_atr_multiplier']) for (const value of ['', '0', '0.09', '20.01', 'Infinity', '1e1', '0.101', '-1']) assert.ok(validateAutomation({ ...draft, [field]: value }), field + ':' + value);
});
test('automation requires exact broker symbol and positive Numeric2 decimal volume', () => {
  const { validateAutomation: validate } = require('../src/features/mt5-automation/model.ts');
  const validateAutomation = draft => validate({ sl_atr_multiplier: '2.00', tp_atr_multiplier: '3.00', ...draft });
  for (const volume of ['', '0', '-1', 'Infinity', 'NaN', '1e2', '0.001', '1,2', '99999999999999.99', '999999999.99']) assert.ok(validateAutomation({ broker_symbol: 'EURUSD.a', volume, direction: 'buy' }), volume);
  for (const volume of ['0.01', '1', '1.20']) assert.equal(validateAutomation({ broker_symbol: 'EURUSD.a', volume, direction: 'both' }), null);
  assert.ok(validateAutomation({ broker_symbol: ' ', volume: '0.10', direction: 'sell' }));
  assert.ok(validateAutomation({ broker_symbol: ' EURUSD.a', volume: '0.10', direction: 'sell' }));
  assert.ok(validateAutomation({ broker_symbol: 'EURUSD.a', volume: '0.10', direction: 'other' }));
});
