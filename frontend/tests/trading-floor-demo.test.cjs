require('./register-typescript.cjs');
const { test }=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const file=path.join(__dirname,'../src/features/trading-floor/demo.ts');
test('demo has deterministic isolated identities, supports 150 stations and does not fabricate first-load closure events',()=>{
  assert.ok(fs.existsSync(file),'demo generator not implemented');
  const {createDemo}=require(file);
  for(const count of [10,20,50,100,150]) {
    const frame=createDemo(count,1000);
    assert.equal(frame.stations.length,count);
    assert.equal(new Set(frame.stations.map(s=>s.id)).size,count);
    assert.ok(frame.stations.every(s=>s.id.startsWith('demo-')&&s.scope==='robot'));
    assert.deepEqual(frame.events,[]);
    assert.deepEqual(frame,createDemo(count,1000));
  }
});

test('demo closure changes only its station, emits a bounded unique event and never mutates previous snapshot',()=>{
  const {createDemo,advanceDemo}=require(file);
  assert.equal(typeof advanceDemo,'function');
  const initial=createDemo(100,1000);
  const original=JSON.stringify(initial);
  const next=advanceDemo(initial,1,7000);
  assert.equal(JSON.stringify(initial),original);
  assert.equal(next.events.length,1);
  assert.ok(next.events[0].id.startsWith('demo-event-'));
  assert.ok(next.stations.filter((s,i)=>s!==initial.stations[i]).length<=1);
  assert.equal(next.summary.openPositions,initial.summary.openPositions-1);
  const again=advanceDemo(next,1,7000);
  assert.equal(again,next,'same closure must not replay');
  const later=advanceDemo(next,2,14000);
  assert.ok(later.events.every(e=>14000-e.at<=5000));
  assert.equal(advanceDemo(createDemo(0),1).stations.length,0);
});
