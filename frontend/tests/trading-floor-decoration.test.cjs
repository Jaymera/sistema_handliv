require('./register-typescript.cjs');
const fs=require('node:fs'),ts=require('typescript');
require.extensions['.tsx']=(m,f)=>m._compile(ts.transpileModule(fs.readFileSync(f,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.React,esModuleInterop:true,target:ts.ScriptTarget.ES2020}}).outputText,f);
const {test}=require('node:test');const assert=require('node:assert/strict');
const {layoutScene}=require('../src/features/trading-floor/sceneGeometry.ts');
test('shared architecture contains large room floors, glass partitions, doors and visible furnishings',()=>{
 const {officeShapes}=require('../src/features/trading-floor/officeDecor.ts');
 for(const count of [1,3,20,150]){
  const scene=layoutScene(Array.from({length:count},(_,i)=>({id:String(i),symbol:['XAUUSD','EURUSD','AAPL','BTCUSD',null][i%5]})));
  const shapes=officeShapes(scene);
  for(const kind of ['room','partition','door','rug','plant','bookcase','sofa','lamp','classroom','dog-bed'])assert.ok(shapes.some(s=>s.tag===kind),kind);
  for(const room of scene.rooms)assert.ok(shapes.some(s=>s.type==='text'&&s.text===room.kind));
  assert.ok(shapes.some(s=>s.type==='text'&&s.text.includes('VISUAL')),'no fictional operational telemetry');
 }
});
test('Canvas actually paints shared room/furniture plan, not unused architecture data',()=>{
 const {drawFloorScene}=require('../src/features/trading-floor/FloorScene.web.tsx');
 const {fitCamera}=require('../src/features/trading-floor/sceneGeometry.ts');const texts=[];
 const ctx=new Proxy({fillText:t=>texts.push(t),createRadialGradient:()=>({addColorStop(){}})}, {get:(o,k)=>k in o?o[k]:()=>{}});
 const stations=[{id:'a',name:'Real robot',symbol:'EURUSD',status:'AGUARDANDO',currency:'USD',profitDay:null}];const scene=layoutScene(stations);
 drawFloorScene(ctx,{stations,summary:{currency:'USD',equityHistory:[]},events:[],reducedMotion:true,demo:false},scene,fitCamera(scene.bounds,1100,650),1100,650,0);
 for(const text of ['Commodities','Forex','Ações','Crypto','Outros','DOG LOUNGE','LOUNGE • PAUSA','SALA DE REUNIÃO / AULA'])assert.ok(texts.includes(text),text);
});
