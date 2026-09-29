require('./register-typescript.cjs');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const file = path.join(__dirname, '../src/features/trading-floor/model.ts');
test('account telemetry produces an explicitly account-scoped station without invented robot fields', () => {
  assert.ok(fs.existsSync(file), 'Trading Floor account adapter is not implemented');
  const { accountsToStations } = require(file);
  const now = Date.parse('2026-09-24T12:00:00Z');
  const rows = accountsToStations([{id:'a',account_number:'123',broker:'Broker',is_active:true,stats:{currency:'USD',balance:1000,equity:1040,floating_pl:40,dd_percent:0,profit_day:35,profit_week:90,profit_month:120,total_trades:4,win_trades:3,loss_trades:1,open_positions:2,updated_at:'2026-09-24T11:59:45'}}], now);
  assert.equal(rows.length,1);
  assert.equal(rows[0].scope,'account');
  assert.match(rows[0].name,/HandlivPanel.*123/);
  assert.equal(rows[0].magic,null);
  assert.equal(rows[0].symbol,null);
  assert.equal(rows[0].profitDay,35);
  assert.equal(rows[0].status,'POSIÇÃO ABERTA');
  assert.deepEqual(rows[0].positions,[]);
});

test('real accounts take priority over demo, including accounts awaiting MT5', () => {
  const { chooseSource } = require(file);
  assert.equal(typeof chooseSource, 'function');
  assert.equal(chooseSource([{id:'a',stats:null}],true),'real');
  assert.equal(chooseSource([],true),'demo');
  assert.equal(chooseSource([],false),'real');
});

test('summary remains scoped to selected account, no currency/percentage aggregation or fake equity series', () => {
  const { accountSummary } = require(file);
  assert.equal(typeof accountSummary, 'function');
  const account={stats:{currency:'BRL',balance:20,equity:18,profit_day:0,floating_pl:-2,dd_percent:10,open_positions:1}};
  const summary=accountSummary(account,[{status:'AGUARDANDO'},{status:'OFFLINE'}]);
  assert.equal(summary.currency,'BRL');
  assert.equal(summary.balance,20);
  assert.equal(summary.profitDay,0);
  assert.equal(summary.online,1);
  assert.deepEqual(summary.equityHistory,[]);
  assert.equal(accountSummary(undefined,[]).equity,null);
});

test('stale, invalid, absent and inactive telemetry is not shown online; no stats is unknown not zero', () => {
  const { accountsToStations } = require(file);
  const base={id:'a',account_number:'123',is_active:true,stats:{currency:'USD',open_positions:0,updated_at:'2026-09-24T10:00:00Z'}};
  const now=Date.parse('2026-09-24T12:00:00Z');
  assert.equal(accountsToStations([base],now)[0].status,'OFFLINE');
  const fresh={...base,stats:{...base.stats,updated_at:'2026-09-24T12:00:00Z'}};
  assert.equal(accountsToStations([fresh],now)[0].status,'AGUARDANDO');
  assert.equal(accountsToStations([{...fresh,is_active:false}],now)[0].status,'OFFLINE');
  const missing=accountsToStations([{...base,stats:null}],now)[0];
  assert.equal(missing.profitDay,null);
  assert.equal(missing.openPositions,null);
});

test('money formatting distinguishes unknown/invalid values and zero, with account currency', () => {
  const { money } = require(file);
  assert.equal(typeof money,'function');
  assert.equal(money(null,'USD'),'—');
  assert.equal(money(NaN,'USD'),'—');
  assert.match(money(0,'USD',true),/^\+US\$/);
  assert.match(money(-12.3,'BRL',true),/^-R\$/);
  assert.match(money(42.8,'USD',true),/42[,.]80/);
});
