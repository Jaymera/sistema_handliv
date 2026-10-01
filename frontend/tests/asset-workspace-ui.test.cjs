const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
test('asset workspace exposes section navigation, selectable observed windows and factor evidence', () => {
  const source = fs.readFileSync(path.join(__dirname,'../src/features/asset-terminal/AssetTerminal.tsx'),'utf8');
  assert.match(source, /accessibilityRole="tab"/);
  assert.match(source, /windowEvidence\(data.price_history/);
  assert.match(source, /factorEvidence\(data\)/);
  assert.match(source, /Confiança do motor, não probabilidade/);
  assert.match(source, /Provedor não informado/);
  assert.doesNotMatch(source, /cruzamento alcista|cruzamento baixista/);
});
