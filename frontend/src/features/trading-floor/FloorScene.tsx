import React, { memo, useEffect, useMemo, useRef, useState } from 'react';
import { PanResponder, View } from 'react-native';
import Svg, { Circle, Ellipse, G, Line, Polygon, Rect, Text } from 'react-native-svg';
import type { FloorSceneProps, FloorStation } from './types';
import { Camera, fitCamera, hitStation, iso, layoutScene, money, zoomCamera } from './sceneGeometry';

const INK='#E9EFF9', MUTED='#8498B7', GREEN='#16D39A';
const Station = memo(function Station({station:s,x,y,selected}:{station:FloorStation;x:number;y:number;selected:boolean}) {
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
    <Rect x={-16} y={-30} width={31} height={40} rx={10} fill="#536D98" />
    <Line x1={-12} y1={-23} x2={-27} y2={-18} stroke="#7893B8" strokeWidth={7}/><Line x1={12} y1={-22} x2={23} y2={-28} stroke="#7893B8" strokeWidth={7}/>
    <Ellipse cx={-1} cy={-39} rx={12} ry={14} fill="#D2A183"/><Ellipse cx={-2} cy={-45} rx={12} ry={8} fill="#252332"/>
    <Rect x={-90} y={40} width={180} height={65} rx={7} fill="#0B1527"/><Rect x={-90} y={40} width={3} height={65} fill={color}/>
    <Text x={-80} y={57} fill={INK} fontSize={12} fontWeight="700">{s.name.length>23?s.name.slice(0,22)+'…':s.name}</Text>
    <Text x={-80} y={72} fill={MUTED} fontSize={10}>{s.symbol??'—'}</Text>
    <Text x={81} y={73} textAnchor="end" fill={(s.profitDay??0)<0?'#FF7289':GREEN} fontSize={11}>{money(s.profitDay,s.currency)}</Text>
    <Text x={-80} y={94} fill={color} fontSize={9}>{s.status}</Text>
    {s.status==='POSIÇÃO ABERTA'&&<Circle cx={77} cy={90} r={3} fill={color}/>}
  </G>;
});

function FloorScene(props:FloorSceneProps) {
  const [size,setSize]=useState({width:1,height:1});
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
    onPanResponderRelease:e=>{if(gesture.current.dragged)return;const l=live.current;const id=hitStation({x:e.nativeEvent.locationX,y:e.nativeEvent.locationY},l.layout.stations,l.camera);if(id)l.props.onSelect(id);},
    onPanResponderTerminate:()=>{gesture.current.dragged=true;},
  }),[]);
  const floorPoints=layout.floor.map(p=>`${p.x},${p.y}`).join(' ');
  const [a,b,,d]=layout.floor;
  const byId=new Map(props.stations.map(s=>[s.id,s]));
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
        {layout.stations.filter(p=>{const x=p.x*camera.scale+camera.x,y=p.y*camera.scale+camera.y;return x+110*camera.scale>=0&&x-110*camera.scale<=size.width&&y+110*camera.scale>=0&&y-125*camera.scale<=size.height;}).map(p=><Station key={p.id} station={byId.get(p.id)!} x={p.x} y={p.y} selected={props.selectedId===p.id}/>)}
      </G>
    </Svg>
  </View>;
}
export default memo(FloorScene);
