require('./register-typescript.cjs');
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {dogPose,layoutScene,traderPose}=require('../src/features/trading-floor/sceneGeometry.ts');
test('decorative dog walks and rests even without online robots, with continuous bounded return',()=>{
 for(const count of [1,3,20,150]){
  const layout=layoutScene(Array.from({length:count},(_,i)=>({id:`d-${i}`})));
  const samples=Array.from({length:901},(_,i)=>dogPose([],layout,i*100,false));
  assert.ok(samples.some(p=>Math.hypot(p.x-layout.dogHome.x,p.y-layout.dogHome.y)>35),'dog must leave its home');
  assert.ok(samples.some(p=>p.walking&&Math.abs(p.stride)>0));
  assert.ok(samples.some(p=>!p.walking),'dog must rest');
  assert.ok(samples.some(p=>p.facing==='right')&&samples.some(p=>p.facing==='left'));
  for(let i=1;i<samples.length;i++)assert.ok(Math.hypot(samples[i].x-samples[i-1].x,samples[i].y-samples[i-1].y)<10,'no teleport');
  const start=dogPose([],layout,0,false),end=dogPose([],layout,90000,false);
  assert.deepEqual([start.x,start.y,start.walking],[end.x,end.y,end.walking]);
  assert.deepEqual(dogPose([],layout,0,true),dogPose([],layout,15000,true));
 }
});
test('dog gait and facing follow blended return and departure velocity',()=>{
 const layout=layoutScene([{id:'dog-visitor'}]),stations=[{id:'dog-visitor',status:'AGUARDANDO'}];
 // Both times were missed by the patrol-only gait: 9500 slid without stepping,
 // 9700 faced left even though the clearance blend moved the dog right.
 for(const t of [9500,9700,...Array.from({length:5000},(_,i)=>i*100+37)]){
  const before=dogPose(stations,layout,t-1,false),p=dogPose(stations,layout,t,false),after=dogPose(stations,layout,t+1,false);
  const dx=(after.x-before.x)/2,dy=(after.y-before.y)/2,moving=Math.hypot(dx,dy)>1e-6;
  assert.equal(p.walking,moving,`gait must match rendered velocity at ${t}ms`);
  if(moving&&Math.abs(dx)>1e-6)assert.equal(p.facing,dx<0?'left':'right',`facing must match rendered velocity at ${t}ms`);
  if(!moving)assert.equal(p.stride,0,`resting feet at ${t}ms`);
 }
});
test('dog patrol silhouette clears the lounge sofa and water bowl',()=>{
 const {officeShapes}=require('../src/features/trading-floor/officeDecor.ts');
 for(const count of [1,3,20,150]){
  const layout=layoutScene(Array.from({length:count},(_,i)=>({id:i===0?'dog-visitor':`d-${i}`})));
  const shapes=officeShapes(layout);
  const obstacles=shapes.filter(s=>s.tag==='sofa'&&s.type==='rect').map(s=>({...s,name:'sofa'}));
  const bowl=shapes.find(s=>s.tag==='dog-bed'&&s.type==='ellipse'&&s.rx===10);
  obstacles.push({x:bowl.x-bowl.rx,y:bowl.y-bowl.ry,width:bowl.rx*2,height:bowl.ry*2,name:'water bowl'});
  // Canvas and SVG both use scale 1.3: head/tail including strokes reach
  // +/-32.5; the foot strokes reach 18.85 below the motion anchor.
  for(const stations of [[],[{id:'dog-visitor',status:'AGUARDANDO'}]]){
   const end=stations.length?500000:30000;
   for(let t=37;t<end;t+=137){
    const p=dogPose(stations,layout,t,false),left=p.x-32.5,right=p.x+32.5,bottom=p.y-p.bounce+18.85,top=p.y-p.bounce-32;
    // Invert the conservative screen silhouette, not just its anchor. Even
    // its upper/right corner must remain below the lowest room's floor wall.
    const minGridY=(top/.39-right/.78)/2,minGridX=(left/.78+top/.39)/2,maxGridX=(right/.78+bottom/.39)/2;
    assert.ok(minGridY>layout.corridorY-80,`dog silhouette crosses a room wall at ${t}ms`);
    assert.ok(minGridX>0&&maxGridX<layout.worldWidth,`dog silhouette leaves the floor at ${t}ms`);
    for(const obstacle of obstacles){
     const overlaps=right>obstacle.x&&left<obstacle.x+obstacle.width&&bottom>obstacle.y&&top<obstacle.y+obstacle.height;
     assert.equal(overlaps,false,`dog silhouette overlaps ${obstacle.name} at ${t}ms (${count} desks)`);
    }
   }
  }
 }
});
test('dog returns smoothly to the petting stop as a real rendered visitor approaches',()=>{
 const layout=layoutScene([{id:'dog-visitor'}]),desk=layout.stations[0],stations=[{id:desk.id,status:'AGUARDANDO'}];
 let previous;
 let greeted=false;
 for(let t=0;t<500000;t+=100){
  const p=dogPose(stations,layout,t,false);
  if(previous)assert.ok(Math.hypot(p.x-previous.x,p.y-previous.y)<12,'approach/return cannot teleport');
  if(traderPose('AGUARDANDO',t,desk.id,false,desk,layout).activity==='dog'){
   assert.equal(p.visitorId,desk.id);assert.equal(p.walking,false);assert.equal(p.x,layout.dogHome.x);assert.equal(p.y,layout.dogHome.y);greeted=true;
  }
  previous=p;
 }
 assert.ok(greeted);
});
