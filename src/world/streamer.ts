import * as THREE from 'three/webgpu';
import { createChunk, createChunkAsync } from './chunk';
import { CHUNK_SIZE,planChunk,chunkAt,chunkKey,lakeRadius } from './layout.mjs';
import type { CollisionWorld,VectorLike } from './collision';
import type { ChunkVisual,ChunkPlan,WorldTarget } from './types';

export class WorldStreamer {
  readonly group=new THREE.Group();
  readonly loaded=new Map<string,{plan:ChunkPlan;visual:ChunkVisual}>();
  readonly targets:WorldTarget[]=[];
  private wanted=new Set<string>();
  private queue:{cx:number;cz:number}[]=[];
  private center='';
  private timer=0;
  private searchCache=new Set<string>();
  private openedDoors=new Set<string>();
  private lastSearchCount=-1;
  private building=false;
  private disposed=false;
  error:Error|null=null;
  revision=0;
  constructor(readonly seed:number,private collision:CollisionWorld,private onLoaded?:()=>void,private cooperative=false) {this.group.name='Streamed open world';}
  private load(cx:number,cz:number) {
    const key=chunkKey(cx,cz);if(this.loaded.has(key))return;
    const plan=planChunk(this.seed,cx,cz) as ChunkPlan,visual=createChunk(plan);
    this.commit(plan,visual);
  }
  private commit(plan:ChunkPlan,visual:ChunkVisual) {
    const key=plan.key;
    this.collision.addChunk(key,visual.boxes,visual.terrain);this.group.add(visual.group);
    this.loaded.set(key,{plan,visual});this.targets.push(...visual.targets);
    for(const [id,object]of visual.lootVisuals)object.visible=!this.searchCache.has(id);
    for(const [id,door]of visual.doors)if(this.openedDoors.has(id)) {
      const pose=door.setOpen(true);this.collision.setObstaclePose(id,pose.center,pose.rotationY??0);
    }
    this.revision++;this.onLoaded?.();
  }
  private async loadAsync(cx:number,cz:number) {
    const key=chunkKey(cx,cz);if(this.loaded.has(key)||this.disposed)return;
    this.building=true;
    try {
      const plan=planChunk(this.seed,cx,cz) as ChunkPlan;
      const stale=()=>this.disposed||!this.wanted.has(key);
      const visual=await createChunkAsync(plan,stale);
      if(visual){if(stale())visual.dispose();else this.commit(plan,visual);}
    } finally {this.building=false;}
  }
  async prime(position:VectorLike) {
    this.select(position);
    while(this.queue.length&&!this.disposed){const next=this.queue.shift()!;
      if(this.cooperative)await this.loadAsync(next.cx,next.cz);
      else{this.load(next.cx,next.cz);await new Promise(resolve=>setTimeout(resolve,0));}
    }
  }
  private select(position:VectorLike) {
    const {cx,cz}=chunkAt(position.x,position.z),key=chunkKey(cx,cz);if(key===this.center)return;
    this.center=key;this.wanted.clear();this.queue=[];
    for(let x=cx-2;x<=cx+2;x++)for(let z=cz-2;z<=cz+2;z++) {
      const id=chunkKey(x,z);this.wanted.add(id);if(!this.loaded.has(id))this.queue.push({cx:x,cz:z});
    }
    this.queue.sort((a,b)=>(a.cx-cx)**2+(a.cz-cz)**2-((b.cx-cx)**2+(b.cz-cz)**2));
    // Retire distant colliders as well as meshes. Never keep a visited-world mesh cache.
    for(const [id,chunk]of this.loaded)if(!this.wanted.has(id)) {
      const retired=new Set(chunk.visual.targets.map(t=>t.id));
      this.collision.removeChunk(id);chunk.visual.dispose();chunk.visual.group.removeFromParent();this.loaded.delete(id);
      for(let i=this.targets.length-1;i>=0;i--)if(retired.has(this.targets[i].id))this.targets.splice(i,1);
      this.revision++;
    }
  }
  update(position:VectorLike,dt:number,looted:string[]) {
    if(this.disposed)return;
    this.select(position);this.timer+=dt;
    if(this.queue.length&&!this.building&&!this.error&&this.timer>.055){this.timer=0;const next=this.queue.shift()!;
      if(this.cooperative)void this.loadAsync(next.cx,next.cz).catch(error=>{this.error=error instanceof Error?error:new Error(String(error));});
      else this.load(next.cx,next.cz);
    }
    if(looted.length!==this.lastSearchCount) {
      this.lastSearchCount=looted.length;this.searchCache=new Set(looted);
      for(const chunk of this.loaded.values())for(const [id,object]of chunk.visual.lootVisuals)object.visible=!this.searchCache.has(id);
    }
  }
  planAt(position:VectorLike) {
    const {cx,cz}=chunkAt(position.x,position.z);
    return this.loaded.get(chunkKey(cx,cz))?.plan??planChunk(this.seed,cx,cz) as ChunkPlan;
  }
  waterLevel(position:VectorLike):number|null {
    const plan=this.planAt(position);
    return plan.lake&&lakeRadius(plan.lake,position.x,position.z)<1?plan.lake.level:null;
  }
  get pending(){return this.queue.length+Number(this.building);}
  setDoors(opened:string[]) {
    const next=new Set(opened);
    for(const chunk of this.loaded.values())for(const [id,door]of chunk.visual.doors) {
      const open=next.has(id);if(open===this.openedDoors.has(id))continue;
      const pose=door.setOpen(open);this.collision.setObstaclePose(id,pose.center,pose.rotationY??0);
      this.onLoaded?.();
    }
    this.openedDoors=next;
  }
  dispose() {
    this.disposed=true;
    for(const [key,chunk]of this.loaded){this.collision.removeChunk(key);chunk.visual.dispose();}
    this.group.clear();this.loaded.clear();this.targets.length=0;this.queue.length=0;
  }
}
