import React, { memo, useEffect, useMemo, useRef, useState } from 'react';
import { useIsFocused } from '@react-navigation/native';
import { PanResponder, View } from 'react-native';
import Svg, { Circle, Ellipse, G, Line, Polygon, Rect, Text } from 'react-native-svg';
import type { FloorSceneProps, FloorStation } from './types';
import { Camera, agentAppearance, avatarVisible, fitCamera, hitAgent, hitStation, iso, layoutScene, money, traderPose, zoomCamera } from './sceneGeometry';

const INK='#E9EFF9', MUTED='#8498B7', GREEN='#16D39A';
const Station = memo(function Station({station:s,x,y,selected,demo}:{station:FloorStation;x:number;y:number;selected:boolean;demo:boolean}) {
  const color=s.status==='OFFLINE'?'#66758C':s.status==='POSIÇÃO ABERTA'?'#4C8DFF':s.status==='OPERANDO'?GREEN:'#E6B866';
  return <G transform={`translate(${x} ${y})`}>
    {(selected||s.status==='POSIÇÃO ABERTA')&&<Polygon points="0,-56 102,-5 0,46 -102,-5" fill={color} opacity={selected?.8:.25} />}
    <Ellipse cx={0} cy={18} rx={91} ry={31} fill="#080F1D" />
    <Rect x={-65} y={-15} width={7} height={43} fill="#0A1426" /><Rect x={54} y={-15} width={7} height={43} fill="#0A1426" />
    <Polygon points="-90,-37 19,-77 92,-40 -18,4" fill="#34465F" stroke="#536681" />
    <Polygon points="-90,-37 -18,4 -18,13 -90,-28" fill="#18283E" /><Polygon points="-18,4 92,-40 92,-31 -18,13" fill="#22344C" />
    {[-49,-6,37].map((mx,i)=><G key={mx} transform={`translate(${mx} ${-72+(i===1?-7:0)})`}>
      <Rect x={14} y={28} width={4} height={13} fill="#71809A" /><Rect x={7} y={38} width={20} height={3} fill="#142135" />
      <Rect width={39} height={30} rx={3} fill="#080F1C" /><Rect x={3} y={3} width={33} height={23} fill="#102D3B" />
      <Line x1={7} y1={9} x2={30} y2={9} stroke={color} strokeWidth={2}/>
      {[0,1,2].map(j=><Rect key={j} x={7} y={14+j*4} width={18-j*4} height={1} fill="#48768D" />)}
    </G>)}
    <Polygon points="-27,-21 -5,-29 13,-20 -10,-12" fill="#8392A6" />
    <Line x1={-10} y1={9} x2={-16} y2={26} stroke="#27344B" strokeWidth={8}/><Line x1={7} y1={9} x2={13} y2={29} stroke="#27344B" strokeWidth={8}/>
    <Rect x={-24} y={-14} width={47} height={30} rx={10} fill="#0A1426" /><Line x1={0} y1={12} x2={0} y2={33} stroke="#63718A" strokeWidth={4}/><Line x1={-20} y1={34} x2={20} y2={34} stroke="#63718A" strokeWidth={3}/>
    <Rect x={-90} y={40} width={180} height={65} rx={7} fill="#0B1527"/><Rect x={-90} y={40} width={3} height={65} fill={color}/>
    <Text x={-80} y={57} fill={INK} fontSize={12} fontWeight="700">{s.name.length>23?s.name.slice(0,22)+'…':s.name}</Text>
    <Text x={-80} y={72} fill={MUTED} fontSize={10}>{s.symbol??'—'}</Text>
    <Text x={81} y={73} textAnchor="end" fill={((demo?s.profitDay:s.floatingPl)??0)<0?'#FF7289':GREEN} fontSize={11}>{money(demo?s.profitDay:s.floatingPl??null,s.currency)}</Text>
    <Text x={-80} y={94} fill={color} fontSize={9}>{s.status}</Text>
    {s.status==='POSIÇÃO ABERTA'&&<Circle cx={77} cy={90} r={3} fill={color}/>}
  </G>;
});

const Avatar = memo(function Avatar({id,name,x,y,pose,now,reducedMotion}:{id:string;name:string;x:number;y:number;pose:ReturnType<typeof traderPose>;now:number;reducedMotion:boolean}) {
  const appearance=agentAppearance(id),step=pose.walking?pose.stride:0;
  const breath=reducedMotion?0:Math.sin(now/730+(x%13))*.8;
  const hand=pose.activity==='desk'&&!reducedMotion?Math.sin(now/190+(y%17))*3:0;
  return <G transform={`translate(${x+pose.x} ${y+pose.y})`}>
    <Ellipse cx={0} cy={30} rx={19} ry={6} fill="#07101D"/>
    <Line x1={-9} y1={2} x2={-10+step} y2={28} stroke="#26354A" strokeWidth={8}/>
    <Line x1={8} y1={2} x2={10-step} y2={28} stroke="#26354A" strokeWidth={8}/>
    <Rect x={-18+step} y={27} width={13} height={6} rx={2} fill="#0A0C16"/><Rect x={7-step} y={27} width={13} height={6} rx={2} fill="#0A0C16"/>
    <Rect x={-16} y={-30+breath} width={31} height={40} rx={10} fill={appearance.jacket}/>
    <Line x1={-12} y1={-22} x2={-24} y2={-18+hand} stroke={appearance.jacket} strokeWidth={7}/>
    <Line x1={12} y1={-22} x2={23} y2={-26-hand} stroke={appearance.jacket} strokeWidth={7}/>
    <Ellipse cx={-1} cy={-39+breath} rx={12} ry={14} fill={appearance.skin}/>
    <Ellipse cx={-2} cy={-46+breath} rx={12} ry={8} fill={appearance.hair}/>
    <Line x1={pose.facing==='left'?-9:8} y1={-38} x2={pose.facing==='left'?-9:8} y2={-33} stroke="#1B2432" strokeWidth={2}/>
    {pose.activity!=='desk'&&<><Rect x={-41} y={-72} width={82} height={18} rx={5} fill="#0B1527"/>
      <Text x={-35} y={-59} fill={INK} fontSize={9} fontWeight="700">{name.length>11?name.slice(0,10)+'…':name}</Text></>}
  </G>;
});

function FloorScene(props:FloorSceneProps) {
  const [size,setSize]=useState({width:1,height:1});
  const [now,setNow]=useState(Date.now());
  const focused=useIsFocused();
  useEffect(()=>{if(props.reducedMotion||!focused)return;const timer=setInterval(()=>setNow(Date.now()),200);return()=>clearInterval(timer);},[props.reducedMotion,focused]);
  const layout=useMemo(()=>layoutScene(props.stations),[props.stations]);
  const signature=layout.stations.map(s=>s.id).join('\0');
  const [camera,setCamera]=useState<Camera>({x:0,y:0,scale:1});
  const live=useRef({props,layout,camera,size});live.current={props,layout,camera,size};
  const gesture=useRef({camera,dragged:false,distance:0});
  useEffect(()=>{setCamera(fitCamera(layout.bounds,size.width,size.height));},[size.width,size.height,signature]);
  useEffect(()=>{setCamera(c=>props.command.type==='fit'?fitCamera(layout.bounds,size.width,size.height):zoomCamera(c,{x:size.width/2,y:size.height/2},props.command.type==='in'?1.25:.8));},[props.command.seq]);
  const responder=useMemo(()=>PanResponder.create({
    onStartShouldSetPanResponder:()=>true,
    onMoveShouldSetPanResponder:()=>true,
    onPanResponderGrant:e=>{const ts=e.nativeEvent.touches;gesture.current={camera:live.current.camera,dragged:ts.length>1,distance:ts.length>1?Math.hypot(ts[0].pageX-ts[1].pageX,ts[0].pageY-ts[1].pageY):0};},
    onPanResponderMove:(e,g)=>{
      const ts=e.nativeEvent.touches;
      if(ts.length>1){const distance=Math.hypot(ts[0].pageX-ts[1].pageX,ts[0].pageY-ts[1].pageY);gesture.current.dragged=true;
        if(gesture.current.distance>0){const factor=distance/gesture.current.distance;setCamera(c=>zoomCamera(c,{x:live.current.size.width/2,y:live.current.size.height/2},factor));}gesture.current.distance=distance;
      }else if(Math.hypot(g.dx,g.dy)>5){gesture.current.dragged=true;setCamera({...gesture.current.camera,x:gesture.current.camera.x+g.dx,y:gesture.current.camera.y+g.dy});}
    },
    onPanResponderRelease:e=>{if(gesture.current.dragged)return;const l=live.current;const id=hitAgent({x:e.nativeEvent.locationX,y:e.nativeEvent.locationY},l.props.stations,l.layout,l.camera,Date.now(),l.props.reducedMotion)||hitStation({x:e.nativeEvent.locationX,y:e.nativeEvent.locationY},l.layout.stations,l.camera);if(id)l.props.onSelect(id);},
    onPanResponderTerminate:()=>{gesture.current.dragged=true;},
  }),[]);
  const floorPoints=layout.floor.map(p=>`${p.x},${p.y}`).join(' ');
  const [a,b,,d]=layout.floor;
  const byId=new Map(props.stations.map(s=>[s.id,s]));
  const people=layout.stations.flatMap(p=>{
    const station=byId.get(p.id);
    if(!station||!avatarVisible(station.status))return [];
    return [{point:p,station,pose:traderPose(station.status,now,p.id,props.reducedMotion,p,layout)}];
  }).filter(({point,pose})=>{
    const x=(point.x+pose.x)*camera.scale+camera.x,y=(point.y+pose.y)*camera.scale+camera.y;
    return x+45>=0&&x-45<=size.width&&y+70>=0&&y-50<=size.height;
  }).sort((a,b)=>(a.point.y+a.pose.y)-(b.point.y+b.pose.y));
  return <View style={{flex:1,backgroundColor:'#0A1120',overflow:'hidden',borderRadius:16}} onLayout={e=>setSize(e.nativeEvent.layout)} {...responder.panHandlers}>
    <Svg width="100%" height="100%" accessibilityLabel="HANDLIV Trading Floor. Selecione uma estação; dados disponíveis também na lista." testID="floor-svg">
      <G transform={`translate(${camera.x} ${camera.y}) scale(${camera.scale})`}>
        <Polygon points={`${a.x},${a.y} ${b.x},${b.y} ${b.x},${b.y-100} ${a.x},${a.y-100}`} fill="#17253B" stroke="#2D4260"/>
        <Polygon points={`${a.x},${a.y} ${d.x},${d.y} ${d.x},${d.y-100} ${a.x},${a.y-100}`} fill="#101D30" stroke="#2D4260"/>
        <Line x1={d.x} y1={d.y-99} x2={a.x} y2={-99} stroke={GREEN} strokeWidth={3}/><Line x1={a.x} y1={-99} x2={b.x} y2={b.y-99} stroke="#4C8DFF" strokeWidth={3}/>
        <Polygon points={floorPoints} fill="#172439" stroke="#344763"/>
        {Array.from({length:layout.cols*2+1},(_,i)=>{const p=iso(i*120,0),q=iso(i*120,layout.rows*240);return <Line key={`x${i}`} x1={p.x} y1={p.y} x2={q.x} y2={q.y} stroke="#22324A"/>;})}
        {Array.from({length:layout.rows*2+1},(_,i)=>{const p=iso(0,i*120),q=iso(layout.cols*240,i*120);return <Line key={`y${i}`} x1={p.x} y1={p.y} x2={q.x} y2={q.y} stroke="#22324A"/>;})}
        {['TRADING FLOOR','RISK','MACRO','NEWS','AI LAB'].map((s,i)=>{const p=iso((i+.5)*layout.cols*240/5,0);return <Text key={s} transform={`translate(${p.x} ${p.y-51}) rotate(26.565)`} x={-45} fill={i===0?GREEN:'#93ACD0'} fontSize={12} fontWeight="700">{s}</Text>;})}
        <Rect x={-244} y={-214} width={488} height={164} rx={12} fill="#060E1B"/><Rect x={-244} y={-214} width={4} height={164} fill={GREEN}/>
        <Text x={-220} y={-183} fill={INK} fontSize={22} fontWeight="800">HANDLIV</Text><Text x={-86} y={-183} fill={GREEN} fontSize={12}>TRADING FLOOR</Text>
        <Text x={-220} y={-161} fill={MUTED} fontSize={9}>{props.demo?'AMBIENTE DEMONSTRATIVO':'CENTRO DE OPERAÇÕES'}</Text>
        <Text x={-220} y={-133} fill={MUTED} fontSize={10}>RESULTADO HOJE</Text><Text x={-220} y={-104} fill={(props.summary.profitDay??0)<0?'#FF7289':GREEN} fontSize={26} fontWeight="700">{money(props.summary.profitDay,props.summary.currency)}</Text>
        <Text x={35} y={-135} fill={MUTED} fontSize={9}>SALDO</Text><Text x={35} y={-117} fill={INK} fontSize={14}>{money(props.summary.balance,props.summary.currency)}</Text>
        <Text x={35} y={-92} fill={MUTED} fontSize={9}>PATRIMÔNIO</Text><Text x={35} y={-73} fill={INK} fontSize={14}>{money(props.summary.equity,props.summary.currency)}</Text>
        {layout.stations.filter(p=>{const x=p.x*camera.scale+camera.x,y=p.y*camera.scale+camera.y;return x+190*camera.scale>=0&&x-110*camera.scale<=size.width&&y+160*camera.scale>=0&&y-125*camera.scale<=size.height;}).map(p=><Station key={p.id} station={byId.get(p.id)!} x={p.x} y={p.y} selected={props.selectedId===p.id} demo={props.demo}/>)}
        {layout.amenities.map(a=><G key={a.kind} transform={`translate(${a.x} ${a.y})`}>
          <Ellipse cx={0} cy={22} rx={94} ry={41} fill="#0B1728"/>
          {a.kind==='pool'?<><Rect x={-80} y={-35} width={160} height={77} rx={9} fill="#603C2F"/><Rect x={-73} y={-30} width={146} height={61} rx={6} fill="#0D634B" stroke="#E8E1CE" strokeWidth={3}/>
            {[-40,10,32].map((x,i)=><Circle key={i} cx={x} cy={i%2?5:0} r={4} fill={i===0?'#EFEADB':i===1?'#F2B74D':'#4C8DFF'}/>)}<Text x={-34} y={58} fill={MUTED} fontSize={10}>SINUCA</Text></>
          :a.kind==='coffee'?<><Rect x={-65} y={-23} width={130} height={53} rx={12} fill="#B28764"/>{[-28,0,28].map(x=><Circle key={x} cx={x} cy={0} r={8} fill="#F2EEE1"/>)}<Text x={-20} y={53} fill={MUTED} fontSize={10}>CAFÉ</Text></>
          :<><Rect x={-83} y={-27} width={166} height={64} rx={23} fill="#576E83"/>{[-56,-18,20,58].map(x=><G key={x}><Rect x={x} y={-44} width={19} height={12} rx={5} fill="#243D56"/><Rect x={x} y={39} width={19} height={12} rx={5} fill="#243D56"/></G>)}<Text x={-29} y={60} fill={MUTED} fontSize={10}>REUNIÃO</Text></>}
        </G>)}
        {people.map(({point,station,pose})=><Avatar key={point.id} id={point.id} name={station.name} x={point.x} y={point.y} pose={pose} now={now} reducedMotion={props.reducedMotion}/>)}
        {(()=>{const left=layout.amenities[0],right=layout.amenities[2],phase=props.reducedMotion?.5:(now%18000)/18000,step=phase<.5?phase*2:2-phase*2;
          const dir=phase<.5?1:-1,stride=props.reducedMotion?0:Math.sin(now/175)*4;
          return <G transform={`translate(${left.x+(right.x-left.x)*step} ${left.y+(right.y-left.y)*step+85})`}><Ellipse cx={0} cy={0} rx={16} ry={9} fill="#A87852"/><Circle cx={dir*15} cy={-8} r={8} fill="#A87852"/><Polygon points={`${dir*10},-13 ${dir*7},-24 ${dir*17},-15`} fill="#79543C"/><Circle cx={dir*19} cy={-10} r={2} fill="#101725"/><Circle cx={dir*23} cy={-5} r={2} fill="#101725"/><Line x1={-10} y1={6} x2={-10+stride} y2={13} stroke="#79543C" strokeWidth={3}/><Line x1={10} y1={6} x2={10-stride} y2={13} stroke="#79543C" strokeWidth={3}/><Line x1={-dir*14} y1={-2} x2={-dir*23} y2={-15+(props.reducedMotion?0:Math.sin(now/220)*3)} stroke="#A87852" strokeWidth={4}/></G>;})()}
      </G>
    </Svg>
  </View>;
}
export default memo(FloorScene);
