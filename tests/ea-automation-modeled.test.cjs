// Offline modeled MQL harness: executes transliterated EA helper bodies with
// modeled broker/clock/file builtins. NOT MetaTrader or real broker execution.
const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const os = require('node:os');
const root = path.resolve(__dirname, '..');
const uuid = '19ca2e1f-6807-4013-8147-4c160016adf9';
const id2 = '29ca2e1f-6807-4013-8147-4c160016adf9';
function extract(source, name) {
  const r = new RegExp('(?:bool|string|int|datetime|double|void) '+name+'\\(([^]*?)\\)\\s*\\{');
  const match = r.exec(source);
  assert.ok(match, `Missing helper ${name}`); // never include secret-bearing source
  let i=match.index+match[0].length, depth=1, quote='', escaped=false;
  const begin=i;
  for(;i<source.length;i++) {
    const c=source[i];
    if(quote) { if(escaped) escaped=false; else if(c==='\\') escaped=true; else if(c===quote) quote=''; continue; }
    if(c==='"'||c==="'") quote=c;
    else if(c==='{') depth++;
    else if(c==='}' && --depth===0) break;
  }
  let body=source.slice(begin,i);
  body=body.replace(/\b(?:const\s+)?(?:string|int|double|bool|datetime|ushort|uint|ulong|long)\s+(?=[A-Za-z_])/g,'let ')
    .replace(/StringReplace\((\w+),([^;]+)\);/g,'$1=Replace($1,$2);')
    .replace(/CTrade automatic;/g, 'let automatic=new CTrade();')
    .replace(/MqlTick quote;/g, 'let quote={};')
    .replace(/let (\w+)\[(\d+)\];/g,'let $1=Array($2);')
    .replace(/\((?:int|long|ulong|uint|double|datetime)\)/g,'');
  const args=match[1].replace(/\b(?:const\s+)?(?:string|int|double|bool|datetime)\s*&?\s*/g,'');
  return `function ${name}(${args}) {${body}}`;
}
function harness(platform, directory=fs.mkdtempSync(path.join(os.tmpdir(),'hlv-model-'))) {
 const source=fs.readFileSync(path.join(root,`ea_mt${platform}/HandlivPanel.mq${platform}`),'utf8');
 const state={ready:true, now:Date.UTC(2026,9,2)/1000, positions:[], orders:[], netting:false, trades:[], retcode:10009, accepted:true, writeFail:false, occupiedError:false};
 let handles=new Map(), locks=new Set(), next=0;
 const c={state, AUTOMATION_MAGIC:20261002,
 StringLen:s=>s.length,StringGetCharacter:(s,p)=>s.charCodeAt(p),StringSubstr:(s,p,n)=>n===undefined?s.slice(p):s.slice(p,p+n),StringFind:(s,t,p=0)=>s.indexOf(t,p),Replace:(s,a,b)=>s.split(a).join(b),
 StringToDouble:Number, MathIsValidNumber:Number.isFinite,MathAbs:Math.abs,MathRound:Math.round,MathMax:Math.max,MathCeil:Math.ceil,MathFloor:Math.floor,NormalizeDouble:(v,d)=>Number(v.toFixed(d)),
 PERIOD_H1:60,BrokerClockFresh:()=>true,TimeCurrent:()=>10000,iTime:()=>6000,ClosedCandleAtr:()=>state.atr??.01,ProtectionFault:()=>{state.ready=false;},VerifyAutomationProtection:()=>state.protected!==false,
 StringToTime:s=>Date.parse(s.replace(/\./g,'-').replace(' ','T')+'Z')/1000,
 TimeToString:t=>Number.isFinite(t)?new Date(t*1000).toISOString().slice(0,19).replace(/-/g,'.').replace('T',' '):'', TIME_DATE:1,TIME_SECONDS:2,
 TimeGMT:()=>state.now, AutomationReady:()=>state.ready,
 SymbolsTotal:()=>2,SymbolName:i=>['EURUSD.m','XAUUSD'][i],SymbolSelect:()=>true,
 CommandScope:()=>crypto.createHash('sha256').update('modeled account scope').digest('hex'),Sha256Hex:s=>crypto.createHash('sha256').update(s).digest('hex'),
 FILE_READ:1,FILE_WRITE:2,FILE_TXT:4,FILE_ANSI:8,FILE_COMMON:16,INVALID_HANDLE:-1,SEEK_END:2,
 FileOpen:name=>{const file=path.join(directory,name);if(locks.has(file))return -1; locks.add(file);if(!fs.existsSync(file))fs.writeFileSync(file,'');const h=next++;handles.set(h,{file,pos:0});return h;},
 FileSize:h=>fs.statSync(handles.get(h).file).size,
 FileIsEnding:h=>handles.get(h).pos>=fs.statSync(handles.get(h).file).size,
 FileReadString:h=>{const f=handles.get(h),s=fs.readFileSync(f.file,'ascii'),e=s.indexOf('\r\n',f.pos);const line=e<0?s.slice(f.pos):s.slice(f.pos,e);f.pos=e<0?s.length:e+2;return line;},
 FileSeek:(h)=>{handles.get(h).pos=fs.statSync(handles.get(h).file).size;return true;},
 FileWriteString:(h,s)=>{if(state.writeFail)return 0;fs.appendFileSync(handles.get(h).file,s);return s.length;},FileFlush:h=>{},ResetLastError:()=>{},GetLastError:()=>0,
 FileClose:h=>{locks.delete(handles.get(h).file);handles.delete(h);},
 AccountInfoInteger:k=>state.netting?0:2,ACCOUNT_MARGIN_MODE:1,ACCOUNT_MARGIN_MODE_RETAIL_HEDGING:2,
 PositionsTotal:()=>state.positions.length,PositionGetTicket:i=>{state.position=state.positions[i];return state.occupiedError?0:i+1;},PositionGetString:()=>state.position.symbol,PositionGetInteger:()=>state.position.magic,POSITION_SYMBOL:1,POSITION_MAGIC:2,
 OrdersTotal:()=>state.orders.length,OrderGetTicket:i=>{state.order=state.orders[i];return state.occupiedError?0:i+1;},OrderGetString:()=>state.order.symbol,OrderGetInteger:()=>state.order.magic,ORDER_SYMBOL:1,ORDER_MAGIC:2,
 OrderSelect:(i,mode)=>{state.order=mode===3?state.trades[state.trades.length-1]:state.orders[i];return !state.occupiedError;},SELECT_BY_POS:1,SELECT_BY_TICKET:3,MODE_TRADES:2,OrderStopLoss:()=>state.order.sl,OrderTakeProfit:()=>state.order.tp,OrderSymbol:()=>state.order.symbol,OrderMagicNumber:()=>state.order.magic,
 MarketInfo:(s,k)=>({1:.01,2:100,3:.01,4:1,5:1.05,6:1.04,7:.00001,8:10,9:0,10:5,12:9999}[k]),MODE_MINLOT:1,MODE_MAXLOT:2,MODE_LOTSTEP:3,MODE_TRADEALLOWED:4,MODE_ASK:5,MODE_BID:6,MODE_POINT:7,MODE_STOPLEVEL:8,MODE_FREEZELEVEL:9,MODE_DIGITS:10,MODE_TIME:12,
 SymbolInfoDouble:(s,k)=>({1:.01,2:100,3:.01,5:1.05,6:1.04,7:.00001,11:.00001}[k]),SYMBOL_VOLUME_MIN:1,SYMBOL_VOLUME_MAX:2,SYMBOL_VOLUME_STEP:3,SYMBOL_ASK:5,SYMBOL_BID:6,SYMBOL_TRADE_TICK_SIZE:11,SYMBOL_POINT:7,SYMBOL_TRADE_STOPS_LEVEL:8,SYMBOL_TRADE_FREEZE_LEVEL:9,SYMBOL_DIGITS:10,
 SymbolInfoTick:(s,q)=>{q.ask=1.05;q.bid=1.04;q.time=9999;return true;},SymbolInfoInteger:(s,k)=>({8:10,9:0,10:5}[k]),
 InpSlippage:10,RefreshRates:()=>{},OP_BUY:0,OP_SELL:1,clrNONE:0,g_lastError:0,
 OrderSend:(symbol,action,volume,price,slip,sl,tp,comment,magic)=>{state.trades.push({symbol,action,volume,magic,sl,tp});return state.accepted?1:-1;},
 TRADE_RETCODE_DONE:10009,TRADE_RETCODE_DONE_PARTIAL:10010,
 HistoryDealSelect:()=>true,HistoryDealGetInteger:(t,k)=>k===1?20261002:1,HistoryDealGetString:()=> 'EURUSD.m',DEAL_MAGIC:1,DEAL_SYMBOL:2,DEAL_POSITION_ID:3,
 CTrade:class { SetAsyncMode(){} SetExpertMagicNumber(m){this.magic=m;}SetDeviationInPoints(){}SetTypeFillingBySymbol(){return true;} Buy(volume,symbol,price,sl,tp){state.trades.push({volume,symbol,magic:this.magic,action:0,sl,tp});return state.accepted;}Sell(volume,symbol,price,sl,tp){state.trades.push({volume,symbol,magic:this.magic,action:1,sl,tp});return state.accepted;}ResultDeal(){return 1;}ResultRetcode(){return state.retcode;} }
 };
 vm.createContext(c);
 for(const name of ['JsonSpace','JsonNumber','JsonRawField','RawString','ValidUuid','UtcExpiry','ExactVolume','ExactBrokerSymbol','ProtectionParameters','ProtectionPrice','ProtectionPair','FreshBrokerTimes','AutomationVolume','AutomationValidate','AutomationOccupied','AutomationExecute','CommandClaim'])vm.runInContext(extract(source,name),c);
 return {c,state,source,directory};
}
function payload(change={}) {return JSON.stringify({id:uuid,action:'buy',symbol:'EURUSD.m',volume:.1,automation:true,rule_id:id2,magic:'20261002',stop_mode:'atr',atr_period:14,atr_timeframe:'H1',sl_atr_multiplier:'2.00',tp_atr_multiplier:'3.00',expires_at:'2026-10-02T00:05:00+00:00',...change});}
for(const platform of [4,5]) {
 test(`MT${platform}: upgraded opted-in consumer capability is included on command poll`,()=>{
  const {c,source,state}=harness(platform);vm.runInContext(extract(source,'AutomationPollCapabilities'),c);
  assert.equal(c.AutomationPollCapabilities(),'&automation_v1=1&automation_protection_v1=1&automation_ready=1');
  state.ready=false;assert.equal(c.AutomationPollCapabilities(),'&automation_v1=1&automation_protection_v1=1&automation_ready=0');
  assert.ok(source.includes('url += AutomationPollCapabilities();'));
 });
 test(`MT${platform}: broker quote and closed H1 candle must be fresh`,()=>{
  const {c,source}=harness(platform);vm.runInContext(extract(source,'FreshBrokerTimes'),c);
  assert.equal(c.FreshBrokerTimes(10000,9990,6000),true);
  for(const [now,quote,bar] of [[10000,9800,6000],[10000,10001,6000],[10000,9990,9500],[10000,9990,1000],[10000,0,6000]])assert.equal(c.FreshBrokerTimes(now,quote,bar),false);
 });
 test(`MT${platform}: complete automation-only symbol snapshot, reset to explicit empty, incomplete to null`,()=>{
  const {c,source}=harness(platform);c.g_automationSymbols=[];c.g_automationCounts=[];c.g_automationSnapshotComplete=true;
  c.ArraySize=a=>a.length;c.ArrayResize=(a,n)=>{a.length=n;return n;};c.IntegerToString=String;
  for(const name of ['ResetAutomationSnapshot','CollectAutomationSymbol','AutomationPositionsJson'])vm.runInContext(extract(source,name),c);
  assert.equal(c.AutomationPositionsJson(),'[]');c.CollectAutomationSymbol('EURUSD.m');c.CollectAutomationSymbol('EURUSD.m');c.CollectAutomationSymbol('XAUUSD');
  assert.deepEqual(JSON.parse(c.AutomationPositionsJson()),[{symbol:'EURUSD.m',open_positions:2},{symbol:'XAUUSD',open_positions:1}]);
  c.g_automationSnapshotComplete=false;assert.equal(c.AutomationPositionsJson(),'null');c.ResetAutomationSnapshot();assert.equal(c.AutomationPositionsJson(),'[]');
 });
 test(`MT${platform}: mandatory ATR direction, invalid ATR, broker minimum distance and tick rounding`,()=>{
  const {c,source}=harness(platform);
  for(const name of ['ProtectionParameters','ProtectionPrice','ProtectionPair'])vm.runInContext(extract(source,name),c);
  c.NormalizeDouble=(v,d)=>Number(v.toFixed(d));c.MathCeil=Math.ceil;c.MathFloor=Math.floor;
  assert.equal(c.ProtectionPrice('buy',true,100,2,2,.25,2),96);
  assert.equal(c.ProtectionPrice('buy',false,100,2,3,.25,2),106);
  assert.equal(c.ProtectionPrice('sell',true,100,2,2,.25,2),104);
  assert.equal(c.ProtectionPrice('sell',false,100,2,3,.25,2),94);
  assert.equal(c.ProtectionPrice('buy',true,100,.13,2,.25,2),99.5);
  for(const atr of [0,-1,NaN,Infinity])assert.equal(c.ProtectionPrice('buy',true,100,atr,2,.25,2),0);
  assert.equal(c.ProtectionPair('buy',100,99.9,100,96,106,1,.25),true);
  assert.equal(c.ProtectionPair('sell',100,100,100.1,104,94,1,.25),true);
  assert.equal(c.ProtectionPair('buy',100,99.9,100,99.5,106,1,.25),false);
  assert.equal(c.ProtectionPair('buy',100,99.9,100,101,106,0,.25),false);
  assert.equal(c.ProtectionPair('sell',100,100,100.1,104,101,0,.25),false);
  assert.equal(c.ProtectionPair('buy',100,99.9,100,96.1,106,1,.25),false);
  assert.equal(c.ProtectionPair('buy',100,99.9,100,96,106,-1,.25),false);
 });
 test(`MT${platform}: JSON boolean/serializer spacing/key order and malformed auto never become manual`,()=>{
  const {c}=harness(platform), valid=payload();
  assert.equal(c.AutomationValidate(valid,'buy','EURUSD.m',.1),1);
  assert.equal(c.AutomationValidate(JSON.stringify(JSON.parse(valid),null,2),'buy','EURUSD.m',.1),1);
  for(const automation of ['true',1,null,'false'])assert.equal(c.AutomationValidate(payload({automation}),'buy','EURUSD.m',.1),-1);
  assert.equal(c.AutomationValidate(payload({automation:false}),'buy','EURUSD.m',.1),-1);
  assert.equal(c.AutomationValidate('{"action":"buy","automation":false}','buy','EURUSD.m',.1),0);
  assert.equal(c.AutomationValidate('{"action":"buy"}','buy','EURUSD.m',.1),0);
  assert.equal(c.AutomationValidate('{"automation":true,"automation":false}','buy','EURUSD.m',.1),-1);
  for(const field of ['rule_id','magic','expires_at','volume','symbol','id']) { const p=JSON.parse(valid);delete p[field];assert.equal(c.AutomationValidate(JSON.stringify(p),'buy','EURUSD.m',.1),-1); }
  for(const bad of [valid.replace('"volume":0.1','"volume":0.1junk'),valid.replace('"rule_id":','"nested":{},"rule_id":'),'{"automation":true,}'])assert.equal(c.AutomationValidate(bad,'buy','EURUSD.m',.1),-1);
 });
 test(`MT${platform}: opt-in, UUID, reserved magic, exact symbol, UTC expiry and volume guards`,()=>{
  const {c,state}=harness(platform);
  for(const [field,values] of Object.entries({rule_id:['', 'not-a-uuid'],magic:[20261002,'42'],expires_at:['2026-10-02T00:00:00Z','2026-10-02T01:00:00+01:00','2026-02-31T00:05:00Z','bad'],volume:[0,-1,.001,100.01,.105,'0.1']})) for(const value of values)assert.equal(c.AutomationValidate(payload({[field]:value}),'buy','EURUSD.m',Number(value)), -1,field);
  for(const symbol of ['', 'EURUSD','eurusd.m','EURUSD.m ']) assert.equal(c.AutomationValidate(payload({symbol}),'buy',symbol,.1),-1);
  state.ready=false;assert.equal(c.AutomationValidate(payload(),'buy','EURUSD.m',.1),-1);state.ready=true;
  assert.equal(c.AutomationValidate(payload({action:'close'}),'close','EURUSD.m',.1),-1);
  for(const date of ['2026-10-02T00:05:00Z','2026-10-02T00:05:00.123456+00:00'])assert.equal(c.AutomationValidate(payload({expires_at:date}),'buy','EURUSD.m',.1),1);
  for(const n of [NaN,Infinity,.105,.001,101])assert.equal(c.ExactVolume(n,.01,100,.01),false);
  assert.equal(c.ExactVolume(.03,.01,100,.01),true);assert.equal(c.ExactVolume(.1,.01,100,0),false);
 });
 test(`MT${platform}: execution rechecks occupancy and never rounds automatic lots or uses manual magic`,()=>{
  const {c,state}=harness(platform);state.positions=[{symbol:'EURUSD.m',magic:20261002}];state.orders=[...state.positions];
  assert.equal(c.AutomationExecute(payload(),'buy','EURUSD.m',.1),false);assert.equal(state.trades.length,0);
  state.positions=[];state.orders=[];
  assert.equal(c.AutomationExecute(payload(),'buy','EURUSD.m',.1),true);
  assert.equal(state.trades[0].magic,20261002);assert.equal(state.trades[0].volume,.1);
  assert.ok(state.trades[0].sl>0 && state.trades[0].tp>0,'initial order includes both stops');
  for(const atr of [0,-1,NaN,Infinity]) {state.atr=atr;const before=state.trades.length;assert.equal(c.AutomationExecute(payload(),'buy','EURUSD.m',.1),false);assert.equal(state.trades.length,before);}state.atr=.01;
  for(const change of [{stop_mode:null},{atr_period:15},{atr_timeframe:'M15'},{sl_atr_multiplier:'NaN'},{sl_atr_multiplier:'0.09'},{tp_atr_multiplier:'20.1'}])assert.equal(c.AutomationValidate(payload(change),'buy','EURUSD.m',.1),-1);
  state.orders=[{symbol:'EURUSD.m',magic:20261002}];assert.equal(c.AutomationExecute(payload(),'buy','EURUSD.m',.1),false);
  state.orders=[];state.now+=600;assert.equal(c.AutomationExecute(payload(),'buy','EURUSD.m',.1),false);
 });
 test(`MT${platform}: real temporary-file modeled durable preclaim, restart, lock and corruption fail closed`,()=>{
  const h=harness(platform), {c,state}=h;
  let claim=c.CommandClaim(uuid);assert.ok(claim>=0);assert.equal(c.CommandClaim(id2),-1);c.FileClose(claim);
  assert.equal(c.CommandClaim(uuid),-2);
  const restart=harness(platform,h.directory);assert.equal(restart.c.CommandClaim(uuid),-2);
  state.writeFail=true;assert.equal(c.CommandClaim(id2),-1);state.writeFail=false;
  fs.appendFileSync(path.join(h.directory,fs.readdirSync(h.directory)[0]),'partial');assert.equal(c.CommandClaim(id2),-1);
  assert.equal(state.trades.length,0);
 });
}
test('MT5: netting rejects ANY symbol position/order; hedging permits unrelated magic; broker Boolean alone is not success',()=>{
 const {c,state}=harness(5);state.positions=[{symbol:'EURUSD.m',magic:99}];state.netting=true;
 assert.equal(c.AutomationExecute(payload(),'buy','EURUSD.m',.1),false);
 state.positions=[];state.orders=[{symbol:'EURUSD.m',magic:99}];assert.equal(c.AutomationExecute(payload(),'buy','EURUSD.m',.1),false);
 state.netting=false;state.orders=[];state.positions=[{symbol:'EURUSD.m',magic:99}];assert.equal(c.AutomationExecute(payload(),'buy','EURUSD.m',.1),true);
 state.positions=[];state.retcode=10008;assert.equal(c.AutomationExecute(payload(),'buy','EURUSD.m',.1),false);
 state.retcode=10010;assert.equal(c.AutomationExecute(payload(),'buy','EURUSD.m',.1),true);
 state.accepted=false;assert.equal(c.AutomationExecute(payload(),'buy','EURUSD.m',.1),false);
});
