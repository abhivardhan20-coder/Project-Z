import * as THREE from 'three/webgpu';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
import type { CollisionBox } from './collision';

/** Hand-composed street dressing. Static meshes are batched by material, foliage is instanced. */
export function createProps(): { group: THREE.Group; update: (elapsed: number, wind: number) => void } {
  const group = new THREE.Group();
  group.name = 'Street dressing / instanced vegetation';
  const collisionBoxes: CollisionBox[] = [];
  group.userData.collisionBoxes = collisionBoxes;
  let seed = 73193;
  const random = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };
  const range = (a: number, b: number) => a + random() * (b - a);
  const batches = new Map<THREE.Material, THREE.BufferGeometry[]>();
  const transform = new THREE.Object3D();
  let parentMatrix = new THREE.Matrix4();

  function surface(color: string, streaks = false): THREE.CanvasTexture {
    const canvas = document.createElement('canvas'); canvas.width = canvas.height = 256;
    const ctx = canvas.getContext('2d')!;
    ctx.fillStyle = color; ctx.fillRect(0, 0, 256, 256);
    for (let i = 0; i < 4200; i++) {
      const light = random() > 0.45;
      ctx.fillStyle = light ? `rgba(213,208,174,${range(0.015, 0.10)})` : `rgba(24,28,23,${range(0.02, 0.12)})`;
      ctx.fillRect(range(0, 256), range(0, 256), range(1, 7), range(1, 4));
    }
    if (streaks) for (let i = 0; i < 85; i++) {
      ctx.fillStyle = `rgba(33,27,14,${range(0.015, 0.10)})`;
      ctx.fillRect(range(0, 256), range(0, 256), range(1, 5), range(15, 90));
    }
    const map = new THREE.CanvasTexture(canvas);
    map.colorSpace = THREE.SRGBColorSpace;
    map.wrapS = map.wrapT = THREE.RepeatWrapping;
    map.anisotropy = 4;
    return map;
  }
  const mat = (color: THREE.ColorRepresentation, roughness = 0.8, metalness = 0, map?: THREE.Texture) =>
    new THREE.MeshStandardMaterial({ color, roughness, metalness, ...(map ? { map } : {}) });
  const rubber = mat('#141916', 0.96);
  const chassis = mat('#27312d', 0.77, 0.55);
  const chrome = mat('#888d82', 0.39, 0.78);
  const dirtyGlass = mat('#263e3e', 0.22, 0.55);
  const paleGlass = mat('#8c9682', 0.31, 0.38);
  const canvas = mat('#bca352', 0.95, 0, surface('#cfb959', true));
  const greenPaint = mat('#b4c5a2', 0.64, 0.4, surface('#28583b', true));
  const bluePaint = mat('#9bb6af', 0.62, 0.42, surface('#617f7b', true));
  const creamPaint = mat('#eee7c9', 0.8, 0.1, surface('#b8bda8', true));
  const busRed = mat('#b59270', 0.7, 0.35, surface('#66382b', true));
  const wood = mat('#a69474', 1, 0, surface('#675d44', true));
  const bark = mat('#c1b19c', 1, 0, surface('#5e5740', true));
  const concrete = mat('#a7aa99', 0.96, 0, surface('#818375', true));
  const terracotta = mat('#9f7962', 1, 0, surface('#795644', true));
  const rust = mat('#825f3b', 0.96, 0.26);
  const paper = mat('#b2b199', 0.98);
  const darkSoil = mat('#353d29', 1);
  const amber = mat('#ca9b3f', 0.32, 0.15);
  const redLight = mat('#933d2c', 0.3, 0.14);
  const headlight = mat('#b8bcab', 0.17, 0.6);

  function add(geometry: THREE.BufferGeometry, material: THREE.Material, p: number[] = [0, 0, 0], r: number[] = [0, 0, 0], s: number[] = [1, 1, 1]) {
    transform.position.set(p[0], p[1], p[2]);
    transform.rotation.set(r[0], r[1], r[2]);
    transform.scale.set(s[0], s[1], s[2]); transform.updateMatrix();
    geometry.applyMatrix4(transform.matrix).applyMatrix4(parentMatrix);
    // Rounded boxes and extrusions have groups, but batching uses a single shared material.
    geometry.clearGroups();
    const list = batches.get(material) ?? [];
    list.push(geometry); batches.set(material, list);
  }
  function box(material: THREE.Material, p: number[], size: number[], r: number[] = [0, 0, 0], radius = 0) {
    const geometry = radius > 0
      ? new RoundedBoxGeometry(size[0], size[1], size[2], 2, radius)
      : new THREE.BoxGeometry(size[0], size[1], size[2]);
    add(geometry, material, p, r);
  }
  function cylinder(material: THREE.Material, p: number[], rt: number, rb: number, height: number, r: number[] = [0, 0, 0], segments = 10) {
    add(new THREE.CylinderGeometry(rt, rb, height, segments), material, p, r);
  }
  function rod(material: THREE.Material, a: number[], b: number[], radius: number, tip = radius) {
    const from = new THREE.Vector3(...a as [number, number, number]);
    const to = new THREE.Vector3(...b as [number, number, number]);
    const delta = to.clone().sub(from);
    const geometry = new THREE.CylinderGeometry(tip, radius, delta.length(), 8);
    geometry.applyQuaternion(new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), delta.normalize()));
    add(geometry, material, from.add(to).multiplyScalar(0.5).toArray());
  }
  function vehicleAt(x: number, z: number, angle: number, build: () => void) {
    const origin = new THREE.Object3D(); origin.position.set(x, 0.03, z); origin.rotation.y = angle; origin.updateMatrix();
    parentMatrix = origin.matrix.clone(); build(); parentMatrix = new THREE.Matrix4();
  }
  function wheel(x: number, y: number, z: number, radius: number, width: number) {
    add(new THREE.TorusGeometry(radius * 0.75, radius * 0.25, 8, 24), rubber, [x, y, z], [0, Math.PI / 2, 0], [1, 1, width / (radius * 0.5)]);
    cylinder(chassis, [x, y, z], radius * 0.63, radius * 0.63, width * 0.91, [0, 0, Math.PI / 2], 20);
    cylinder(chrome, [x, y, z], radius * 0.47, radius * 0.47, width * 0.97, [0, 0, Math.PI / 2], 20);
    for (let side = -1; side <= 1; side += 2) {
      cylinder(chassis, [x + side * width * 0.51, y, z], radius * 0.17, radius * 0.17, 0.024, [0, 0, Math.PI / 2], 12);
      for (let i = 0; i < 5; i++) {
        const a = i * Math.PI * 0.4;
        cylinder(rubber, [x + side * width * 0.495, y + Math.sin(a) * radius * 0.32, z + Math.cos(a) * radius * 0.32], 0.027, 0.027, 0.02, [0, 0, Math.PI / 2], 6);
      }
    }
  }
  function sign(text: string, sub: string, bg: string, fg: string, width: number, height: number, p: number[], angle = 0) {
    const c = document.createElement('canvas'); c.width = 512; c.height = 256;
    const ctx = c.getContext('2d')!; ctx.fillStyle = bg; ctx.fillRect(0, 0, 512, 256);
    ctx.strokeStyle = fg; ctx.lineWidth = 5; ctx.strokeRect(12, 12, 488, 232);
    ctx.textAlign = 'center'; ctx.fillStyle = fg; ctx.font = 'bold 56px Arial'; ctx.fillText(text, 256, 119);
    ctx.font = '23px Arial'; ctx.fillText(sub, 256, 174);
    for (let i = 0; i < 90; i++) { ctx.fillStyle = 'rgba(32,30,20,.1)'; ctx.fillRect(range(0, 512), range(0, 256), range(2, 35), range(1, 4)); }
    const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace;
    add(new THREE.PlaneGeometry(width, height), new THREE.MeshStandardMaterial({ map: t, roughness: 0.9 }), p, [0, angle, 0]);
  }

  // Three-wheeler: open passenger compartment, canvas hood, fork and exposed tubular chassis.
  collisionBoxes.push({ center: [-4.9, 1.07, -.8], half: [.86, 1.07, 1.48], rotationY: -.29 });
  vehicleAt(-4.9, -0.8, -0.29, () => {
    box(chassis, [0, 0.43, -0.05], [1.35, 0.15, 2.62], [0, 0, 0], 0.05);
    box(greenPaint, [0, 0.69, -0.78], [1.52, 0.52, 1.1], [0, 0, 0], 0.09);
    box(greenPaint, [0, 0.82, 0.94], [1.18, 0.86, 0.57], [0.14, 0, 0], 0.15);
    box(greenPaint, [0, 1.08, -1.25], [1.51, 0.8, 0.13], [0, 0, 0], 0.065);
    box(canvas, [0, 1.69, -1.24], [1.55, 0.57, 0.12], [0, 0, 0], 0.045);
    box(canvas, [0, 2.02, -0.27], [1.65, 0.26, 2.27], [0, 0, 0], 0.12);
    box(rubber, [0, 1.889, -0.25], [1.59, 0.045, 2.21]);
    box(dirtyGlass, [0, 1.55, 0.842], [1.26, 0.71, 0.037], [0.15, 0, 0], 0.04);
    box(canvas, [0, 1.979, 0.862], [1.49, 0.13, 0.08]);
    box(canvas, [0, 1.133, 0.98], [1.37, 0.11, 0.1]);
    for (const side of [-1, 1]) {
      rod(chassis, [side * 0.7, 0.62, -1.14], [side * 0.7, 1.95, -1.11], 0.032);
      rod(canvas, [side * 0.665, 1.12, 0.97], [side * 0.665, 1.98, 0.78], 0.049);
      rod(chassis, [side * 0.7, 1.87, -1.08], [side * 0.7, 1.87, 0.76], 0.028);
      rod(chrome, [side * 0.765, 0.48, 0.24], [side * 0.765, 0.48, -0.87], 0.026);
      box(greenPaint, [side * 0.738, 0.65, -0.8], [0.09, 0.4, 0.91], [0, 0, 0], 0.035);
      wheel(side * 0.74, 0.35, -0.88, 0.35, 0.23);
      // Curved wheel mudguards.
      add(new THREE.TorusGeometry(0.37, 0.045, 5, 16, Math.PI), greenPaint, [side * 0.76, 0.37, -0.88], [0, Math.PI / 2, 0]);
      rod(chassis, [side * 0.57, 1.44, 0.9], [side * 0.86, 1.55, 1.01], 0.018);
      box(chassis, [side * 0.88, 1.59, 1.01], [0.21, 0.15, 0.05], [0, side * 0.25, 0], 0.025);
      box(paleGlass, [side * 0.88, 1.59, 1.042], [0.165, 0.115, 0.014], [0, side * 0.25, 0], 0.02);
      box(amber, [side * 0.51, 0.87, 1.245], [0.13, 0.14, 0.035], [0.1, 0, 0], 0.025);
      box(redLight, [side * 0.59, 0.76, -1.33], [0.13, 0.19, 0.035]);
    }
    wheel(0, 0.35, 1.1, 0.35, 0.2);
    rod(chrome, [-0.12, 0.38, 1.1], [-0.12, 0.94, 0.91], 0.034);
    rod(chrome, [0.12, 0.38, 1.1], [0.12, 0.94, 0.91], 0.034);
    rod(chassis, [0, 0.86, 0.85], [0, 1.2, 0.5], 0.031);
    rod(chrome, [-0.29, 1.21, 0.5], [0.29, 1.21, 0.5], 0.024);
    box(rubber, [0, 0.87, -0.75], [1.19, 0.19, 0.48], [0, 0, 0], 0.06);
    box(rubber, [0, 1.12, -1.06], [1.2, 0.47, 0.13], [-0.08, 0, 0], 0.04);
    box(rubber, [0, 0.87, 0.15], [0.51, 0.17, 0.46], [0, 0, 0], 0.05);
    box(rubber, [0, 1.08, -0.075], [0.48, 0.43, 0.09], [-0.07, 0, 0], 0.035);
    cylinder(chrome, [0, 0.925, 1.225], 0.21, 0.21, 0.065, [Math.PI / 2, 0, 0], 24);
    cylinder(headlight, [0, 0.925, 1.264], 0.169, 0.169, 0.035, [Math.PI / 2, 0, 0], 24);
    rod(chassis, [-0.67, 0.51, 1.17], [0.67, 0.51, 1.17], 0.035);
    rod(rubber, [-0.25, 1.22, 0.997], [0.21, 1.57, 0.924], 0.011);
    sign('TS 09', 'UA 4862', '#cdb55b', '#222923', 0.36, 0.19, [0, 0.605, 1.255]);
  });

  // Dusty compact hatchback, stranded at the curb with glazed cabin and sunken rear tire.
  collisionBoxes.push({ center: [4.65, .61, -25], half: [.89, .61, 1.9], rotationY: .12 });
  collisionBoxes.push({ center: [4.61, 1.43, -25.33], half: [.76, .32, 1.03], rotationY: .12 });
  vehicleAt(4.65, -25, 0.12, () => {
    box(chassis, [0, 0.4, 0], [1.57, 0.18, 3.57], [0, 0, 0], 0.07);
    box(bluePaint, [0, 0.77, 0], [1.73, 0.56, 3.7], [0, 0, 0], 0.18);
    box(bluePaint, [0, 1.05, 1.1], [1.68, 0.15, 1.42], [-0.08, 0, 0], 0.085);
    box(dirtyGlass, [0, 1.33, -0.33], [1.49, 0.64, 1.79], [0, 0, 0], 0.15);
    box(bluePaint, [0, 1.673, -0.36], [1.44, 0.13, 1.6], [0, 0, 0], 0.06);
    box(dirtyGlass, [0, 1.358, 0.61], [1.43, 0.66, 0.045], [0.48, 0, 0], 0.035);
    box(dirtyGlass, [0, 1.326, -1.35], [1.39, 0.6, 0.04], [-0.37, 0, 0], 0.035);
    for (const side of [-1, 1]) {
      rod(bluePaint, [side * 0.68, 1.66, 0.44], [side * 0.785, 1.04, 0.89], 0.057);
      rod(bluePaint, [side * 0.68, 1.65, -1.08], [side * 0.79, 1.04, -1.5], 0.075);
      rod(bluePaint, [side * 0.749, 1.08, -0.31], [side * 0.717, 1.62, -0.31], 0.041);
      rod(chassis, [side * 0.846, 1.035, -1.44], [side * 0.846, 1.035, 0.88], 0.016);
      box(chassis, [side * 0.873, 0.72, -0.12], [0.015, 0.39, 0.015]);
      box(chrome, [side * 0.88, 0.995, 0.01], [0.025, 0.035, 0.2]);
      box(chrome, [side * 0.88, 0.995, -1], [0.025, 0.035, 0.2]);
      box(bluePaint, [side * 0.954, 1.139, 0.73], [0.25, 0.16, 0.25], [0, 0, 0], 0.055);
      wheel(side * 0.846, 0.42, 1.12, 0.4, 0.22);
      wheel(side * 0.846, 0.38, -1.14, 0.38, 0.23);
      box(headlight, [side * 0.597, 0.892, 1.808], [0.45, 0.22, 0.11], [0, side * 0.12, 0], 0.045);
      box(redLight, [side * 0.67, 0.973, -1.802], [0.27, 0.35, 0.07], [0, 0, 0], 0.045);
      box(rubber, [side * 0.46, 0.562, 1.824], [0.25, 0.12, 0.06], [0, 0, 0], 0.04);
    }
    box(rubber, [0, 0.757, 1.858], [0.63, 0.19, 0.032], [0, 0, 0], 0.02);
    for (let i = 0; i < 3; i++) box(chrome, [0, 0.71 + i * 0.055, 1.879], [0.54, 0.012, 0.016]);
    box(rubber, [0, 0.47, 1.73], [1.57, 0.085, 0.18], [0, 0, 0], 0.03);
    box(chassis, [0, 0.56, -1.84], [1.49, 0.12, 0.08]);
    rod(rubber, [-0.64, 1.095, 0.803], [-0.15, 1.24, 0.735], 0.012);
    rod(rubber, [0.01, 1.095, 0.803], [0.57, 1.24, 0.735], 0.012);
    sign('TS 10 EH', '7294', '#bec2ad', '#282c26', 0.44, 0.18, [0, 0.571, 1.84]);
  });

  collisionBoxes.push({ center: [-3.8, 1.72, -81], half: [1.28, 1.72, 4.65], rotationY: -.08 });
  vehicleAt(-3.8, -81, -0.08, () => {
    box(busRed, [0, 1.29, 0], [2.45, 1.46, 9.2], [0, 0, 0], 0.14);
    box(creamPaint, [0, 2.6, 0], [2.49, 1.44, 9.16], [0, 0, 0], 0.18);
    box(creamPaint, [0, 3.31, 0], [2.52, 0.22, 9.17], [0, 0, 0], 0.1);
    box(dirtyGlass, [0, 2.54, 4.584], [2.21, 1.04, 0.026], [0.025, 0, 0], 0.06);
    box(chassis, [0, 2.55, 4.61], [0.046, 1.05, 0.03]);
    for (const side of [-1, 1]) {
      for (let i = 0; i < 7; i++) {
        box(dirtyGlass, [side * 1.251, 2.64, 3.28 - i * 1.04], [0.024, 0.97, 0.87], [0, 0, 0], 0.015);
        rod(chrome, [side * 1.271, 2.65, 2.87 - i * 1.04], [side * 1.271, 2.65, 3.69 - i * 1.04], 0.011);
      }
      wheel(side * 1.19, 0.55, 2.88, 0.55, 0.3);
      wheel(side * 1.19, 0.55, -2.79, 0.55, 0.34);
      box(headlight, [side * 0.75, 1.2, 4.62], [0.42, 0.21, 0.055], [0, 0, 0], 0.02);
      box(amber, [side * 1.08, 1.25, 4.627], [0.12, 0.16, 0.03]);
    }
    for (let i = 0; i < 5; i++) box(chassis, [0, 1.11 + i * 0.095, 4.612], [0.67, 0.04, 0.055]);
    box(chassis, [0, 0.8, 4.63], [2.28, 0.13, 0.14]);
    sign('17 / SECUNDERABAD', 'CITY SERVICE', '#2c3328', '#b7bda0', 1.92, 0.36, [0, 3.12, 4.59]);
  });

  // Trapezoidal concrete roadblocks have chipped collars and exposed lifting loops.
  for (let i = 0; i < 3; i++) vehicleAt(-1.4 + i * 2.25, -51 - i * 0.4, i * 0.04, () => {
    collisionBoxes.push({ center: [-1.4 + i * 2.25, .575, -51 - i * .4], half: [1, .55, .32], rotationY: i * .04 });
    const shape = new THREE.Shape();
    shape.moveTo(-0.38, 0); shape.lineTo(0.38, 0); shape.lineTo(0.24, 0.44); shape.lineTo(0.14, 1.03); shape.lineTo(-0.14, 1.03); shape.lineTo(-0.24, 0.44); shape.closePath();
    const geo = new THREE.ExtrudeGeometry(shape, { depth: 1.95, bevelEnabled: true, bevelSegments: 1, steps: 1, bevelSize: 0.025, bevelThickness: 0.025 });
    geo.translate(0, 0, -0.975); add(geo, concrete, [0, 0.045, 0], [0, Math.PI / 2, 0]);
    for (let k = 0; k < 3; k++) box(amber, [-0.73 + k * 0.62, 0.76, 0.211], [0.2, 0.28, 0.017], [0, 0, -0.35]);
    for (const x of [-0.66, 0.66]) add(new THREE.TorusGeometry(0.055, 0.012, 5, 10, Math.PI), rust, [x, 1.08, 0]);
  });

  // Practical curb-side dressing: drain grates, broken crates, collapsed temporary fencing.
  for (const [x, z] of [[-8.7, 3], [8.4, -15], [-8.3, -39], [8.6, -64], [-8.5, -104]]) {
    collisionBoxes.push({ center: [x, .45, z], half: [.59, .45, .59] });
    cylinder(terracotta, [x, 0.43, z], 0.57, 0.42, 0.78, [0, 0, 0], 14);
    cylinder(terracotta, [x, 0.843, z], 0.625, 0.625, 0.13, [0, 0, 0], 14);
    cylinder(darkSoil, [x, 0.904, z], 0.555, 0.555, 0.01, [0, 0, 0], 14);
  }
  vehicleAt(7.9, -8, -0.28, () => {
    collisionBoxes.push({ center: [7.9, .4, -8], half: [.62, .4, .41], rotationY: -.28 });
    box(wood, [0, 0.11, 0], [1.24, 0.12, 0.82]);
    for (const side of [-1, 1]) for (let i = 0; i < 4; i++) {
      box(wood, [0, 0.2 + i * 0.14, side * 0.39], [1.24, 0.1, 0.06]);
      box(wood, [side * 0.59, 0.2 + i * 0.14, 0], [0.06, 0.1, 0.76]);
    }
    for (const x of [-0.53, 0.53]) for (const z of [-0.32, 0.32]) box(wood, [x, 0.4, z], [0.08, 0.66, 0.08]);
    box(wood, [0.98, 0.25, 0.36], [1.14, 0.09, 0.67], [0.13, 0.3, -0.38]);
  });
  for (const z of [-7, -31, -56, -103]) for (const side of [-1, 1]) {
    box(chassis, [side * 6.87, 0.037, z], [0.36, 0.035, 0.88]);
    for (let i = 0; i < 7; i++) box(concrete, [side * 6.87, 0.058, z - 0.36 + i * 0.12], [0.34, 0.02, 0.018]);
  }
  // Fallen traffic cone and a few remnants of the evacuation.
  for (const [x, z, rot] of [[2.9, -44, 0], [3.9, -47, 1.3], [-5.6, -16, 0]]) {
    const base = new THREE.Object3D(); base.position.set(x, rot ? 0.24 : 0.02, z); base.rotation.z = rot; base.updateMatrix(); parentMatrix = base.matrix;
    box(rubber, [0, 0.045, 0], [0.43, 0.08, 0.43], [0, 0, 0], 0.035);
    cylinder(rust, [0, 0.36, 0], 0.035, 0.175, 0.58, [0, 0, 0], 14);
    cylinder(creamPaint, [0, 0.39, 0], 0.094, 0.115, 0.09, [0, 0, 0], 14);
    parentMatrix = new THREE.Matrix4();
  }
  for (let i = 0; i < 165; i++) {
    const z = range(-126, 22); const x = random() < 0.77 ? (random() > 0.5 ? 1 : -1) * range(6.3, 9.1) : range(-6, 6);
    if (i % 4 === 0) box(paper, [x, 0.045, z], [range(0.15, 0.35), 0.01, range(0.12, 0.4)], [range(-0.05, 0.06), range(0, 6.28), range(-0.04, 0.04)]);
    else if (i % 7 === 0) cylinder(chrome, [x, 0.065, z], 0.043, 0.043, 0.16, [Math.PI / 2, 0, range(0, 6.28)], 8);
    else add(new THREE.DodecahedronGeometry(range(0.045, 0.14), 0), i % 3 ? concrete : rust, [x, 0.04, z], [range(0, 3), range(0, 3), range(0, 3)], [range(0.8, 2.5), range(0.3, 0.7), 1]);
  }
  box(wood, [-6.1, 0.08, -10.4], [0.17, 0.11, 2.32], [0.02, 0.92, 0]);
  box(wood, [-6.4, 0.14, -11.3], [0.15, 0.09, 1.43], [0, -0.45, 0.04]);
  cylinder(rubber, [8, 0.22, -33], 0.4, 0.4, 0.32, [0.13, 0, 0.05], 20);
  cylinder(darkSoil, [8, 0.389, -33], 0.26, 0.26, 0.025, [0.13, 0, 0.05], 20);

  // Leaf geometry: curved blades, rather than polygon balls. Each instance catches light differently.
  function leafGeometry(): THREE.BufferGeometry {
    const positions: number[] = [], uv: number[] = [], indices: number[] = [];
    for (let i = 0; i < 5; i++) {
      const t = i / 4, width = Math.sin(t * Math.PI) * 0.31;
      positions.push(-width, t, Math.sin(t * Math.PI) * 0.13, 0, t, Math.sin(t * Math.PI) * 0.05, width, t, Math.sin(t * Math.PI) * 0.13);
      uv.push(0, t, 0.5, t, 1, t);
      if (i < 4) { const n = i * 3; indices.push(n, n + 3, n + 1, n + 1, n + 3, n + 4, n + 1, n + 4, n + 2, n + 2, n + 4, n + 5); }
    }
    const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3)); g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2)); g.setIndex(indices); g.computeVertexNormals(); return g;
  }
  const leaves: { position: THREE.Vector3; rotation: THREE.Euler; scale: THREE.Vector3; color: THREE.Color }[] = [];
  const leafColors = ['#4e6134', '#647445', '#7a8750', '#3b502d', '#859153', '#536b3d', '#8a9257'];
  function putLeaf(x: number, y: number, z: number, size: number, angle = random() * 6.28) {
    leaves.push({ position: new THREE.Vector3(x, y, z), rotation: new THREE.Euler(range(-1.3, 1.3), angle, range(-2, 2)), scale: new THREE.Vector3(size * range(0.7, 1.1), size, size), color: new THREE.Color(leafColors[Math.floor(random() * leafColors.length)]) });
  }
  function tree(x: number, z: number, height: number, spread: number) {
    collisionBoxes.push({ center: [x, height * .31, z], half: [height * .033, height * .31, height * .033] });
    const sway = range(-0.45, 0.45);
    rod(bark, [x, 0.1, z], [x + sway, height * 0.62, z + 0.15], height * 0.04, height * 0.017);
    for (let i = 0; i < 5; i++) {
      const angle = i * Math.PI * 0.4 + range(-0.23, 0.23);
      rod(bark, [x, 0.12, z], [x + Math.cos(angle) * 0.7, 0.04, z + Math.sin(angle) * 0.7], 0.16, 0.018);
    }
    for (let b = 0; b < 9; b++) {
      const angle = b * 2.399 + range(-0.2, 0.2), length = spread * range(0.52, 0.96);
      const y = height * range(0.6, 0.85);
      const tip = [x + sway + Math.cos(angle) * length, y, z + Math.sin(angle) * length];
      rod(bark, [x + sway * 0.65, height * (0.37 + b * 0.034), z], tip, height * range(0.013, 0.022), 0.025);
      for (let k = 0; k < 3; k++) {
        const a2 = angle + range(-1.1, 1.1);
        const end = [tip[0] + Math.cos(a2) * spread * 0.29, tip[1] + range(0.2, 0.95), tip[2] + Math.sin(a2) * spread * 0.29];
        rod(bark, [tip[0] - Math.cos(angle) * 0.3, tip[1] - 0.1, tip[2] - Math.sin(angle) * 0.3], end, 0.029, 0.009);
        // Irregular overlapping sprays give a canopy with holes, depth and a soft outline.
        const count = height > 7 ? 85 : 58;
        for (let l = 0; l < count; l++) {
          const az = range(0, Math.PI * 2), el = range(-1, 1), rad = Math.cbrt(random());
          const radius = spread * range(0.29, 0.47) * rad;
          putLeaf(end[0] + Math.cos(az) * Math.sqrt(1 - el * el) * radius, end[1] + el * radius * 0.61, end[2] + Math.sin(az) * Math.sqrt(1 - el * el) * radius, range(0.19, 0.4));
        }
      }
    }
  }
  tree(-8.9, -15, 8.6, 3.45);
  tree(9.3, -43, 10.2, 4.05);
  tree(-9.8, -64, 8.7, 3.7);
  tree(10, -88, 9.1, 4.2);
  tree(-10.1, -111, 10, 3.9);
  tree(10.2, 14, 7.6, 2.9);
  tree(-10.4, -140, 10.4, 4.5);

  // Broad-leaf volunteers escaping cracked pavement, and denser growth beneath trees.
  for (let n = 0; n < 165; n++) {
    const x = (random() > 0.5 ? -1 : 1) * range(7.25, 10.6), z = range(-143, 25);
    const size = range(0.18, 0.58), cy = range(0.12, 0.38);
    for (let l = 0; l < 19; l++) putLeaf(x + range(-0.36, 0.36), cy + range(0, size * 0.8), z + range(-0.4, 0.4), size);
  }
  for (const [x, z] of [[-8.7, 3], [8.4, -15], [-8.3, -39], [8.6, -64], [-8.5, -104]]) {
    for (let j = 0; j < 80; j++) putLeaf(x + range(-0.48, 0.48), range(0.9, 1.65), z + range(-0.48, 0.48), range(0.3, 0.61));
  }
  const foliageMat = new THREE.MeshStandardMaterial({ color: '#ffffff', roughness: 0.87, side: THREE.DoubleSide, metalness: 0 });
  const foliage = new THREE.InstancedMesh(leafGeometry(), foliageMat, leaves.length);
  foliage.name = 'Instanced curved tropical leaves';
  for (let i = 0; i < leaves.length; i++) {
    const leaf = leaves[i]; transform.position.copy(leaf.position); transform.rotation.copy(leaf.rotation); transform.scale.copy(leaf.scale); transform.updateMatrix();
    foliage.setMatrixAt(i, transform.matrix); foliage.setColorAt(i, leaf.color);
  }
  foliage.castShadow = true; foliage.receiveShadow = true; foliage.computeBoundingSphere(); group.add(foliage);

  // Individual bent grass blades are combined into one patch and instanced along the gutters.
  const grassParts: THREE.BufferGeometry[] = [];
  for (let i = 0; i < 8; i++) {
    const h = range(0.19, 0.61), a = i * 2.399, x = Math.cos(a) * range(0.02, 0.12), z = Math.sin(a) * range(0.02, 0.12);
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute([x - 0.018, 0, z, x + 0.018, 0, z, x + Math.cos(a) * 0.06, h * 0.63, z + Math.sin(a) * 0.07, x + Math.cos(a) * 0.14, h, z + Math.sin(a) * 0.17], 3));
    g.setIndex([0, 1, 2, 1, 3, 2]); g.computeVertexNormals(); grassParts.push(g);
  }
  const grassGeometry = mergeGeometries(grassParts)!;
  const grass = new THREE.InstancedMesh(grassGeometry, new THREE.MeshStandardMaterial({ color: '#6e7950', roughness: 1, side: THREE.DoubleSide }), 980);
  for (let i = 0; i < 980; i++) {
    const side = random() > 0.5 ? 1 : -1;
    transform.position.set(side * range(6.92, 8.25), 0.06, range(-153, 29));
    transform.rotation.set(0, range(0, 6.28), 0); transform.scale.setScalar(range(0.4, 1.3)); transform.updateMatrix(); grass.setMatrixAt(i, transform.matrix);
    grass.setColorAt(i, new THREE.Color().setHSL(range(0.18, 0.24), range(0.12, 0.28), range(0.33, 0.53)));
  }
  grass.receiveShadow = true; grass.computeBoundingSphere(); group.add(grass);

  for (const [material, geometries] of batches) {
    // Normalize indexing: Extrude/RoundedBox use flat buffers, basic shapes use indices.
    const flat = geometries.map(geometry => geometry.index ? geometry.toNonIndexed() : geometry);
    const combined = mergeGeometries(flat, false);
    if (!combined) continue;
    const mesh = new THREE.Mesh(combined, material); mesh.castShadow = true; mesh.receiveShadow = true;
    mesh.name = 'Batched street prop surfaces'; group.add(mesh);
    for (const geo of new Set([...geometries, ...flat])) geo.dispose();
  }
  for (const geo of grassParts) geo.dispose();

  return {
    group,
    update(elapsed, wind) {
      // Minute canopy drift is enough to keep the otherwise still street alive; no per-frame uploads.
      foliage.rotation.z = Math.sin(elapsed * 0.49) * Math.min(wind, 2) * 0.00045;
      foliage.rotation.x = Math.sin(elapsed * 0.31 + 1) * Math.min(wind, 2) * 0.00018;
      grass.rotation.z = Math.sin(elapsed * 0.81) * Math.min(wind, 2) * 0.00008;
    },
  };
}
