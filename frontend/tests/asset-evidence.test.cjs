require('./register-typescript.cjs');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { analysisEvidence } = require('../src/features/asset-terminal/evidence.ts');

test('label categories are counted independently of numeric measurements and engine coverage', () => {
  const result = analysisEvidence({news_items:[
    {sentiment_label:'positive',sentiment_score:null},
    {sentiment_label:'negative'},
    {sentiment_label:'neutral',sentiment_score:null},
    {sentiment_label:'positive',sentiment_score:0.8},
    {sentiment_label:null,sentiment_score:0},
    {sentiment_label:null,sentiment_score:null},
    {sentiment_label:'unknown',sentiment_score:NaN},
  ]});
  assert.deepEqual(result.sentimentCategories,{positive:2,negative:1,neutral:1,unclassified:3});
  assert.equal(result.measuredNews,2);
  assert.equal(result.scoredNews,null, 'labels and displayed scores do not infer engine sample count');
  assert.equal(analysisEvidence({sentiment_sample_count:0}).scoredNews,0);
  assert.deepEqual(analysisEvidence({}).sentimentCategories,{positive:0,negative:0,neutral:0,unclassified:0});
  const panel = fs.readFileSync(path.join(__dirname,'../src/features/asset-terminal/AssetTerminal.tsx'),'utf8');
  for (const label of ['positive','negative','neutral','unclassified']) {
    assert.ok(panel.includes(`evidence.sentimentCategories.${label}`), `UI exposes ${label} independently`);
  }
});
