import RAPIER from '@dimforge/rapier3d-compat';
import type { CollisionWorld, VectorLike } from '../world/collision';

export interface MovementInput {
  moveX: number; moveZ: number; sprint: boolean; walk: boolean; crouch: boolean; jump: boolean;
}
export type Locomotion = 'idle' | 'walk' | 'run' | 'sprint' | 'crouch' | 'air' | 'climb' | 'swim';
export interface MotorState {
  position: VectorLike; velocity: VectorLike; grounded: boolean; crouched: boolean;
  stamina: number; speed: number; yaw: number; locomotion: Locomotion;
}

const FIXED_DT = 1 / 60;
const RADIUS = .3;
const STANDING_HEIGHT = 1.78;
const CROUCH_HEIGHT = 1.05;
const SKIN = .025;
const identity = { x: 0, y: 0, z: 0, w: 1 };
const clamp = (value: number, min: number, max: number) => Math.max(min, Math.min(max, value));
const approach = (current: number, target: number, delta: number) => current + clamp(target - current, -delta, delta);

/** A fixed-step capsule controller. State.position always describes the player's feet. */
export class PlayerMotor {
  readonly state: MotorState;
  readonly collider: RAPIER.Collider;
  private readonly collision: CollisionWorld;
  private readonly body: RAPIER.RigidBody;
  private readonly controller: RAPIER.KinematicCharacterController;
  private accumulator = 0;
  private readonly previousPosition: VectorLike = { x: 0, y: 0, z: 0 };
  private previousYaw = Math.PI;
  private previousSpeed = 0;
  private readonly renderState: MotorState;
  private jumpHeld = false;
  private jumpBuffer = 0;
  private coyoteTime = 0;
  private exhausted = false;
  private staminaDelay = 0;
  private speedModifier = 1;
  private staminaModifier = 1;
  private waterLevel:number|null=null;
  private disposed = false;
  private mantle: { target: VectorLike; lift: number; stage: 'up' | 'forward'; timeout: number } | null = null;

  constructor(collision: CollisionWorld, spawn: VectorLike = { x: 0, y: .05, z: 22 }) {
    this.collision = collision;
    this.state = { position: { ...spawn }, velocity: { x: 0, y: 0, z: 0 }, grounded: false, crouched: false,
      stamina: 1, speed: 0, yaw: Math.PI, locomotion: 'idle' };
    this.renderState = { ...this.state, position: { ...spawn }, velocity: { ...this.state.velocity } };
    this.body = collision.world.createRigidBody(RAPIER.RigidBodyDesc.kinematicPositionBased()
      .setTranslation(spawn.x, spawn.y + STANDING_HEIGHT / 2, spawn.z));
    this.collider = collision.world.createCollider(RAPIER.ColliderDesc.capsule(STANDING_HEIGHT / 2 - RADIUS, RADIUS)
      .setFriction(0), this.body);
    this.controller = collision.world.createCharacterController(SKIN);
    this.controller.setUp({ x: 0, y: 1, z: 0 });
    this.controller.enableAutostep(.35, .22, false);
    this.controller.enableSnapToGround(.3);
    this.controller.setMaxSlopeClimbAngle(Math.PI / 4);
    this.controller.setMinSlopeSlideAngle(Math.PI / 4 + .03);
    this.controller.setApplyImpulsesToDynamicBodies(false);
    this.teleport(spawn, false);
  }

  step(dt: number, input: MovementInput) {
    if (this.disposed || !Number.isFinite(dt) || dt < 0) return;
    if (input.jump && !this.jumpHeld) this.jumpBuffer = .13;
    this.jumpHeld = input.jump;
    this.accumulator += Math.min(dt, .1);
    // At most six simulation ticks: a background-tab stall cannot trigger a huge catch-up.
    let ticks = 0;
    while (this.accumulator + 1e-9 >= FIXED_DT && ticks++ < 6) {
      this.capturePreviousPose();
      this.fixedStep(input);
      this.accumulator = Math.max(0, this.accumulator - FIXED_DT);
    }
  }

  private capturePreviousPose() {
    Object.assign(this.previousPosition, this.state.position);
    this.previousYaw = this.state.yaw;
    this.previousSpeed = this.state.speed;
  }

  /** One-tick interpolation prevents 60 Hz physics from stuttering at other refresh rates.
   * This reusable view is only for rendering. Collision, saving, and interactions use state.
   */
  getRenderState(): MotorState {
    const alpha = clamp(this.accumulator / FIXED_DT, 0, 1);
    const result = this.renderState, current = this.state;
    const position = result.position, velocity = result.velocity;
    Object.assign(result, current, { position, velocity });
    for (const axis of ['x', 'y', 'z'] as const) {
      position[axis] = this.previousPosition[axis] + (current.position[axis] - this.previousPosition[axis]) * alpha;
      velocity[axis] = current.velocity[axis];
    }
    const yawDelta = Math.atan2(Math.sin(current.yaw - this.previousYaw), Math.cos(current.yaw - this.previousYaw));
    result.yaw = this.previousYaw + yawDelta * alpha;
    result.speed = this.previousSpeed + (current.speed - this.previousSpeed) * alpha;
    return result;
  }

  private get height() { return this.state.crouched ? CROUCH_HEIGHT : STANDING_HEIGHT; }

  private setCrouched(crouched: boolean) {
    if (crouched === this.state.crouched) return;
    const p = this.state.position;
    if (!crouched && this.collision.world.intersectionWithShape(
      { x: p.x, y: p.y + STANDING_HEIGHT / 2 + .005, z: p.z }, identity,
      new RAPIER.Capsule(STANDING_HEIGHT / 2 - RADIUS, RADIUS),
      RAPIER.QueryFilterFlags.EXCLUDE_SENSORS, undefined, this.collider,
    )) return;
    this.state.crouched = crouched;
    this.collider.setShape(new RAPIER.Capsule(this.height / 2 - RADIUS, RADIUS));
    const centre = { x: p.x, y: p.y + this.height / 2, z: p.z };
    this.body.setTranslation(centre, true);
    this.body.setNextKinematicTranslation(centre);
    this.collision.world.updateSceneQueries();
  }

  private fixedStep(input: MovementInput) {
    const s = this.state;
    const swimming=this.waterLevel!==null && s.position.y<this.waterLevel-.7;
    this.setCrouched(swimming?false:input.crouch);
    this.jumpBuffer = Math.max(0, this.jumpBuffer - FIXED_DT);
    this.coyoteTime = s.grounded ? .1 : Math.max(0, this.coyoteTime - FIXED_DT);
    this.staminaDelay = Math.max(0, this.staminaDelay - FIXED_DT);
    if (this.exhausted && s.stamina >= .25) this.exhausted = false;

    const rawX = Number.isFinite(input.moveX) ? input.moveX : 0;
    const rawZ = Number.isFinite(input.moveZ) ? input.moveZ : 0;
    const magnitude = Math.hypot(rawX, rawZ);
    const moveX = rawX / Math.max(1, magnitude), moveZ = rawZ / Math.max(1, magnitude);
    const moving = magnitude > .05;
    const sprinting = input.sprint && moving && !swimming && !s.crouched && !this.exhausted && s.stamina > 0 && s.grounded;
    const maxSpeed = (swimming?2.2:s.crouched ? 1.5 : sprinting ? 6.3 : input.walk ? 1.8 : 3.5) * this.speedModifier;
    const acceleration = (swimming?7:s.grounded ? moving ? 19 : 25 : 7) * FIXED_DT;
    s.velocity.x = approach(s.velocity.x, moveX * maxSpeed, acceleration);
    s.velocity.z = approach(s.velocity.z, moveZ * maxSpeed, acceleration);
    if (moving) {
      const targetYaw = Math.atan2(moveX, moveZ);
      const delta = Math.atan2(Math.sin(targetYaw - s.yaw), Math.cos(targetYaw - s.yaw));
      s.yaw += delta * Math.min(1, FIXED_DT * 14);
    }

    if (this.jumpBuffer > 0 && this.coyoteTime > 0 && !swimming && !s.crouched && !this.mantle && s.stamina >= .08) {
      const unit = Math.max(Math.hypot(moveX, moveZ), 1e-4);
      if (!moving || !this.tryMantle(moveX / unit, moveZ / unit)) {
        s.velocity.y = 7.2;
        s.grounded = false;
      }
      this.coyoteTime = 0;
      this.jumpBuffer = 0;
      s.stamina = Math.max(0, s.stamina - .08);
      this.staminaDelay = .7;
    }

    if (sprinting && !this.mantle) {
      s.stamina = Math.max(0, s.stamina - FIXED_DT * .13 / this.staminaModifier);
      this.staminaDelay = .8;
      if (s.stamina === 0) this.exhausted = true;
    } else if (this.staminaDelay === 0 && (s.grounded||swimming)) {
      s.stamina = Math.min(1, s.stamina + FIXED_DT * .19 * this.staminaModifier);
    }

    let desired: VectorLike;
    if (this.mantle) {
      this.mantle.timeout -= FIXED_DT;
      if (this.mantle.stage === 'up' && s.position.y >= this.mantle.lift - .015) this.mantle.stage = 'forward';
      const target = this.mantle.stage === 'up' ? { ...s.position, y: this.mantle.lift } : this.mantle.target;
      desired = { x: approach(s.position.x, target.x, .07) - s.position.x,
        y: approach(s.position.y, target.y, .07) - s.position.y,
        z: approach(s.position.z, target.z, .07) - s.position.z };
      s.velocity = { x: 0, y: 0, z: 0 };
      if (this.mantle.timeout <= 0 || (this.mantle.stage === 'forward' && Math.hypot(target.x - s.position.x, target.z - s.position.z) < .02)) {
        this.mantle = null;
      }
    } else {
      if(swimming) {
        // Damped buoyancy keeps the head above water while the capsule still collides with banks.
        const error=this.waterLevel!-.95-s.position.y;
        s.velocity.y=clamp(error*5,-1.8,2.4);
      } else s.velocity.y = Math.max(-35, s.velocity.y - 21 * FIXED_DT);
      desired = { x: s.velocity.x * FIXED_DT, y: s.velocity.y * FIXED_DT, z: s.velocity.z * FIXED_DT };
    }

    this.controller.computeColliderMovement(this.collider, desired, RAPIER.QueryFilterFlags.EXCLUDE_SENSORS);
    const corrected = this.controller.computedMovement();
    s.grounded = this.controller.computedGrounded() && !this.mantle;
    if ((s.grounded && s.velocity.y < 0) || (desired.y > 0 && corrected.y < desired.y - .001)) s.velocity.y = 0;
    s.position.x += corrected.x; s.position.y += corrected.y; s.position.z += corrected.z;
    if (s.grounded && !swimming && desired.y <= 0) {
      // Rapier's capsule/cuboid contact can lose its skin offset by millimetres
      // while sliding across a wide floor. Resolve the support plane explicitly
      // on level surfaces so that floors do not make the survivor/camera tremble.
      // Slopes, unsupported ledges, jumps and substantial height changes remain
      // entirely under the swept character controller.
      const support = this.collision.raycast({ x: s.position.x, y: s.position.y + .08, z: s.position.z },
        { x: 0, y: -1, z: 0 }, .18, this.collider);
      if (support && support.normal.y > .9995) {
        const adjustment = .08 - support.toi + SKIN;
        if (Math.abs(adjustment) < .06) s.position.y += adjustment;
      }
    }
    this.body.setNextKinematicTranslation({ x: s.position.x, y: s.position.y + this.height / 2, z: s.position.z });
    this.collision.world.step();
    s.speed = Math.hypot(corrected.x, corrected.z) / FIXED_DT;
    s.locomotion = swimming ? 'swim' : this.mantle ? 'climb' : !s.grounded ? 'air' : s.speed < .1 ? 'idle'
      : s.crouched ? 'crouch' : sprinting ? 'sprint' : input.walk ? 'walk' : 'run';
  }

  /** Mantle only onto a verified top with clearance along both portions of the path. */
  private tryMantle(dx: number, dz: number) {
    const p = this.state.position;
    const lower = this.collision.raycast({ x: p.x, y: p.y + .55, z: p.z }, { x: dx, y: 0, z: dz }, .95);
    if (!lower || Math.abs(lower.normal.y) > .25) return false;
    const x = p.x + dx * (lower.toi + RADIUS + .12), z = p.z + dz * (lower.toi + RADIUS + .12);
    const top = this.collision.raycast({ x, y: p.y + 1.3, z }, { x: 0, y: -1, z: 0 }, .8);
    if (!top || top.normal.y < .85) return false;
    const topY = p.y + 1.3 - top.toi;
    if (topY - p.y < .55 || topY - p.y > 1.2) return false;
    const lift = topY + SKIN + .035;
    const shape = new RAPIER.Capsule(STANDING_HEIGHT / 2 - RADIUS, RADIUS);
    const centre = { x: p.x, y: p.y + STANDING_HEIGHT / 2, z: p.z };
    const filter = this.collision.isStaticObstacle;
    if (this.collision.world.castShape(centre, identity, { x: 0, y: 1, z: 0 }, shape, lift - p.y, true,
      undefined, undefined, this.collider, undefined, filter)) return false;
    const raised = { x: p.x, y: lift + STANDING_HEIGHT / 2, z: p.z };
    const distance = Math.hypot(x - p.x, z - p.z);
    if (this.collision.world.castShape(raised, identity, { x: dx, y: 0, z: dz }, shape, distance, true,
      undefined, undefined, this.collider, undefined, filter)) return false;
    if (this.collision.world.intersectionWithShape({ x, y: lift + STANDING_HEIGHT / 2, z }, identity, shape,
      undefined, undefined, this.collider, undefined, filter)) return false;
    this.mantle = { target: { x, y: lift, z }, lift, stage: 'up', timeout: 1.3 };
    this.state.grounded = false;
    return true;
  }

  /** Restore stance before any camera/physics update; old saves under a beam crouch safely. */
  teleport(position: VectorLike, crouched = this.state.crouched) {
    if (![position.x, position.y, position.z].every(Number.isFinite)) return;
    Object.assign(this.state.position, position);
    this.resetMotion();
    this.state.grounded = false;
    // Start with the smaller shape, then attempt standing at the destination.
    // Checking standing at the old position would let a reload intersect a low ceiling.
    this.state.crouched = true;
    this.collider.setShape(new RAPIER.Capsule(CROUCH_HEIGHT / 2 - RADIUS, RADIUS));
    const centre = { x: position.x, y: position.y + this.height / 2, z: position.z };
    this.body.setTranslation(centre, true);
    this.body.setNextKinematicTranslation(centre);
    this.collision.world.updateSceneQueries();
    if (!crouched) this.setCrouched(false);
  }

  resetMotion() {
    this.state.velocity = { x: 0, y: 0, z: 0 };
    this.state.speed = 0;
    this.state.locomotion = 'idle';
    this.accumulator = 0;
    this.jumpBuffer = 0;
    this.jumpHeld = false;
    this.coyoteTime = 0;
    this.mantle = null;
    this.capturePreviousPose();
  }

  setMovementModifier(modifier: { speed?: number; stamina?: number }) {
    if (modifier.speed !== undefined && Number.isFinite(modifier.speed)) this.speedModifier = clamp(modifier.speed, 0, 2);
    if (modifier.stamina !== undefined && Number.isFinite(modifier.stamina)) this.staminaModifier = clamp(modifier.stamina, .1, 2);
  }
  setWaterLevel(level:number|null) {this.waterLevel=level;}

  dispose() {
    if (this.disposed) return;
    this.disposed = true;
    this.collision.world.removeCharacterController(this.controller);
    this.collision.world.removeRigidBody(this.body);
  }
}
