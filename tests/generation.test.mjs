import test from 'node:test';
import assert from 'node:assert/strict';
import {planChunk,chunkAt,terrainHeight,biomeAt} from '../src/world/layout.mjs';
test('world generation is coordinate deterministic, independent of visit order',()=>{
  const first=planChunk(7307,13,-9);for(let i=0;i<20;i++)planChunk(7307,i,-i);
  assert.deepEqual(planChunk(7307,13,-9),first);
  assert.notDeepEqual(planChunk(1234,13,-9),first);
});
test('negative chunk coordinates join roads without seams',()=>{
  assert.deepEqual(chunkAt(-.01,-96.01),{cx:-1,cz:-2});
  for(let x=-4;x<=4;x++)for(let z=-4;z<=4;z++) {
    const a=planChunk(7307,x,z),b=planChunk(7307,x+1,z);
    for(let offset=0;offset<=96;offset+=8)assert.equal(terrainHeight(a,(x+1)*96,z*96+offset),terrainHeight(b,(x+1)*96,z*96+offset));
  }
});
test('starting district contains accessible shelters and a nearby real lake basin',()=>{
  const start=planChunk(7307,0,0);assert.ok(start.buildings.some(b=>b.enterable&&b.shelter));
  const lake=planChunk(7307,0,-1);assert.equal(lake.biome,'lake');
  assert.ok(terrainHeight(lake,lake.lake.x,lake.lake.z)<lake.lake.level-2);
  const kinds=new Set();for(let x=-12;x<12;x++)for(let z=-12;z<12;z++)kinds.add(biomeAt(7307,x,z));
  assert.deepEqual(kinds,new Set(['urban','residential','park','lake','forest','hills','mountain']));
});
