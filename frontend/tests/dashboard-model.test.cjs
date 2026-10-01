require('./register-typescript.cjs');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { dashboardOverview } = require('../src/features/dashboard/model.ts');

test('unknown watchlist and catalogue remain unavailable rather than zero', () => {
  const result = dashboardOverview(undefined, undefined);
  assert.equal(result.watchCount, null);
  assert.equal(result.catalogueTotal, null);
  assert.equal(result.loadedCount, null);
  assert.equal(result.marketCount, null);
  assert.deepEqual(result.markets, []);
});

test('catalogue total is distinct from sampled market coverage', () => {
  const result = dashboardOverview([], { total: 421, items: [
    {symbol:'A',name:'Alpha',market:'B3'}, {symbol:'B',name:'Beta',market:'B3'},
    {symbol:'C',name:'Gamma',market:'US'}, {symbol:'D',name:'Delta',market:''},
  ] });
  assert.equal(result.watchCount, 0);
  assert.equal(result.catalogueTotal, 421);
  assert.equal(result.loadedCount, 4);
  assert.equal(result.marketCount, 2);
  assert.deepEqual(result.markets, [{market:'B3',count:2},{market:'US',count:1}]);
});
