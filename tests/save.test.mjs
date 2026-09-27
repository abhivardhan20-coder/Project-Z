import test from 'node:test';
import assert from 'node:assert/strict';
import {newJourney,validateSave,loadJourney,saveJourney,SAVE_KEY} from '../src/game/save.mjs';

test('save roundtrip preserves collected supplies and permanently opened shelter',()=>{
  const state=newJourney();state.flags.fieldKit=true;state.flags.serviceCache=true;state.flags.shelterOpen=true;
  state.inventory.water=2;state.inventory.battery=1;state.inventory.key=1;state.position={x:5,y:.23,z:-54};
  const entries=new Map();const storage={getItem:key=>entries.get(key),setItem:(key,value)=>entries.set(key,value)};
  assert.equal(saveJourney(storage,state),true);
  assert.equal(loadJourney(storage).inventory.water,2);
  assert.equal(loadJourney(storage).flags.shelterOpen,true);
  assert.deepEqual(loadJourney(storage).position,state.position);
});
test('corrupt, unsupported, non-finite and out-of-world saves are rejected',()=>{
  assert.equal(loadJourney({getItem:()=>'{broken'}),null);
  for(const patch of [{version:2},{position:{x:999,y:0,z:0}},{position:{x:0,y:NaN,z:0}},{stamina:Infinity},{inventory:{water:-1}}]) assert.equal(validateSave({...newJourney(),...patch}),null);
  const inconsistent=newJourney();inconsistent.flags.rested=true;assert.equal(validateSave(inconsistent),null);
  const missingKey=newJourney();missingKey.flags.serviceCache=true;assert.equal(validateSave(missingKey),null);
  const missingBattery=newJourney();missingBattery.flags.fieldKit=true;assert.equal(validateSave(missingBattery),null);
});
test('crouched stance and boundary positions survive storage validation',()=>{
  const state=newJourney();state.crouched=true;state.position={x:11.15,y:.025,z:-154.6};
  assert.equal(validateSave(state).crouched,true);assert.deepEqual(validateSave(state).position,state.position);
  assert.equal(validateSave({...state,crouched:'false'}),null);
});
test('unavailable storage fails gracefully without corrupting the current session',()=>{
  const state=newJourney();const storage={getItem:()=>{throw Error('denied');},setItem:()=>{throw Error('quota');}};
  assert.equal(loadJourney(storage),null);assert.equal(saveJourney(storage,state),false);assert.equal(state.stamina,1);
});
test('validation removes unexpected properties and protects item counts',()=>{
  const state=newJourney();state.inventory.water=500;assert.equal(validateSave(state),null);
  const result=validateSave({...newJourney(),injected:'untrusted'});assert.equal('injected' in result,false);assert.equal(SAVE_KEY,'afterfall.journey.v1');
});
