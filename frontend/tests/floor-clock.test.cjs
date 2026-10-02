require('./register-typescript.cjs');
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {accountsToStations,snapshotNow}=require('../src/features/trading-floor/model.ts');
const server=Date.parse('2026-10-02T01:08:46Z');
const local=server-152000;
const accounts=[{id:'clock-test',account_number:'TEST',is_active:true,stats:null,robots:[{magic:'101',symbol:'EURUSD',updated_at:new Date(server-5000).toISOString(),heartbeat:true,is_present:true,open_positions:0}]}];
test('fresh robot stays present when browser clock is 152 seconds behind server',()=>{
 assert.equal(accountsToStations(accounts,local)[0].status,'OFFLINE','reproduces current wall-clock bug');
 assert.equal(accountsToStations(accounts,snapshotNow(new Date(server).toISOString(),local,local))[0].status,'AGUARDANDO');
});
test('server clock reference advances and still expires genuinely stale telemetry',()=>{
 assert.equal(accountsToStations(accounts,snapshotNow(new Date(server).toISOString(),local,local+100000))[0].status,'OFFLINE');
});
test('missing server time preserves legacy clock and invalid timestamps remain offline',()=>{
 assert.equal(snapshotNow(null,local,local+15000),local+15000);
 assert.equal(snapshotNow('invalid',local,local+15000),local+15000);
});
