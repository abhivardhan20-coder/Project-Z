import RAPIER from '@dimforge/rapier3d-compat';
import type * as THREE from 'three/webgpu';

export interface CollisionBox {
  id?: string;
  center: [number, number, number];
  half: [number, number, number];
  rotationY?: number;
}

export interface VectorLike { x: number; y: number; z: number }

let initialization: Promise<void> | undefined;
const identity = { x: 0, y: 0, z: 0, w: 1 };

/** Deliberately coarse collision proxies; facade trim and foliage never enter physics. */
export class CollisionWorld {
  readonly world: RAPIER.World;
  private readonly cameraShape: RAPIER.Ball;
  private disposed = false;
  private readonly obstacles = new Map<string, RAPIER.Collider>();
  private readonly chunks = new Map<string,{body:RAPIER.RigidBody;ids:string[]}>();
  // Rapier 0.12's JS query-filter enum and WASM flags differ for fixed bodies.
  // A predicate also keeps disabled doors out of queries immediately, before a simulation tick.
  readonly isStaticObstacle = (collider: RAPIER.Collider) => collider.isEnabled() && !collider.isSensor()
    && (!collider.parent() || collider.parent()!.isFixed());

  constructor(boxes: CollisionBox[]) {
    this.world = new RAPIER.World({ x: 0, y: -21, z: 0 });
    this.world.timestep = 1 / 60;
    this.cameraShape = new RAPIER.Ball(.24);
    const staticBody = this.world.createRigidBody(RAPIER.RigidBodyDesc.fixed());
    for (const box of boxes) {
      if (![...box.center, ...box.half, box.rotationY ?? 0].every(Number.isFinite) || box.half.some(value => value <= 0)) {
        throw new Error('Invalid collision box');
      }
      const angle = (box.rotationY ?? 0) / 2;
      const collider = this.world.createCollider(RAPIER.ColliderDesc.cuboid(...box.half)
        .setTranslation(...box.center).setRotation({ x: 0, y: Math.sin(angle), z: 0, w: Math.cos(angle) })
        .setFriction(.8), staticBody);
      if (box.id) this.obstacles.set(box.id, collider);
    }
    this.world.updateSceneQueries();
  }

  setObstacleEnabled(id: string, enabled: boolean) {
    const collider = this.obstacles.get(id);
    if (!collider) return false;
    collider.setEnabled(enabled);
    this.world.updateSceneQueries();
    return true;
  }

  /** Move a hinged panel without rebuilding the district's other colliders. */
  setObstaclePose(id:string,center:[number,number,number],rotationY:number) {
    const collider=this.obstacles.get(id);
    if(!collider||![...center,rotationY].every(Number.isFinite))return false;
    // Streamed chunk bodies are fixed at identity. Rapier restores an attached
    // collider from this relative pose, so changing only its world pose is lost.
    collider.setTranslationWrtParent({x:center[0],y:center[1],z:center[2]});
    collider.setRotationWrtParent({x:0,y:Math.sin(rotationY/2),z:0,w:Math.cos(rotationY/2)});
    this.world.updateSceneQueries();return true;
  }

  /** Chunk collision is registered and retired with its rendered geometry. */
  addChunk(key:string,boxes:CollisionBox[],terrain?:{vertices:Float32Array;indices:Uint32Array}) {
    this.removeChunk(key);
    const body=this.world.createRigidBody(RAPIER.RigidBodyDesc.fixed());
    const ids:string[]=[];
    for(const box of boxes) {
      const angle=(box.rotationY??0)/2;
      const collider=this.world.createCollider(RAPIER.ColliderDesc.cuboid(...box.half).setTranslation(...box.center)
        .setRotation({x:0,y:Math.sin(angle),z:0,w:Math.cos(angle)}).setFriction(.8),body);
      if(box.id){this.obstacles.set(box.id,collider);ids.push(box.id);}
    }
    if(terrain)this.world.createCollider(RAPIER.ColliderDesc.trimesh(terrain.vertices,terrain.indices).setFriction(.8),body);
    this.chunks.set(key,{body,ids});this.world.updateSceneQueries();
  }
  removeChunk(key:string) {
    const chunk=this.chunks.get(key);if(!chunk)return;
    for(const id of chunk.ids)this.obstacles.delete(id);
    this.world.removeRigidBody(chunk.body);this.chunks.delete(key);this.world.updateSceneQueries();
  }
  get chunkCount(){return this.chunks.size;}

  /** Direction is normalized internally; returned toi is a distance in metres. */
  raycast(origin: VectorLike, direction: VectorLike, maxDistance: number, exclude?: RAPIER.Collider) {
    const length = Math.hypot(direction.x, direction.y, direction.z);
    if (!length || maxDistance <= 0) return null;
    return this.world.castRayAndGetNormal(new RAPIER.Ray(origin, {
      x: direction.x / length, y: direction.y / length, z: direction.z / length,
    }), maxDistance, true, undefined, undefined, exclude, undefined, this.isStaticObstacle);
  }

  /** Sweep the camera's near-plane envelope, not only its centre ray. */
  cameraDistance(origin: VectorLike, direction: VectorLike, maxDistance: number) {
    const length = Math.hypot(direction.x, direction.y, direction.z);
    if (!length || maxDistance <= 0) return 0;
    const hit = this.world.castShape(origin, identity, {
      x: direction.x / length, y: direction.y / length, z: direction.z / length,
    }, this.cameraShape, maxDistance, true, undefined, undefined, undefined, undefined, this.isStaticObstacle);
    return hit ? Math.max(0, hit.toi - .06) : maxDistance;
  }

  dispose() {
    if (this.disposed) return;
    this.disposed = true;
    this.world.free();
  }
}

export async function createCollisionWorld(groups: THREE.Group[], extraBoxes: CollisionBox[] = [], bounded=true): Promise<CollisionWorld> {
  initialization ??= RAPIER.init();
  await initialization;
  const boxes = groups.flatMap(group => (group.userData.collisionBoxes ?? []) as CollisionBox[]);
  return new CollisionWorld([...boxes, ...extraBoxes,...(bounded?[
    // Boundaries are confined to the edge of the playable block, outside the carriageway.
    { center: [-11.75, 6, -56.5], half: [.25, 8, 98.75] },
    { center: [11.75, 6, -56.5], half: [.25, 8, 98.75] },
    { center: [0, 6, 42.25], half: [12, 8, .25] },
    { center: [0, 6, -155.25], half: [12, 8, .25] },
  ] as CollisionBox[]:[])]);
}
