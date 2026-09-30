require('./register-typescript.cjs');
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {layoutScene,traderPose,avatarGesture}=require('../src/features/trading-floor/sceneGeometry.ts');
test('activity gestures give coffee a cup, rest a phone, conversation expressive hands and opposing gait',()=>{
 assert.equal(typeof avatarGesture,'function');
 const pose=activity=>({activity,walking:activity==='walking',stride:4,facing:'right'});
 assert.equal(avatarGesture(pose('coffee'),1000,false).prop,'cup');
 assert.equal(avatarGesture(pose('rest'),1000,false).prop,'phone');
 assert.notDeepEqual(avatarGesture(pose('chat'),1000,false).right,avatarGesture(pose('chat'),1300,false).right);
 assert.ok(avatarGesture(pose('walking'),1000,false).left.y!==avatarGesture(pose('walking'),1000,false).right.y);
 assert.deepEqual(avatarGesture(pose('desk'),1000,true),avatarGesture(pose('desk'),1300,true));
});
test('idle people rotate coffee, conversation, rest, meeting and pool with smooth returns',()=>{
 const layout=layoutScene([{id:'magic-10'}]);
 assert.equal(layout.cols,3,'small real accounts have no phantom desk columns');
 assert.equal(layout.deskRows,1,'one desk row is enough for a single Magic');
 const desk=layout.stations[0],activities=new Set();
 let last;
 for(let t=0;t<900000;t+=100){
  const p=traderPose('AGUARDANDO',t,desk.id,false,desk,layout);
  activities.add(p.activity);
  if(last) assert.ok(Math.hypot(p.x-last.x,p.y-last.y)<16,'no teleport at routine boundaries');
  last=p;
 }
 for(const activity of ['desk','walking','coffee','chat','rest','meeting','pool'])assert.ok(activities.has(activity),activity);
});
