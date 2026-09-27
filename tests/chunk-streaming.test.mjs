import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { registerHooks } from 'node:module';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import ts from 'typescript';
import { BufferGeometry } from 'three/webgpu';
import { planChunk } from '../src/world/layout.mjs';

// Rendering is unnecessary here; the real geometry, ownership and async lifecycle
// are exercised while the canvas text/texture drawing surface is replaced.
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
const {createChunk,createChunkAsync}=await import('../src/world/chunk.ts');
const {WorldStreamer}=await import('../src/world/streamer.ts');
const {createCollisionWorld}=await import('../src/world/collision.ts');

function geometrySignature(visual) {
  const hash=createHash('sha256');
  const bytes=array=>hash.update(Buffer.from(array.buffer,array.byteOffset,array.byteLength));
  visual.group.traverse(object=>{
    if(!object.geometry)return;
    hash.update(object.name);hash.update(JSON.stringify(object.matrix.elements));
    for(const key of Object.keys(object.geometry.attributes).sort()) {
      hash.update(key);bytes(object.geometry.attributes[key].array);
    }
    if(object.geometry.index)bytes(object.geometry.index.array);
    if(object.instanceMatrix)bytes(object.instanceMatrix.array);
  });
  hash.update(JSON.stringify(visual.boxes));hash.update(JSON.stringify(visual.targets));
  return hash.digest('hex');
}

test('cooperative generation yields to the host and preserves exact generated geometry',async()=>{
  let yields=0;
  const previousScheduler=globalThis.scheduler;
  globalThis.scheduler={yield:()=>new Promise(resolve=>{yields++;setImmediate(resolve);})};
  try {
    for(const [cx,cz]of[[0,0],[0,-1],[8,0]]) {
      const plan=planChunk(7307,cx,cz),sync=createChunk(plan),async=await createChunkAsync(plan);
      try {
        assert.ok(async);
        assert.equal(geometrySignature(async),geometrySignature(sync),`generation changed for ${plan.key}`);
      }finally{sync.dispose();async?.dispose();}
    }
    assert.ok(yields>3,'generation must actually give rendering/input work a turn');
  }finally{
    if(previousScheduler===undefined)delete globalThis.scheduler;else globalThis.scheduler=previousScheduler;
  }
});

test('cancelling generation disposes all partial geometry and permits subsequent builds',async()=>{
  const plan=planChunk(7307,0,0);
  let totalStages=0;
  const warm=await createChunkAsync(plan,()=>{totalStages++;return false;});warm.dispose();
  const created=new Set(),disposed=new Set();
  const setAttribute=BufferGeometry.prototype.setAttribute,dispose=BufferGeometry.prototype.dispose;
  BufferGeometry.prototype.setAttribute=function(...args){created.add(this);return setAttribute.apply(this,args);};
  BufferGeometry.prototype.dispose=function(){disposed.add(this);return dispose.call(this);};
  try {
    for(const threshold of [Math.floor(totalStages*.35),Math.floor(totalStages*.9)]) {
      created.clear();disposed.clear();let checks=0;
      const result=await createChunkAsync(plan,()=>++checks>threshold);
      assert.equal(result,null);
      assert.ok(created.size>10,'cancellation must happen after geometry has been allocated');
      const leaked=[...created].filter(geometry=>!disposed.has(geometry));
      assert.equal(leaked.length,0,`cancelled generation retained ${leaked.length} geometry objects`);
    }
  }finally{
    BufferGeometry.prototype.setAttribute=setAttribute;BufferGeometry.prototype.dispose=dispose;
  }
  const next=await createChunkAsync(plan);
  assert.ok(next?.targets.length);next.dispose();
  assert.equal(await createChunkAsync(plan,()=>true),null,'immediate cancellation must allocate nothing');
});

test('runtime streaming cancels obsolete generation and cannot commit after disposal',async()=>{
  const collision=await createCollisionWorld([],[],false);
  const streamer=new WorldStreamer(7307,collision,undefined,true);
  const waitFor=async predicate=>{
    const deadline=performance.now()+10000;
    while(!predicate()) {
      assert.ok(performance.now()<deadline,'streaming did not settle before the deadline');
      await new Promise(resolve=>setTimeout(resolve,0));
    }
  };
  try {
    const start={x:0,y:.1,z:22},far={x:960,y:0,z:22};
    streamer.update(start,.1,[]);
    streamer.update(far,0,[]);
    await waitFor(()=>streamer.pending===25);
    assert.equal(streamer.loaded.has('0:0'),false);
    assert.equal(collision.chunkCount,0,'an obsolete async result must not create invisible colliders');
    assert.equal(streamer.targets.length,0);
    streamer.update(far,.1,[]);
    await waitFor(()=>streamer.loaded.size===1||streamer.error!==null);
    assert.equal(streamer.error,null);
    assert.equal(streamer.loaded.has('10:0'),true);
    assert.equal(collision.chunkCount,1);
    streamer.update(far,.1,[]);
    streamer.dispose();
    await waitFor(()=>streamer.pending===0);
    assert.equal(streamer.loaded.size,0);
    assert.equal(collision.chunkCount,0,'a disposed world must not receive late collider registrations');
    assert.equal(streamer.targets.length,0);
    assert.equal(streamer.group.children.length,0);
  }finally{streamer.dispose();collision.dispose();}
});
