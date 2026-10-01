import React, { memo, useEffect, useRef } from 'react';
import type { FloorSceneProps } from './types';
import { officeShapes } from './officeDecor';
import { Camera, Point, dogPose, officeCoworkers, agentAppearance, avatarGesture, avatarVisible, fitCamera, hitAgent, hitStation, iso, layoutScene, money, toScreen, traderPose, zoomCamera } from './sceneGeometry';

const C = { bg: '#0A1120', ink: '#E9EFF9', muted: '#8498B7', green: '#16D39A', blue: '#4C8DFF', red: '#FF7289' };
type Layout = ReturnType<typeof layoutScene>;

/** Pure drawing entry point; the component owns scheduling and input only. */
export function drawFloorScene(ctx: CanvasRenderingContext2D, props: FloorSceneProps, layout: Layout, camera: Camera, width: number, height: number, now: number) {
  const poly = (points: Point[], fill: string, stroke?: string) => {
    ctx.beginPath(); points.forEach((p, i) => i ? ctx.lineTo(p.x, p.y) : ctx.moveTo(p.x, p.y)); ctx.closePath();
    ctx.fillStyle = fill; ctx.fill(); if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = 1; ctx.stroke(); }
  };
  const rect = (x: number, y: number, w: number, h: number, color: string, radius = 0) => {
    ctx.fillStyle = color; ctx.beginPath(); ctx.roundRect(x, y, w, h, radius); ctx.fill();
  };
  const text = (t: string, x: number, y: number, size = 12, color = C.ink, weight = 500) => {
    ctx.font = `${weight} ${size}px Inter, system-ui, sans-serif`; ctx.fillStyle = color; ctx.fillText(t, x, y);
  };
  const line = (a: Point, b: Point, color: string, w = 1) => { ctx.beginPath(); ctx.moveTo(a.x,a.y); ctx.lineTo(b.x,b.y); ctx.strokeStyle = color; ctx.lineWidth = w; ctx.stroke(); };
  ctx.clearRect(0, 0, width, height);
  const glow = ctx.createRadialGradient(width * .5, height * .5, 10, width * .5, height * .5, width * .7);
  glow.addColorStop(0, '#15243B'); glow.addColorStop(1, C.bg); ctx.fillStyle = glow; ctx.fillRect(0, 0, width, height);
  ctx.save(); ctx.translate(camera.x, camera.y); ctx.scale(camera.scale, camera.scale);
  const [a,b,c,d] = layout.floor;
  // Architectural plinth, copper-free glass walls and a fine tiled raised floor.
  poly([d,c,{x:c.x,y:c.y+20},{x:d.x,y:d.y+20}], '#0A1324', '#26374F');
  poly([b,c,{x:c.x,y:c.y+20},{x:b.x,y:b.y+20}], '#111D32', '#26374F');
  poly([a,b,{x:b.x,y:b.y-100},{x:a.x,y:a.y-100}], '#17253B', '#2D4260');
  poly([a,d,{x:d.x,y:d.y-100},{x:a.x,y:a.y-100}], '#101D30', '#2D4260');
  line({x:d.x,y:d.y-99},{x:a.x,y:-99}, C.green, 3);
  line({x:a.x,y:-99},{x:b.x,y:b.y-99}, C.blue, 3);
  poly(layout.floor, '#172439', '#344763');
  for (let x=0; x<=layout.cols*240; x+=120) line(iso(x,0),iso(x,layout.rows*240),'#22324A');
  for (let y=0; y<=layout.rows*240; y+=120) line(iso(0,y),iso(layout.cols*240,y),'#22324A');
  for(const shape of officeShapes(layout)){
    if(shape.type==='poly')poly(shape.points,shape.fill,shape.stroke);
    else if(shape.type==='rect')rect(shape.x,shape.y,shape.width,shape.height,shape.fill,shape.radius);
    else if(shape.type==='line')line(shape.a,shape.b,shape.stroke,shape.width);
    else if(shape.type==='text')text(shape.text,shape.x,shape.y,shape.size,shape.fill,700);
    else {ctx.fillStyle=shape.fill;ctx.beginPath();ctx.ellipse(shape.x,shape.y,shape.rx,shape.ry,0,0,Math.PI*2);ctx.fill();}
  }
  // Central command display: only supplied financial data, never decorative quotes.
  rect(-244,-214,488,164,'#060E1B',12);
  rect(-244,-214,4,164,C.green,2);
  text('HANDLIV',-220,-183,22,C.ink,850); text('TRADING FLOOR',-86,-183,12,C.green,750);
  text(props.demo ? 'AMBIENTE DEMONSTRATIVO' : 'CENTRO DE OPERAÇÕES',-220,-161,9,C.muted,650);
  text('RESULTADO HOJE',-220,-133,10,C.muted,650);
  text(money(props.summary.profitDay,props.summary.currency),-220,-104,26,(props.summary.profitDay??0)<0?C.red:C.green,750);
  text('SALDO',35,-135,9,C.muted); text(money(props.summary.balance,props.summary.currency),35,-117,14);
  text('PATRIMÔNIO',35,-92,9,C.muted); text(money(props.summary.equity,props.summary.currency),35,-73,14);
  const byId = new Map(props.stations.map(s=>[s.id,s]));
  for (const pos of layout.stations) {
    const screen = toScreen(pos,camera);
    if (screen.x+110*camera.scale<0 || screen.x-110*camera.scale>width || screen.y+65*camera.scale<0 || screen.y-125*camera.scale>height) continue;
    const s=byId.get(pos.id)!;
    const active=s.status==='POSIÇÃO ABERTA', offline=s.status==='OFFLINE';
    const color=offline?'#66758C':active?C.blue:s.status==='OPERANDO'?C.green:'#E6B866';
    ctx.save(); ctx.translate(pos.x,pos.y);
    if (props.selectedId===s.id || active) {
      ctx.globalAlpha=props.selectedId===s.id?.8:.22;
      poly([{x:0,y:-56},{x:102,y:-5},{x:0,y:46},{x:-102,y:-5}],color,color); ctx.globalAlpha=1;
    }
    // Desk cast shadow, steel legs, beveled walnut/graphite worktop.
    ctx.fillStyle='#080F1D'; ctx.beginPath(); ctx.ellipse(0,18,91,31,0,0,Math.PI*2); ctx.fill();
    [-65,54].forEach(x=>{rect(x,-15,7,43,'#091220',2);rect(x+1,23,12,4,'#41506A',1);});
    poly([{x:-90,y:-37},{x:19,y:-77},{x:92,y:-40},{x:-18,y:4}],'#34465F','#536681');
    poly([{x:-90,y:-37},{x:-18,y:4},{x:-18,y:13},{x:-90,y:-28}],'#18283E');
    poly([{x:-18,y:4},{x:92,y:-40},{x:92,y:-31},{x:-18,y:13}],'#22344C');
    // Three angled screens with non-market telemetry bars (no fabricated candles).
    [-49,-6,37].forEach((x,i)=>{
      const y=-72+(i===1?-7:0);
      rect(x+14,y+28,4,13,'#71809A');rect(x+7,y+38,20,3,'#142135',1);
      rect(x,y,39,30,'#080F1C',3);rect(x+3,y+3,33,23,offline?'#182336':'#102D3B',1);
      line({x:x+7,y:y+9},{x:x+30,y:y+9},offline?'#41506A':color,2);
      for(let j=0;j<3;j++) rect(x+7,y+14+j*4,18-j*4,1,offline?'#34435A':'#48768D');
    });
    poly([{x:-27,y:-21},{x:-5,y:-29},{x:13,y:-20},{x:-10,y:-12}],'#8392A6');
    // Chair remains at the desk even when the trader visits the social area.
    rect(-21,25,12,7,'#060B14',3);rect(8,27,12,7,'#060B14',3);
    line({x:-10,y:9},{x:-16,y:26},'#27344B',8);line({x:7,y:9},{x:13,y:29},'#27344B',8);
    rect(-24,-14,47,30,'#0A1426',10);rect(-3,12,5,20,'#63718A');line({x:-20,y:34},{x:20,y:34},'#63718A',3);
    // Screen-aligned name plate remains readable while inspecting a station.
    rect(-90,40,180,65,'#0B1527',7);rect(-90,40,3,65,color,2);
    text(s.name.length>23?s.name.slice(0,22)+'…':s.name,-80,57,12,C.ink,700);
    text(s.symbol??'—',-80,72,10,C.muted);
    const deskValue=props.demo?s.profitDay:s.floatingPl??null;
    ctx.textAlign='right';text(money(deskValue,s.currency),81,73,11,(deskValue??0)<0?C.red:C.green,700);ctx.textAlign='left';
    text(s.status,-80,94,9,color,750);
    if(active){ctx.globalAlpha=props.reducedMotion?1:.65+Math.sin(now/500)*.25;ctx.fillStyle=color;ctx.beginPath();ctx.arc(77,90,3,0,Math.PI*2);ctx.fill();ctx.globalAlpha=1;}
    ctx.restore();
  }
  // The social row is separated from the trading stations in layoutScene.
  for(const area of layout.amenities){
    const p=toScreen(area,camera);if(p.x<-120||p.x>width+120||p.y<-130||p.y>height+130)continue;
    ctx.save();ctx.translate(area.x,area.y);
    ctx.fillStyle='#0B1728';ctx.beginPath();ctx.ellipse(0,22,94,41,0,0,Math.PI*2);ctx.fill();
    if(area.kind==='pool'){
      rect(-80,-35,160,77,'#603C2F',9);rect(-73,-30,146,61,'#0D634B',6);
      ctx.strokeStyle='#E8E1CE';ctx.lineWidth=2;ctx.strokeRect(-69,-26,138,53);
      for(const [x,y] of [[-63,-22],[63,-22],[-63,25],[63,25],[0,-22],[0,25]]){ctx.fillStyle='#101725';ctx.beginPath();ctx.arc(x,y,5,0,Math.PI*2);ctx.fill();}
      for(const [x,y,color] of [[-18,0,'#EFEADB'],[32,3,'#F2B74D'],[26,-3,'#4C8DFF']] as [number,number,string][]) {ctx.fillStyle=color;ctx.beginPath();ctx.arc(x,y,3,0,Math.PI*2);ctx.fill();}
      line({x:-43,y:24},{x:37,y:-15},'#E6C999',2);text('SINUCA',-35,58,10,C.muted,700);
    }else if(area.kind==='coffee'){
      rect(-65,-23,130,53,'#38516B',12);rect(-57,-17,114,41,'#B28764',10);
      for(const [x,y] of [[-28,0],[0,-4],[28,1]]){ctx.fillStyle='#F2EEE1';ctx.beginPath();ctx.arc(x,y,8,0,Math.PI*2);ctx.fill();ctx.fillStyle='#75513C';ctx.beginPath();ctx.arc(x,y,5,0,Math.PI*2);ctx.fill();}
      text('CAFÉ',-20,53,10,C.muted,700);
    }else{
      rect(-83,-27,166,64,'#213F55',23);rect(-76,-22,152,54,'#576E83',19);
      for(const x of [-56,-18,20,58]){rect(x,-44,19,12,'#243D56',5);rect(x,39,19,12,'#243D56',5);}
      rect(-31,-7,62,3,C.blue,2);text('REUNIÃO',-29,60,10,C.muted,700);
    }
    ctx.restore();
  }
  // Agents are rendered after furniture, in foot-depth order, so a visitor stays visible.
  const people=layout.stations.flatMap(pos=>{
    const station=byId.get(pos.id);
    if(!station||!avatarVisible(station.status))return [];
    const pose=traderPose(station.status,now,pos.id,props.reducedMotion,pos,layout);
    return [{pos,pose,name:station.name,appearance:agentAppearance(pos.id)}];
  }).concat(officeCoworkers(props.stations,layout,now,props.reducedMotion).map(peer=>({pos:{...layout.stations[0],id:peer.id,x:peer.x,y:peer.y},pose:peer.pose,name:peer.name,appearance:agentAppearance(peer.id)}))).sort((a,b)=>(a.pos.y+a.pose.y)-(b.pos.y+b.pose.y));
  for(const {pos,pose,name,appearance} of people){
    const p=toScreen({x:pos.x+pose.x,y:pos.y+pose.y},camera);
    if(p.x<-45||p.x>width+45||p.y<-70||p.y>height+50)continue;
    ctx.save();ctx.translate(pos.x+pose.x,pos.y+pose.y);ctx.scale(1.16,1.16);
    const step=pose.walking?pose.stride:0;
    const breathing=props.reducedMotion?0:Math.sin(now/730+(pos.x%13))*.8;
    ctx.fillStyle='#07101D';ctx.beginPath();ctx.ellipse(0,30,19,6,0,0,Math.PI*2);ctx.fill();
    line({x:-9,y:2},{x:-10+step,y:28},'#26354A',8);
    line({x:8,y:2},{x:10-step,y:28},'#26354A',8);
    rect(-18+step,27,13,6,'#0A0C16',2);rect(7-step,27,13,6,'#0A0C16',2);
    rect(-16,-30+breathing,31,40,appearance.jacket,10);
    const gesture=avatarGesture(pose,now,props.reducedMotion);
    line({x:-12,y:-22},{x:gesture.left.x,y:gesture.left.y},appearance.jacket,8);
    line({x:12,y:-22},{x:gesture.right.x,y:gesture.right.y},appearance.jacket,8);
    for(const hand of [gesture.left,gesture.right]){ctx.fillStyle=appearance.skin;ctx.beginPath();ctx.arc(hand.x,hand.y,4,0,Math.PI*2);ctx.fill();}
    if(gesture.prop==='cup'){
      rect(gesture.right.x-5,gesture.right.y-8,11,11,'#F3EADF',3);
      ctx.strokeStyle='#F3EADF';ctx.lineWidth=2;ctx.beginPath();ctx.arc(gesture.right.x+7,gesture.right.y-3,4,-Math.PI/2,Math.PI/2);ctx.stroke();
      line({x:gesture.right.x,y:gesture.right.y-13},{x:gesture.right.x+2,y:gesture.right.y-19},'#A7BACB',1);
    }
    if(gesture.prop==='ball'){ctx.fillStyle='#F4C35C';ctx.beginPath();ctx.arc(gesture.left.x,gesture.left.y,5,0,Math.PI*2);ctx.fill();}
    if(gesture.prop==='phone'){rect(gesture.right.x-5,gesture.right.y-11,10,15,'#101725',2);rect(gesture.right.x-3,gesture.right.y-9,6,10,'#91BADA',1);}
    if(gesture.prop==='cue')line({x:gesture.left.x-20,y:gesture.left.y+12},{x:gesture.right.x+24,y:gesture.right.y-16},'#D7B17A',3);
    // Shirt collar and visible human hands, not anonymous blocks.
    poly([{x:-8,y:-31},{x:0,y:-24},{x:8,y:-31}], '#D9E4ED');
    line({x:0,y:-24},{x:0,y:3},'#34445C',2);
    ctx.fillStyle=appearance.skin;ctx.beginPath();ctx.ellipse(-1,-39+breathing,12,14,0,0,Math.PI*2);ctx.fill();
    ctx.fillStyle=appearance.hair;ctx.beginPath();ctx.ellipse(-2,-46+breathing,12,8,-.2,0,Math.PI*2);ctx.fill();
    if(pose.facing==='left')line({x:-9,y:-38},{x:-9,y:-33},'#1B2432',2);
    else line({x:8,y:-38},{x:8,y:-33},'#1B2432',2);
    if(pose.activity==='chat'){rect(22,-66,34,17,'#D6E5E7',6);text('···',29,-53,16,'#365568',800);}
    if(pose.activity!=='desk'){
      if(!pose.walking){const label={coffee:'CAFÉ',chat:'CONVERSA',meeting:'REUNIÃO',rest:'PAUSA',pool:'SINUCA',dog:'CARINHO / PLAY'}[pose.activity as 'coffee'|'chat'|'meeting'|'rest'|'pool'|'dog'];rect(-35,-94,70,17,'#213F55',5);text(label,-29,-82,9,'#B8D9E8',750);}
      rect(-41,-72,82,18,'#0B1527',5);text(name.length>14?name.slice(0,13)+'…':name,-35,-59,9,C.ink,700);
    }
    ctx.restore();
  }
  // Shared dog response: faster wag and playful bounce while an idle visitor pets it.
  {const dog=dogPose(props.stations,layout,now,props.reducedMotion),dir=-1;
    ctx.save();ctx.translate(dog.x,dog.y-dog.bounce);ctx.scale(1.3,1.3);ctx.fillStyle='#A87852';ctx.beginPath();ctx.ellipse(0,0,16,9,0,0,Math.PI*2);ctx.fill();
    ctx.beginPath();ctx.arc(dir*15,-8,8,0,Math.PI*2);ctx.fill();
    poly([{x:dir*10,y:-13},{x:dir*7,y:-24},{x:dir*17,y:-15}],'#79543C');
    ctx.fillStyle='#101725';ctx.beginPath();ctx.arc(dir*19,-10,2,0,Math.PI*2);ctx.fill();
    ctx.beginPath();ctx.arc(dir*23,-5,2,0,Math.PI*2);ctx.fill();
    line({x:-10,y:6},{x:-10,y:13},'#79543C',3);line({x:10,y:6},{x:10,y:13},'#79543C',3);
    line({x:14,y:-2},{x:23,y:-15+dog.wag},'#A87852',4);
    if(dog.visitorId){text('♥',-6,-32,18,'#F2B485',800);ctx.fillStyle='#F4C35C';ctx.beginPath();ctx.arc(-30,10,5,0,Math.PI*2);ctx.fill();}
    ctx.restore();}
  if(!props.reducedMotion) for(const event of props.events){
    const age=now-event.at;
    if(age<0 || age>4200) continue;
    const p=layout.stations.find(s=>s.id===event.stationId);if(!p)continue;
    ctx.globalAlpha=Math.min(1,(4200-age)/900);text(`${event.pnl>0?'+':''}${money(event.pnl,event.currency)}`,p.x-40,p.y-112-age/80,17,event.pnl<0?C.red:C.green,800);ctx.globalAlpha=1;
  }
  ctx.restore();
}

function FloorScene(props: FloorSceneProps) {
  const canvasRef=useRef<HTMLCanvasElement>(null);
  const latest=useRef(props); latest.current=props;
  const invalidate=useRef<() => void>(()=>{});
  const control=useRef<(type: FloorSceneProps['command']['type']) => void>(()=>{});
  useEffect(()=>{
    const canvas=canvasRef.current!;const ctx=canvas.getContext('2d');if(!ctx)return;
    let width=1,height=1,dpr=1,frame=0,last=0,lastTargets=-Infinity,dirty=true,disposed=false;
    let layout=layoutScene(latest.current.stations),signature=latest.current.stations.map(s=>s.id+':'+(s.symbol??'')).sort().join('\0');
    let camera:Camera=fitCamera(layout.bounds,width,height);
    const pointers=new Map<number,Point>();let start:Point|null=null,dragged=false,pinchDistance=0;
    const draw=(time:number)=>{
      frame=0;if(disposed||document.hidden)return;
      const p=latest.current;const key=p.stations.map(s=>s.id+':'+(s.symbol??'')).sort().join('\0');
      if(key!==signature){signature=key;layout=layoutScene(p.stations);camera=fitCamera(layout.bounds,width,height);dirty=true;}
      const animate=!p.reducedMotion;
      if(time-last>=1000/30&&(dirty||animate)){last=time;ctx.setTransform(dpr,0,0,dpr,0,0);drawFloorScene(ctx,p,layout,camera,width,height,Date.now());dirty=false;
        canvas.dataset.stationTargets=JSON.stringify(layout.stations.map(s=>({id:s.id,...toScreen({x:s.x,y:s.y+62},camera)})));
        if(time-lastTargets>=500||p.reducedMotion){lastTargets=time;const statuses=new Map(p.stations.map(s=>[s.id,s.status]));const stamp=Date.now();
          canvas.dataset.agentTargets=JSON.stringify(layout.stations.flatMap(s=>{const status=statuses.get(s.id);if(!status||!avatarVisible(status))return [];const pose=traderPose(status,stamp,s.id,p.reducedMotion,s,layout);return [{id:s.id,...toScreen({x:s.x+pose.x,y:s.y+pose.y-20},camera),walking:pose.walking,activity:pose.activity}];}));
        }
      }
      if(dirty||animate)frame=requestAnimationFrame(draw);
    };
    const request=()=>{dirty=true;if(!frame&&!document.hidden)frame=requestAnimationFrame(draw);};invalidate.current=request;
    const resize=()=>{const r=canvas.getBoundingClientRect();width=Math.max(1,r.width);height=Math.max(1,r.height);dpr=Math.min(2,window.devicePixelRatio||1);canvas.width=Math.round(width*dpr);canvas.height=Math.round(height*dpr);camera=fitCamera(layout.bounds,width,height);request();};
    const observer=new ResizeObserver(resize);observer.observe(canvas);resize();
    control.current=type=>{camera=type==='fit'?fitCamera(layout.bounds,width,height):zoomCamera(camera,{x:width/2,y:height/2},type==='in'?1.25:.8);request();};
    const point=(e:PointerEvent|WheelEvent):Point=>{const r=canvas.getBoundingClientRect();return{x:e.clientX-r.left,y:e.clientY-r.top};};
    const down=(e:PointerEvent)=>{if(e.button!==0)return;const p=point(e);pointers.set(e.pointerId,p);canvas.setPointerCapture(e.pointerId);if(pointers.size===1){start=p;dragged=false;}else{dragged=true;const [a,b]=[...pointers.values()];pinchDistance=Math.hypot(a.x-b.x,a.y-b.y);}canvas.style.cursor='grabbing';};
    const target=(p:Point)=>hitAgent(p,latest.current.stations,layout,camera,Date.now(),latest.current.reducedMotion)||hitStation(p,layout.stations,camera);
    const move=(e:PointerEvent)=>{const old=pointers.get(e.pointerId),p=point(e);if(!old){canvas.style.cursor=target(p)?'pointer':'grab';return;}pointers.set(e.pointerId,p);
      if(pointers.size===2){const[a,b]=[...pointers.values()];const dist=Math.hypot(a.x-b.x,a.y-b.y);if(pinchDistance>0)camera=zoomCamera(camera,{x:(a.x+b.x)/2,y:(a.y+b.y)/2},dist/pinchDistance);pinchDistance=dist;dragged=true;}
      else {if(start&&Math.hypot(p.x-start.x,p.y-start.y)>5)dragged=true;if(dragged)camera={...camera,x:camera.x+p.x-old.x,y:camera.y+p.y-old.y};}request();};
    const up=(e:PointerEvent)=>{if(!pointers.has(e.pointerId))return;const select=!dragged&&pointers.size===1&&e.type==='pointerup';pointers.delete(e.pointerId);if(select){const id=target(point(e));if(id)latest.current.onSelect(id);}if(canvas.hasPointerCapture(e.pointerId))canvas.releasePointerCapture(e.pointerId);canvas.style.cursor='grab';request();};
    const wheel=(e:WheelEvent)=>{e.preventDefault();camera=zoomCamera(camera,point(e),Math.exp(-e.deltaY*.001));request();};
    const visibility=()=>{if(document.hidden){cancelAnimationFrame(frame);frame=0;}else request();};
    canvas.addEventListener('pointerdown',down);canvas.addEventListener('pointermove',move);canvas.addEventListener('pointerup',up);canvas.addEventListener('pointercancel',up);canvas.addEventListener('wheel',wheel,{passive:false});document.addEventListener('visibilitychange',visibility);
    return()=>{disposed=true;cancelAnimationFrame(frame);observer.disconnect();canvas.removeEventListener('pointerdown',down);canvas.removeEventListener('pointermove',move);canvas.removeEventListener('pointerup',up);canvas.removeEventListener('pointercancel',up);canvas.removeEventListener('wheel',wheel);document.removeEventListener('visibilitychange',visibility);invalidate.current=()=>{};control.current=()=>{};};
  },[]);
  useEffect(()=>{invalidate.current();},[props]);
  useEffect(()=>{control.current(props.command.type);},[props.command.seq,props.command.type]);
  return <canvas ref={canvasRef} data-testid="floor-canvas" role="img" aria-label="HANDLIV Trading Floor: escritório isométrico interativo. Arraste para mover, use os controles para ampliar e selecione uma estação. Dados também disponíveis na lista de estações." style={{width:'100%',height:'100%',display:'block',touchAction:'none',cursor:'grab',background:C.bg,borderRadius:16}} />;
}
export default memo(FloorScene);
