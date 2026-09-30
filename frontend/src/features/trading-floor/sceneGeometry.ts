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
type SocialArea = 'pool' | 'coffee' | 'meeting' | 'chat' | 'rest';
type Pose = { x: number; y: number; walking: boolean; stride: number; facing: 'left' | 'right'; activity: 'desk' | 'walking' | SocialArea };
/** Shared Canvas/SVG body language, independent of financial telemetry. */
export function avatarGesture(pose: Pose, now: number, reducedMotion: boolean) {
  const wave = reducedMotion ? 0 : Math.sin(now / 420);
  const step = reducedMotion ? 0 : pose.stride;
  const left = { x: -24, y: -16 }, right = { x: 23, y: -16 };
  let prop: 'cup' | 'phone' | 'cue' | null = null;
  let lean = 0;
  switch (pose.activity) {
    case 'walking': left.y += step * 1.4; right.y -= step * 1.4; lean = step * .15; break;
    case 'desk': left.y = -20 + wave * 2; right.y = -22 - wave * 2; break;
    case 'coffee': right.x = 15; right.y = -31 + wave * 6; prop = 'cup'; break;
    case 'chat': case 'meeting': right.x = 28 + wave * 4; right.y = -30 + wave * 8; left.y = -18 - wave * 3; break;
    case 'rest': right.x = 18; right.y = -28; left.x = -10; left.y = -23; lean = -3; prop = 'phone'; break;
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
  const row = Math.floor(index / layout.cols), col = index % layout.cols;
  // Original Handliv choreography, inspired by room/corridor routing in AgentFleet.
  // All feet stay in column seams and the front social aisle; no table crossings.
  const seam = (col + 1) * 240, deskY = (row + .5) * 240;
  const aisleY = (layout.deskRows + 1) * 240;
  const routes = layout.amenities.map((area, i) => {
    const destinationX = (i + .5) * layout.cols * 240 / 3;
    const end = iso(destinationX + (seed % 5 - 2) * 22, aisleY - 36);
    return [desk, iso(seam, deskY), iso(seam, aisleY), iso(destinationX, aisleY), end];
  });
  const lengths = routes.map(points => points.slice(1).reduce((total, p, i) => total + Math.hypot(p.x - points[i].x, p.y - points[i].y), 0));
  // A common period keeps destinations changing only when safely back at the desk.
  const trip = Math.max(3500, Math.max(...lengths) / 105 * 1000);
  const pause = 11000 + seed % 6000, deskPause = 4500 + seed % 2500;
  const cycle = deskPause * 2 + trip * 2 + pause;
  const absolute = now + seed % Math.floor(cycle);
  const round = Math.floor(absolute / cycle);
  const routine = ((round + seed % 5) % 5 + 5) % 5;
  const activity: SocialArea = (['pool', 'coffee', 'meeting', 'chat', 'rest'] as const)[routine];
  const destinationIndex = activity === 'pool' || activity === 'rest' ? 0 : activity === 'meeting' ? 2 : 1;
  const points = routes[destinationIndex];
  const t = ((absolute % cycle) + cycle) % cycle;
  if (t < deskPause || t >= deskPause + trip * 2 + pause) return atDesk;
  if (t >= deskPause + trip && t < deskPause + trip + pause) {
    const p = points[points.length - 1];
    return { x: p.x - desk.x, y: p.y - desk.y, walking: false, stride: 0, facing: seed % 2 ? 'left' : 'right', activity };
  }
  const outgoing = t < deskPause + trip;
  const part = outgoing ? (t - deskPause) / trip : 1 - (t - deskPause - trip - pause) / trip;
  const { point, facing } = along(points, part);
  return { x: point.x - desk.x, y: point.y - desk.y, walking: true,
    stride: Math.sin(now / 145) * 5, facing: outgoing ? facing : facing === 'left' ? 'right' : 'left', activity: 'walking' };
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
export function layoutScene(items: readonly { id: string }[]) {
  const sorted = [...items].sort((a, b) => a.id.localeCompare(b.id));
  const cols = Math.max(3, Math.ceil(Math.sqrt(Math.max(items.length, 1) * 1.4)));
  const deskRows = Math.max(1, Math.ceil(items.length / cols));
  const rows = deskRows + 2; // lounge plus circulation for the moving dog
  const stations = sorted.map((s, i) => ({ id: s.id, ...iso((i % cols + .5) * 240, (Math.floor(i / cols) + .5) * 240) }));
  const amenities = (['pool', 'coffee', 'meeting'] as const).map((kind, i) => {
    const gridY = (deskRows + .5) * 240;
    return { kind, gridY, ...iso(((i + .5) * cols / 3) * 240, gridY) };
  });
  const floor = [iso(0, 0), iso(cols * 240, 0), iso(cols * 240, rows * 240), iso(0, rows * 240)];
  const bounds = { x: floor[3].x - 70, y: -230, width: floor[1].x - floor[3].x + 140, height: floor[2].y + 330 };
  return { stations, amenities, floor, bounds, cols, rows, deskRows };
}
