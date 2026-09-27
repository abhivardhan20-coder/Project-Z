import test from 'node:test';
import assert from 'node:assert/strict';
import { WORLD_SAVE_KEY, newWorld, validateWorldSave, loadWorld, saveWorld } from '../src/game/world-save.mjs';
import { SAVE_KEY, newJourney, saveJourney } from '../src/game/save.mjs';
import { ExplorationSession, doorSweepsPlayer } from '../src/game/exploration.ts';

const memory = () => {
  const records=new Map();
  return {getItem:key=>records.get(key)??null,setItem:(key,value)=>records.set(key,value),removeItem:key=>records.delete(key)};
};
const clearSight={raycast:()=>null};
const standing={x:0,y:0,z:0};
const cache={id:'b:-2:3:1:loot:0',kind:'loot',position:{x:0,y:1.2,z:-1},label:'Search pantry',buildingId:'b:-2:3:1',buildingName:'Corner shop',loot:{water:2,food:1,bandage:1}};
const bed={id:'b:-2:3:1:bed',kind:'bed',position:{x:0,y:.6,z:1},label:'Sleep until morning',buildingId:'b:-2:3:1',buildingName:'Corner shop'};
const stable={position:{x:8500,y:2.3,z:-9200},grounded:true,crouched:false,stamina:.6,locomotion:'idle'};

test('world save retains its seed, distant coordinates, clock and stable unique exploration IDs',()=>{
  const storage=memory(),data=newWorld(0xffffffff);
  data.position={x:54321,y:-2.5,z:-9123};data.day=42;data.hour=23.75;
  data.looted=[cache.id];data.visited=[cache.buildingId];data.shelterId=cache.buildingId;
  data.inventory={water:17,food:12,bandage:4};
  assert.equal(saveWorld(storage,data),true);
  assert.deepEqual({...loadWorld(storage),savedAt:0},data);
});

test('world save rejects invalid versions, seeds, coordinates, inventories and duplicate or unsafe IDs',()=>{
  const mutations=[
    {version:1},{seed:-1},{seed:0x100000000},{seed:1.5},{position:{x:Infinity,y:1,z:0}},
    {position:{x:1e6+1,y:0,z:0}},{position:{x:0,y:-51,z:0}},{hour:24},{hour:NaN},{day:0},
    {crouched:'false'},{stamina:2},{inventory:{water:1,food:-1,bandage:0}},
    {looted:[cache.id,cache.id]},{visited:['<script>']},{shelterId:'../bad'},
    {looted:Array.from({length:10001},(_,i)=>`loot:${i}`)},
  ];
  for(const patch of mutations)assert.equal(validateWorldSave({...newWorld(),...patch}),null,JSON.stringify(patch).slice(0,120));
  const clean=validateWorldSave({...newWorld(),unexpected:'removed'});
  assert.equal('unexpected' in clean,false);
});

test('v1 saves migrate supplies into a safe v2 spawn and preserve the original save',()=>{
  const storage=memory(),old=newJourney();
  old.position={x:6,y:1,z:-45};old.inventory.water=2;old.inventory.bandage=1;
  assert.equal(saveJourney(storage,old),true);
  const raw=storage.getItem(SAVE_KEY),migrated=loadWorld(storage);
  assert.equal(migrated.version,2);
  assert.deepEqual(migrated.position,newWorld().position);
  assert.deepEqual(migrated.inventory,{water:2,food:0,bandage:1});
  assert.equal(storage.getItem(SAVE_KEY),raw);
  assert.equal(saveWorld(storage,migrated),true);
  assert.equal(storage.getItem(SAVE_KEY),raw);
});

test('malformed v2 storage and denied storage fail safely without reviving legacy progress',()=>{
  const storage=memory();saveJourney(storage,newJourney());storage.setItem(WORLD_SAVE_KEY,'broken json');
  assert.equal(loadWorld(storage),null);
  const denied={getItem(){throw Error('denied');},setItem(){throw Error('quota');}};
  assert.equal(loadWorld(denied),null);assert.equal(saveWorld(denied,newWorld()),false);
  const session=new ExplorationSession(denied);
  assert.equal(session.save(stable,0),false);assert.equal(session.saveStatus,'Saving unavailable');
});

test('looting is deterministic, cannot be repeated after chunk unload or after restoring a save',()=>{
  const storage=memory(),session=new ExplorationSession(storage);
  session.setTargets([cache]);
  assert.equal(session.interact(cache,standing,false,clearSight).changed,true);
  assert.deepEqual(session.data.inventory,{water:2,food:1,bandage:1});
  session.setTargets([]);session.setTargets([{...cache}]);
  assert.equal(session.nearby(standing,false,clearSight),null);
  session.save(stable,Math.PI);
  const restored=new ExplorationSession(storage);restored.setTargets([cache]);
  assert.equal(restored.interact(cache,standing,false,clearSight),null);
  assert.deepEqual(restored.data.looted,[cache.id]);
});

test('interactions require current proximity and clear sight and ignore caller-supplied loot contents',()=>{
  const session=new ExplorationSession(null);session.setTargets([cache]);
  assert.equal(session.interact(cache,{x:20,y:0,z:0},false,clearSight),null);
  assert.equal(session.interact(cache,standing,false,{raycast:()=>({toi:.2})}),null);
  const forged={...cache,loot:{water:800}};
  assert.equal(session.interact(forged,standing,false,clearSight).changed,true);
  assert.equal(session.data.inventory.water,2);
});

test('a full pack never destroys uncollected contents and consumables cannot be duplicated',()=>{
  const session=new ExplorationSession(null);session.setTargets([cache]);session.data.inventory.water=999;
  assert.equal(session.interact(cache,standing,false,clearSight).changed,false);
  assert.equal(session.data.looted.length,0);
  assert.equal(session.useItem('water',1).changed,false);assert.equal(session.data.inventory.water,999);
  assert.equal(session.useItem('water',.1).changed,true);assert.equal(session.data.inventory.water,998);
  session.useItem('water',.1);
  assert.equal(session.interact(cache,standing,false,clearSight).changed,true);
  assert.equal(session.data.inventory.water,999);
  assert.equal(session.useItem('food',.3).stamina,.8);
  assert.equal(session.useItem('food',.3).changed,false);
});

test('sleep blocks interaction, reaches the following 07:00 and records shelter without time drift',()=>{
  const session=new ExplorationSession(null);session.setTargets([bed]);session.data.day=3;session.data.hour=22.5;
  const result=session.interact(bed,standing,false,clearSight);
  assert.equal(result.rest,true);assert.equal(session.nearby(standing,false,clearSight),null);
  assert.equal(session.update(2),false);assert.equal(session.data.hour,22.5);
  assert.equal(session.update(1),true);
  assert.equal(session.data.day,4);assert.equal(session.data.hour,7);assert.equal(session.data.stamina,1);
  assert.equal(session.data.shelterId,bed.buildingId);assert.equal(session.restRemaining,0);
  assert.equal(session.update(60),false);assert.equal(session.data.hour,8);
  session.data.hour=3;session.interact(bed,standing,false,clearSight);session.update(3);
  assert.equal(session.data.day,4);assert.equal(session.data.hour,7);
});

test('world clock crosses midnight and does not advance on invalid or negative frame deltas',()=>{
  const session=new ExplorationSession(null);session.data.hour=23.5;
  session.update(60);assert.equal(session.data.day,2);assert.equal(session.data.hour,.5);
  session.update(NaN);session.update(-60);assert.equal(session.data.hour,.5);
});

test('saving in flight keeps safe footing while swimming positions and crouch persist',()=>{
  const storage=memory(),session=new ExplorationSession(storage);
  session.save(stable,1);
  session.save({...stable,position:{x:10,y:8,z:20},grounded:false,locomotion:'air'},2);
  assert.deepEqual(loadWorld(storage).position,stable.position);
  const swimming={...stable,position:{x:250,y:-1.2,z:720},grounded:false,locomotion:'swim',crouched:true};
  session.save(swimming,2);assert.deepEqual(loadWorld(storage).position,swimming.position);
  assert.equal(loadWorld(storage).crouched,true);
});

test('reset changes the world seed only when requested and immediately persists fresh progress',()=>{
  const storage=memory(),session=new ExplorationSession(storage);saveJourney(storage,newJourney());
  session.setTargets([cache]);session.interact(cache,standing,false,clearSight);session.save(stable,0);
  const originalSeed=session.data.seed;session.reset();
  assert.equal(session.data.seed,originalSeed);assert.equal(new ExplorationSession(storage).data.looted.length,0);
  session.reset(12345);assert.equal(new ExplorationSession(storage).data.seed,12345);
  assert.ok(storage.getItem(SAVE_KEY),'legacy save is left intact');
});

test('door state survives saves and legacy v2 saves initialize every door shut',()=>{
  const storage=memory(),data=newWorld();
  data.openedDoors=['b:0:0:0:door','b:-2:1:4:door'];
  assert.equal(saveWorld(storage,data),true);
  assert.deepEqual(loadWorld(storage).openedDoors,data.openedDoors);
  const old={...newWorld()};delete old.openedDoors;
  assert.deepEqual(validateWorldSave(old).openedDoors,[]);
  for(const openedDoors of [['unsafe/id'],['door','door'],null,Array(10001).fill('door')]) {
    assert.equal(validateWorldSave({...newWorld(),openedDoors}),null);
  }
});

test('door opening and closing require a clear swing and persistent state cannot be forged by the caller',()=>{
  const door={id:'b:0:0:0:door',kind:'door',position:{x:0,y:1.27,z:0},label:'Open door',
    buildingId:'b:0:0:0',buildingName:'House',door:{hinge:{x:-1,y:0,z:0},width:2,height:2.54,thickness:.085,closedRotation:0}};
  const storage=memory(),session=new ExplorationSession(storage);session.setTargets([door]);
  assert.equal(session.isDoorOpen(door.id),false);
  const outside={x:0,y:0,z:.7};
  const opened=session.interact({...door,door:{...door.door,width:0}},outside,false,clearSight);
  assert.deepEqual(opened.door,{id:door.id,open:true});
  door.position={x:-1,y:1.27,z:-1};
  assert.equal(session.nearby({x:0,y:0,z:-1},false,clearSight).label,'Close door');
  const blocked=session.interact(door,{x:0,y:0,z:-1},false,clearSight);
  assert.equal(blocked.changed,false);assert.match(blocked.message,/Step clear/);
  assert.equal(session.isDoorOpen(door.id),true);
  session.save(stable,0);
  assert.equal(new ExplorationSession(storage).isDoorOpen(door.id),true);
  const closed=session.interact(door,{x:-1.6,y:0,z:-1},false,clearSight);
  assert.deepEqual(closed.door,{id:door.id,open:false});
  assert.equal(session.data.openedDoors.length,0);
});

test('door sweep exclusion follows rotated hinges and the vertical player capsule',()=>{
  for(const rotation of [0,Math.PI/2,Math.PI,-Math.PI/2]) {
    const hinge={x:12,y:30,z:-7},door={hinge,width:2,height:2.54,thickness:.085,closedRotation:rotation};
    const local=(x,y,z)=>({x:hinge.x+Math.cos(rotation)*x+Math.sin(rotation)*z,y:hinge.y+y,
      z:hinge.z-Math.sin(rotation)*x+Math.cos(rotation)*z});
    assert.equal(doorSweepsPlayer(door,local(1,0,-1),false),true);
    assert.equal(doorSweepsPlayer(door,local(1,0,.6),false),false);
    assert.equal(doorSweepsPlayer(door,local(-.6,0,-1),false),false);
    assert.equal(doorSweepsPlayer(door,local(1,4,-1),false),false);
  }
});
