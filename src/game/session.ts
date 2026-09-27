import { Vector3 } from 'three/webgpu';
import { newJourney, loadJourney, saveJourney } from './save.mjs';
import { applyInteraction, useWater } from './rules.mjs';
import type { CollisionWorld, VectorLike } from '../world/collision';
import type { MotorState } from '../player/motor';
import type { InventoryInterfaceItem } from '../ui/interface';

export type JourneyTarget = {id:string;position:Vector3;label:string};
const TARGETS:JourneyTarget[]=[
  {id:'fieldKit',position:new Vector3(2,.72,17.45),label:'Search field supplies'},
  {id:'serviceCache',position:new Vector3(6.2,1.65,-18.55),label:'Take the service key'},
  {id:'shelterDoor',position:new Vector3(5.5,1.35,-52.60),label:'Unlock shelter'},
  {id:'power',position:new Vector3(6.45,1.25,-55.1),label:'Install charged battery'},
  {id:'rest',position:new Vector3(4.5,.9,-55.3),label:'Rest at shelter'},
];
const ITEM_INFO=[
  {id:'water',name:'Drinking water',description:'Sealed, clean water. Drink to recover some stamina.',usable:true},
  {id:'bandage',name:'Field dressing',description:'A clean dressing. Carried for the journey ahead.',usable:false},
  {id:'battery',name:'Charged battery',description:'A 12V battery. Install it at the shelter power panel.',usable:false},
  {id:'key',name:'Service key',description:'An orange-tagged key for the district rest point.',usable:false},
] as const;

export class JourneySession {
  data:ReturnType<typeof newJourney>;
  hasSave=false;
  saveStatus='Local save';
  restRemaining=0;
  private storage:Storage|null=null;
  private origin=new Vector3();
  private direction=new Vector3();
  constructor() {
    try { this.storage=window.localStorage; } catch { /* Storage can be disabled by browser policy. */ }
    const saved=this.storage?loadJourney(this.storage):null;
    this.data=saved??newJourney();this.hasSave=!!saved;
    if(!this.storage)this.saveStatus='Saving unavailable';
  }
  reset() {this.data=newJourney();this.restRemaining=0;this.hasSave=false;}
  inventory():InventoryInterfaceItem[] {
    return ITEM_INFO.filter(item=>this.data.inventory[item.id]>0).map(item=>({...item,count:this.data.inventory[item.id]}));
  }
  private active(id:string) {
    const f=this.data.flags;
    return id==='fieldKit'?!f.fieldKit:id==='serviceCache'?!f.serviceCache:id==='shelterDoor'?!f.shelterOpen:
      id==='power'?f.shelterOpen&&!f.powerRestored:id==='rest'&&f.powerRestored;
  }
  nearby(position:VectorLike,crouched:boolean,collision:CollisionWorld):JourneyTarget|null {
    if(this.restRemaining>0)return null;
    this.origin.set(position.x,position.y+(crouched?.72:1.23),position.z);
    let nearest:JourneyTarget|null=null,nearestDistance=2.0;
    for(const target of TARGETS) {
      if(!this.active(target.id))continue;
      if(target.id==='serviceCache'&&(position.y<.85||position.z> -17.7))continue;
      const distance=this.origin.distanceTo(target.position);
      if(distance>nearestDistance)continue;
      if(target.id==='serviceCache'&&distance>1.2)continue;
      this.direction.copy(target.position).sub(this.origin);
      // Exclude the last few centimetres occupied by the target's own housing.
      if(collision.raycast(this.origin,this.direction,Math.max(0,distance-.3)))continue;
      nearest=target;nearestDistance=distance;
    }
    return nearest;
  }
  interact(target:JourneyTarget|null,position:VectorLike,crouched:boolean,collision:CollisionWorld) {
    if(!target || this.nearby(position,crouched,collision)?.id!==target.id)return null;
    const result=applyInteraction(this.data,target.id);
    if('rest' in result&&result.rest)this.restRemaining=3;
    return result;
  }
  update(dt:number) {
    if(this.restRemaining<=0)return false;
    this.restRemaining=Math.max(0,this.restRemaining-dt);
    if(this.restRemaining===0){this.data.flags.rested=true;return true;}
    return false;
  }
  drink(stamina:number) {return useWater(this.data,stamina);}
  objective(position:VectorLike) {
    const f=this.data.flags;
    if(this.restRemaining>0)return {title:'A moment of quiet',detail:`Resting · ${Math.ceil(this.restRemaining)} seconds`};
    if(f.rested)return {title:'A place to return to',detail:'Shelter secured · explore Sector 07 · progress saves locally'};
    const index=!f.fieldKit?0:!f.serviceCache?1:!f.shelterOpen?2:!f.powerRestored?3:4;
    const target=TARGETS[index],distance=Math.ceil(Math.hypot(position.x-target.position.x,position.z-target.position.z));
    const titles=['Find supplies','Find the service key','Reach the shelter','Bring the shelter online','Rest before moving on'];
    const details=['Orange field crate near the district entrance','East-side scaffold · climb the steps, crouch under the beam','Follow the street north to Rest Point 04','Install the battery at the panel inside','Use the camp bed inside the shelter'];
    return {title:titles[index],detail:`${details[index]} · ${distance} m`};
  }
  save(state:MotorState,yaw:number) {
    // Persist stable contact positions; a tab closed mid-jump restores its last safe footing.
    if(state.grounded && state.locomotion!=='climb') {
      this.data.position={...state.position};this.data.crouched=state.crouched;
    }
    this.data.yaw=yaw;this.data.stamina=state.stamina;
    const saved=!!this.storage&&saveJourney(this.storage,this.data);
    this.hasSave ||= saved;this.saveStatus=saved?'Progress saved locally':'Saving unavailable';
    return saved;
  }
}
