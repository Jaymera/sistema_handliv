require('./register-typescript.cjs');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { layoutScene, traderPose, avatarVisible, hitAgent, fitCamera, toScreen } = require('../src/features/trading-floor/sceneGeometry.ts');

test('three social areas fit on a dedicated row without overlapping magic desks', () => {
  for (const count of [0, 1, 20, 150]) {
    const layout = layoutScene(Array.from({ length: count }, (_, i) => ({ id: String(i) })));
    assert.deepEqual(layout.amenities.map(a => a.kind), ['pool', 'coffee', 'meeting']);
    assert.equal(new Set(layout.amenities.map(a => `${a.x},${a.y}`)).size, 3);
    assert.ok(layout.amenities.every(a => a.gridY > layout.deskRows * 240));
  }
});

test('idle trader walks and returns to desk; active and reduced-motion trader stay seated', () => {
  const first = traderPose('AGUARDANDO', 0, 'magic-10', false);
  const samples = Array.from({length: 100}, (_, i) => traderPose('AGUARDANDO', i * 200, 'magic-10', false));
  assert.ok(samples.some(p => p.walking && p.x !== first.x));
  assert.ok(samples.some(p => !p.walking));
  for (const status of ['OPERANDO', 'POSIÇÃO ABERTA', 'OFFLINE']) {
    assert.deepEqual(traderPose(status, 5000, 'magic-10', false), traderPose(status, 0, 'magic-10', false));
  }
  assert.deepEqual(traderPose('AGUARDANDO', 5000, 'magic-10', true), traderPose('AGUARDANDO', 0, 'magic-10', true));
});

test('an idle agent takes a coherent route from its own desk to a social area, pauses and returns', () => {
  const layout = layoutScene(Array.from({ length: 20 }, (_, i) => ({ id: `magic-${i}` })));
  const desk = layout.stations[10];
  const samples = Array.from({ length: 360 }, (_, i) => traderPose('AGUARDANDO', i * 500, desk.id, false, desk, layout));
  assert.ok(samples.some(p => p.activity === 'coffee' || p.activity === 'meeting' || p.activity === 'pool'));
  assert.ok(samples.some(p => p.walking && p.x !== 0 && p.y !== 0));
  assert.ok(samples.some(p => p.activity === 'desk' && !p.walking && p.x === 0 && p.y === 0));
  assert.ok(samples.every(p => Number.isFinite(p.x) && Number.isFinite(p.y) && Number.isFinite(p.stride)));
  assert.ok(samples.every(p => p.facing === 'left' || p.facing === 'right'));
  assert.ok(samples.some(p => p.activity !== 'desk' && !p.walking), 'social stop should be visible');
  assert.deepEqual(traderPose('AGUARDANDO', 25000, desk.id, true, desk, layout), traderPose('AGUARDANDO', 0, desk.id, true, desk, layout));
});

test('150 independently routed agents stay finite and all three destinations are reachable', () => {
  const layout = layoutScene(Array.from({ length: 150 }, (_, i) => ({ id: `magic-${i}` })));
  const destinations = new Set();
  for (const desk of layout.stations) {
    for (let t = 0; t <= 180000; t += 3000) {
      const pose = traderPose('AGUARDANDO', t, desk.id, false, desk, layout);
      if (pose.activity !== 'desk' && pose.activity !== 'walking') destinations.add(pose.activity);
      assert.ok(Number.isFinite(pose.x) && Number.isFinite(pose.y));
      assert.ok(Math.abs(desk.x + pose.x) < layout.bounds.width + Math.abs(layout.bounds.x));
    }
  }
  assert.deepEqual([...destinations].sort(), ['coffee', 'meeting', 'pool']);
});

test('walking agent remains selectable at its current location, offline one never becomes a target', () => {
  const layout = layoutScene([{id:'magic-10'}]);
  const desk = layout.stations[0], camera = fitCamera(layout.bounds, 1100, 550);
  const stations = [{id:desk.id,status:'AGUARDANDO'}];
  let time = 0, pose;
  for (; time < 180000; time += 300) {
    pose = traderPose('AGUARDANDO', time, desk.id, false, desk, layout);
    if (pose.activity === 'coffee' || pose.activity === 'meeting' || pose.activity === 'pool') break;
  }
  assert.ok(pose && pose.activity !== 'desk');
  const screen = toScreen({x:desk.x+pose.x,y:desk.y+pose.y-20},camera);
  assert.equal(hitAgent(screen, stations, layout, camera, time, false),desk.id);
  assert.equal(hitAgent(screen, [{id:desk.id,status:'OFFLINE'}], layout, camera, time, false),null);
});

test('agents at open positions remain at work and offline desks have no agent', () => {
  assert.equal(avatarVisible('OFFLINE'), false);
  assert.equal(avatarVisible('POSIÇÃO ABERTA'), true);
  assert.equal(avatarVisible('AGUARDANDO'), true);
  for (const status of ['OPERANDO', 'POSIÇÃO ABERTA', 'OFFLINE']) {
    assert.equal(traderPose(status, 20000, 'magic-10', false).activity, 'desk');
  }
});
