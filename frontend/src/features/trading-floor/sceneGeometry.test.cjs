const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require('typescript');
require.extensions['.ts'] = (m, f) => m._compile(ts.transpileModule(fs.readFileSync(f, 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText, f);
test('camera preserves zoom anchor, fits bounds and hit-tests transformed stations', () => {
  const g = require('./sceneGeometry.ts');
  const scene = g.layoutScene([{id:'a'}]);
  const camera = g.fitCamera(scene.bounds, 800, 550);
  const point = g.toScreen(scene.stations[0], camera);
  assert.equal(g.hitStation(point, scene.stations, camera), 'a');
  assert.equal(g.hitStation(g.toScreen({x:scene.stations[0].x,y:scene.stations[0].y+94},camera),scene.stations,camera),'a');
  assert.equal(g.hitStation({x:-999,y:-999}, scene.stations, camera), null);
  const zoom = g.zoomCamera(camera, point, 2);
  assert.deepEqual(g.toWorld(point, zoom), g.toWorld(point, camera));
  assert.ok(zoom.scale <= 2.5);
  assert.equal(g.money(0, 'USD'), 'US$ 0,00');
  assert.equal(g.money(null, 'USD'), '—');
});
test('layout assigns stable distinct stations and bounds enclose all targets', () => {
  const { layoutScene } = require('./sceneGeometry.ts');
  const ids = Array.from({length: 120}, (_, i) => ({ id: `s${i}` }));
  const a = layoutScene(ids), b = layoutScene([...ids].reverse());
  assert.equal(a.stations.length, 120);
  assert.deepEqual(a, b);
  assert.equal(new Set(a.stations.map(s => `${s.x},${s.y}`)).size, 120);
  for (const s of a.stations) { assert.ok(s.x >= a.bounds.x); assert.ok(s.y + 55 <= a.bounds.y + a.bounds.height); }
});
