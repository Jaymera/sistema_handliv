const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');

const source=fs.readFileSync(path.join(__dirname,'../HandlivPanel.mq5'),'utf8');

/**
 * These tests model MQL platform builtins to check branching and byte counts.
 * They are not a claim about how the MT5 terminal implements StringToCharArray.
 */
function transport(json,{conversionFails=false,resizeFails=false}={}){
  const start=source.indexOf('bool HttpPost(');
  const end=source.indexOf('\n//+---',start);
  assert.ok(start>=0&&end>start,'HttpPost region present');
  const fn=source.slice(start,end)
    .replace(/bool HttpPost\([^)]*\)/,'function HttpPost(url,json,response)')
    .replace(/char\s+post\[\]\s*;\s*char result\[\];\s*string resultHeaders;/,'let post=[],result=[];let resultHeaders="";')
    .replace(/\b(?:string|int|char|bool)\s+(?=[A-Za-z_]\w*\s*[=,;(])/g,'');
  const calls=[],logs=[];
  const context={
    g_status:'',HTTP_TIMEOUT:5000,CP_UTF8:65001,WHOLE_ARRAY:-1,
    StringLen:s=>s.length,ResetLastError:()=>{},GetLastError:()=>0,
    // MQL StringToCharArray writes a terminating NUL byte into the array.
    StringToCharArray:(s,a)=>{if(conversionFails)return 0;const b=Buffer.from(s,'utf8');a.push(...b);a.push(0);return b.length;},
    ArrayResize:(a,n)=>{if(resizeFails)return -1;a.length=n;return n;},
    WebRequest:(method,url,headers,timeout,post)=>{calls.push({method,url,headers,bytes:Buffer.from(post)});return 200;},
    CharArrayToString:()=>'',JsonGetString:()=>'',IntegerToString:String,
    StringSubstr:(s,i,n)=>s.slice(i,i+n),HttpErrorHelp:()=>'',Print:(...v)=>logs.push(v.join(' ')),
  };
  vm.createContext(context);
  const result=vm.runInContext(
    fn+';HttpPost("https://example.invalid/mt5/ea/stats",'+JSON.stringify(json)+',"")',context);
  return {result,calls,logs,status:context.g_status};
}

test('HTTP response is decoded before validation diagnostics read it',()=>{
  const start=source.indexOf('bool HttpPost(');
  const end=source.indexOf('\n//+---',start);
  const fn=source.slice(start,end);
  assert.ok(fn.indexOf('response = CharArrayToString') < fn.indexOf('JsonGetString(response'), 'decode before inspecting error fields');
});

test('POST body carries no terminating NUL byte, otherwise the API parser rejects it',()=>{
  const json='{"account":"123","robots":[]}';
  const r=transport(json);
  assert.equal(r.result,true);
  assert.equal(r.calls.length,1);
  assert.equal(r.calls[0].bytes[r.calls[0].bytes.length-1]!==0,true,'last byte must not be NUL');
  assert.equal(r.calls[0].bytes.toString('utf8'),json);
  assert.match(r.calls[0].headers,/Content-Type: application\/json/);
});

test('an empty body is refused locally instead of being submitted and rejected by the API',()=>{
  const r=transport('');
  assert.equal(r.result,false);
  assert.equal(r.calls.length,0);
  assert.match(r.status,/corpo vazio/i);
});

test('a failed UTF-8 conversion or resize never reaches WebRequest',()=>{
  assert.equal(transport('{"a":1}',{conversionFails:true}).calls.length,0);
  assert.equal(transport('{"a":1}',{resizeFails:true}).calls.length,0);
});

const statsBody=()=>{
  const start=source.indexOf('void SendStats()');
  const match=source.slice(start).match(/string json\s*=([\s\S]*?);\s*string resp/);
  assert.ok(match,'stats serialization assignment');
  // Strip MQL type casts, which are not JavaScript, and provide JS builtins below.
  return match[1].replace(/\(int\)/g,'');
};

test('stats JSON is not built by one variadic formatter wrapping the robot snapshot',()=>{
  assert.doesNotMatch(statsBody(),/StringFormat\(/);
});

test('stats serializer keeps every account field and the robot snapshot intact',()=>{
  const robots=[{magic:'20260817',symbol:'EURUSD',open_positions:0,floating_pl:0,heartbeat:true}];
  const ctx={
    now:100,day0:1,week0:2,month0:3,g_peakEquity:0,equity:10.5,balance:10,dd:0,wins:1,losses:0,
    ACCOUNT_LOGIN:0,ACCOUNT_CURRENCY:1,ACCOUNT_EQUITY:2,ACCOUNT_BALANCE:3,
    ACCOUNT_MARGIN:4,ACCOUNT_MARGIN_LEVEL:5,ACCOUNT_PROFIT:6,
    AccountInfoDouble:k=>({[k]:0})[k]??0,AccountInfoInteger:()=>123456,AccountInfoString:()=> 'USD',
    AccountToken:()=> 'test-not-a-secret',
    HttpErrorHelp:()=>'',
    HistoryProfit:()=>2,PositionsTotal:()=>0,RobotStatsJson:()=>JSON.stringify(robots),
    DoubleToString:(v,n)=>Number(v).toFixed(n),IntegerToString:String,
    StringFormat:()=>'', // fault injection: an upstream failure must not empty the body
  };
  const json=vm.runInNewContext(statsBody(),ctx);
  assert.ok(json.length>0,'a formatting failure must not produce an empty body');
  const data=JSON.parse(json);
  assert.equal(data.account,'123456');
  assert.equal(data.login,'123456');
  assert.equal(data.equity,10.5);
  assert.equal(data.balance,10);
  assert.equal(data.profit_day,2);
  assert.equal(data.profit_total,2);
  assert.equal(data.open_positions,0);
  assert.equal(data.currency,'USD');
  assert.deepEqual(data.robots,robots,'the robot list drives the trading floor desks');
});
