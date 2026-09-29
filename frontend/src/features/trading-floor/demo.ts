/** Synthetic fixtures ONLY. No API calls or writes; never merged with account telemetry. */
import type { FloorEvent, FloorPosition, FloorStation, FloorSummary } from './types';

export interface DemoFrame { stations: FloorStation[]; summary: FloorSummary; events: FloorEvent[]; step?: number }

export function advanceDemo(previous: DemoFrame, step: number, now = Date.now()): DemoFrame {
  if (step <= (previous.step ?? 0) || !previous.stations.length) return previous;
  const openIndex = previous.stations.findIndex(s => s.status !== 'OFFLINE' && s.positions.length > 0);
  const index = openIndex >= 0 ? openIndex : step % previous.stations.length;
  const station = previous.stations[index];
  const closing = openIndex >= 0;
  const pnl = closing ? station.positions[0].pnl ?? 0 : 0;
  const stations = previous.stations.slice();
  stations[index] = { ...station, updatedAt: new Date(now).toISOString(),
    positions: closing ? [] : [position(index)], openPositions: closing ? 0 : 1,
    status: closing ? 'AGUARDANDO' : 'POSIÇÃO ABERTA',
    profitDay: round((station.profitDay ?? 0)+pnl),
    profitWeek: round((station.profitWeek ?? 0)+pnl),profitMonth: round((station.profitMonth ?? 0)+pnl),
    trades: (station.trades ?? 0)+(closing ? 1:0),
    wins:(station.wins ?? 0)+(closing && pnl>0 ? 1:0),losses:(station.losses ?? 0)+(closing && pnl<0 ? 1:0) };
  const balance=round((previous.summary.balance ?? 100000)+pnl);
  const floating=round(stations.reduce((sum,s)=>sum+s.positions.reduce((p,pos)=>p+(pos.pnl??0),0),0));
  const equity=round(balance+floating);
  const events=previous.events.filter(e=>now-e.at<=5000);
  if (closing) events.push({id:`demo-event-${step}`,stationId:station.id,pnl,currency:station.currency,at:now});
  return {step,stations,events:events.slice(-8),summary:{...previous.summary,balance,equity,floating,
    profitDay:round((previous.summary.profitDay??0)+pnl),
    drawdown:round(Math.max(0,-floating)/Math.max(1,balance)*100),
    openPositions:stations.reduce((sum,s)=>sum+s.positions.length,0),
    online:stations.filter(s=>s.status!=='OFFLINE').length,
    equityHistory:[...previous.summary.equityHistory,equity].slice(-40)}};
}
const instruments = [ ['GOLD', 'XAUUSD', 2635.4], ['NASDAQ', 'USTEC', 20110.5], ['EURUSD', 'EURUSD', 1.1124], ['GBPUSD', 'GBPUSD', 1.321], ['BITCOIN', 'BTCUSD', 65250], ['OIL', 'USOIL', 71.42] ] as const;
const round = (value: number) => Math.round(value * 100) / 100;

function position(index: number): FloorPosition {
  const [,symbol,entry] = instruments[index % instruments.length];
  const buy = index % 2 === 0;
  return { id:`demo-position-${index}`,symbol,side:buy ? 'BUY' : 'SELL',entry,
    current:entry * (buy ? 1.0003 : 1.0002),stop:entry * (buy ? .998 : 1.002),
    take:entry * (buy ? 1.004 : .996),lot:.1,pnl:round(index % 3 === 0 ? -14.2-index : 35.4+index) };
}

export function createDemo(count: number, now = Date.now()): DemoFrame {
  const size = Number.isFinite(count) ? Math.min(250,Math.max(0,Math.floor(count))) : 10;
  const stations: FloorStation[] = Array.from({length:size},(_,i) => {
    const positions = i % 4 === 0 ? [position(i)] : [];
    const trades=12+i%13, wins=7+i%7;
    return { id:`demo-${i}`,scope:'robot',name:`LIVWELL ${instruments[i % instruments.length][0]}${i>=6 ? ` ${Math.floor(i/6)+1}` : ''}`,
      symbol:instruments[i % instruments.length][1],currency:'USD',
      profitDay:round(i%3===1 ? -12.3-i*1.7 : 42.8+i*2.3),
      status:i%9===8 ? 'OFFLINE' : positions.length ? 'POSIÇÃO ABERTA' : i%3===0 ? 'OPERANDO' : 'AGUARDANDO',
      updatedAt:new Date(now).toISOString(),magic:77000+i,timeframe:i%2 ? 'M15':'H1',
      profitWeek:round(140.5+i*12.5),profitMonth:round(510.25+i*18),trades,wins:Math.min(wins,trades),
      losses:trades-Math.min(wins,trades),drawdown:round(1.2+(i%7)*.3),positions,openPositions:positions.length };
  });
  const profitDay=round(stations.reduce((sum,s)=>sum+(s.profitDay??0),0));
  const floating=round(stations.reduce((sum,s)=>sum+s.positions.reduce((p,pos)=>p+(pos.pnl??0),0),0));
  const balance=round(100000+profitDay);
  return {stations,events:[],summary:{currency:'USD',balance,equity:round(balance+floating),profitDay,floating,
    drawdown:round(Math.max(0,-floating)/balance*100),openPositions:stations.reduce((sum,s)=>sum+s.positions.length,0),
    online:stations.filter(s=>s.status!=='OFFLINE').length,
    equityHistory:Array.from({length:24},(_,i)=>round(balance-250+i*10+Math.sin(i*.9)*22)).concat(round(balance+floating)) }};
}
