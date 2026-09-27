import { newWorld, loadWorld, saveWorld } from './world-save.mjs';
import type { CollisionWorld, VectorLike } from '../world/collision';
import type { DoorGeometry, WorldTarget } from '../world/types';
import type { InventoryInterfaceItem } from '../ui/interface';

export interface WorldSave {
  version:number; seed:number; position:VectorLike; yaw:number; stamina:number; crouched:boolean;
  inventory:{water:number;food:number;bandage:number}; looted:string[]; visited:string[]; openedDoors:string[];
  day:number; hour:number; shelterId:string|null; savedAt:number;
}
interface SaveableState {
  position:VectorLike; grounded:boolean; crouched:boolean; stamina:number; locomotion:string;
}
interface InteractionResult { changed:boolean; message:string; rest?:boolean; door?:{id:string;open:boolean} }
const ITEMS = [
  { id:'water', name:'Drinking water', description:'Clean, sealed water. Restores some stamina.', usable:true },
  { id:'food', name:'Preserved food', description:'A meal for the road. Restores stamina.', usable:true },
  { id:'bandage', name:'Field dressing', description:'Clean dressings kept for the journey ahead.', usable:false },
] as const;
const validId = (id:string) => id.length > 0 && id.length <= 160 && /^[a-zA-Z0-9:._-]+$/.test(id);

/** Conservative capsule test against the complete quarter-circle swept by a hinged leaf. */
export function doorSweepsPlayer(door:DoorGeometry,position:VectorLike,crouched:boolean) {
  const radius=.31+door.thickness/2, capsuleHeight=crouched?1.13:1.79;
  if (position.y>door.hinge.y+door.height+.05 || position.y+capsuleHeight<door.hinge.y-.05) return false;
  const dx=position.x-door.hinge.x,dz=position.z-door.hinge.z;
  const c=Math.cos(door.closedRotation),s=Math.sin(door.closedRotation);
  const x=c*dx-s*dz,z=s*dx+c*dz;
  if (x>=0 && z<=0 && Math.hypot(x,z)<=door.width+radius) return true;
  // Expanded radial edges catch a capsule whose centre is just outside the swept quadrant.
  const closedDistance=Math.hypot(x-Math.max(0,Math.min(door.width,x)),z);
  const openDistance=Math.hypot(x,z-Math.max(-door.width,Math.min(0,z)));
  return Math.min(closedDistance,openDistance)<=radius;
}

/** Persistent exploration state is independent of the currently streamed chunks. */
export class ExplorationSession {
  data:WorldSave;
  hasSave=false;
  saveStatus='Local save';
  restRemaining=0;
  private storage:Storage|null=null;
  private targets=new Map<string,WorldTarget>();
  private looted=new Set<string>();
  private visited=new Set<string>();
  private openedDoors=new Set<string>();
  private restingAt:string|null=null;

  constructor(storage?:Storage|null) {
    if (storage !== undefined) this.storage=storage;
    else try { this.storage=typeof window !== 'undefined' ? window.localStorage : null; } catch { /* Browser policy can deny storage. */ }
    const saved=this.storage ? loadWorld(this.storage) : null;
    this.data=(saved ?? newWorld()) as WorldSave;
    this.hasSave=!!saved;
    this.rebuildIndexes();
    if (!this.storage) this.saveStatus='Saving unavailable';
  }

  private rebuildIndexes() {
    this.looted=new Set(this.data.looted);
    this.visited=new Set(this.data.visited);
    this.openedDoors=new Set(this.data.openedDoors);
  }

  reset(seed=this.data.seed) {
    this.data=newWorld(seed) as WorldSave;
    this.restRemaining=0;
    this.restingAt=null;
    this.rebuildIndexes();
    // Replace v2 immediately: reloading cannot resurrect the old journey after a reset.
    this.hasSave=!!this.storage && saveWorld(this.storage,this.data);
    this.saveStatus=this.hasSave ? 'New world saved locally' : 'Saving unavailable';
    return this.data;
  }

  setTargets(targets:WorldTarget[]) {
    this.targets=new Map(targets.map(target=>[target.id,target]));
  }
  isDoorOpen(id:string) {return this.openedDoors.has(id);}

  visit(id:string) {
    if (!validId(id) || this.visited.has(id) || this.visited.size>=10000) return false;
    this.visited.add(id);
    this.data.visited.push(id);
    return true;
  }

  inventory():InventoryInterfaceItem[] {
    return ITEMS.filter(item=>this.data.inventory[item.id]>0).map(item=>({...item,count:this.data.inventory[item.id]}));
  }

  nearby(position:VectorLike,crouched:boolean,collision:Pick<CollisionWorld,'raycast'>):WorldTarget|null {
    if (this.restRemaining>0) return null;
    const origin={x:position.x,y:position.y+(crouched ? .72 : 1.23),z:position.z};
    let nearest:WorldTarget|null=null, nearestDistance=2;
    for (const target of this.targets.values()) {
      if (target.kind==='loot' && this.looted.has(target.id)) continue;
      const direction={x:target.position.x-origin.x,y:target.position.y-origin.y,z:target.position.z-origin.z};
      const distance=Math.hypot(direction.x,direction.y,direction.z);
      if (distance>nearestDistance) continue;
      // Crates and mattresses occupy the final few centimetres of the sight line.
      if (collision.raycast(origin,direction,Math.max(0,distance-.16))) continue;
      nearest=target.kind==='door'?{...target,label:this.isDoorOpen(target.id)?'Close door':'Open door'}:target;
      nearestDistance=distance;
    }
    return nearest;
  }

  interact(target:WorldTarget|null,position:VectorLike,crouched:boolean,collision:Pick<CollisionWorld,'raycast'>):InteractionResult|null {
    if (!target) return null;
    const actual=this.nearby(position,crouched,collision);
    if (!actual || actual.id!==target.id) return null;
    // Use the registered target, never contents supplied by a caller or stale chunk.
    if (actual.kind==='door') {
      if (!actual.door) return {changed:false,message:'This door is unavailable.'};
      if (doorSweepsPlayer(actual.door,position,crouched)) return {changed:false,message:'Step clear of the door before moving it.'};
      const open=!this.openedDoors.has(actual.id);
      if (open && this.openedDoors.size>=10000) return {changed:false,message:'The world door record is full.'};
      if (open) this.openedDoors.add(actual.id); else this.openedDoors.delete(actual.id);
      this.data.openedDoors=[...this.openedDoors];
      this.visit(actual.buildingId);
      return {changed:true,door:{id:actual.id,open},message:open?'Door opened.':'Door closed.'};
    }
    this.visit(actual.buildingId);
    if (actual.kind==='bed') {
      this.restRemaining=3;
      this.restingAt=actual.buildingId;
      return {changed:false,rest:true,message:`Resting in ${actual.buildingName} until 07:00.`};
    }
    if (this.looted.size>=10000) return {changed:false,message:'Exploration record is full. Start a new world from System to begin another journey.'};
    const contents=ITEMS.map(item=>({item,count:actual.loot?.[item.id] ?? 0}));
    if (contents.some(({item,count})=>!Number.isInteger(count) || count<0 || count+this.data.inventory[item.id]>999)) {
      return {changed:false,message:'Your pack is full of these supplies. Use some before taking this cache.'};
    }
    for (const {item,count} of contents) this.data.inventory[item.id]+=count;
    this.looted.add(actual.id);
    this.data.looted.push(actual.id);
    const found=contents.filter(({count})=>count>0).map(({item,count})=>`${count} ${item.name.toLowerCase()}`).join(', ');
    return {changed:true,message:found ? `Found ${found}.` : 'The container is empty.'};
  }

  update(dt:number) {
    if (!Number.isFinite(dt) || dt<=0) return false;
    if (this.restRemaining>0) {
      this.restRemaining=Math.max(0,this.restRemaining-dt);
      if (this.restRemaining>0) return false;
      if (this.data.hour>=7) this.data.day=Math.min(1000000,this.data.day+1);
      this.data.hour=7;
      this.data.stamina=1;
      this.data.shelterId=this.restingAt;
      this.restingAt=null;
      return true;
    }
    // One real second equals one game minute: a full day lasts 24 minutes.
    const hour=this.data.hour+dt/60;
    this.data.day=Math.min(1000000,this.data.day+Math.floor(hour/24));
    this.data.hour=hour%24;
    return false;
  }

  useItem(id:string,stamina:number) {
    if (id!=='water' && id!=='food') return {changed:false,stamina,message:'This item is carried for the journey ahead.'};
    if (!Number.isFinite(stamina) || stamina<0 || stamina>1) return {changed:false,stamina:this.data.stamina,message:'Unable to use supplies right now.'};
    if (this.restRemaining>0) return {changed:false,stamina,message:'You are resting.'};
    if (this.data.inventory[id]<=0) return {changed:false,stamina,message:`No ${id} in your pack.`};
    if (stamina>=.98) return {changed:false,stamina,message:'You already have full stamina.'};
    this.data.inventory[id]--;
    this.data.stamina=Math.min(1,stamina+(id==='water' ? .32 : .5));
    return {changed:true,stamina:this.data.stamina,message:id==='water' ? 'Drank clean water. Stamina restored.' : 'A meal for the road. Stamina restored.'};
  }

  drink(stamina:number) { return this.useItem('water',stamina); }

  objective(position:VectorLike) {
    if (this.restRemaining>0) return {title:'A roof for the night',detail:`Sleeping until 07:00 · ${Math.ceil(this.restRemaining)} seconds`};
    const night=this.data.hour>=20 || this.data.hour<6;
    let nearest:WorldTarget|null=null, nearestDistance=Infinity;
    for (const target of this.targets.values()) {
      if (night ? target.kind!=='bed' : target.kind!=='loot' || this.looted.has(target.id)) continue;
      const distance=Math.hypot(target.position.x-position.x,target.position.z-position.z);
      if (distance<nearestDistance) {nearest=target;nearestDistance=distance;}
    }
    if (nearest) return {
      title:night ? 'Find a roof for the night' : 'Search the world for supplies',
      detail:`${nearest.buildingName} · ${Math.ceil(nearestDistance)} m · ${night ? 'a bed waits inside' : 'look inside for supplies'}`,
    };
    return {title:night ? 'Find a place to spend the night' : 'Keep exploring',detail:night ? 'Shelters have beds. Enter a building and look for a place to sleep.' : 'Follow the roads. Search buildings, woodland and lakes beyond the city.'};
  }

  save(state:SaveableState,yaw:number) {
    // Keep the last stable footing if a tab closes in mid-jump or during a mantle.
    if ((state.grounded && state.locomotion!=='climb') || state.locomotion==='swim') {
      this.data.position={...state.position};
      this.data.crouched=state.crouched;
    }
    this.data.yaw=yaw;
    this.data.stamina=state.stamina;
    const saved=!!this.storage && saveWorld(this.storage,this.data);
    if (saved) this.data.savedAt=Date.now();
    this.hasSave ||= saved;
    this.saveStatus=saved ? 'Progress saved locally' : 'Saving unavailable';
    return saved;
  }
}
