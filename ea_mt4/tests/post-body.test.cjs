const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const source=fs.readFileSync(path.join(__dirname,'../HandlivPanel.mq4'),'utf8');
// Run the extracted MQL transport with modeled platform builtins. This checks
// branching/bytes, not a live terminal or the implementation of MQL builtins.
function transport(json, conversionFails=false){
  const start=source.indexOf('bool HttpPost(');
  const end=source.indexOf('\n//+----',start);
  let fn=source.slice(start,end).replace(/bool HttpPost\([^)]*\)/,'function HttpPost(url,json,response)');
  fn=fn.replace(/char\s+post\[\],\s*result\[\];/g,'let post=[],result=[];')
    .replace(/\b(?:string|int)\s+(?=[A-Za-z_]\w*\s*[=,;])/g,'let ');
  const calls=[],logs=[];
  const context={g_status:'',HTTP_TIMEOUT:5000,CP_UTF8:65001,WHOLE_ARRAY:-1,
    StringLen:s=>s.length,ResetLastError:()=>{},GetLastError:()=>0,
    StringToCharArray:(s,a)=>{if(conversionFails)return 0;const b=Buffer.from(s,'utf8');a.push(...b);return b.length;},
    ArrayResize:(a,n)=>{a.length=n;return n;},
    WebRequest:(method,url,headers,timeout,post)=>{calls.push({method,url,headers,bytes:Buffer.from(post)});return 200;},
    CharArrayToString:()=>'',JsonGetString:()=>'',IntegerToString:String,
    StringSubstr:(s,i,n)=>s.slice(i,i+n),HttpErrorHelp:()=>'',Print:(...v)=>logs.push(v.join('')),
  };
  vm.createContext(context);
  const result=vm.runInContext(fn+';HttpPost("https://example.invalid/mt5/ea/stats",'+JSON.stringify(json)+',"")',context);
  return {result,calls,logs,status:context.g_status};
}
test('empty payload is refused locally, never submitted as a zero-byte JSON POST',()=>{
  const r=transport('');assert.equal(r.result,false);assert.equal(r.calls.length,0);
  assert.match(r.status,/corpo vazio/i);
});
test('conversion failure is refused locally before WebRequest',()=>{
  const r=transport('{"test":true}',true);assert.equal(r.result,false);assert.equal(r.calls.length,0);
});
test('UTF8 object is sent as exact JSON bytes without trailing NUL',()=>{
  const json='{"message":"ação","test":true}';const r=transport(json);
  assert.equal(r.result,true);assert.equal(r.calls.length,1);
  assert.equal(r.calls[0].bytes.toString('utf8'),json);
  assert.match(r.calls[0].headers,/Content-Type: application\/json/);
});
