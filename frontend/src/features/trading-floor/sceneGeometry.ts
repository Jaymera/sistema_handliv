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
/** Decorative motion is deterministic and never changes a telemetry status. */
export function traderPose(status: string, now: number, id: string, reducedMotion: boolean) {
  if (status !== 'AGUARDANDO' || reducedMotion) return { x: 0, y: 0, walking: false, stride: 0 };
  let seed = 0;
  for (let i = 0; i < id.length; i++) seed = (seed * 31 + id.charCodeAt(i)) | 0;
  const cycle = ((now + (Math.abs(seed) % 7000)) % 12000) / 12000;
  // Leave the chair, walk along the aisle, pause, then return to the station.
  if (cycle < .16 || cycle > .86) return { x: 0, y: 0, walking: false, stride: 0 };
  const progress = cycle < .40 ? (cycle - .16) / .24 : cycle < .63 ? 1 : 1 - (cycle - .63) / .23;
  const distance = Math.max(0, Math.min(1, progress));
  return { x: 88 * distance, y: 56 * distance, walking: true, stride: Math.sin(now / 155) * 5 };
}
export function layoutScene(items: readonly { id: string }[]) {
  const sorted = [...items].sort((a, b) => a.id.localeCompare(b.id));
  const cols = Math.max(3, Math.ceil(Math.sqrt(Math.max(items.length, 10) * 1.4)));
  const deskRows = Math.max(2, Math.ceil(items.length / cols));
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
