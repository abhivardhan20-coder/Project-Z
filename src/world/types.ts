import type * as THREE from 'three/webgpu';
import type { CollisionBox } from './collision';

export type Biome = 'urban'|'residential'|'park'|'lake'|'forest'|'hills'|'mountain';
export interface BuildingPlan {
  id:string; x:number; y?:number; z:number; width:number; depth:number; floors:number; rotation:number;
  kind:'shop'|'apartment'|'clinic'|'house'|'warehouse'; enterable:boolean; shelter:boolean; variant:number; seed:number;
}
export interface LakePlan {x:number;z:number;rx:number;rz:number;level:number;depth:number}
export interface ChunkPlan {key:string;cx:number;cz:number;seed:number;worldSeed?:number;rural?:boolean;biome:Biome;name:string;buildings:BuildingPlan[];lake:LakePlan|null}
export interface DoorGeometry {
  hinge:{x:number;y:number;z:number}; width:number; height:number; thickness:number; closedRotation:number;
}
export interface WorldTarget {
  id:string; kind:'loot'|'bed'|'door'; position:{x:number;y:number;z:number}; label:string;
  buildingId:string; buildingName:string; loot?:{water?:number;food?:number;bandage?:number}; door?:DoorGeometry;
}
export interface DoorVisual {
  id:string; target:WorldTarget;
  /** Returns the matching collider pose; visual and physical pose change in the same update. */
  setOpen(open:boolean):CollisionBox;
}
export interface TerrainCollider {vertices:Float32Array;indices:Uint32Array}
export interface ChunkVisual {
  group:THREE.Group; boxes:CollisionBox[]; terrain?:TerrainCollider; targets:WorldTarget[];
  water:THREE.Mesh[]; lootVisuals:Map<string,THREE.Object3D>; doors:Map<string,DoorVisual>; dispose():void;
}
export interface BuildingVisual {
  group:THREE.Group; boxes:CollisionBox[]; targets:WorldTarget[]; lootVisuals:Map<string,THREE.Object3D>; doors:Map<string,DoorVisual>; dispose():void;
}
