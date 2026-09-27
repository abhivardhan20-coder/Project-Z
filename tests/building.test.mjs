import test from 'node:test';
import assert from 'node:assert/strict';
import { createBuilding, createBuildingStages, disposeBuildingResources } from '../src/world/building.ts';
import { BufferGeometry } from 'three/webgpu';
import { createCollisionWorld } from '../src/world/collision.ts';
import { PlayerMotor } from '../src/player/motor.ts';
import { ExplorationSession } from '../src/game/exploration.ts';

const base = { id: 'test:house', x: 23, z: 23, width: 8, depth: 10, floors: 2,
  rotation: 0, kind: 'house', enterable: true, shelter: true, variant: 0, seed: 1723 };
const input = { moveX: 0, moveZ: 0, sprint: false, walk: false, crouch: false, jump: false };
const tick = (motor, count, movement = {}) => {
  for (let i = 0; i < count; i++) motor.step(1 / 60, { ...input, ...movement });
};

test('procedural buildings preserve deterministic loot and bounded shared material batches', () => {
  for (const kind of ['house', 'shop', 'clinic', 'apartment', 'warehouse']) {
    const plan = { ...base, kind, shelter: kind === 'house', variant: 4 };
    const a = createBuilding(plan), b = createBuilding(plan);
    try {
      assert.deepEqual(a.targets, b.targets);
      assert.deepEqual(a.boxes, b.boxes);
      assert.ok(a.boxes.length < 25);
      let draws = 0;
      a.group.traverse(value => { if (value.isMesh) draws++; });
      assert.ok(draws <= 20, `${kind} used ${draws} material batches`);
      assert.equal(new Set(a.targets.map(target => target.id)).size, a.targets.length);
      assert.ok(a.targets.every(target => target.buildingId === plan.id));
      assert.ok(a.targets.filter(target => target.kind === 'loot').every(target => a.lootVisuals.has(target.id)));
      for (const box of a.boxes) {
        assert.ok([...box.center, ...box.half, box.rotationY].every(Number.isFinite));
        assert.ok(box.half.every(value => value > 0));
      }
    } finally { a.dispose(); a.dispose(); b.dispose(); }
  }
});

test('doors begin shut, physically block entry, and working hinges allow entry and exit in every orientation', async () => {
  for (const rotation of [0, Math.PI / 2, Math.PI, -Math.PI / 2]) {
    const building = createBuilding({ ...base, rotation });
    const terrain = { center: [23, -.5, 23], half: [30, .5, 30] };
    const world = await createCollisionWorld([], [terrain, ...building.boxes], false);
    const forward = { x: Math.sin(rotation), z: Math.cos(rotation) };
    const motor = new PlayerMotor(world, { x: 23 + forward.x * 7, y: .05, z: 23 + forward.z * 7 });
    const session = new ExplorationSession(null); session.setTargets(building.targets);
    try {
      tick(motor, 15);
      tick(motor, 90, { moveX: -forward.x, moveZ: -forward.z });
      const blockedDistance = (motor.state.position.x - 23) * forward.x + (motor.state.position.z - 23) * forward.z;
      assert.ok(blockedDistance > 5.1, 'closed door must block the capsule');
      const target = session.nearby(motor.state.position, false, world);
      assert.equal(target?.kind, 'door'); assert.equal(target.label, 'Open door');
      const result = session.interact(target, motor.state.position, false, world);
      assert.equal(result?.door?.open, true, result?.message);
      const door = building.doors.get(target.id), pose = door.setOpen(true);
      assert.equal(world.setObstaclePose(pose.id, pose.center, pose.rotationY), true);
      tick(motor, 120, { moveX: -forward.x, moveZ: -forward.z });
      const insideDistance = (motor.state.position.x - 23) * forward.x + (motor.state.position.z - 23) * forward.z;
      assert.ok(insideDistance < 3.8, `door blocked at local z ${insideDistance}`);
      assert.ok(motor.state.position.y > .17, 'player stands on raised interior slab');
      tick(motor, 200, { moveX: forward.x, moveZ: forward.z });
      const outsideDistance = (motor.state.position.x - 23) * forward.x + (motor.state.position.z - 23) * forward.z;
      assert.ok(outsideDistance > 5.5, `exit blocked at local z ${outsideDistance}`);
    } finally { motor.dispose(); world.dispose(); building.dispose(); }
  }
});

test('elevated rural buildings translate floors, targets and both door poses together', () => {
  const a = createBuilding(base), b = createBuilding({ ...base, y: 37.25 });
  try {
    assert.equal(b.group.position.y, 37.25);
    for (let i = 0; i < a.boxes.length; i++) assert.ok(Math.abs(b.boxes[i].center[1] - a.boxes[i].center[1] - 37.25) < 1e-8);
    for (let i = 0; i < a.targets.length; i++) assert.ok(Math.abs(b.targets[i].position.y - a.targets[i].position.y - 37.25) < 1e-8);
    const first = a.doors.get(`${base.id}:door`).setOpen(true), second = b.doors.get(`${base.id}:door`).setOpen(true);
    assert.ok(Math.abs(second.center[1] - first.center[1] - 37.25) < 1e-8);
  } finally { a.dispose(); b.dispose(); }
});

// Flood the walkable floor with a capsule-sized disc. Every interaction must have
// an approach position connected to the entrance, including the minimum footprint.
test('furnished rooms retain a walkable approach to every loot container and bed', () => {
  for (const kind of ['house', 'shop', 'clinic', 'apartment', 'warehouse']) {
    for (const [width, depth] of [[6, 6], [8, 10], [12, 14]]) {
      const building = createBuilding({ ...base, x: 0, z: 0, width, depth, kind, shelter: true });
      try {
        const solids = building.boxes.filter(box => box.center[1] + box.half[1] > .22 && box.center[1] - box.half[1] < 1.96);
        const radius = .30, step = .20;
        const clear = (x, z) => !solids.some(box => {
          const dx = Math.max(0, Math.abs(x - box.center[0]) - box.half[0]);
          const dz = Math.max(0, Math.abs(z - box.center[2]) - box.half[2]);
          return dx * dx + dz * dz < radius * radius;
        });
        const queue = [[0, Math.round((depth / 2 - .7) / step)]], visited = new Set();
        const approaches = new Set();
        for (let index = 0; index < queue.length; index++) {
          const [gx, gz] = queue[index], key = `${gx},${gz}`;
          if (visited.has(key)) continue;
          visited.add(key);
          const x = gx * step, z = gz * step;
          if (Math.abs(x) > width / 2 || Math.abs(z) > depth / 2 || !clear(x, z)) continue;
          for (const target of building.targets) {
            if (Math.hypot(x - target.position.x, z - target.position.z) < .8) approaches.add(target.id);
          }
          queue.push([gx + 1, gz], [gx - 1, gz], [gx, gz + 1], [gx, gz - 1]);
        }
        for (const target of building.targets) assert.ok(approaches.has(target.id), `${kind} ${width}×${depth} cannot reach ${target.kind}`);
      } finally { building.dispose(); }
    }
  }
});

test('unloading a building disposes its geometry without invalidating shared neighbour materials', () => {
  const a = createBuilding(base), b = createBuilding({ ...base, id: 'neighbour', x: 40 });
  let disposedGeometry = 0, disposedMaterials = 0;
  a.group.traverse(mesh => {
    if (!mesh.isMesh) return;
    mesh.geometry.addEventListener('dispose', () => disposedGeometry++);
    mesh.material.addEventListener('dispose', () => disposedMaterials++);
  });
  a.dispose();
  assert.ok(disposedGeometry > 0);
  assert.equal(disposedMaterials, 0);
  assert.ok(b.group.children.length > 0);
  b.dispose(); disposeBuildingResources();
});

test('cooperative building generation releases unfinished geometry when cancelled at different stages', () => {
  const originalTransform = BufferGeometry.prototype.applyMatrix4, originalDispose = BufferGeometry.prototype.dispose;
  try {
    for (const limit of [2, 4, 10, 22, 30]) {
      const created = new Set(), disposed = new Set();
      BufferGeometry.prototype.applyMatrix4 = function(matrix) { created.add(this); return originalTransform.call(this, matrix); };
      BufferGeometry.prototype.dispose = function() { disposed.add(this); return originalDispose.call(this); };
      const stages = createBuildingStages({ ...base, width: 28, depth: 28, floors: 4 });
      let result;
      for (let i = 0; i < limit; i++) { result = stages.next(); if (result.done) break; }
      if (result.done) result.value.dispose(); else assert.equal(stages.return(null).done, true);
      assert.ok(created.size > 0);
      for (const geometry of created) assert.ok(disposed.has(geometry), `stage ${limit} leaked unfinished geometry`);
    }
  } finally {
    BufferGeometry.prototype.applyMatrix4 = originalTransform; BufferGeometry.prototype.dispose = originalDispose;
  }
});
