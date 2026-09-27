import test from 'node:test';
import assert from 'node:assert/strict';
import {newJourney,validateSave} from '../src/game/save.mjs';
import {applyInteraction,useWater} from '../src/game/rules.mjs';

test('shelter journey requires supplies and key, consumes its battery once',()=>{
  const data=newJourney();
  assert.equal(applyInteraction(data,'shelterDoor').changed,false);
  assert.equal(applyInteraction(data,'power').changed,false);
  applyInteraction(data,'serviceCache');applyInteraction(data,'shelterDoor');
  assert.equal(applyInteraction(data,'power').changed,false);
  applyInteraction(data,'fieldKit');
  assert.equal(applyInteraction(data,'power').changed,true);
  assert.equal(data.inventory.battery,0);
  assert.equal(applyInteraction(data,'power').changed,false);
  assert.equal(applyInteraction(data,'rest').rest,true);
  assert.ok(validateSave(data));
});
test('repeated interaction cannot duplicate loot, including after save restoration',()=>{
  let data=newJourney();
  applyInteraction(data,'fieldKit');applyInteraction(data,'serviceCache');
  data=validateSave(JSON.parse(JSON.stringify(data)));
  for(let i=0;i<20;i++){applyInteraction(data,'fieldKit');applyInteraction(data,'serviceCache');}
  assert.deepEqual(data.inventory,{water:2,bandage:1,battery:1,key:1});
});
test('water use is bounded and does not consume a bottle at full stamina',()=>{
  const data=newJourney();applyInteraction(data,'fieldKit');
  assert.equal(useWater(data,1).changed,false);assert.equal(data.inventory.water,2);
  assert.equal(useWater(data,.7).stamina,1);assert.equal(data.inventory.water,1);
  assert.equal(useWater(data,.2).stamina,.65);assert.equal(data.inventory.water,0);
  assert.equal(useWater(data,.2).changed,false);
});
