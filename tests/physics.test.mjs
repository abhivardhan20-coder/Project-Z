import test from 'node:test';
import assert from 'node:assert/strict';
import { createCollisionWorld } from '../src/world/collision.ts';
import { PlayerMotor } from '../src/player/motor.ts';

const idle = { moveX: 0, moveZ: 0, sprint: false, walk: false, crouch: false, jump: false };
const floor = { center: [0, -.5, -50], half: [11, .5, 100] };
const tick = (motor, count, input = {}) => {
  for (let i = 0; i < count; i++) motor.step(1 / 60, { ...idle, ...input });
};
async function fixture(boxes = [], spawn = { x: 0, y: .05, z: 0 }) {
  const world = await createCollisionWorld([], [floor, ...boxes]);
  const motor = new PlayerMotor(world, spawn);
  return { world, motor, cleanup: () => { motor.dispose(); world.dispose(); } };
}

test('capsule blocks at a wall and slides along it without tunnelling', async () => {
  const f = await fixture([{ center: [0, 2, -2], half: [10, 2, .15] }]);
  try {
    tick(f.motor, 20);
    tick(f.motor, 180, { moveX: .25, moveZ: -1, sprint: true });
    assert.ok(f.motor.state.position.z > -1.56);
    assert.ok(f.motor.state.position.x > 1);
    assert.equal(f.motor.state.grounded, true);
    f.motor.step(8, { ...idle, moveZ: -1, sprint: true });
    assert.ok(f.motor.state.position.z > -1.56, 'a long frame cannot tunnel through the wall');
  } finally { f.cleanup(); }
});

test('jump leaves ground, reaches a physical apex, lands and does not repeat while held', async () => {
  const f = await fixture();
  try {
    tick(f.motor, 10);
    assert.equal(f.motor.state.grounded, true);
    tick(f.motor, 1, { jump: true });
    assert.equal(f.motor.state.grounded, false);
    let highest = 0;
    for (let i = 0; i < 110; i++) {
      tick(f.motor, 1, { jump: true });
      highest = Math.max(highest, f.motor.state.position.y);
    }
    assert.ok(highest > 1 && highest < 1.4);
    assert.equal(f.motor.state.grounded, true);
    assert.ok(Math.abs(f.motor.state.position.y - .025) < .005);
  } finally { f.cleanup(); }
});

test('autostep ascends a metre-high staircase made of 20 cm risers', async () => {
  const stairs = Array.from({ length: 5 }, (_, i) => ({ center: [0, .1 * (i + 1), -1 - i * .55], half: [1.5, .1 * (i + 1), .275] }));
  const f = await fixture([...stairs, { center: [0, .5, -4.8], half: [1.5, .5, 1.3] }]);
  try {
    tick(f.motor, 10);
    tick(f.motor, 90, { moveZ: -1 });
    assert.ok(f.motor.state.position.z < -3.5, `stalled at ${f.motor.state.position.z}`);
    assert.ok(f.motor.state.position.y > 1);
    assert.equal(f.motor.state.grounded, true);
  } finally { f.cleanup(); }
});

test('crouched capsule fits below a beam and cannot stand until its head is clear', async () => {
  const f = await fixture([{ center: [0, 1.42, 0], half: [3, .12, 1] }], { x: 0, y: .05, z: 2 });
  try {
    tick(f.motor, 10);
    tick(f.motor, 65, { moveZ: -1, crouch: true });
    assert.ok(f.motor.state.position.z < 1);
    tick(f.motor, 15);
    assert.equal(f.motor.state.crouched, true);
    tick(f.motor, 70, { moveZ: 1 });
    assert.equal(f.motor.state.crouched, false);
  } finally { f.cleanup(); }
});

test('sprinting exhausts stamina, enforces recovery, and resting replenishes it', async () => {
  const f = await fixture();
  try {
    tick(f.motor, 10);
    tick(f.motor, 470, { moveZ: -1, sprint: true });
    assert.ok(f.motor.state.stamina < .08);
    assert.notEqual(f.motor.state.locomotion, 'sprint');
    tick(f.motor, 360);
    assert.equal(f.motor.state.stamina, 1);
    tick(f.motor, 30, { moveZ: -1, sprint: true });
    assert.equal(f.motor.state.locomotion, 'sprint');
  } finally { f.cleanup(); }
});

test('mantle verifies a ledge and climbs onto it with swept movement', async () => {
  const f = await fixture([{ center: [0, .45, -1.5], half: [2, .45, 1] }]);
  try {
    tick(f.motor, 10);
    tick(f.motor, 1, { moveZ: -1, jump: true });
    assert.equal(f.motor.state.locomotion, 'climb');
    tick(f.motor, 32);
    assert.ok(f.motor.state.position.z < -.7);
    assert.ok(f.motor.state.position.y > .9);
    tick(f.motor, 20);
    assert.equal(f.motor.state.grounded, true);
  } finally { f.cleanup(); }
});

test('mantle rejects a ledge whose landing has insufficient headroom', async () => {
  const f = await fixture([
    { center: [0, .45, -1.5], half: [2, .45, 1] },
    { center: [0, 2.1, -1.5], half: [2, .1, 1] },
  ]);
  try {
    tick(f.motor, 10);
    tick(f.motor, 1, { moveZ: -1, jump: true });
    assert.notEqual(f.motor.state.locomotion, 'climb');
    tick(f.motor, 80, { moveZ: -1 });
    assert.ok(f.motor.state.position.z > -.5, 'standing capsule cannot pass through the overhang');
  } finally { f.cleanup(); }
});

test('crouching clears the actual one-metre platform and 2.15m scaffold gap', async () => {
  const f = await fixture([
    { center: [0, .5, -2], half: [2, .5, 3] },
    { center: [0, 2.25, -2], half: [2, .1, 1] },
  ], { x: 0, y: 1.03, z: .5 });
  try {
    tick(f.motor, 10);
    tick(f.motor, 120, { moveZ: -1, crouch: true });
    assert.ok(f.motor.state.position.z < -2);
    tick(f.motor, 10);
    assert.equal(f.motor.state.crouched, true);
    assert.ok(f.motor.state.position.y >= 1);
  } finally { f.cleanup(); }
});

test('restoring a saved position under a beam crouches before the first physics tick', async () => {
  const f = await fixture([
    { center: [0, .5, -2], half: [2, .5, 3] },
    { center: [0, 2.25, -2], half: [2, .1, 1] },
  ], { x: 0, y: 1.03, z: .5 });
  try {
    f.motor.teleport({ x: 0, y: 1.025, z: -2 }, false);
    assert.equal(f.motor.state.crouched, true, 'legacy standing saves must detect destination headroom');
    assert.ok(Math.abs(f.motor.collider.shape.halfHeight - .225) < .001);
    tick(f.motor, 10);
    assert.equal(f.motor.state.crouched, true);
    assert.ok(Math.abs(f.motor.state.position.y - 1.025) < .01);
    f.motor.teleport({ x: 0, y: 1.025, z: .5 }, true);
    assert.equal(f.motor.state.crouched, true, 'explicit crouch stance survives a restore into open space');
    f.motor.teleport({ x: 0, y: 1.025, z: .5 }, false);
    assert.equal(f.motor.state.crouched, false);
  } finally { f.cleanup(); }
});

test('camera sphere sweeps keep its near plane away from surfaces and ignore the player', async () => {
  const f = await fixture([{ center: [0, 2, 3], half: [2, 2, .1] }]);
  try {
    const distance = f.world.cameraDistance({ x: 0, y: 1.5, z: 0 }, { x: 0, y: 0, z: 1 }, 5);
    assert.ok(distance > 2.5 && distance < 2.65);
    assert.equal(f.world.cameraDistance({ x: 0, y: 1.5, z: 0 }, { x: 0, y: 0, z: -1 }, 5), 5);
  } finally { f.cleanup(); }
});

test('door obstacle toggles update physics queries immediately', async () => {
  const f = await fixture([{ id: 'door', center: [0, 1.2, -2], half: [1, 1.2, .08] }]);
  try {
    const origin = { x: 0, y: 1, z: 0 }, direction = { x: 0, y: 0, z: -1 };
    assert.ok(f.world.raycast(origin, direction, 5));
    assert.equal(f.world.setObstacleEnabled('door', false), true);
    assert.equal(f.world.raycast(origin, direction, 5), null);
    f.world.setObstacleEnabled('door', true);
    assert.ok(f.world.raycast(origin, direction, 5));
  } finally { f.cleanup(); }
});

test('motor displacement is identical at 30 and 60 render frames per second', async () => {
  const a = await fixture(), b = await fixture();
  try {
    const input = { ...idle, moveX: .3, moveZ: -.7, sprint: true };
    for (let i = 0; i < 120; i++) a.motor.step(1 / 60, input);
    for (let i = 0; i < 60; i++) b.motor.step(1 / 30, input);
    assert.deepEqual(a.motor.state.position, b.motor.state.position);
    assert.equal(a.motor.state.stamina, b.motor.state.stamina);
  } finally { a.cleanup(); b.cleanup(); }
});

test('lake buoyancy holds the head above the water and permits horizontal swimming',async()=>{
  const f=await fixture();
  try{
    f.motor.teleport({x:0,y:1,z:0});f.motor.setWaterLevel(2);
    for(let i=0;i<180;i++)f.motor.step(1/60,{...idle,moveX:1});
    assert.equal(f.motor.state.locomotion,'swim');
    assert.ok(Math.abs(f.motor.state.position.y-1.05)<.03);
    assert.ok(f.motor.state.position.x>4);
    f.motor.setWaterLevel(null);for(let i=0;i<120;i++)f.motor.step(1/60,idle);
    assert.equal(f.motor.state.grounded,true);
  }finally{f.cleanup();}
});

test('retiring streamed collision removes old obstacles without deleting the player',async()=>{
  const f=await fixture();
  try{
    f.world.addChunk('east',[{center:[3,1,0],half:[.5,1,1]}]);
    assert.equal(f.world.chunkCount,1);
    assert.ok(f.world.raycast({x:0,y:1,z:0},{x:1,y:0,z:0},5));
    f.world.removeChunk('east');assert.equal(f.world.chunkCount,0);
    assert.equal(f.world.raycast({x:0,y:1,z:0},{x:1,y:0,z:0},5),null);
    for(let i=0;i<30;i++)f.motor.step(1/60,idle);
    assert.equal(f.motor.state.grounded,true);
  }finally{f.cleanup();}
});
