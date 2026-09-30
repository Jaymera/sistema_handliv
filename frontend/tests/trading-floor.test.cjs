require('./register-typescript.cjs');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const file = path.join(__dirname, '../src/features/trading-floor/model.ts');
test('account-only telemetry cannot produce fictitious magic desks', () => {
  assert.ok(fs.existsSync(file), 'Trading Floor account adapter is not implemented');
  const { accountsToStations } = require(file);
  const now = Date.parse('2026-09-24T12:00:00Z');
  const rows = accountsToStations([{id:'a',account_number:'123',broker:'Broker',is_active:true,stats:{currency:'USD',balance:1000,equity:1040,floating_pl:40,dd_percent:0,profit_day:35,profit_week:90,profit_month:120,total_trades:4,win_trades:3,loss_trades:1,open_positions:2,updated_at:'2026-09-24T11:59:45'}}], now);
  assert.deepEqual(rows, []);
});

test('one real desk per positive Magic, scoped by account and using robot metrics', () => {
  const { accountsToStations } = require(file);
  const now=Date.parse('2026-09-24T12:00:00Z');
  const stats={updated_at:'2026-09-24T11:59:45Z',currency:'USD',profit_day:999,open_positions:8};
  const robots=[
    {magic:'101',symbol:'EURUSD',open_positions:1,floating_pl:12,profit_total:25,total_trades:3,win_trades:2,loss_trades:1,heartbeat:true,is_present:true,updated_at:stats.updated_at},
    {magic:'202',symbol:'GBPUSD',open_positions:0,floating_pl:0,profit_total:-3,total_trades:1,win_trades:0,loss_trades:1,heartbeat:true,is_present:true,updated_at:stats.updated_at},
    {magic:'0',symbol:'USDJPY',open_positions:1,is_present:true,updated_at:stats.updated_at},
  ];
  const rows=accountsToStations([{id:'a',account_number:'123',is_active:true,stats,robots},{id:'b',account_number:'456',is_active:true,stats,robots:[robots[0]]}],now);
  assert.equal(rows.length,3);
  assert.equal(new Set(rows.map(s=>s.id)).size,3);
  assert.deepEqual(rows.map(s=>s.magic),['101','202','101']);
  assert.deepEqual(rows.map(s=>s.status),['POSIÇÃO ABERTA','AGUARDANDO','POSIÇÃO ABERTA']);
  assert.equal(rows[0].profitDay,null);
  assert.equal(rows[1].symbol,'GBPUSD');
  assert.equal(rows[0].scope,'robot');
  assert.equal(rows[0].accountId,'a');
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
  const account={id:'a',stats:{currency:'BRL',balance:20,equity:18,profit_day:0,floating_pl:-2,dd_percent:10,open_positions:1}};
  const summary=accountSummary(account,[{accountId:'a',status:'AGUARDANDO'},{accountId:'b',status:'AGUARDANDO'},{accountId:'a',status:'OFFLINE'}]);
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
  assert.deepEqual(accountsToStations([base],now),[]);
  const fresh={...base,stats:{...base.stats,updated_at:'2026-09-24T12:00:00Z'}};
  const withRobot={...fresh,robots:[{magic:'901',open_positions:0,heartbeat:true,is_present:true,updated_at:fresh.stats.updated_at}]};
  assert.equal(accountsToStations([{...base,robots:[{...withRobot.robots[0],updated_at:base.stats.updated_at}]}],now)[0].status,'OFFLINE');
  assert.equal(accountsToStations([withRobot],now)[0].status,'AGUARDANDO');
  assert.equal(accountsToStations([{...withRobot,is_active:false}],now)[0].status,'OFFLINE');
  assert.equal(accountsToStations([{...withRobot,robots:[{...withRobot.robots[0],heartbeat:false}]}],now)[0].status,'OFFLINE');
  assert.deepEqual(accountsToStations([{...base,stats:null}],now),[]);
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
