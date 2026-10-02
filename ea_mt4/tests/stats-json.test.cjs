const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const source=fs.readFileSync(path.join(__dirname,'../HandlivPanel.mq4'),'utf8');
const stats=source.slice(source.indexOf('void SendStats()'),source.indexOf('void PollCommands()'));
const match=stats.match(/string json\s*=([\s\S]*?);\s*string resp/);
assert.ok(match,'stats serialization assignment');
test('stats JSON does not depend on one variadic formatter containing nested format calls',()=>{
  assert.doesNotMatch(match[1],/StringFormat\(/);
});
test('stats serializer produces a nonempty object, retains every account field and robot snapshot',()=>{
  const robots=[{magic:'123',open_positions:0,floating_pl:0,profit_total:2,total_trades:1,win_trades:1,loss_trades:0,history_scope:'terminal_loaded',heartbeat:true}];
  const ctx={equity:10.5,balance:10,margin:0,mlevel:0,accountFloating:0.5,dd:0,day0:1,week0:2,month0:3,now:100,accountWins:1,accountLosses:0,
    AccountNumber:()=>123456,AccountToken:()=> 'test-not-a-secret',AccountCurrency:()=> 'USD',
    HistoryProfit:()=>2,OpenPositionsCount:()=>0,RobotStatsJson:()=>JSON.stringify(robots),
    DoubleToString:(v,n)=>Number(v).toFixed(n),IntegerToString:String,
    // Fault injection of a formatting failure; no claim about MQL builtins.
    StringFormat:()=>'',
  };
  ctx.AutomationPositionsJson=()=>JSON.stringify([{symbol:'EURUSD.m',open_positions:2}]);
  ctx.AutomationReady=()=>false;
  const prefix=stats.match(/string robots=RobotStatsJson\(\);\s*string automationPositions=AutomationPositionsJson\(\);/);
  assert.ok(prefix,'snapshot collectors are evaluated before serialization');
  const json=vm.runInNewContext(prefix[0].replace(/\bstring /g,'let ')+'\n('+match[1]+')',ctx);
  assert.ok(json.length>0,'an upstream formatting failure must not produce an empty body');
  const data=JSON.parse(json);
  assert.equal(data.account,'123456');assert.equal(data.login,data.account);
  assert.equal(data.equity,10.5);assert.equal(data.floating_pl,0.5);
  assert.equal(data.profit_day,2);assert.equal(data.profit_week,2);
  assert.equal(data.profit_month,2);assert.equal(data.profit_total,2);
  assert.equal(data.win_trades,1);assert.equal(data.loss_trades,0);
  assert.equal(data.total_trades,1);assert.equal(data.open_positions,0);
  assert.equal(data.currency,'USD');assert.deepEqual(data.robots,robots);
  assert.equal(data.automation_v1,true);assert.equal(data.automation_protection_v1,true);assert.equal(data.automation_ready,false);
  assert.deepEqual(data.automation_positions,[{symbol:'EURUSD.m',open_positions:2}]);
});
