require('./register-typescript.cjs');
const {test}=require('node:test');const assert=require('node:assert/strict');
const g=require('../src/features/trading-floor/sceneGeometry.ts');
test('trustworthy symbol rooms partition real stations and unknowns stay Outros',()=>{
 const items=['XAUUSD','EURUSD','AAPL','BTCUSD','mystery'].map((symbol,i)=>({id:String(i),symbol}));
 const scene=g.layoutScene(items);
 assert.deepEqual(scene.rooms.map(r=>r.kind),['Commodities','Forex','Ações','Crypto','Outros']);
 assert.deepEqual(scene.stations.map(s=>s.room),scene.rooms.map(r=>r.kind));
 assert.equal(g.stationRoom({symbol:null}),'Outros');assert.equal(g.stationRoom({symbol:'ABCDEF'}),'Outros');
 assert.equal(g.stationRoom({symbol:'GOLD'}),'Ações','ambiguous GOLD is catalogued Barrick, not invented gold CFD');
 for(const s of scene.stations){const r=scene.rooms.find(r=>r.kind===s.room);assert.ok(s.gridX>r.x&&s.gridX<r.x+r.width);}
});
test('rooms wrap into two compact banks instead of shrinking 20 people into one strip',()=>{
 const scene=g.layoutScene(Array.from({length:20},(_,i)=>({id:String(i),symbol:['XAUUSD','EURUSD','AAPL','BTCUSD',null][i%5]})));
 assert.ok(scene.rooms[3].y>scene.rooms[0].height);assert.ok(scene.worldWidth<scene.rooms.reduce((sum,r)=>sum+r.width,0));
});
test('conversation has a facing nearby visual-only coworker, never invented real robot telemetry',()=>{
 const scene=g.layoutScene([{id:'a'},{id:'b'}]);let found=false;
 for(let t=0;t<800000;t+=500){
  const peers=g.officeCoworkers([{id:'a',status:'AGUARDANDO'},{id:'b',status:'AGUARDANDO'}],scene,t,false);
  for(const peer of peers){found=true;const desk=scene.stations.find(s=>s.id===peer.visitorId),p=g.traderPose('AGUARDANDO',t,desk.id,false,desk,scene);
   assert.equal(peer.decorative,true);assert.equal(p.activity,'chat');assert.equal(p.facing,'right');assert.equal(peer.pose.facing,'left');assert.ok(Math.hypot(peer.x-desk.x-p.x,peer.y-desk.y-p.y)<90);
  }
 }
 assert.ok(found);assert.deepEqual(g.officeCoworkers([{id:'a',status:'OFFLINE'},{id:'b',status:'OFFLINE'}],scene,30000,false),[]);
});
test('dog visits visibly pet/play and synchronize dog response, continuous return and reduced motion',()=>{
 const scene=g.layoutScene([{id:'solo',symbol:'EURUSD'}]),desk=scene.stations[0];let last,seen=new Set(),pets=0;
 for(let t=0;t<1200000;t+=100){
  const pose=g.traderPose('AGUARDANDO',t,desk.id,false,desk,scene);seen.add(pose.activity);
  if(last)assert.ok(Math.hypot(pose.x-last.x,pose.y-last.y)<16,'no boundary teleport');last=pose;
  if(pose.activity==='dog'){
   pets++;const dog=g.dogPose([{id:desk.id,status:'AGUARDANDO'}],scene,t,false);
   assert.equal(dog.visitorId,desk.id);assert.ok(Math.hypot(dog.x-desk.x-pose.x,dog.y-desk.y-pose.y)<65);
   assert.equal(g.avatarGesture(pose,t,false).prop,'ball');
  }
 }
 assert.ok(pets>0);assert.ok(seen.has('desk')&&seen.has('walking'));assert.ok(!seen.has('chat'),'solo robot prefers dog, not fake real peer');
 const dog=g.dogPose([{id:desk.id,status:'OFFLINE'}],scene,10000,false);assert.equal(dog.visitorId,null);
 assert.deepEqual(g.dogPose([],scene,1000,true),g.dogPose([],scene,2000,true));
});
test('1/3/20/150 scenes circulate through actual doors and avoid other desks',()=>{
 for(const count of [1,3,20,150]){
  const scene=g.layoutScene(Array.from({length:count},(_,i)=>({id:String(i),symbol:['XAUUSD','EURUSD','AAPL','BTCUSD',null][i%5]})));
  for(const desk of scene.stations){
   const points=g.routeGrid(desk.id,scene,'coffee');const room=scene.rooms.find(r=>r.kind===desk.room);
   assert.ok(points.some(p=>p.x===room.x+room.width/2&&p.y===room.y+room.height),'route uses doorway');
   for(let k=1;k<points.length;k++)for(let f=0;f<=1;f+=.1){
    const p={x:points[k-1].x+(points[k].x-points[k-1].x)*f,y:points[k-1].y+(points[k].y-points[k-1].y)*f};
    for(const other of scene.stations.filter(s=>s.id!==desk.id))assert.ok(!(Math.abs(p.x-other.gridX)<105&&p.y>other.gridY-100&&p.y<other.gridY+90),'no desk crossing');
    for(const w of scene.walls)assert.ok(!(w.a.x===w.b.x&&Math.abs(p.x-w.a.x)<1&&p.y>Math.min(w.a.y,w.b.y)&&p.y<Math.max(w.a.y,w.b.y))&&!(w.a.y===w.b.y&&Math.abs(p.y-w.a.y)<1&&p.x>Math.min(w.a.x,w.b.x)&&p.x<Math.max(w.a.x,w.b.x)),'no wall crossing');
   }
  }
 }
});
