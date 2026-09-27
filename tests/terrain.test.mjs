import test from 'node:test';
import assert from 'node:assert/strict';
import {planChunk,terrainHeight,regionalHeight,ruralTrailX,ruralTrailZ,terrainNoise} from '../src/world/layout.mjs';

test('regional terrain stays reproducible and preserves the original starting city elevations',()=>{
  for(const [x,z]of [[-192,-192],[288,288],[0,0],[96,-96],[288,0]])assert.equal(regionalHeight(7307,x,z),0);
  const city=planChunk(7307,0,0);assert.equal(city.rural,false);
  for(const building of city.buildings)assert.equal(terrainHeight(city,building.x,building.z),0);
  const far=planChunk(7307,10,-4);
  assert.deepEqual(planChunk(7307,10,-4),far);
  assert.equal(far.rural,true);
  assert.notEqual(regionalHeight(7307,1400,-620),regionalHeight(3711,1400,-620));
  assert.equal(terrainNoise(7307,-123,34,90),terrainNoise(7307,-123,34,90));
});

test('both terrain axes join exactly across city, forest, hill and mountain chunk boundaries',()=>{
  for(const seed of [7307,0,123456])for(const [cx,cz]of [[-3,-2],[2,1],[3,-4],[8,0],[11,-9],[-12,7]]) {
    const current=planChunk(seed,cx,cz),east=planChunk(seed,cx+1,cz),south=planChunk(seed,cx,cz+1);
    for(let offset=0;offset<=96;offset+=2) {
      const x=(cx+1)*96,z=cz*96+offset;
      assert.equal(terrainHeight(current,x,z),terrainHeight(east,x,z),`east seam ${seed}/${cx}:${cz}/${offset}`);
      assert.equal(terrainHeight(current,cx*96+offset,(cz+1)*96),terrainHeight(south,cx*96+offset,(cz+1)*96),`south seam ${seed}/${cx}:${cz}/${offset}`);
    }
  }
});

test('outskirts rise gradually into connected substantial mountain ridges',()=>{
  let min=Infinity,max=-Infinity,maxSlope=0;
  for(let x=-1600;x<=1600;x+=16)for(let z=-1600;z<=1600;z+=16) {
    const y=regionalHeight(7307,x,z),dx=(regionalHeight(7307,x+1,z)-regionalHeight(7307,x-1,z))/2;
    const dz=(regionalHeight(7307,x,z+1)-regionalHeight(7307,x,z-1))/2;
    assert.ok(Number.isFinite(y));min=Math.min(min,y);max=Math.max(max,y);maxSlope=Math.max(maxSlope,Math.hypot(dx,dz));
  }
  assert.equal(min,0);assert.ok(max>150&&max<400,`mountain elevation ${max}`);
  assert.ok(maxSlope<1,`regional terrain must remain traversable at its steepest sampled slope: ${maxSlope}`);
  // A former 96m tile edge must continue the surrounding ridge instead of returning to zero.
  const plan=planChunk(7307,12,1),left=terrainHeight(plan,12*96,144),right=terrainHeight(plan,13*96,144);
  assert.ok(left>60&&right>60);
});

test('country routes and graded foundations follow the same physical terrain sampler',()=>{
  for(let coordinate=300;coordinate<1600;coordinate+=8) {
    assert.ok(Math.abs(ruralTrailX(7307,coordinate))<20);
    assert.equal(ruralTrailX(7307,coordinate),ruralTrailZ(7307,coordinate));
    const dz=ruralTrailZ(7307,coordinate+1)-ruralTrailZ(7307,coordinate);
    assert.ok(Math.abs(dz)<.3,'country lanes have smooth bends');
  }
  let checked=0;
  for(let x=3;x<=12;x++)for(let z=-3;z<=3;z++) {
    const plan=planChunk(7307,x,z);
    for(const building of plan.buildings) {
      assert.ok(Number.isFinite(building.y));
      assert.equal(terrainHeight(plan,building.x,building.z),building.y);
      for(const dx of [-building.width/2,building.width/2])for(const dz of [-building.depth/2,building.depth/2]) {
        const wx=building.x+Math.cos(building.rotation)*dx+Math.sin(building.rotation)*dz;
        const wz=building.z-Math.sin(building.rotation)*dx+Math.cos(building.rotation)*dz;
        assert.equal(terrainHeight(plan,wx,wz),building.y,'the entire foundation sits on its physical platform');
      }
      checked++;
    }
  }
  assert.ok(checked>5);
});
