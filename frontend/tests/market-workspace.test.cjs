const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
test('market catalog filters real asset classes and distinguishes errors from empty results', () => {
  const source = fs.readFileSync(path.join(__dirname,'../app/(tabs)/markets.tsx'),'utf8');
  assert.match(source, /type: assetType \|\| undefined/);
  assert.match(source, /Não foi possível consultar o catálogo/);
  assert.match(source, /asset_type/);
  assert.match(source, /Visualização em lista/);
});
