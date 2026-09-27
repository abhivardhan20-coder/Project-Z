import test from 'node:test';
import assert from 'node:assert/strict';
import { registerHooks } from 'node:module';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import ts from 'typescript';
import { planChunk } from '../src/world/layout.mjs';
import { ExplorationSession } from '../src/game/exploration.ts';

// Test the same procedural geometry and physics as the browser. Canvas painting is
// irrelevant to collision, so only its drawing surface is replaced in this test.
const context=new Proxy({}, {get(target,key) {
  if(key in target)return target[key];
  if(key==='createRadialGradient'||key==='createLinearGradient')return ()=>({addColorStop(){}});
  if(key==='measureText')return text=>({width:text.length*8});
  return ()=>{};
}});
globalThis.document={createElement(){return {width:1,height:1,getContext:()=>context};}};
const sourceRoot=new URL('../src/',import.meta.url).href;
registerHooks({
  resolve(specifier,context,next) {
    if(context.parentURL?.startsWith(sourceRoot)&&specifier.startsWith('.')&&!/\.[a-z]+$/i.test(specifier))return next(`${specifier}.ts`,context);
    return next(specifier,context);
  },
  load(url,context,next) {
    if(url.startsWith(sourceRoot)&&url.endsWith('.ts'))return {format:'module',shortCircuit:true,
      source:ts.transpileModule(readFileSync(fileURLToPath(url),'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ESNext}}).outputText};
    return next(url,context);
  },
});
const {createChunk}=await import('../src/world/chunk.ts');
const {createCollisionWorld}=await import('../src/world/collision.ts');
const {PlayerMotor}=await import('../src/player/motor.ts');
const {WorldStreamer}=await import('../src/world/streamer.ts');
const idle={moveX:0,moveZ:0,sprint:false,walk:false,crouch:false,jump:false};
const settle=motor=>{for(let i=0;i<30;i++)motor.step(1/60,idle);};
function walkTo(motor,x,z,maxTicks=4000) {
  for(let i=0;i<maxTicks;i++) {
    const dx=x-motor.state.position.x,dz=z-motor.state.position.z,distance=Math.hypot(dx,dz);
    if(distance<.13){settle(motor);return;}
    motor.step(1/60,{...idle,moveX:dx/distance,moveZ:dz/distance});
  }
  assert.fail(`Traversal stalled at ${JSON.stringify(motor.state.position)} while walking to (${x},${z})`);
}
function local(plan,x,z) {
  return {x:plan.x+Math.cos(plan.rotation)*x+Math.sin(plan.rotation)*z,
    z:plan.z-Math.sin(plan.rotation)*x+Math.cos(plan.rotation)*z};
}
const walkLocal=(motor,plan,x,z)=>{const p=local(plan,x,z);walkTo(motor,p.x,p.z);};
async function fixture(cells) {
  const collision=await createCollisionWorld([],[],false),chunks=[];
  for(const [cx,cz]of cells) {
    const plan=planChunk(7307,cx,cz),visual=createChunk(plan);chunks.push({plan,visual});
    collision.addChunk(plan.key,visual.boxes,visual.terrain);
  }
  const motor=new PlayerMotor(collision,{x:0,y:.1,z:22});settle(motor);
  return {collision,motor,chunks,dispose(){motor.dispose();for(const {visual}of chunks)visual.dispose();collision.dispose();}};
}

test('generated roads allow walking north, turning east at a junction and crossing into another district',async()=>{
  const f=await fixture([[-1,-1],[0,-1],[1,-1],[-1,0],[0,0],[1,0]]);
  try {
    walkTo(f.motor,0,0);walkTo(f.motor,110,0);
    assert.ok(f.motor.state.position.x>109,'the old street boundary no longer blocks lateral exploration');
    assert.ok(Math.abs(f.motor.state.position.z)<.3);
    assert.equal(f.motor.state.grounded,true);
    assert.ok(f.motor.state.position.y>=0&&f.motor.state.position.y<.2,'adjacent terrain edges meet without a drop');
  } finally {f.dispose();}
});

test('starter shop has a reachable doorway, pantry loot and a usable bed behind physical walls',async()=>{
  const f=await fixture([[-1,0],[0,0]]);
  try {
    const {plan,visual}=f.chunks.find(({plan})=>plan.key==='0:0'),shop=plan.buildings[0];
    const session=new ExplorationSession(null);session.setTargets(visual.targets);
    const front=shop.depth/2,back=-shop.depth/2,shelfX=-shop.width/2+.6,shelfZ=front-Math.min(shop.depth*.36,3);
    walkTo(f.motor,0,shop.z);walkLocal(f.motor,shop,0,front+1.2);
    const entrance=session.nearby(f.motor.state.position,false,f.collision);
    assert.equal(entrance?.id,`${shop.id}:door`,'enterable buildings begin with a closed usable door');
    const opened=session.interact(entrance,f.motor.state.position,false,f.collision);
    assert.deepEqual(opened.door,{id:entrance.id,open:true});
    const pose=visual.doors.get(entrance.id).setOpen(true);
    f.collision.setObstaclePose(pose.id,pose.center,pose.rotationY);
    walkLocal(f.motor,shop,0,front-3);
    assert.ok(f.motor.state.position.y>.17,'the motor steps onto the actual interior floor');
    walkLocal(f.motor,shop,shelfX+1.5,shelfZ);
    const pantry=session.nearby(f.motor.state.position,false,f.collision);
    assert.equal(pantry?.id,`${shop.id}:loot:0`,'the pantry is visible from its clear aisle');
    assert.equal(session.interact(pantry,f.motor.state.position,false,f.collision).changed,true);
    assert.ok(session.data.inventory.water>0&&session.data.inventory.food>0);
    assert.equal(session.nearby(f.motor.state.position,false,f.collision),null,'the same shelf cannot be looted twice');
    walkLocal(f.motor,shop,0,shelfZ);walkLocal(f.motor,shop,0,back+1.65);walkLocal(f.motor,shop,-shop.width/2+2.55,back+1.65);
    const bed=session.nearby(f.motor.state.position,false,f.collision);
    assert.equal(bed?.id,`${shop.id}:bed`,'the bed is accessible from inside the room');
    session.data.hour=22;
    assert.equal(session.interact(bed,f.motor.state.position,false,f.collision).rest,true);
    assert.equal(session.update(3),true);assert.equal(session.data.hour,7);assert.equal(session.data.shelterId,shop.id);
    const outside=local(shop,-shop.width/2-1,back+1.65);
    assert.equal(session.nearby({...outside,y:0},false,f.collision),null,'a closed exterior wall cannot be used to sleep through');
  } finally {f.dispose();}
});

test('streaming unloads meshes and collision together, preserves loot state and keeps chunk count bounded',async t=>{
  const collision=await createCollisionWorld([],[],false),streamer=new WorldStreamer(7307,collision);
  try {
    const spawn={x:0,y:.1,z:22};await streamer.prime(spawn);
    assert.equal(streamer.loaded.size,25);assert.equal(collision.chunkCount,25);
    const initialColliders=collision.world.colliders.len();
    const initialTargets=streamer.targets.length;
    let meshes=0,triangles=0;
    streamer.group.traverse(object=>{if(object.isMesh){meshes++;triangles+=(object.geometry.index?.count??object.geometry.attributes.position.count)/3*(object.isInstancedMesh?object.count:1);}});
    t.diagnostic(`Initial 25 chunks: ${initialColliders} static colliders, ${initialTargets} interaction targets, ${meshes} meshes, ${Math.round(triangles)} triangles before camera culling.`);
    const target=streamer.targets.find(target=>target.id==='b:0:0:0:loot:0');assert.ok(target);
    const searched=[target.id];streamer.update(spawn,0,searched);
    assert.equal(streamer.loaded.get('0:0').visual.lootVisuals.get(target.id).visible,false);
    const doorId='b:0:0:0:door';streamer.setDoors([doorId]);
    assert.equal(streamer.loaded.get('0:0').visual.doors.get(doorId).target.label,'Close door');
    assert.ok(collision.raycast({x:0,y:20,z:22},{x:0,y:-1,z:0},30));
    await streamer.prime({x:960,y:.1,z:22});
    assert.equal(streamer.loaded.size,25);assert.equal(collision.chunkCount,25);
    assert.equal(streamer.targets.length,[...streamer.loaded.values()].reduce((sum,chunk)=>sum+chunk.visual.targets.length,0),'interaction registry contains only loaded targets');
    assert.equal(streamer.loaded.has('0:0'),false);
    assert.ok(!collision.raycast({x:0,y:20,z:22},{x:0,y:-1,z:0},30),'unloaded ground leaves no ghost collider');
    assert.equal(streamer.targets.some(candidate=>candidate.id===target.id),false,'unloaded buildings leave no ghost interaction');
    await streamer.prime(spawn);
    assert.equal(streamer.loaded.size,25);assert.equal(collision.chunkCount,25);
    assert.equal(streamer.targets.length,initialTargets,'returning to the same region does not accumulate interaction targets');
    assert.equal(collision.world.colliders.len(),initialColliders,'returning to the same region does not accumulate colliders');
    assert.equal(streamer.loaded.get('0:0').visual.lootVisuals.get(target.id).visible,false,'unloading never replenishes searched contents');
    const restored=streamer.loaded.get('0:0');
    assert.equal(restored.visual.doors.get(doorId).target.label,'Close door','door pose persists when revisiting a chunk');
    const shop=restored.plan.buildings[0],outside=local(shop,0,shop.depth/2+.5);
    const rayOrigin={...outside,y:(shop.y??0)+1.4},rayDirection={x:-Math.sin(shop.rotation),y:0,z:-Math.cos(shop.rotation)};
    const restoredHit=collision.raycast(rayOrigin,rayDirection,1);
    const hitDetail=restoredHit?JSON.stringify({toi:restoredHit.toi,center:restoredHit.collider.translation(),rotation:restoredHit.collider.rotation()}):'';
    assert.ok(!restoredHit,`restored open door has matching clear collision ${hitDetail}`);
    streamer.setDoors([]);
    assert.ok(collision.raycast(rayOrigin,rayDirection,1),'closing the door restores its collision immediately');
    assert.equal(new Set(streamer.targets.map(target=>target.id)).size,streamer.targets.length);
    streamer.dispose();assert.equal(collision.chunkCount,0);assert.equal(streamer.group.children.length,0);
  } finally {streamer.dispose();collision.dispose();}
});
