require('./register-typescript.cjs');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { layoutScene, traderPose } = require('../src/features/trading-floor/sceneGeometry.ts');

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
