import * as THREE from 'three/webgpu';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import type { CollisionBox } from './collision';

export interface JourneyFlags {
  fieldKit: boolean;
  serviceCache: boolean;
  shelterOpen: boolean;
  powerRestored: boolean;
  rested: boolean;
}

/** Three authored encounters, in metres. All solid geometry has an explicit coarse proxy. */
export function createJourneyWorld() {
  const group = new THREE.Group();
  group.name = 'Journey encounters';
  const collisionBoxes: CollisionBox[] = [];
  const batches = new Map<THREE.Material, THREE.BufferGeometry[]>();
  const materials = new Set<THREE.Material>();
  const textures = new Set<THREE.Texture>();
  const dynamicGeometry = new Set<THREE.BufferGeometry>();
  const transform = new THREE.Object3D();
  let flags: JourneyFlags = { fieldKit: false, serviceCache: false, shelterOpen: false, powerRestored: false, rested: false };
  let disposed = false;

  function surface(color: number, roughness = .85, metalness = 0) {
    const material = new THREE.MeshStandardMaterial({ color, roughness, metalness });
    materials.add(material);
    return material;
  }
  const concrete = surface(0x65665a, .98);
  const steel = surface(0x343e36, .72, .62);
  const rust = surface(0x75543a, .97, .2);
  const painted = surface(0x626c56, .86, .26);
  const cream = surface(0xb6b29a, .94);
  const yellow = surface(0xc8a25e, .88, .15);
  const dark = surface(0x131e19, .94);
  const canvas = surface(0x67725b, .99);
  const wood = surface(0x796649, .97);
  const screen = surface(0x2e6248, .55, .12);
  screen.emissive.setHex(0x78b98a);
  screen.emissiveIntensity = 0;
  const lightGlass = surface(0xc9aa73, .5);
  lightGlass.emissive.setHex(0xffc483);
  lightGlass.emissiveIntensity = .02;

  const addStatic = (geometry: THREE.BufferGeometry, material: THREE.Material, position: [number, number, number], rotation: [number, number, number] = [0, 0, 0]) => {
    transform.position.set(...position); transform.rotation.set(...rotation); transform.scale.set(1, 1, 1); transform.updateMatrix();
    geometry.applyMatrix4(transform.matrix);
    const list = batches.get(material) ?? [];
    list.push(geometry); batches.set(material, list);
  };
  const box = (size: [number, number, number], position: [number, number, number], material: THREE.Material, solid = false, id?: string) => {
    addStatic(new THREE.BoxGeometry(...size), material, position);
    if (solid) collisionBoxes.push({ center: position, half: [size[0] / 2, size[1] / 2, size[2] / 2], ...(id ? { id } : {}) });
  };
  const tube = (radius: number, height: number, position: [number, number, number], material = steel, rotation: [number, number, number] = [0, 0, 0]) => {
    addStatic(new THREE.CylinderGeometry(radius, radius, height, 8), material, position, rotation);
  };
  const movingBox = (size: [number, number, number], position: [number, number, number], material: THREE.Material, parent: THREE.Group) => {
    const geometry = new THREE.BoxGeometry(...size); dynamicGeometry.add(geometry);
    const mesh = new THREE.Mesh(geometry, material); mesh.position.set(...position); mesh.castShadow = true; mesh.receiveShadow = true; parent.add(mesh);
    return mesh;
  };
  function sign(title: string, subtitle: string, width: number, height: number, position: [number, number, number], background = '#34483c') {
    const drawing = document.createElement('canvas'); drawing.width = 768; drawing.height = 256;
    const ctx = drawing.getContext('2d');
    if (!ctx) throw new Error('Canvas support is needed for district signage.');
    ctx.fillStyle = background; ctx.fillRect(0, 0, 768, 256);
    ctx.strokeStyle = '#b5b498'; ctx.lineWidth = 3; ctx.strokeRect(16, 15, 736, 226);
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.fillStyle = '#e3dcc1'; ctx.font = '600 64px Arial, sans-serif'; ctx.fillText(title, 384, 100, 685);
    ctx.fillStyle = '#b6bda7'; ctx.font = '24px Arial, sans-serif'; ctx.fillText(subtitle, 384, 176, 684);
    // Deterministic abrasion keeps the sign legible at the intended viewing distance.
    for (let i = 0; i < 140; i++) {
      ctx.fillStyle = i % 3 ? 'rgba(12,26,18,.13)' : 'rgba(234,219,179,.13)';
      ctx.fillRect((i * 137) % 768, (i * 71) % 256, 2 + i % 13, 1 + i % 3);
    }
    const texture = new THREE.CanvasTexture(drawing); texture.colorSpace = THREE.SRGBColorSpace; texture.anisotropy = 4; textures.add(texture);
    const material = new THREE.MeshStandardMaterial({ map: texture, roughness: .88, metalness: .15 }); materials.add(material);
    addStatic(new THREE.PlaneGeometry(width, height), material, position);
  }

  function supplyCrate(x: number, floor: number, z: number, label: string) {
    const w = 1.02, h = .52, d = .65;
    box([w, .09, d], [x, floor + .06, z], steel);
    box([w, h, .06], [x, floor + h / 2 + .07, z + d / 2], painted);
    box([w, h, .06], [x, floor + h / 2 + .07, z - d / 2], painted);
    box([.06, h, d], [x - w / 2, floor + h / 2 + .07, z], painted);
    box([.06, h, d], [x + w / 2, floor + h / 2 + .07, z], painted);
    collisionBoxes.push({ center: [x, floor + .31, z], half: [.54, .31, .36] });
    for (const offset of [-.37, .37]) {
      box([.07, h + .035, .02], [x + offset, floor + .34, z + .365], steel);
      box([.07, .1, .045], [x + offset, floor + .54, z + .385], rust);
    }
    for (const offset of [-.535, .535]) box([.045, .06, .22], [x + offset, floor + .38, z], steel);
    const lid = new THREE.Group(); lid.position.set(x, floor + .62, z - d / 2); group.add(lid);
    movingBox([1.1, .09, .73], [0, 0, d / 2], painted, lid);
    for (const offset of [-.37, .37]) movingBox([.075, .018, .75], [offset, .055, d / 2], steel, lid);
    const contents = new THREE.Group(); contents.position.set(x, floor + .29, z); group.add(contents);
    movingBox([.32, .22, .32], [-.19, 0, -.02], cream, contents);
    movingBox([.08, .015, .26], [-.19, .119, -.02], rust, contents);
    movingBox([.27, .23, .28], [.21, 0, .04], wood, contents);
    sign(label, 'CIVIL RELIEF / SECTOR 07', .66, .22, [x, floor + .32, z + .361]);
    return { lid, contents };
  }

  // First encounter: a relief crate left beside a discarded field pallet.
  for (let plank = 0; plank < 5; plank++) box([1.48, .055, .14], [2, .028, 16.57 + plank * .19], wood);
  const field = supplyCrate(2, .065, 17, 'FIELD SUPPLIES');
  tube(.025, 1.5, [2.7, .75, 16.82]);
  box([.92, .42, .06], [2.7, 1.5, 16.82], steel);
  sign('FIELD SUPPLIES', 'TAKE WHAT YOU NEED', .85, .35, [2.7, 1.5, 16.853]);
  box([.4, .04, .25], [1.21, .025, 17.22], canvas);

  // A maintenance deck: small steps, a clear low passage, then the service cache.
  for (let step = 0; step < 5; step++) {
    const height = (step + 1) * .2;
    box([1.56, height, .54], [6.2, height / 2, -14 - step * .5], concrete, true);
    box([1.57, .025, .055], [6.2, height + .0125, -13.765 - step * .5], yellow);
  }
  box([1.6, 1, .88], [6.2, .5, -16.67], concrete, true);
  box([1.6, 1, 3], [6.2, .5, -18.5], concrete, true);
  // Weathered planks over the top are visual detail; the proxy stays flat.
  for (let plank = 0; plank < 5; plank++) box([.3, .025, 3.73], [5.56 + plank * .32, 1.006, -18.1], wood);
  for (const x of [5.43, 6.97]) {
    for (const z of [-17.17, -18.47]) {
      tube(.045, 2.39, [x, 1.195, z]);
      collisionBoxes.push({ center: [x, 1.2, z], half: [.045, 1.2, .045] });
      box([.21, .06, .2], [x, .03, z], steel);
      tube(.061, .12, [x, 1.74, z], rust);
    }
    tube(.037, 1.4, [x, 2.23, -17.82], steel, [Math.PI / 2, 0, 0]);
  }
  box([1.7, .18, 1.4], [6.2, 2.24, -17.82], steel, true);
  for (let strip = 0; strip < 8; strip++) box([.1, .025, 1.44], [5.48 + strip * .205, 2.345, -17.82], rust);
  box([1.68, .16, .07], [6.2, 2.21, -17.08], yellow);
  sign('MAINTENANCE', 'LOW CLEARANCE / CROUCH TO PASS', 1.48, .24, [6.2, 2.45, -17.035], '#3d4434');
  const cache = supplyCrate(6.2, 1.025, -19.24, 'SERVICE CACHE');

  // Rest shelter, open to the approach at +Z. The only removable proxy is the door.
  box([3.6, .2, 4.2], [5.5, .1, -54.9], concrete, true);
  box([1.45, .1, .4], [5.5, .05, -52.6], concrete, true);
  box([.14, 2.4, 4.2], [3.77, 1.4, -54.9], painted, true);
  box([.14, 2.4, 4.2], [7.23, 1.4, -54.9], painted, true);
  box([3.6, 2.4, .14], [5.5, 1.4, -56.93], painted, true);
  for (const x of [4.3, 6.7]) box([1.2, 2.4, .16], [x, 1.4, -52.88], painted, true);
  box([1.2, .15, .16], [5.5, 2.525, -52.88], steel, true);
  box([3.9, .15, 4.5], [5.5, 2.675, -54.87], steel, true);
  for (let seam = 0; seam < 8; seam++) box([.035, .038, 4.46], [3.7 + seam * .51, 2.77, -54.87], rust);
  for (const x of [3.83, 7.17]) box([.1, 2.4, .1], [x, 1.4, -52.76], steel);
  for (const x of [4.85, 6.15]) box([.065, 2.38, .045], [x, 1.39, -52.765], steel);
  for (let slat = 0; slat < 10; slat++) {
    const y = .42 + slat * .21;
    box([1.12, .012, .014], [4.3, y, -52.791], rust);
    box([1.12, .012, .014], [6.7, y, -52.791], rust);
  }
  collisionBoxes.push({ id: 'shelter-door', center: [5.5, 1.35, -52.8], half: [.6, 1.2, .08] });
  const door = new THREE.Group(); door.name = 'Shelter hinged door'; door.position.set(4.9, .2, -52.8); group.add(door);
  movingBox([1.16, 2.24, .085], [.6, 1.12, 0], cream, door);
  movingBox([.86, .26, .026], [.6, 1.74, .055], dark, door);
  movingBox([.035, .24, .11], [1.02, 1.05, .065], steel, door);
  for (const y of [.32, 1.9]) movingBox([.08, .12, .12], [.025, y, 0], rust, door);
  box([3.78, .44, .13], [5.5, 2.7, -52.57], steel);
  sign('REST POINT / 04', 'TRANSIT RELIEF / FINANCIAL DISTRICT', 3.54, .37, [5.5, 2.7, -52.5]);
  sign('04', 'SHELTER', .62, .38, [6.73, 1.7, -52.79]);
  sign('KEEP THE LIGHT ON', 'CHECK THE POWER / LEAVE SUPPLIES', 1.25, .44, [5.52, 1.83, -56.85]);

  // Bunk and console stay against the sides, leaving a direct route between them.
  box([.86, .12, 1.82], [4.5, .53, -55.5], steel);
  collisionBoxes.push({ center: [4.5, .52, -55.5], half: [.43, .32, .91] });
  box([.78, .16, 1.72], [4.5, .67, -55.5], canvas);
  box([.7, .11, .34], [4.5, .8, -56.1], cream);
  box([.8, .05, .82], [4.5, .775, -55.04], painted);
  for (const x of [4.18, 4.82]) for (const z of [-54.77, -56.23]) tube(.026, .32, [x, .36, z]);
  for (const z of [-54.61, -56.4]) tube(.025, .85, [4.5, .7, z], steel, [0, 0, Math.PI / 2]);
  box([.7, .9, .54], [6.6, .65, -55.2], steel, true);
  box([.73, .06, .58], [6.6, 1.13, -55.2], cream);
  box([.52, .31, .055], [6.6, .87, -54.901], dark);
  box([.36, .13, .06], [6.6, .92, -54.866], screen);
  for (const x of [6.42, 6.55, 6.68, 6.81]) box([.045, .045, .07], [x, .73, -54.86], x > 6.7 ? rust : cream);
  sign('AUXILIARY POWER', 'INSERT FUSE / RESET', .66, .18, [6.6, 1.4, -55.48]);
  box([.04, 1.21, .045], [6.88, 1.75, -55.45], steel);
  box([.85, .04, .045], [6.49, 2.35, -55.45], steel);
  const poweredLamp = new THREE.Group(); group.add(poweredLamp);
  movingBox([.5, .065, .24], [5.55, 2.48, -54.4], steel, poweredLamp);
  movingBox([.39, .035, .17], [5.55, 2.426, -54.4], lightGlass, poweredLamp);
  const lamp = new THREE.PointLight(0xffc48b, 0, 5.5, 2); lamp.position.set(5.55, 2.25, -54.4); lamp.castShadow = false; group.add(lamp);
  box([.53, .18, .33], [6.62, .3, -56.27], wood, true);
  box([.44, .035, .24], [6.62, .408, -56.27], canvas);

  // Merge by material after authoring; animated lids/door and lamp remain independent.
  for (const [material, geometries] of batches) {
    const merged = mergeGeometries(geometries, false);
    for (const geometry of geometries) geometry.dispose();
    if (!merged) throw new Error('Could not assemble journey scene geometry.');
    const mesh = new THREE.Mesh(merged, material); mesh.castShadow = true; mesh.receiveShadow = true; group.add(mesh);
    dynamicGeometry.add(merged);
  }
  batches.clear();

  return {
    group,
    collisionBoxes,
    sync(nextFlags: JourneyFlags) {
      flags = { ...nextFlags };
      field.contents.visible = !flags.fieldKit;
      cache.contents.visible = !flags.serviceCache;
      screen.emissiveIntensity = flags.powerRestored ? .55 : 0;
      lightGlass.emissiveIntensity = flags.powerRestored ? 2.2 : .02;
    },
    update(dt: number, elapsed: number) {
      const blend = 1 - Math.exp(-Math.max(0, dt) * 8);
      field.lid.rotation.x = THREE.MathUtils.lerp(field.lid.rotation.x, flags.fieldKit ? -1.23 : 0, blend);
      cache.lid.rotation.x = THREE.MathUtils.lerp(cache.lid.rotation.x, flags.serviceCache ? -1.23 : 0, blend);
      door.rotation.y = THREE.MathUtils.lerp(door.rotation.y, flags.shelterOpen ? 1.47 : 0, blend);
      const warmth = flags.rested ? 21 : 17;
      lamp.intensity = THREE.MathUtils.lerp(lamp.intensity, flags.powerRestored ? warmth + Math.sin(elapsed * 1.2) * .22 : 0, blend);
    },
    dispose() {
      if (disposed) return;
      disposed = true;
      for (const geometry of dynamicGeometry) geometry.dispose();
      for (const material of materials) material.dispose();
      for (const texture of textures) texture.dispose();
      lamp.dispose();
      group.clear();
    },
  };
}
