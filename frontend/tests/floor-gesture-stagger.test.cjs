require('./register-typescript.cjs');
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {avatarGesture}=require('../src/features/trading-floor/sceneGeometry.ts');
const pose={x:0,y:0,walking:false,stride:0,facing:'right',activity:'desk'};
test('desk gestures are staggered by stable identity instead of an office-wide synchronized stretch',()=>{
  const gestures=new Set(Array.from({length:20},(_,i)=>JSON.stringify(avatarGesture(pose,15000,false,`person-${i}`))));
  assert.ok(gestures.size>5,'people should not all have identical hand positions at the same time');
  assert.deepEqual(avatarGesture(pose,15000,false,'person-1'),avatarGesture(pose,15000,false,'person-1'));
  assert.deepEqual(avatarGesture(pose,15000,true,'person-1'),avatarGesture(pose,1000,true,'person-2'));
});
