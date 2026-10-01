const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const ts=require('typescript');
const {chromium}=require('playwright');
const compile=f=>ts.transpileModule(fs.readFileSync(path.join(__dirname,f),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.React,esModuleInterop:true,target:ts.ScriptTarget.ES2020}}).outputText;
test('real browser: resize, selection, drag suppression, wheel and commands',async()=>{
  const browser=await chromium.launch({headless:true});
  try{
    const page=await browser.newPage({viewport:{width:1200,height:700},deviceScaleFactor:2});
    const errors=[];page.on('pageerror',e=>errors.push(e.message));
    await page.setContent('<div id="root" style="width:1100px;height:550px"></div>');
    await page.addScriptTag({content:fs.readFileSync(require.resolve('react').replace(/index\.js$/,'umd/react.development.js'),'utf8')});
    await page.addScriptTag({content:fs.readFileSync(require.resolve('react-dom').replace(/index\.js$/,'umd/react-dom.development.js'),'utf8')});
    await page.addScriptTag({content:`window.rooms={};(function(exports){${compile('symbolRooms.ts')}})(window.rooms);window.geometry={};(function(exports,require){${compile('sceneGeometry.ts')}})(window.geometry,()=>window.rooms);window.decor={};(function(exports,require){${compile('officeDecor.ts')}})(window.decor,()=>window.geometry);window.renderer={};(function(exports,require){${compile('FloorScene.web.tsx')}})(window.renderer,n=>n==='react'?React:n==='./officeDecor'?window.decor:window.geometry);`});
    await page.evaluate(()=>{
      window.paintTimes=[];const clear=CanvasRenderingContext2D.prototype.clearRect;
      CanvasRenderingContext2D.prototype.clearRect=function(...args){window.paintTimes.push(performance.now());return clear.apply(this,args);};
      window.selected=[];
      window.props={stations:Array.from({length:10},(_,i)=>({id:'s'+i,name:'Estação '+(i+1),symbol:'EURUSD',currency:'USD',profitDay:i===0?0:null,status:i===0?'POSIÇÃO ABERTA':'AGUARDANDO'})),summary:{currency:'USD',balance:0,equity:null,profitDay:0,equityHistory:[]},events:[],selectedId:null,onSelect:id=>window.selected.push(id),command:{type:'fit',seq:0},reducedMotion:true,demo:true};
      window.root=ReactDOM.createRoot(document.getElementById('root'));window.root.render(React.createElement(window.renderer.default,window.props));
    });
    await page.waitForFunction(()=>document.querySelector('canvas')?.dataset.stationTargets);
    const canvas=page.locator('canvas'), box=await canvas.boundingBox();
    const target=await canvas.evaluate(el=>JSON.parse(el.dataset.stationTargets)[0]);
    await page.mouse.click(box.x+target.x,box.y+target.y);
    assert.deepEqual(await page.evaluate(()=>window.selected),['s0']);
    await page.mouse.move(box.x+target.x,box.y+target.y);await page.mouse.down();await page.mouse.move(box.x+target.x+80,box.y+target.y+20,{steps:10});await page.mouse.up();
    assert.deepEqual(await page.evaluate(()=>window.selected),['s0']);
    const before=await canvas.getAttribute('data-station-targets');
    await page.mouse.wheel(0,-300);await page.waitForTimeout(80);
    assert.notEqual(await canvas.getAttribute('data-station-targets'),before);
    await page.evaluate(()=>{window.props={...window.props,command:{type:'fit',seq:1}};window.root.render(React.createElement(window.renderer.default,window.props));});
    await page.waitForTimeout(80);
    const fit=await canvas.evaluate(el=>JSON.parse(el.dataset.stationTargets)[0]);
    assert.ok(Math.abs(fit.x-target.x)<1);
    assert.equal(await canvas.evaluate(el=>el.width),2200);
    await page.evaluate(()=>document.getElementById('root').style.width='600px');await page.waitForTimeout(80);
    assert.equal(await canvas.evaluate(el=>el.width),1200);
    assert.deepEqual(errors,[]);
    await page.waitForTimeout(80);
    const idle=await page.evaluate(()=>window.paintTimes.length);await page.waitForTimeout(150);
    assert.equal(await page.evaluate(()=>window.paintTimes.length),idle,'reduced motion stops the loop');
    await page.mouse.move(250,250);await page.mouse.down();
    await page.evaluate(()=>window.paintTimes=[]);
    await page.mouse.move(420,360,{steps:30});await page.mouse.up();
    const times=await page.evaluate(()=>window.paintTimes);
    assert.ok(times.every((t,i)=>i===0||t-times[i-1]>=29),'all input painting capped at 30fps');
    await page.evaluate(()=>{window.props={...window.props,stations:Array.from({length:120},(_,i)=>({...window.props.stations[0],id:'s'+i})),command:{type:'fit',seq:2}};window.root.render(React.createElement(window.renderer.default,window.props));});
    await page.waitForFunction(()=>JSON.parse(document.querySelector('canvas').dataset.stationTargets).length===120);
    await page.screenshot({path:path.join(process.env.TEMP||process.env.TMP||'.','handliv-floor-renderer.png')});
    console.log('screenshot',path.join(process.env.TEMP||process.env.TMP||'.','handliv-floor-renderer.png'));
    for(const count of [1,3,20,150]){
      await page.evaluate(count=>{window.props={...window.props,stations:Array.from({length:count},(_,i)=>({id:'scene'+i,name:'Magic '+(100+i),symbol:['XAUUSD','EURUSD','AAPL','BTCUSD','unknown'][i%5],currency:'USD',profitDay:null,status:i===1?'POSIÇÃO ABERTA':'AGUARDANDO'})),command:{type:'fit',seq:count+10}};window.root.render(React.createElement(window.renderer.default,window.props));},count);
      await page.waitForFunction(count=>JSON.parse(document.querySelector('canvas').dataset.stationTargets).length===count,count);
      await page.screenshot({path:path.join(process.env.TEMP||process.env.TMP||'.',`handliv-rooms-${count}.png`)});
      console.log('room screenshot',path.join(process.env.TEMP||process.env.TMP||'.',`handliv-rooms-${count}.png`));
    }
    await page.evaluate(()=>{window.props={...window.props,stations:[{id:'solo',name:'Magic 101',symbol:'EURUSD',currency:'USD',profitDay:null,status:'AGUARDANDO'}],command:{type:'fit',seq:1000}};window.root.render(React.createElement(window.renderer.default,window.props));});
    await page.waitForFunction(()=>JSON.parse(document.querySelector('canvas').dataset.stationTargets).length===1);
    await page.evaluate(()=>{const canvas=document.querySelector('canvas'),g=window.geometry,layout=g.layoutScene(window.props.stations),desk=layout.stations[0];let time=0;for(;time<1000000;time+=100)if(g.traderPose('AGUARDANDO',time,desk.id,false,desk,layout).activity==='dog')break;window.renderer.drawFloorScene(canvas.getContext('2d'),{...window.props,reducedMotion:false},layout,g.fitCamera(layout.bounds,600,550),600,550,time);});
    await page.screenshot({path:path.join(process.env.TEMP||process.env.TMP||'.','handliv-dog-interaction.png')});
    assert.deepEqual(errors,[]);
  }finally{await browser.close();}
});
