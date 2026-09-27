import test from 'node:test';
import assert from 'node:assert/strict';
import RAPIER from '@dimforge/rapier3d-compat';
import { PerspectiveCamera } from 'three/webgpu';
import { createCollisionWorld } from '../src/world/collision.ts';
import { PlayerMotor } from '../src/player/motor.ts';
import { FollowCamera } from '../src/player/follow-camera.ts';

const idle = { moveX: 0, moveZ: 0, sprint: false, walk: false, crouch: false, jump: false };
const orbit = { yaw: Math.PI, pitch: .19, distance: 3.65 };
const floor = { center: [0, -.5, 0], half: [100, .5, 100] };

for (const fps of [60, 90, 144]) test(`walking render pose and camera move continuously at ${fps} Hz`, async () => {
  const world = await createCollisionWorld([], [floor], false);
  const motor = new PlayerMotor(world, { x: 0, y: .025, z: 8 });
  const camera = new PerspectiveCamera(65, 1, .08, 200);
  const follow = new FollowCamera(camera, world);
  try {
    const input = { ...idle, moveZ: -1 };
    for (let i = 0; i < fps; i++) {
      motor.step(1 / fps, input);
      const pose = motor.getRenderState();
      follow.update(1 / fps, pose.position, pose.crouched, orbit);
    }
    let previousZ = motor.getRenderState().position.z;
    let physicsZ = motor.state.position.z;
    let physicsRepeatedFrames = 0;
    const cameraY = camera.position.y;
    const orientation = camera.quaternion.clone();
    for (let i = 0; i < fps; i++) {
      motor.step(1 / fps, input);
      const pose = motor.getRenderState();
      follow.update(1 / fps, pose.position, pose.crouched, orbit);
      assert.ok(Math.abs(previousZ - pose.position.z - 3.5 / fps) < 1e-5,
        'a steady walk must move on every render frame, including frames without a physics tick');
      assert.ok(Math.abs(camera.position.y - cameraY) < 1e-5, 'level ground must not move the camera up and down');
      assert.ok(camera.quaternion.angleTo(orientation) < 1e-6, 'walking cannot oscillate the view angle');
      if (motor.state.position.z === physicsZ) physicsRepeatedFrames++;
      previousZ = pose.position.z;
      physicsZ = motor.state.position.z;
    }
    if (fps > 60) assert.ok(physicsRepeatedFrames >= fps - 61, 'the test actually samples between fixed physics ticks');
  } finally { motor.dispose(); world.dispose(); }
});

test('teleport and pause reset interpolation without blending across the world', async () => {
  const world = await createCollisionWorld([], [floor], false);
  const motor = new PlayerMotor(world);
  try {
    for (let i = 0; i < 37; i++) motor.step(1 / 90, { ...idle, moveZ: -1 });
    motor.resetMotion();
    assert.deepEqual(motor.getRenderState().position, motor.state.position);
    const destination = { x: 77, y: 5.2, z: -64 };
    motor.teleport(destination, true);
    assert.deepEqual(motor.getRenderState().position, destination);
    assert.equal(motor.getRenderState().crouched, true);
    motor.step(1 / 144, idle);
    assert.deepEqual(motor.getRenderState().position, destination);
  } finally { motor.dispose(); world.dispose(); }
});

test('camera passes a narrow doorway and orbits a room without crossing its walls', async () => {
  const world = await createCollisionWorld([], [floor,
    { center: [-2, 1.5, 0], half: [.975, 1.5, .15] },
    { center: [2, 1.5, 0], half: [.975, 1.5, .15] },
    { center: [0, 2.8, 0], half: [1.025, .2, .15] },
    { center: [-3, 1.5, -3], half: [.15, 1.5, 3] },
    { center: [3, 1.5, -3], half: [.15, 1.5, 3] },
    { center: [0, 1.5, -6], half: [3, 1.5, .15] },
  ], false);
  const motor = new PlayerMotor(world, { x: .65, y: .025, z: 3 });
  const camera = new PerspectiveCamera(65, 1, .08, 200);
  const follow = new FollowCamera(camera, world);
  const envelope = new RAPIER.Ball(.19);
  const identity = { x: 0, y: 0, z: 0, w: 1 };
  try {
    for (let i = 0; i < 360; i++) {
      motor.step(1 / 90, { ...idle, moveZ: i < 165 ? -1 : 0 });
      const pose = motor.getRenderState();
      const yaw = Math.PI + (i < 165 ? 0 : (i - 165) / 195 * Math.PI * 2);
      follow.update(1 / 90, pose.position, pose.crouched, { ...orbit, yaw });
      const collision = world.world.intersectionWithShape(camera.position, identity, envelope,
        undefined, undefined, undefined, undefined, world.isStaticObstacle);
      assert.equal(collision, null, `camera envelope intersects a surface on frame ${i}`);
    }
    assert.ok(motor.state.position.z < -3, 'the route passed through the real doorway');
  } finally { motor.dispose(); world.dispose(); }
});

test('camera retracts safely and recovers smoothly after an obstruction opens', async () => {
  const world = await createCollisionWorld([], [floor,
    { id: 'door', center: [0, 1.6, 2], half: [2, 1.6, .1] },
  ], false);
  const camera = new PerspectiveCamera(65, 1, .08, 200);
  const follow = new FollowCamera(camera, world);
  try {
    const position = { x: 0, y: .025, z: 0 };
    follow.update(1 / 60, position, false, orbit);
    position.z = .3;
    const retracted = follow.update(1 / 60, position, false, orbit);
    assert.ok(retracted < 1.5);
    world.setObstacleEnabled('door', false);
    assert.equal(follow.update(1 / 60, position, false, orbit), retracted,
      'a newly clear frame must not pop the camera outward');
    let length = retracted;
    for (let i = 0; i < 180; i++) {
      const next = follow.update(1 / 60, position, false, orbit);
      assert.ok(next >= length && next - length < .3);
      length = next;
    }
    assert.ok(Math.abs(length - orbit.distance) < 1e-6);
    const before = camera.position.y;
    follow.update(1 / 144, position, true, orbit);
    assert.ok(before - camera.position.y > 0 && before - camera.position.y < .1,
      'changing stance eases the vertical anchor without a 63 cm camera jump');
  } finally { world.dispose(); }
});

test('flat triangulated terrain does not inject vertical movement at triangle seams', async () => {
  const world = await createCollisionWorld([], [], false);
  const vertices = [], indices = [];
  for (let z = 0; z <= 20; z++) for (let x = 0; x <= 20; x++) vertices.push(x * 2 - 20, 0, z * 2 - 20);
  for (let z = 0; z < 20; z++) for (let x = 0; x < 20; x++) {
    const i = z * 21 + x;
    indices.push(i, i + 21, i + 1, i + 1, i + 21, i + 22);
  }
  world.addChunk('flat', [], { vertices: new Float32Array(vertices), indices: new Uint32Array(indices) });
  const motor = new PlayerMotor(world, { x: -8, y: .025, z: 8 });
  try {
    let min = Infinity, max = -Infinity;
    for (let i = 0; i < 480; i++) {
      motor.step(1 / 144, { ...idle, moveX: .5, moveZ: -.8 });
      if (i > 60) { min = Math.min(min, motor.state.position.y); max = Math.max(max, motor.state.position.y); }
    }
    assert.ok(max - min < .0001, `triangle seam movement was ${max - min} metres`);
  } finally { motor.dispose(); world.dispose(); }
});
