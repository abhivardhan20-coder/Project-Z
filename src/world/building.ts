import * as THREE from 'three/webgpu';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import type { CollisionBox } from './collision';
import type { BuildingPlan, BuildingVisual, DoorVisual, WorldTarget } from './types';

type V3 = [number, number, number];
type Materials = Record<string, THREE.MeshStandardMaterial>;
let resources: { materials: Materials; textures: Set<THREE.Texture>; signs: Map<string, THREE.MeshStandardMaterial> } | undefined;

const NAMES = {
  shop: ['SHARMA PROVISIONS', 'KIRAN GENERAL STORE', 'NANDINI STORES'],
  house: ['MEHTA RESIDENCE', 'GULMOHAR HOUSE', 'SEN RESIDENCE'],
  apartment: ['ASHOK APARTMENTS', 'LAKE VIEW RESIDENCY', 'NEELKANTH HOMES'],
  clinic: ['RIVERBEND CLINIC', 'SEVA HEALTH CENTRE', 'LOTUS MEDICAL'],
  warehouse: ['GANESH WAREHOUSE', 'EASTERN SUPPLY CO.', 'SAI DISTRIBUTORS'],
} as const;
const SUBTITLES = {
  shop: 'GROCERIES  ·  HOUSEHOLD  ·  DAILY ESSENTIALS', house: 'PRIVATE RESIDENCE',
  apartment: 'RESIDENTIAL ASSOCIATION', clinic: 'CONSULTATION  ·  FIRST AID  ·  PHARMACY',
  warehouse: 'STORAGE & DISTRIBUTION',
};

function rng(seed: number) {
  return () => {
    seed |= 0; seed = seed + 0x6D2B79F5 | 0;
    let t = Math.imul(seed ^ seed >>> 15, 1 | seed);
    t ^= t + Math.imul(t ^ t >>> 7, 61 | t);
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}

function drawnTexture(width: number, height: number, draw: (context: CanvasRenderingContext2D) => void) {
  // Geometry and collider generation also run in headless validation.
  let texture: THREE.Texture;
  if (typeof document !== 'undefined') {
    const canvas = document.createElement('canvas'); canvas.width = width; canvas.height = height;
    const context = canvas.getContext('2d');
    if (!context) throw new Error('Canvas is required for building textures.');
    draw(context); texture = new THREE.CanvasTexture(canvas);
  } else {
    texture = new THREE.DataTexture(new Uint8Array([220, 220, 210, 255]), 1, 1);
    texture.needsUpdate = true;
  }
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
  texture.anisotropy = 4;
  return texture;
}

function sharedResources() {
  if (resources) return resources;
  const textures = new Set<THREE.Texture>();
  const map = (kind: 'plaster' | 'tile' | 'wood' | 'shutter') => {
    const random = rng(7181 + kind.length);
    const texture = drawnTexture(256, 256, ctx => {
      ctx.fillStyle = kind === 'wood' ? '#b09c76' : kind === 'tile' ? '#b8b5a2' : '#e0d9bc';
      ctx.fillRect(0, 0, 256, 256);
      for (let i = 0; i < 3800; i++) {
        ctx.fillStyle = random() > .5 ? 'rgba(28,33,25,.09)' : 'rgba(255,250,231,.11)';
        ctx.fillRect(random() * 256, random() * 256, 1 + random() * 3, 1 + random() * 4);
      }
      for (let i = 0; i < 25; i++) {
        const x = random() * 256, y = random() * 256, radius = 15 + random() * 66;
        const gradient = ctx.createRadialGradient(x, y, 0, x, y, radius);
        gradient.addColorStop(0, 'rgba(44,44,26,.18)'); gradient.addColorStop(1, 'rgba(44,44,26,0)');
        ctx.fillStyle = gradient; ctx.fillRect(x - radius, y - radius, radius * 2, radius * 2);
      }
      if (kind === 'tile') {
        ctx.strokeStyle = 'rgba(35,46,37,.25)'; ctx.lineWidth = 2;
        for (let n = 0; n <= 256; n += 64) {
          ctx.beginPath(); ctx.moveTo(n, 0); ctx.lineTo(n, 256); ctx.moveTo(0, n); ctx.lineTo(256, n); ctx.stroke();
        }
      }
      if (kind === 'wood') {
        for (let i = 0; i < 100; i++) {
          ctx.fillStyle = 'rgba(44,31,17,.15)'; ctx.fillRect(random() * 256, 0, 1 + random(), 256);
        }
      }
      if (kind === 'shutter') {
        for (let y = 0; y < 256; y += 12) {
          ctx.fillStyle = 'rgba(25,36,31,.65)'; ctx.fillRect(0, y, 256, 2);
          ctx.fillStyle = 'rgba(250,241,201,.3)'; ctx.fillRect(0, y + 3, 256, 1);
        }
      }
      if (kind === 'plaster') {
        for (let i = 0; i < 40; i++) {
          const x = random() * 256, y = random() * 230;
          ctx.fillStyle = 'rgba(70,62,35,.07)'; ctx.fillRect(x, y, 3 + random() * 10, 18 + random() * 68);
        }
      }
    });
    textures.add(texture); return texture;
  };
  const plaster = map('plaster'), tile = map('tile'), wood = map('wood'), shutter = map('shutter');
  const materials: Materials = {};
  const material = (name: string, color: number, roughness = .9, metalness = 0, texture?: THREE.Texture) => {
    materials[name] = new THREE.MeshStandardMaterial({ color, roughness, metalness, ...(texture ? { map: texture } : {}) });
    return materials[name];
  };
  [0xc3b28b, 0x8caa9b, 0xb79e89, 0xaaaab1, 0xe0c18e, 0xabc1ad].forEach((color, i) => material(`wall${i}`, color, .98, 0, plaster));
  material('cream', 0xdbd4ba, .96, 0, plaster);
  material('concrete', 0x777b6f, .98, 0, plaster);
  material('tile', 0xe0dfce, .84, 0, tile);
  material('steel', 0x4c574c, .73, .54);
  material('dark', 0x222e29, .9);
  material('wood', 0x968261, .98, 0, wood);
  material('shutter', 0x78847a, .79, .36, shutter);
  material('fabric', 0x919479, .97);
  material('green', 0x647b54, .82, .1);
  material('red', 0x9c5f3e, .93);
  material('glass', 0x607d78, .22, .3);
  const clear = material('clear', 0x87a99d, .14, .2);
  clear.transparent = true; clear.opacity = .18; clear.depthWrite = false;
  const glow = material('glow', 0xf7d39d, .6);
  glow.emissive.setHex(0xffc47b); glow.emissiveIntensity = .8;
  resources = { materials, textures, signs: new Map() };
  return resources;
}

function signMaterial(kind: BuildingPlan['kind'], variant: number, shelter: boolean) {
  const pool = sharedResources(), index = ((variant % 3) + 3) % 3, key = `${kind}:${index}:${shelter}`;
  if (pool.signs.has(key)) return pool.signs.get(key)!;
  const texture = drawnTexture(768, 192, ctx => {
    ctx.fillStyle = kind === 'clinic' ? '#a5b8a9' : kind === 'shop' ? '#676b43' : '#34514a';
    ctx.fillRect(0, 0, 768, 192);
    ctx.strokeStyle = '#c7c2a5'; ctx.lineWidth = 3; ctx.strokeRect(10, 10, 748, 172);
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.fillStyle = kind === 'clinic' ? '#24483b' : '#efdfb9';
    ctx.font = 'bold 43px Arial, sans-serif'; ctx.fillText(NAMES[kind][index], 384, 71, 690);
    ctx.font = '19px Arial, sans-serif'; ctx.fillText(shelter ? 'SHELTER  ·  BEDS INSIDE' : SUBTITLES[kind], 384, 130, 690);
    const random = rng(19 + variant);
    for (let i = 0; i < 160; i++) {
      ctx.fillStyle = 'rgba(30,33,23,.18)'; ctx.fillRect(random() * 768, random() * 192, 1 + random() * 16, 1 + random() * 2);
    }
  });
  pool.textures.add(texture);
  const material = new THREE.MeshStandardMaterial({ map: texture, roughness: .86, metalness: .08 });
  pool.signs.set(key, material); return material;
}

/** Procedural architecture in local metres; proxies and targets are returned in world space. */
export function* createBuildingStages(plan: BuildingPlan): Generator<void, BuildingVisual | null, void> {
  if (![plan.x, plan.y ?? 0, plan.z, plan.width, plan.depth, plan.floors, plan.rotation].every(Number.isFinite)
    || plan.width < 6 || plan.depth < 6 || plan.floors < 1) throw new Error('Building footprint must be at least 6 × 6 metres.');
  const group = new THREE.Group(); group.name = plan.id;
  group.position.set(plan.x, plan.y ?? 0, plan.z); group.rotation.y = plan.rotation;
  const boxes: CollisionBox[] = [], targets: WorldTarget[] = [], lootVisuals = new Map<string, THREE.Object3D>();
  const doors = new Map<string, DoorVisual>();
  const batches = new Map<THREE.Material, THREE.BufferGeometry[]>();
  const ownedGeometry = new Set<THREE.BufferGeometry>(), transform = new THREE.Object3D();
  const m = sharedResources().materials, random = rng(plan.seed), w = plan.width, d = plan.depth;
  const front = d / 2, back = -d / 2, floor = .18, storey = 3.38, height = Math.max(1, Math.floor(plan.floors)) * storey;
  const variant = Math.abs(Math.floor(plan.variant));
  const wall = m[`wall${variant % 6}`], name = NAMES[plan.kind][variant % 3];
  const cos = Math.cos(plan.rotation), sin = Math.sin(plan.rotation);
  const world = ([x, y, z]: V3): V3 => [plan.x + cos * x + sin * z, y + (plan.y ?? 0), plan.z - sin * x + cos * z];
  const solid = (size: V3, position: V3, localRotation = 0) => boxes.push({
    center: world(position), half: [size[0] / 2, size[1] / 2, size[2] / 2], rotationY: plan.rotation + localRotation,
  });
  const geometry = (value: THREE.BufferGeometry, material: THREE.Material, position: V3, rotation: V3 = [0, 0, 0]) => {
    transform.position.set(...position); transform.rotation.set(...rotation); transform.scale.set(1, 1, 1); transform.updateMatrix();
    value.applyMatrix4(transform.matrix);
    const list = batches.get(material) ?? []; list.push(value); batches.set(material, list);
  };
  const box = (size: V3, position: V3, material: THREE.Material, collision = false) => {
    geometry(new THREE.BoxGeometry(...size), material, position);
    if (collision) solid(size, position);
  };
  const cylinder = (radius: number, length: number, position: V3, material: THREE.Material, rotation: V3 = [0, 0, 0]) =>
    geometry(new THREE.CylinderGeometry(radius, radius, length, 8), material, position, rotation);
  const plane = (width: number, height: number, position: V3, material: THREE.Material, rotation: V3 = [0, 0, 0]) =>
    geometry(new THREE.PlaneGeometry(width, height), material, position, rotation);
  let completed = false;
  try {
  yield;
  // A raised slab gives the entrance a readable threshold while remaining a walkable step.
  box([w + .16, .28, d + .16], [0, .04, 0], m.concrete, true);
  if (plan.enterable) {
    // The tile is above the slab; coplanar top faces previously flickered as the camera moved.
    box([w - .28, .012, d - .28], [0, floor + .006, 0], m.tile);
    box([.26, 3.2, d - .52], [-w / 2 + .13, 1.6, 0], wall, true);
    box([.26, 3.2, d - .52], [w / 2 - .13, 1.6, 0], wall, true);
    box([w, 3.2, .26], [0, 1.6, back + .13], wall, true);
    const doorWidth = 2.05, sideWidth = (w - doorWidth) / 2;
    // These panels have real visual openings. The window proxies keep the glazing solid.
    for (const sign of [-1, 1]) {
      const x = sign * (doorWidth / 2 + sideWidth / 2);
      solid([sideWidth, 3.2, .26], [x, 1.6, front - .13]);
      const windowWidth = Math.min(1.65, sideWidth - .42), post = (sideWidth - windowWidth) / 2;
      box([sideWidth, .91, .26], [x, .455, front - .13], wall);
      box([sideWidth, .7, .26], [x, 2.85, front - .13], wall);
      for (const edge of [-1, 1]) box([post, 1.59, .26], [x + edge * (sideWidth - post) / 2, 1.705, front - .13], wall);
      plane(windowWidth, 1.59, [x, 1.705, front - .125], m.clear);
      for (const edge of [-1, 1]) {
        box([.045, 1.6, .055], [x + edge * windowWidth / 2, 1.7, front + .015], m.wood);
        box([windowWidth + .16, .07, .14], [x, 1.7 + edge * .8, front + .025], m.cream);
      }
      box([.04, 1.6, .055], [x, 1.7, front + .015], m.wood);
      box([windowWidth, .045, .07], [x, 1.65, front + .025], m.wood);
      for (let i = -2; i <= 2; i++) box([.024, 1.57, .035], [x + i * windowWidth / 6, 1.7, front + .08], m.steel);
    }
    yield;
    box([doorWidth, .42, .26], [0, 2.99, front - .13], wall, true);
    for (const edge of [-1, 1]) box([.10, 2.62, .34], [edge * (doorWidth / 2 + .04), 1.48, front - .08], m.wood);
    box([doorWidth + .16, .10, .34], [0, 2.78, front - .08], m.wood);
    const doorId = `${plan.id}:door`, leafWidth = doorWidth - .04, leafHeight = 2.54, thickness = .085;
    const hinge = new THREE.Group(); hinge.name = `${doorId}:hinge`;
    hinge.position.set(-leafWidth / 2, floor, front - .12); group.add(hinge);
    const doorBatches = new Map<THREE.Material, THREE.BufferGeometry[]>();
    const doorPart = (size: V3, position: V3, material: THREE.Material) => {
      const value = new THREE.BoxGeometry(...size); value.translate(...position);
      const list = doorBatches.get(material) ?? []; list.push(value); doorBatches.set(material, list);
    };
    doorPart([leafWidth, leafHeight, thickness], [leafWidth / 2, leafHeight / 2, 0], m.wood);
    // Raised panels and handles appear on both sides so the closed door reads from either room.
    for (const face of [-1, 1]) {
      for (const x of [leafWidth * .25, leafWidth * .75]) for (const y of [.66, 1.85]) {
        doorPart([leafWidth * .38, .91, .02], [x, y, face * (thickness / 2 + .009)], m.wood);
      }
      doorPart([.075, .25, .025], [leafWidth - .17, 1.27, face * .062], m.steel);
      doorPart([.21, .035, .045], [leafWidth - .25, 1.30, face * .095], m.steel);
    }
    for (const y of [.35, 1.27, 2.19]) doorPart([.09, .16, .11], [.015, y, 0], m.steel);
    for (const [material, parts] of doorBatches) {
      const value = mergeGeometries(parts)!; parts.forEach(part => part.dispose()); ownedGeometry.add(value);
      const mesh = new THREE.Mesh(value, material); mesh.castShadow = mesh.receiveShadow = true; hinge.add(mesh);
    }
    const [hx, hy, hz] = world([hinge.position.x, hinge.position.y, hinge.position.z]);
    const target: WorldTarget = {
      id: doorId, kind: 'door', position: { x: 0, y: 0, z: 0 }, label: 'Open door', buildingId: plan.id, buildingName: name,
      door: { hinge: { x: hx, y: hy, z: hz }, width: leafWidth, height: leafHeight, thickness, closedRotation: plan.rotation },
    };
    const door: DoorVisual = { id: doorId, target, setOpen(open) {
      const angle = open ? Math.PI / 2 : 0, rotationY = plan.rotation + angle;
      hinge.rotation.y = angle;
      const center: V3 = [hx + Math.cos(rotationY) * leafWidth / 2, hy + leafHeight / 2, hz - Math.sin(rotationY) * leafWidth / 2];
      target.position = { x: center[0], y: hy + 1.27, z: center[2] };
      target.label = open ? 'Close door' : 'Open door';
      return { id: doorId, center, half: [leafWidth / 2, leafHeight / 2, thickness / 2], rotationY };
    } };
    boxes.push(door.setOpen(false)); targets.push(target); doors.set(doorId, door);
    box([w, .18, d], [0, 3.29, 0], m.cream, true);
    // Skirting, floor runner, and wall dado make the interior legible at human scale.
    for (const x of [-w / 2 + .145, w / 2 - .145]) box([.05, .14, d - .26], [x, floor + .07, 0], m.wood);
    box([w - .26, .14, .05], [0, floor + .07, back + .145], m.wood);
    box([1.65, .012, 1.2], [0, floor + .022, front - .95], m.fabric);
  } else {
    box([w, height, d], [0, height / 2, 0], wall, true);
    const shutterWidth = Math.min(w * .72, 5.8);
    box([shutterWidth, 2.46, .045], [0, 1.41, front + .025], m.shutter);
    for (const x of [-shutterWidth / 2, shutterWidth / 2]) box([.15, 2.6, .16], [x, 1.42, front + .07], m.steel);
    box([shutterWidth + .3, .22, .28], [0, 2.75, front + .12], m.concrete);
    box([.12, .18, .07], [.25, .46, front + .065], m.steel);
  }
  if (plan.enterable && height > storey) box([w, height - storey, d], [0, storey + (height - storey) / 2, 0], wall, true);
  yield;

  // Facade construction is shared across all variants, with distinct material palettes and detail.
  for (const x of [-w / 2 + .07, w / 2 - .07]) box([.20, height, .15], [x, height / 2, front + .07], m.cream);
  for (let level = 1; level <= plan.floors; level++) {
    box([w + .22, .14, d + .22], [0, level * storey - .09, 0], m.concrete);
    if (level === plan.floors) continue;
    const y = level * storey + 1.6;
    const count = Math.max(2, Math.floor(w / 2.5));
    for (let i = 0; i < count; i++) {
      const x = (i - (count - 1) / 2) * (w - 1.3) / count;
      box([1.22, 1.62, .08], [x, y, front + .045], m.cream);
      box([1.05, 1.43, .045], [x, y, front + .095], m.glass);
      box([.035, 1.46, .035], [x, y, front + .13], m.wood);
      box([1.1, .035, .035], [x, y, front + .13], m.wood);
      box([1.36, .10, .46], [x, y + .84, front + .20], m.concrete);
      box([1.28, .10, .26], [x, y - .83, front + .10], m.cream);
      if ((i + level + variant) % 3 === 0) {
        box([.62, .37, .42], [x + .48, y - .61, front + .28], m.cream);
        for (let vent = 0; vent < 4; vent++) box([.49, .02, .012], [x + .48, y - .72 + vent * .07, front + .496], m.dark);
      }
      if (i % 3 === 2) yield;
    }
    if ((plan.kind === 'apartment' || plan.kind === 'house') && (level + variant) % 2 === 1) {
      const bw = w - .65, bz = front + .64;
      box([bw, .15, 1.35], [0, level * storey + .015, bz], m.concrete);
      box([bw, .045, .045], [0, level * storey + 1.02, front + 1.27], m.steel);
      box([bw, .04, .04], [0, level * storey + .48, front + 1.27], m.steel);
      for (let x = -bw / 2; x <= bw / 2; x += .36) box([.023, 1, .023], [x, level * storey + .53, front + 1.27], m.steel);
      for (const side of [-1, 1]) box([.04, .045, 1.2], [side * bw / 2, level * storey + 1.02, front + .67], m.steel);
    }
    // Side elevations retain windows so buildings work from every street, not just one camera.
    for (const side of [-1, 1]) for (const z of [-d * .26, d * .2]) {
      box([.07, 1.43, 1.12], [side * (w / 2 + .035), y, z], m.cream);
      box([.035, 1.27, .96], [side * (w / 2 + .075), y, z], m.glass);
      box([.28, .09, 1.30], [side * (w / 2 + .1), y + .75, z], m.concrete);
    }
    yield;
  }
  // Parapet, rooftop tank, service pipes, and an individual sign survive silhouette distances.
  box([w + .24, .16, d + .24], [0, height + .015, 0], m.concrete);
  for (const z of [back, front]) box([w + .15, .55, .17], [0, height + .30, z], wall);
  for (const x of [-w / 2, w / 2]) box([.17, .55, d], [x, height + .30, 0], wall);
  const tx = w * .23, tz = -d * .24;
  box([1.4, .24, 1.4], [tx, height + .25, tz], m.concrete);
  cylinder(.55, 1.12, [tx, height + .92, tz], m.dark);
  for (const y of [height + .48, height + .74, height + 1.14, height + 1.39]) cylinder(.57, .045, [tx, y, tz], m.steel);
  cylinder(.43, .08, [tx, height + 1.52, tz], m.dark);
  cylinder(.055, height + .35, [w / 2 + .08, height / 2 + .12, back + .65], m.steel);
  for (let y = .7; y < height; y += 1.7) box([.11, .035, .22], [w / 2 + .06, y, back + .65], m.steel);
  box([Math.min(w - .35, 7.4), .52, .12], [0, 2.98, front + .17], m.dark);
  plane(Math.min(w - .43, 7.32), .47, [0, 2.99, front + .235], signMaterial(plan.kind, variant, plan.shelter));
  if (plan.kind === 'shop' || plan.kind === 'clinic') {
    geometry(new THREE.BoxGeometry(w - .2, .07, 1.20), plan.kind === 'clinic' ? m.green : m.red,
      [0, 2.80, front + .77], [.13, 0, 0]);
    box([w - .2, .22, .055], [0, 2.62, front + 1.37], plan.kind === 'clinic' ? m.green : m.red);
    for (const x of [-w / 2 + .25, w / 2 - .25]) cylinder(.027, 1.28, [x, 2.50, front + .65], m.steel, [.25, 0, 0]);
  }
  yield;

  if (plan.enterable) {
    const rearRoom = d >= 8.6 && ['house', 'apartment', 'clinic'].includes(plan.kind);
    const partitionZ = back + 3.2;
    if (rearRoom) {
      const piece = (w - 2.05) / 2;
      for (const side of [-1, 1]) box([piece, 3.02, .14], [side * (1.025 + piece / 2), 1.69, partitionZ], m.cream, true);
      box([2.05, .44, .14], [0, 2.98, partitionZ], m.cream, true);
    }
    // Shelf lives on the left wall, with an unbroken central aisle wider than two metres.
    const shelfX = -w / 2 + .60, shelfZ = front - Math.min(d * .36, 3.0);
    solid([.60, 1.80, 1.7], [shelfX, 1.08, shelfZ]);
    // The shelf proxy is solid, but the visible furniture has open cubbies and real contents.
    box([.065, 1.80, 1.7], [shelfX - .27, 1.08, shelfZ], m.wood);
    box([.018, 1.58, 1.51], [shelfX - .225, 1.13, shelfZ], m.dark);
    for (let i = 0; i < 4; i++) box([.55, .045, 1.63], [shelfX + .015, .40 + i * .44, shelfZ], m.wood);
    for (const z of [shelfZ - .82, shelfZ + .82]) box([.53, 1.8, .045], [shelfX + .045, 1.09, z], m.wood);
    const lootId = `${plan.id}:loot:0`;
    const supplies = new THREE.Group(); supplies.name = `${lootId}:contents`; group.add(supplies); lootVisuals.set(lootId, supplies);
    const supplyGeometry: THREE.BufferGeometry[] = [];
    for (let i = 0; i < 7; i++) {
      const level = i % 3, z = shelfZ + ((i * .37) % 1.1) - .55;
      const value = new THREE.BoxGeometry(.22, .22 + random() * .15, .18);
      value.translate(shelfX + .07, .56 + level * .44, z); supplyGeometry.push(value);
    }
    const combined = mergeGeometries(supplyGeometry)!; supplyGeometry.forEach(value => value.dispose());
    ownedGeometry.add(combined);
    const content = new THREE.Mesh(combined, plan.kind === 'clinic' ? m.cream : m.green);
    content.castShadow = true; supplies.add(content);
    const target = world([shelfX + .75, 1.10, shelfZ]);
    targets.push({ id: lootId, kind: 'loot', position: { x: target[0], y: target[1], z: target[2] },
      label: plan.kind === 'clinic' ? 'Search medical supplies' : 'Search pantry', buildingId: plan.id, buildingName: name,
      loot: plan.kind === 'clinic' ? { bandage: 1 + Math.floor(random() * 2), water: 1 }
        : { food: 1 + Math.floor(random() * 2), water: 1 + Math.floor(random() * 2) } });
    yield;

    const tableX = w / 2 - 1.15, tableZ = front - Math.min(3.6, d * .52);
    const isShop = plan.kind === 'shop' || plan.kind === 'warehouse';
    box([1.25, .12, 1.55], [tableX, .96, tableZ], m.wood);
    for (const dx of [-.48, .48]) for (const dz of [-.62, .62]) box([.08, .74, .08], [tableX + dx, .55, tableZ + dz], m.steel);
    solid([1.25, .87, 1.55], [tableX, .615, tableZ]);
    if (isShop) {
      box([.34, .20, .34], [tableX, 1.10, tableZ + .35], m.dark);
      box([.26, .20, .10], [tableX, 1.26, tableZ + .22], m.steel);
      for (let i = 0; i < 3; i++) box([.28, .33, .26], [tableX + .22, 1.18, tableZ - .50 + i * .29], m.red);
    } else {
      box([.50, .045, .36], [tableX, 1.05, tableZ], m.cream);
      cylinder(.07, .12, [tableX - .3, 1.09, tableZ + .35], m.cream);
      // Empty chair stays on the wall side of the table, leaving the doorway route clear.
      const chairZ = tableZ - 1.2;
      box([.53, .065, .52], [tableX, .64, chairZ], m.wood);
      box([.53, .52, .06], [tableX, .91, chairZ - .24], m.wood);
      for (const dx of [-.20, .20]) for (const dz of [-.20, .20]) box([.045, .44, .045], [tableX + dx, .40, chairZ + dz], m.steel);
      solid([.55, .93, .55], [tableX, .645, chairZ]);
    }
    yield;
    const sinkX = w / 2 - .6, sinkZ = back + 1.0;
    box([.66, .82, 1.0], [sinkX, .59, sinkZ], m.cream, true);
    box([.74, .06, 1.06], [sinkX, 1.03, sinkZ], m.steel);
    box([.46, .015, .67], [sinkX - .03, 1.067, sinkZ], m.dark);
    cylinder(.02, .28, [sinkX + .2, 1.20, sinkZ], m.steel);
    cylinder(.02, .20, [sinkX + .11, 1.34, sinkZ], m.steel, [0, 0, Math.PI / 2]);
    // An emissive wall lantern marks a usable interior without dozens of point lights.
    box([.34, .08, .18], [0, 2.59, back + .29], m.steel);
    box([.23, .24, .11], [0, 2.43, back + .31], m.glow);
    box([.34, .06, .18], [0, 2.29, back + .29], m.steel);

    if (plan.shelter) {
      const bedX = -w / 2 + 1.03, bedZ = back + 1.65;
      box([1.31, .13, 2.22], [bedX, .47, bedZ], m.steel);
      for (const x of [bedX - .54, bedX + .54]) for (const z of [bedZ - .95, bedZ + .95]) cylinder(.035, .31, [x, .32, z], m.steel);
      box([1.23, .19, 2.12], [bedX, .63, bedZ], m.fabric);
      box([1.16, .038, 1.27], [bedX, .745, bedZ + .34], m.green);
      box([.90, .13, .38], [bedX, .79, bedZ - .73], m.cream);
      solid([1.33, .64, 2.25], [bedX, .5, bedZ]);
      const bedTarget = world([bedX + .93, .9, bedZ]);
      targets.push({ id: `${plan.id}:bed`, kind: 'bed', position: { x: bedTarget[0], y: bedTarget[1], z: bedTarget[2] },
        label: 'Sleep until morning', buildingId: plan.id, buildingName: name });
    } else {
      const crateX = -w / 2 + 1.04, crateZ = back + 1.10;
      box([1.2, .65, .9], [crateX, .51, crateZ], m.wood, true);
      for (const dx of [-.41, .41]) box([.055, .68, .93], [crateX + dx, .53, crateZ], m.steel);
      const secondId = `${plan.id}:loot:1`, secondGeometry = new THREE.BoxGeometry(.64, .24, .51);
      ownedGeometry.add(secondGeometry);
      const contents = new THREE.Mesh(secondGeometry, m.red); contents.position.set(crateX, .955, crateZ); contents.castShadow = true;
      group.add(contents); lootVisuals.set(secondId, contents);
      const secondTarget = world([crateX + .90, .98, crateZ]);
      targets.push({ id: secondId, kind: 'loot', position: { x: secondTarget[0], y: secondTarget[1], z: secondTarget[2] },
        label: 'Search storage crate', buildingId: plan.id, buildingName: name,
        loot: { food: 1, ...(random() > .45 ? { bandage: 1 } : { water: 1 }) } });
    }
  }
  yield;

  for (const [material, geometries] of batches) {
    const merged = mergeGeometries(geometries);
    geometries.forEach(value => value.dispose());
    batches.delete(material);
    if (!merged) throw new Error('Building material batch could not be merged.');
    merged.computeBoundingSphere(); ownedGeometry.add(merged);
    const mesh = new THREE.Mesh(merged, material);
    mesh.castShadow = material !== m.clear && material !== m.glow; mesh.receiveShadow = true;
    mesh.name = `${plan.id}:architecture`; group.add(mesh);
    yield;
  }
  let disposed = false;
  completed = true;
  return { group, boxes, targets, lootVisuals, doors, dispose() {
    if (disposed) return; disposed = true;
    for (const value of ownedGeometry) value.dispose();
    group.removeFromParent(); group.clear(); lootVisuals.clear(); doors.clear();
  } };
  } finally {
    if (!completed) {
      for (const geometries of batches.values()) for (const value of geometries) value.dispose();
      for (const value of ownedGeometry) value.dispose();
      batches.clear(); ownedGeometry.clear(); group.removeFromParent(); group.clear(); lootVisuals.clear(); doors.clear();
    }
  }
}

/** Synchronous construction remains available for tests and immediate startup callers. */
export function createBuilding(plan: BuildingPlan): BuildingVisual {
  const stages = createBuildingStages(plan);
  let step = stages.next();
  while (!step.done) step = stages.next();
  if (!step.value) throw new Error('Building construction was cancelled.');
  return step.value;
}

/** Called once when the entire world closes, never when an individual chunk unloads. */
export function disposeBuildingResources() {
  if (!resources) return;
  Object.values(resources.materials).forEach(material => material.dispose());
  resources.signs.forEach(material => material.dispose());
  resources.textures.forEach(texture => texture.dispose());
  resources = undefined;
}
