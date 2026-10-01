export interface Point { x: number; y: number }
export interface Rect extends Point { width: number; height: number }
export interface Camera extends Point { scale: number }
export const toScreen = (p: Point, c: Camera): Point => ({ x: p.x * c.scale + c.x, y: p.y * c.scale + c.y });
export const toWorld = (p: Point, c: Camera): Point => ({ x: (p.x - c.x) / c.scale, y: (p.y - c.y) / c.scale });
export function fitCamera(b: Rect, width: number, height: number): Camera {
  const scale = Math.max(.04, Math.min(1.1, (width - 36) / b.width, (height - 32) / b.height));
  return { scale, x: width / 2 - (b.x + b.width / 2) * scale, y: height / 2 - (b.y + b.height / 2) * scale };
}
export function zoomCamera(c: Camera, anchor: Point, factor: number): Camera {
  const p = toWorld(anchor, c), scale = Math.min(2.5, Math.max(.04, c.scale * factor));
  return { scale, x: anchor.x - p.x * scale, y: anchor.y - p.y * scale };
}
export function hitStation(p: Point, stations: readonly (Point & { id: string })[], c: Camera): string | null {
  const w = toWorld(p, c);
  for (let i = stations.length - 1; i >= 0; i--) {
    const s = stations[i];
    if (Math.abs(w.x - s.x) <= 92 && w.y >= s.y - 105 && w.y <= s.y + 105) return s.id;
  }
  return null;
}
const formats = new Map<string, Intl.NumberFormat>();
export function money(value: number | null, currency: string): string {
  if (value === null || !Number.isFinite(value)) return '—';
  try {
    if (!formats.has(currency)) formats.set(currency, new Intl.NumberFormat('pt-BR', { style: 'currency', currency, maximumFractionDigits: 2 }));
    return formats.get(currency)!.format(value);
  } catch { return `${currency} ${value.toFixed(2)}`; }
}
export const iso = (x: number, y: number): Point => ({ x: (x - y) * .78, y: (x + y) * .39 });
/** Movement is visual only: it never changes robot presence, order state or P/L. */
export const avatarVisible = (status: string) => status !== 'OFFLINE';
/** Stable visual identity; not a claim about the EA's real-world operator. */
export function agentAppearance(id: string) {
  const seed = hashId(id);
  return {
    jacket: ['#536D98', '#796491', '#548A83', '#A16D60', '#6383A0'][seed % 5],
    skin: ['#D2A183', '#B77C62', '#E4BB91', '#8D5B49'][Math.floor(seed / 5) % 4],
    hair: ['#252332', '#42362F', '#322B50', '#594232'][Math.floor(seed / 20) % 4],
  };
}
type SocialArea = 'pool' | 'coffee' | 'meeting' | 'chat' | 'rest' | 'dog';
type Pose = { x: number; y: number; walking: boolean; stride: number; facing: 'left' | 'right'; activity: 'desk' | 'walking' | SocialArea };
/** Shared Canvas/SVG body language, independent of financial telemetry. */
export function avatarGesture(pose: Pose, now: number, reducedMotion: boolean) {
  const wave = reducedMotion ? 0 : Math.sin(now / 420);
  const step = reducedMotion ? 0 : pose.stride;
  const left = { x: -24, y: -16 }, right = { x: 23, y: -16 };
  let prop: 'cup' | 'phone' | 'cue' | 'ball' | null = null;
  let lean = 0;
  switch (pose.activity) {
    case 'walking': left.y += step * 1.4; right.y -= step * 1.4; lean = step * .15; break;
    case 'desk': left.y = -20 + wave * 2; right.y = -22 - wave * 2; break;
    case 'coffee': right.x = 15; right.y = -31 + wave * 6; prop = 'cup'; break;
    case 'chat': case 'meeting': right.x = 28 + wave * 4; right.y = -30 + wave * 8; left.y = -18 - wave * 3; break;
    case 'rest': right.x = 18; right.y = -28; left.x = -10; left.y = -23; lean = -3; prop = 'phone'; break;
    case 'dog': right.x = 31; right.y = -2 + wave * 5; left.x = -7; left.y = -12; lean = 7; prop = 'ball'; break;
    case 'pool': right.x = 32; right.y = -17 + wave * 2; left.x = -28; left.y = -13; lean = 4; prop = 'cue'; break;
  }
  return { left, right, prop, lean };
}
const atDesk: Pose = { x: 0, y: 0, walking: false, stride: 0, facing: 'right', activity: 'desk' };
function hashId(id: string): number {
  let value = 2166136261;
  for (let i = 0; i < id.length; i++) value = Math.imul(value ^ id.charCodeAt(i), 16777619);
  return value >>> 0;
}
function along(points: Point[], fraction: number): { point: Point; facing: 'left' | 'right' } {
  const lengths = points.slice(1).map((point, i) => Math.hypot(point.x - points[i].x, point.y - points[i].y));
  let remaining = lengths.reduce((sum, length) => sum + length, 0) * fraction;
  for (let i = 0; i < lengths.length; i++) {
    if (remaining <= lengths[i] || i === lengths.length - 1) {
      const p = points[i], q = points[i + 1], f = lengths[i] ? Math.min(1, remaining / lengths[i]) : 0;
      return { point: { x: p.x + (q.x - p.x) * f, y: p.y + (q.y - p.y) * f }, facing: q.x < p.x ? 'left' : 'right' };
    }
    remaining -= lengths[i];
  }
  return { point: points[0], facing: 'right' };
}
export function traderPose(status: string, now: number, id: string, reducedMotion: boolean,
  desk?: Point, layout?: ReturnType<typeof layoutScene>): Pose {
  if (status !== 'AGUARDANDO' || reducedMotion) return atDesk;
  const seed = hashId(id);
  if (!desk || !layout) {
    const phase = ((now + seed % 7000) % 12000) / 12000;
    if (phase < .16 || phase > .86) return atDesk;
    const t = phase < .40 ? (phase - .16) / .24 : phase < .63 ? 1 : 1 - (phase - .63) / .23;
    return { x: 88 * t, y: 56 * t, walking: phase < .40 || phase > .63,
      stride: Math.sin(now / 155) * 5, facing: phase > .63 ? 'left' : 'right', activity: phase < .40 || phase > .63 ? 'walking' : 'coffee' };
  }
  const index = layout.stations.findIndex(s => s.id === id);
  if (index < 0) return atDesk;
  const activities: SocialArea[]=['dog','coffee','meeting',layout.stations.length>1?'chat':'dog','rest','pool'];
  const routes=activities.map(activity=>routeGrid(id,layout,activity).map(p=>iso(p.x,p.y)));
  const lengths = routes.map(points => points.slice(1).reduce((total, p, i) => total + Math.hypot(p.x - points[i].x, p.y - points[i].y), 0));
  // A common period keeps destinations changing only when safely back at the desk.
  const trip = Math.max(3500, Math.max(...lengths) / 105 * 1000);
  const pause = 11000 + seed % 6000, deskPause = 4500 + seed % 2500;
  const cycle = deskPause * 2 + trip * 2 + pause;
  const absolute = now + seed % Math.floor(cycle);
  const round = Math.floor(absolute / cycle);
  const routine = ((round + seed % 6) % 6 + 6) % 6;
  const activity: SocialArea = activities[routine];
  const points = routes[routine];
  const t = ((absolute % cycle) + cycle) % cycle;
  if (t < deskPause || t >= deskPause + trip * 2 + pause) return atDesk;
  if (t >= deskPause + trip && t < deskPause + trip + pause) {
    const p = points[points.length - 1];
    return { x: p.x - desk.x, y: p.y - desk.y, walking: false, stride: 0, facing: activity === 'chat' || activity === 'dog' ? 'right' : seed % 2 ? 'left' : 'right', activity };
  }
  const outgoing = t < deskPause + trip;
  const part = outgoing ? (t - deskPause) / trip : 1 - (t - deskPause - trip - pause) / trip;
  const { point, facing } = along(points, part);
  return { x: point.x - desk.x, y: point.y - desk.y, walking: true,
    stride: Math.sin(now / 145) * 5, facing: outgoing ? facing : facing === 'left' ? 'right' : 'left', activity: 'walking' };
}
/** A clearly labeled decorative colleague, NOT an EA identity or chat telemetry. */
export function officeCoworkers(stations: readonly {id:string;status:string}[],layout: ReturnType<typeof layoutScene>,now:number,reducedMotion:boolean) {
  if(reducedMotion || layout.stations.length < 2)return [];
  const visitor=layout.stations.find(d=>stations.some(s=>s.id===d.id&&s.status==='AGUARDANDO')&&traderPose('AGUARDANDO',now,d.id,false,d,layout).activity==='chat');
  if(!visitor)return [];
  const p=traderPose('AGUARDANDO',now,visitor.id,false,visitor,layout);
  return [{id:'decor-colleague',name:'COLEGA VISUAL',decorative:true,visitorId:visitor.id,
    x:visitor.x+p.x+72,y:visitor.y+p.y,pose:{...atDesk,facing:'left' as const,activity:'chat' as const}}];
}
/** Dog stays in its lounge and responds only to an actually rendered waiting visitor. */
export function dogPose(stations: readonly {id:string;status:string}[],layout: ReturnType<typeof layoutScene>,now:number,reducedMotion:boolean) {
  const visitor=reducedMotion?undefined:layout.stations.find(d=>{
    const status=stations.find(s=>s.id===d.id)?.status;
    return status==='AGUARDANDO'&&traderPose(status,now,d.id,false,d,layout).activity==='dog';
  });
  return {...layout.dogHome,visitorId:visitor?.id??null,
    facing:'left' as const, wag:reducedMotion?0:Math.sin(now/(visitor?100:350))* (visitor?8:2),
    bounce:visitor?Math.max(0,Math.sin(now/280))*3:0};
}
/** Avatar targeting follows its visual position; no backend mutation or fake presence. */
export function hitAgent(pointer: Point, stations: readonly { id: string; status: string }[],
  layout: ReturnType<typeof layoutScene>, camera: Camera, now: number, reducedMotion: boolean): string | null {
  const statuses = new Map(stations.map(s => [s.id, s.status]));
  let closest: string | null = null, distance = Infinity;
  for (const desk of layout.stations) {
    const status = statuses.get(desk.id);
    if (!status || !avatarVisible(status)) continue;
    const pose = traderPose(status, now, desk.id, reducedMotion, desk, layout);
    const screen = toScreen({ x: desk.x + pose.x, y: desk.y + pose.y - 20 }, camera);
    const delta = Math.hypot(screen.x - pointer.x, screen.y - pointer.y);
    if (delta < Math.max(16, camera.scale * 29) && delta < distance) { closest = desk.id; distance = delta; }
  }
  return closest;
}
/** Axis-aligned walkable grid route, shared by every renderer and pointer target. */
export function routeGrid(id: string, layout: ReturnType<typeof layoutScene>, activity: string): Point[] {
  const desk=layout.stations.find(s=>s.id===id);
  if(!desk)return [];
  const room=layout.rooms.find(r=>r.kind===desk.room)!;
  const doorX=room.x+room.width/2;
  const destinationIndex=activity==='pool'||activity==='rest'||activity==='dog'?0:activity==='meeting'?2:1;
  const area=layout.amenities[destinationIndex];
  const targetX=activity==='dog'?layout.worldWidth/6-70:area.gridX;
  const bottom=room.y+room.height;
  const exitY=room.y===0?Math.max(...layout.rooms.slice(0,3).map(r=>r.height))+80:layout.corridorY;
  const points=[{x:desk.gridX,y:desk.gridY},{x:desk.gridX+120,y:desk.gridY},
    {x:desk.gridX+120,y:bottom-30},{x:doorX,y:bottom-30},
    {x:doorX,y:bottom},{x:doorX,y:exitY}];
  if(room.y===0)points.push({x:layout.worldWidth-80,y:exitY},{x:layout.worldWidth-80,y:layout.corridorY});
  points.push({x:targetX,y:layout.corridorY},{x:targetX,y:layout.corridorY+120});
  return points;
}
export { stationRoom } from './symbolRooms';
import { stationRoom, RoomKind } from './symbolRooms';
export function layoutScene(items: readonly { id: string; symbol?: string | null; assetType?: string | null }[]) {
  const sorted = [...items].sort((a,b)=>a.id.localeCompare(b.id));
  const kinds: RoomKind[] = ['Commodities','Forex','Ações','Crypto','Outros'];
  let offset = 0;
  const rooms = kinds.map((kind,i)=>{
    const members=sorted.filter(s=>stationRoom(s)===kind);
    const cols=Math.max(1,Math.ceil(Math.sqrt(members.length*1.4)));
    const rows=Math.max(1,Math.ceil(members.length/cols));
    const room={kind,x:offset,y:0,width:Math.max(300,cols*240+80),height:members.length?rows*240+100:220,cols,rows,color:['#A98452','#467CA8','#4B8C7C','#8064AE','#617088'][i],members};
    offset+=room.width;
    return room;
  });
  const topHeight=Math.max(...rooms.slice(0,3).map(r=>r.height));
  const firstWidth=rooms.slice(0,3).reduce((sum,r)=>sum+r.width,0);
  let lowerX=0;
  rooms.slice(3).forEach(r=>{r.x=lowerX;r.y=topHeight+180;lowerX+=r.width;});
  offset=Math.max(firstWidth,lowerX)+160;
  const roomHeight=Math.max(...rooms.map(r=>r.y+r.height));
  const corridorY=roomHeight+80;
  const stations=rooms.flatMap(r=>r.members.map((s,i)=>{
    const gridX=r.x+40+(i%r.cols+.5)*240,gridY=r.y+(Math.floor(i/r.cols)+.5)*240;
    return {id:s.id,room:r.kind,gridX,gridY,...iso(gridX,gridY)};
  }));
  const amenities=(['pool','coffee','meeting'] as const).map((kind,i)=>{
    const gridX=(i+.5)*offset/3,gridY=corridorY+240;
    return {kind,gridX,gridY,...iso(gridX,gridY)};
  });
  const walls=rooms.flatMap(r=>{
    const doorX=r.x+r.width/2;
    return [{a:{x:r.x,y:r.y},b:{x:r.x,y:r.y+r.height}},
      {a:{x:r.x,y:r.y},b:{x:r.x+r.width,y:r.y}},
      {a:{x:r.x+r.width,y:r.y},b:{x:r.x+r.width,y:r.y+r.height}},
      {a:{x:r.x,y:r.y+r.height},b:{x:doorX-55,y:r.y+r.height}},
      {a:{x:doorX+55,y:r.y+r.height},b:{x:r.x+r.width,y:r.y+r.height}}];
  });
  const decorations=rooms.flatMap(r=>[
    {kind:'plant' as const,...iso(r.x+28,r.y+35)},
    {kind:'bookcase' as const,...iso(r.x+r.width-55,r.y+35)},
  ]);
  const lounge=iso(offset/6,corridorY+145),petStop=iso(offset/6-70,corridorY+120),dogHome={x:petStop.x+48,y:petStop.y+5};
  const cols=Math.ceil(offset/240),rows=Math.ceil((corridorY+410)/240),deskRows=Math.ceil(roomHeight/240);
  const floor=[iso(0,0),iso(offset,0),iso(offset,rows*240),iso(0,rows*240)];
  const bounds={x:floor[3].x-70,y:-230,width:floor[1].x-floor[3].x+140,height:floor[2].y+330};
  return {stations,rooms,walls,decorations,lounge,dogHome,corridorY,worldWidth:offset,amenities,floor,bounds,cols,rows,deskRows};
}
