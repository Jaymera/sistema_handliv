require('./register-typescript.cjs');
const {test} = require('node:test');
const assert = require('node:assert/strict');
const g = require('../src/features/trading-floor/sceneGeometry.ts');
const {layoutScene,traderPose,avatarGesture}=g;
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
 assert.equal(layout.stations.length,1,'no phantom desk identities in empty rooms');
 assert.equal(layout.rooms.find(r=>r.members.length).rows,1,'one occupied row is enough for a single Magic');
 const desk=layout.stations[0],activities=new Set();
 let last;
 for(let t=0;t<900000;t+=100){
  const p=traderPose('AGUARDANDO',t,desk.id,false,desk,layout);
  activities.add(p.activity);
  if(last) assert.ok(Math.hypot(p.x-last.x,p.y-last.y)<16,'no teleport at routine boundaries');
  last=p;
 }
 for(const activity of ['desk','walking','coffee','dog','rest','meeting','pool'])assert.ok(activities.has(activity),activity);
});

test('geometry-free preview also keeps active traders predominantly working', () => {
  for(const status of ['OPERANDO','POSIÇÃO ABERTA']) {
    const poses=Array.from({length:2000},(_,i)=>g.traderPose(status,i*100,'preview',false));
    assert.ok(poses.some(p=>p.walking));
    assert.ok(poses.filter(p=>p.activity==='desk').length/poses.length>=.8);
  }
});

test('visual pauses are unhurried, with active agents resting less than waiting agents', () => {
  const scene=g.layoutScene([{id:'unhurried',symbol:'EURUSD'}]), desk=scene.stations[0];
  for(const status of ['OPERANDO','AGUARDANDO']) {
    const durations=[]; let started=null;
    for(let t=0;t<1000000;t+=100) {
      const p=g.traderPose(status,t,desk.id,false,desk,scene);
      const dwelling=!p.walking && p.activity!=='desk';
      if(dwelling && started===null) started=t;
      if(!dwelling && started!==null) { if(started>0) durations.push(t-started); started=null; }
    }
    assert.ok(durations.length>2);
    assert.ok(durations.every(ms=>status==='OPERANDO' ? ms>=8000 && ms<=12100 : ms>=15000 && ms<=25100),`${status}: ${durations}`);
  }
});

test('desk body language alternates typing, looking and stretching while reduced motion stays static', () => {
  const pose=g.traderPose('OPERANDO',0,'gesture',true);
  const typing=g.avatarGesture(pose,0,false), looking=g.avatarGesture(pose,13000,false), stretching=g.avatarGesture(pose,16000,false);
  assert.ok(looking.right.y < -35,'hand moves toward face while looking');
  assert.ok(stretching.left.y < -40 && stretching.right.y < -40,'both arms stretch overhead');
  assert.notDeepEqual(typing,looking);
  assert.deepEqual(g.avatarGesture(pose,0,true),g.avatarGesture(pose,16000,true));
});

test('each route uses distance-appropriate walking speed rather than the longest-route duration', () => {
  const scene = g.layoutScene([{id:'speed',symbol:'EURUSD'}]);
  const desk = scene.stations[0];
  let maximum = 0, wasWalking = false;
  const speeds = [];
  for (let t=0; t<1200000; t+=100) {
    const p=g.traderPose('AGUARDANDO',t,desk.id,false,desk,scene);
    if(p.walking) {
      const q=g.traderPose('AGUARDANDO',t+20,desk.id,false,desk,scene);
      if(q.walking) maximum=Math.max(maximum,Math.hypot(q.x-p.x,q.y-p.y)/.02);
    } else if(wasWalking) { speeds.push(maximum); maximum=0; }
    wasWalking=p.walking;
  }
  assert.ok(speeds.length>12);
  assert.ok(speeds.every(speed=>speed>=80 && speed<=120), `natural walking speeds: ${speeds}`);
});

test('all present visitors synchronize pet and chat partners at their actual visual position', () => {
  const scene=g.layoutScene([{id:'visitor',symbol:'EURUSD'},{id:'offline',symbol:'EURUSD'}]);
  const desk=scene.stations.find(s=>s.id==='visitor'), camera=g.fitCamera(scene.bounds,1100,550);
  for(const status of ['AGUARDANDO','OPERANDO','POSIÇÃO ABERTA']) {
    const stations=Object.freeze([Object.freeze({id:desk.id,status}),Object.freeze({id:'offline',status:'OFFLINE'})]);
    const found=new Set();
    for(let t=0;t<4000000 && found.size<2;t+=500) {
      const p=g.traderPose(status,t,desk.id,false,desk,scene);
      if(p.activity==='dog') {
        const dog=g.dogPose(stations,scene,t,false);
        assert.equal(dog.visitorId,desk.id,`${status} dog must respond to actual visitor`);
        assert.ok(dog.bounce>=0);
        assert.ok(Math.hypot(dog.x-desk.x-p.x,dog.y-desk.y-p.y)<65);
        found.add('dog');
      }
      if(p.activity==='chat') {
        const peers=g.officeCoworkers(stations,scene,t,false);
        assert.equal(peers.length,1,`${status} chat must have facing visual partner`);
        assert.equal(peers[0].visitorId,desk.id);
        assert.equal(peers[0].decorative,true);
        assert.equal(peers[0].pose.facing,'left');
        assert.equal(p.facing,'right');
        found.add('chat');
      }
      if(p.walking || p.activity==='dog' || p.activity==='chat') {
        const screen=g.toScreen({x:desk.x+p.x,y:desk.y+p.y-20},camera);
        assert.equal(g.hitAgent(screen,stations,scene,camera,t,false),desk.id);
      }
    }
    assert.deepEqual([...found].sort(),['chat','dog']);
    assert.deepEqual(g.officeCoworkers(stations,scene,30000,true),[]);
    assert.equal(g.dogPose(stations,scene,30000,true).visitorId,null);
  }
});

test('every present status completes deterministic staggered journeys without teleports and honors reduced motion', () => {
  const scene=g.layoutScene([{id:'a',symbol:'EURUSD'},{id:'b',symbol:'EURUSD'}]);
  for(const status of ['AGUARDANDO','OPERANDO','POSIÇÃO ABERTA']) {
    let last, leftDesk=false, returned=false, staggered=false;
    const desk=scene.stations[0], other=scene.stations[1];
    for(let t=-1000;t<2000000;t+=100) {
      const p=g.traderPose(status,t,desk.id,false,desk,scene);
      if(last) assert.ok(Math.hypot(p.x-last.x,p.y-last.y)<=12,'continuous cycle including destination changes');
      if(Math.hypot(p.x,p.y)>50) leftDesk=true;
      if(leftDesk && p.activity==='desk') returned=true;
      if(t%10000===0) {
        assert.deepEqual(p,g.traderPose(status,t,desk.id,false,desk,scene));
        assert.deepEqual(g.traderPose(status,t,desk.id,true,desk,scene),g.traderPose(status,0,desk.id,true,desk,scene));
        const q=g.traderPose(status,t,other.id,false,other,scene);
        if(p.walking!==q.walking || p.activity!==q.activity) staggered=true;
      }
      last=p;
    }
    assert.ok(leftDesk && returned && staggered,status);
  }
  const desk=scene.stations[0];
  for(const t of [0,5000,100000,2000000]) {
    assert.deepEqual(g.traderPose('OFFLINE',t,desk.id,false,desk,scene),g.traderPose('OFFLINE',0,desk.id,false,desk,scene));
  }
});
