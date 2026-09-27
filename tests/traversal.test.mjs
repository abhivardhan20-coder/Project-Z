import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createStreet } from '../src/world/street.ts';
import { createProps } from '../src/world/props.ts';
import { createJourneyWorld } from '../src/world/journey.ts';
import { createCollisionWorld } from '../src/world/collision.ts';
import { PlayerMotor } from '../src/player/motor.ts';
import { JourneySession } from '../src/game/session.ts';

// Exercise the production scene generators. Only canvas painting is stubbed;
// all geometry, collision metadata, physics, and interaction rules are real.
function canvasStub() {
  const canvas = { width: 0, height: 0 };
  const noop = () => {};
  const gradient = () => ({ addColorStop: noop });
  const context = {
    canvas, fillRect: noop, clearRect: noop, fillText: noop, strokeRect: noop,
    beginPath: noop, lineTo: noop, moveTo: noop, stroke: noop,
    createLinearGradient: gradient, createRadialGradient: gradient,
    drawImage: noop, putImageData: noop,
    getImageData: (_x, _y, width, height) => ({ data: new Uint8ClampedArray(width * height * 4) }),
  };
  canvas.getContext = () => context;
  return canvas;
}

let street, props, encounters;
before(() => {
  const previous = globalThis.document;
  globalThis.document = { createElement: name => {
    assert.equal(name, 'canvas');
    return canvasStub();
  } };
  try { street = createStreet(); props = createProps(); encounters = createJourneyWorld(); }
  finally {
    if (previous === undefined) delete globalThis.document;
    else globalThis.document = previous;
  }
});

after(() => {
  encounters?.dispose();
  const geometries = new Set(), materials = new Set(), textures = new Set();
  for (const group of [street?.group, props?.group]) group?.traverse(object => {
    if (object.geometry) geometries.add(object.geometry);
    for (const material of object.material ? [].concat(object.material) : []) {
      materials.add(material);
      for (const value of Object.values(material)) if (value?.isTexture) textures.add(value);
    }
  });
  for (const resource of [...geometries, ...materials, ...textures]) resource.dispose();
});

const idle = { moveX: 0, moveZ: 0, sprint: false, walk: false, crouch: false, jump: false };
function tick(motor, frames, input = {}) {
  for (let i = 0; i < frames; i++) motor.step(1 / 60, { ...idle, ...input });
}
async function fixture(position) {
  const collision = await createCollisionWorld([street.group, props.group], encounters.collisionBoxes);
  const motor = new PlayerMotor(collision, position);
  const session = new JourneySession();
  tick(motor, 10);
  return { collision, motor, session, dispose: () => { motor.dispose(); collision.dispose(); } };
}
const interact = fixture => {
  const { motor, session, collision } = fixture;
  const target = session.nearby(motor.state.position, motor.state.crouched, collision);
  return { target, result: session.interact(target, motor.state.position, motor.state.crouched, collision) };
};

test('actual scaffold steps require crouching, allow key collection, and permit the return route', async () => {
  const f = await fixture({ x: 6.2, y: .05, z: -13 });
  try {
    tick(f.motor, 130, { moveZ: -1 });
    assert.ok(f.motor.state.position.y > .98, `could not ascend steps: ${JSON.stringify(f.motor.state.position)}`);
    assert.ok(f.motor.state.position.z < -16.4 && f.motor.state.position.z > -17.1, 'standing capsule must stop at the low beam');
    assert.equal(f.session.nearby(f.motor.state.position, false, f.collision), null, 'cache cannot be reached before traversing the beam');
    tick(f.motor, 110, { moveZ: -1, crouch: true });
    assert.ok(f.motor.state.position.z < -18.3, `crouched route blocked: ${JSON.stringify(f.motor.state.position)}`);
    assert.ok(f.motor.state.position.y > .98);
    const found = interact(f);
    assert.equal(found.target?.id, 'serviceCache');
    assert.equal(found.result?.changed, true);
    assert.equal(f.session.data.inventory.key, 1);
    tick(f.motor, 15);
    assert.equal(f.motor.state.crouched, true, 'beam must prevent premature standing');
    tick(f.motor, 170, { moveZ: 1, crouch: true });
    tick(f.motor, 15);
    assert.equal(f.motor.state.crouched, false);
    assert.ok(f.motor.state.position.z > -15);
  } finally { f.dispose(); }
});

test('actual service cache cannot be collected from street level beside the scaffold', async () => {
  const f = await fixture({ x: 4.95, y: .05, z: -18.55 });
  try {
    assert.equal(f.session.nearby(f.motor.state.position, false, f.collision), null);
    assert.equal(f.session.data.inventory.key, 0);
  } finally { f.dispose(); }
});

test('actual shelter door blocks entry until unlocked, then its aisle reaches power and bed', async () => {
  const f = await fixture({ x: 5.5, y: .05, z: -51.6 });
  try {
    tick(f.motor, 80, { moveZ: -1 });
    assert.ok(f.motor.state.position.z > -52.5, 'closed door must block the player');
    const locked = interact(f);
    assert.equal(locked.target?.id, 'shelterDoor');
    assert.equal(locked.result?.changed, false);

    f.session.data.flags.fieldKit = true;
    f.session.data.flags.serviceCache = true;
    f.session.data.inventory.key = 1;
    f.session.data.inventory.battery = 1;
    const unlocked = interact(f);
    assert.equal(unlocked.result?.changed, true);
    f.collision.setObstacleEnabled('shelter-door', false);
    tick(f.motor, 42, { moveZ: -1 });
    tick(f.motor, 15);
    assert.ok(f.motor.state.position.z < -54.3 && f.motor.state.position.z > -55.2,
      `door or aisle blocks entry: ${JSON.stringify(f.motor.state.position)}`);
    assert.ok(f.motor.state.position.y >= .18);
    const power = interact(f);
    assert.equal(power.target?.id, 'power');
    assert.equal(power.result?.changed, true);
    assert.equal(f.session.data.flags.powerRestored, true);
    assert.equal(f.session.data.inventory.battery, 0);
    const rest = interact(f);
    assert.equal(rest.target?.id, 'rest');
    assert.equal(rest.result?.rest, true);
    assert.equal(f.session.update(3), true);
    assert.equal(f.session.data.flags.rested, true);
  } finally { f.dispose(); }
});

test('actual field supplies are reachable without intersecting the crate', async () => {
  const f = await fixture({ x: 2, y: .05, z: 19 });
  try {
    tick(f.motor, 23, { moveZ: -1 });
    tick(f.motor, 12);
    const found = interact(f);
    assert.equal(found.target?.id, 'fieldKit');
    assert.equal(found.result?.changed, true);
    assert.equal(f.session.data.inventory.battery, 1);
    assert.equal(f.session.data.inventory.water, 2);
    assert.ok(f.motor.state.position.z > 17.36, 'player must remain outside the solid crate');
  } finally { f.dispose(); }
});
