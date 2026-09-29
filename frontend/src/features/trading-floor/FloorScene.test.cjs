const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require('typescript');
for (const ext of ['.ts','.tsx']) require.extensions[ext] = (m,f) => m._compile(ts.transpileModule(fs.readFileSync(f,'utf8'), {compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.React,esModuleInterop:true,target:ts.ScriptTarget.ES2020}}).outputText,f);
const props = {stations:[{id:'a',name:'Alpha',symbol:'EURUSD',currency:'USD',profitDay:0,status:'POSIÇÃO ABERTA',openPositions:1}],summary:{currency:'USD',balance:0,equity:null,profitDay:0,equityHistory:[]},events:[],selectedId:null,onSelect(){},command:{type:'fit',seq:0},reducedMotion:true,demo:false};
test('native renderer compiles and uses SVG without HTML canvas', () => {
  const file = require('node:path').join(__dirname,'FloorScene.tsx');
  assert.ok(fs.existsSync(file), 'native renderer exists');
  const source=fs.readFileSync(file,'utf8');
  const result=ts.transpileModule(source,{reportDiagnostics:true,compilerOptions:{jsx:ts.JsxEmit.React,module:ts.ModuleKind.CommonJS}});
  assert.equal(result.diagnostics.length,0);
  assert.match(source,/react-native-svg/);
  assert.doesNotMatch(source,/<canvas|HTMLCanvasElement|document\./);
});
test('web renderer is accessible and paints real amounts, labels and five sectors', () => {
  const React = require('react');
  const {renderToStaticMarkup} = require('react-dom/server');
  const {default:FloorScene,drawFloorScene} = require('./FloorScene.web.tsx');
  const html = renderToStaticMarkup(React.createElement(FloorScene,props));
  assert.match(html,/data-testid="floor-canvas"/);
  assert.match(html,/aria-label=/);
  const texts=[];
  const ctx = new Proxy({fillText:(t)=>texts.push(t),measureText:t=>({width:t.length*6}),createLinearGradient:()=>({addColorStop(){}}),createRadialGradient:()=>({addColorStop(){}})}, {get:(o,k)=>k in o?o[k]:()=>{}});
  const {layoutScene,fitCamera} = require('./sceneGeometry.ts');
  const layout=layoutScene(props.stations);
  drawFloorScene(ctx,props,layout,fitCamera(layout.bounds,1000,700),1000,700,0);
  for (const t of ['HANDLIV','TRADING FLOOR','RISK','MACRO','NEWS','AI LAB','Alpha','EURUSD','POSIÇÃO ABERTA','US$ 0,00','—']) assert.ok(texts.includes(t),`missing ${t}`);
});
