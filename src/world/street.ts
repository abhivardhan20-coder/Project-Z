import * as THREE from 'three/webgpu';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import type { CollisionBox } from './collision';

/** A deterministic, metre-scale art block. Static detail is merged by material. */
export interface StreetScene {
  group: THREE.Group;
  roadMaterials: THREE.MeshStandardMaterial[];
  lights: THREE.Light[];
  bounds: { minX: number; maxX: number; minZ: number; maxZ: number };
}

function randomGenerator(seed: number) {
  return () => {
    seed |= 0; seed = seed + 0x6D2B79F5 | 0;
    let n = Math.imul(seed ^ seed >>> 15, 1 | seed);
    n = n + Math.imul(n ^ n >>> 7, 61 | n) ^ n;
    return ((n ^ n >>> 14) >>> 0) / 4294967296;
  };
}

function canvasTexture(draw: (ctx: CanvasRenderingContext2D, size: number) => void, size = 512) {
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = size;
  const ctx = canvas.getContext('2d')!;
  draw(ctx, size);
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
  texture.anisotropy = 8;
  return texture;
}

function surfaceTexture(color: string, seed: number, type: 'plaster' | 'road' | 'concrete' | 'shutter') {
  const random = randomGenerator(seed);
  return canvasTexture((ctx, size) => {
    ctx.fillStyle = color; ctx.fillRect(0, 0, size, size);
    const pixels = ctx.getImageData(0, 0, size, size);
    for (let i = 0; i < pixels.data.length; i += 4) {
      const noise = (random() - 0.5) * (type === 'road' ? 40 : 24);
      pixels.data[i] += noise; pixels.data[i + 1] += noise; pixels.data[i + 2] += noise;
    }
    ctx.putImageData(pixels, 0, 0);
    for (let i = 0; i < 65; i++) {
      const x = random() * size, y = random() * size, radius = 12 + random() * 150;
      const stain = ctx.createRadialGradient(x, y, 0, x, y, radius);
      stain.addColorStop(0, `rgba(${type === 'road' ? '7,13,15' : '32,28,17'},${0.025 + random() * 0.1})`);
      stain.addColorStop(1, 'rgba(20,25,19,0)');
      ctx.fillStyle = stain; ctx.fillRect(x - radius, y - radius, radius * 2, radius * 2);
    }
    if (type === 'plaster') {
      for (let i = 0; i < 40; i++) {
        const x = random() * size, y = random() * size, width = 2 + random() * 19;
        const stain = ctx.createLinearGradient(0, y, 0, y + 150);
        stain.addColorStop(0, 'rgba(26,29,24,.13)'); stain.addColorStop(1, 'rgba(25,24,20,0)');
        ctx.fillStyle = stain; ctx.fillRect(x, y, width, 50 + random() * 170);
      }
      for (let i = 0; i < 160; i++) {
        ctx.fillStyle = random() > .5 ? 'rgba(215,208,175,.13)' : 'rgba(52,43,30,.16)';
        ctx.fillRect(random() * size, random() * size, random() * 9, random() * 5);
      }
    }
    if (type === 'concrete') {
      ctx.strokeStyle = 'rgba(35,37,31,.27)'; ctx.lineWidth = 2;
      for (let y = 0; y < size; y += 128) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(size, y); ctx.stroke(); }
      for (let y = 0; y < size; y += 128) for (let x = (y % 256 ? 64 : 0); x < size; x += 128) {
        ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x, y + 128); ctx.stroke();
      }
    }
    if (type === 'shutter') {
      for (let y = 0; y < size; y += 18) {
        ctx.fillStyle = 'rgba(8,17,15,.42)'; ctx.fillRect(0, y, size, 3);
        ctx.fillStyle = 'rgba(180,200,177,.15)'; ctx.fillRect(0, y + 4, size, 2);
      }
      for (let i = 0; i < 90; i++) {
        ctx.fillStyle = `rgba(96,43,20,${random() * .5})`;
        ctx.fillRect(random() * size, random() * size, 1 + random() * 12, 5 + random() * 110);
      }
    }
    if (type === 'road') {
      ctx.strokeStyle = 'rgba(11,16,17,.5)'; ctx.lineWidth = 1.7;
      for (let n = 0; n < 12; n++) {
        let x = random() * size, y = random() * size;
        ctx.beginPath(); ctx.moveTo(x, y);
        for (let j = 0; j < 7; j++) { x += (random() - .5) * 65; y += random() * 23; ctx.lineTo(x, y); }
        ctx.stroke();
      }
      for (let i = 0; i < 1000; i++) {
        ctx.fillStyle = random() > .6 ? 'rgba(176,177,166,.25)' : 'rgba(10,17,18,.3)';
        ctx.fillRect(random() * size, random() * size, random() * 2, random() * 2);
      }
    }
  }, type === 'road' ? 1024 : 512);
}

function shopTexture(title: string, subtitle: string, color: string, seed: number) {
  const random = randomGenerator(seed);
  return canvasTexture((ctx, size) => {
    ctx.fillStyle = color; ctx.fillRect(0, 0, size, size);
    ctx.strokeStyle = '#b8b396'; ctx.lineWidth = 4; ctx.strokeRect(14, 155, size - 28, 200);
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.fillStyle = '#d5cdae'; ctx.font = 'bold 45px Georgia, serif';
    ctx.fillText(title, size / 2, 236, size - 44);
    ctx.font = '18px Arial, sans-serif'; ctx.fillStyle = '#bdbdaa';
    ctx.fillText(subtitle, size / 2, 302, size - 54);
    ctx.font = '17px Arial, sans-serif'; ctx.fillText('హైదరాబాద్  •  HYDERABAD', size / 2, 185, size - 54);
    for (let i = 0; i < 1900; i++) {
      ctx.fillStyle = random() > .8 ? 'rgba(219,211,185,.16)' : 'rgba(15,20,18,.13)';
      ctx.fillRect(random() * size, 150 + random() * 210, random() * 7, random() * 4);
    }
    const image = ctx.getImageData(0, 144, size, 216);
    ctx.clearRect(0, 0, size, size);
    const scratch = document.createElement('canvas'); scratch.width = size; scratch.height = 216;
    scratch.getContext('2d')!.putImageData(image, 0, 0);
    ctx.drawImage(scratch, 0, 0, size, size);
  });
}

export function createStreet(): StreetScene {
  const group = new THREE.Group(); group.name = 'Old city / static architecture';
  const collisionBoxes: CollisionBox[] = [];
  group.userData.collisionBoxes = collisionBoxes;
  const random = randomGenerator(20260814);
  const range = (a: number, b: number) => a + random() * (b - a);
  const batches = new Map<THREE.Material, THREE.BufferGeometry[]>();
  const matrix = new THREE.Matrix4();
  const position = new THREE.Vector3(); const rotation = new THREE.Quaternion();
  const scale = new THREE.Vector3(); const euler = new THREE.Euler();
  const material = (color: string, roughness = .8, metalness = 0) => new THREE.MeshStandardMaterial({ color, roughness, metalness });
  const add = (geometry: THREE.BufferGeometry, mat: THREE.Material, x: number, y: number, z: number, rx = 0, ry = 0, rz = 0) => {
    // Extruded masonry is non-indexed; keep every batch compatible with boxes.
    if (!geometry.index) geometry.setIndex(Array.from({ length: geometry.attributes.position.count }, (_, i) => i));
    matrix.compose(position.set(x, y, z), rotation.setFromEuler(euler.set(rx, ry, rz)), scale.set(1, 1, 1));
    geometry.applyMatrix4(matrix);
    if (!batches.has(mat)) batches.set(mat, []);
    batches.get(mat)!.push(geometry);
  };
  const box = (mat: THREE.Material, x: number, y: number, z: number, w: number, h: number, d: number, ry = 0, rz = 0) => {
    const geometry = new THREE.BoxGeometry(w, h, d);
    const uv = geometry.attributes.uv, normals = geometry.attributes.normal, vertices = geometry.attributes.position;
    // Consistent texel density across facades, tiny trim and enormous pavement slabs.
    for (let i = 0; i < uv.count; i++) {
      const nx = Math.abs(normals.getX(i)), ny = Math.abs(normals.getY(i));
      uv.setXY(i, (nx > .5 ? vertices.getZ(i) + z : vertices.getX(i) + x) / 4,
        (ny > .5 ? vertices.getZ(i) + z : vertices.getY(i) + y) / 4);
    }
    add(geometry, mat, x, y, z, 0, ry, rz);
  };
  const cylinder = (mat: THREE.Material, x: number, y: number, z: number, radius: number, height: number, segments = 12, topRadius = radius) => {
    add(new THREE.CylinderGeometry(topRadius, radius, height, segments), mat, x, y, z);
  };
  const rod = (mat: THREE.Material, a: THREE.Vector3, b: THREE.Vector3, radius: number) => {
    const geometry = new THREE.CylinderGeometry(radius, radius, a.distanceTo(b), 7);
    const q = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), b.clone().sub(a).normalize());
    geometry.applyQuaternion(q); const mid = a.clone().add(b).multiplyScalar(.5);
    add(geometry, mat, mid.x, mid.y, mid.z);
  };
  const facadePanel = (mat: THREE.Material, x: number, y: number, z: number, w: number, h: number, side: number) => {
    add(new THREE.PlaneGeometry(w, h), mat, x, y, z, 0, -side * Math.PI / 2);
  };
  const textured = (color: string, seed: number, type: 'plaster' | 'road' | 'concrete' | 'shutter', roughness: number) => {
    const map = surfaceTexture(color, seed, type);
    return new THREE.MeshStandardMaterial({ map, bumpMap: map, bumpScale: type === 'road' ? .075 : .045, roughness });
  };

  const walls = ['#898273', '#8f8878', '#8a7964', '#7c827a', '#967c69', '#707b73', '#a49d88', '#787467']
    .map((color, i) => textured(color, 156 + i, 'plaster', .96));
  const stone = textured('#8c8b7e', 843, 'concrete', .91);
  const darkStone = textured('#484d47', 21, 'plaster', .95);
  const trim = textured('#aaa08a', 317, 'plaster', .88);
  const asphalt = textured('#363d3d', 622, 'road', .63);
  const patchedRoad = textured('#2a3333', 622, 'road', .48);
  const gutter = material('#26362f', .93);
  const metal = material('#394a46', .65, .55);
  const rust = material('#625345', .87, .3);
  const dark = material('#152422', .86);
  const glass = material('#1e3435', .27, .32);
  const deadGlass = material('#334645', .52, .2);
  const windowWarm = new THREE.MeshStandardMaterial({ color: '#716347', roughness: .5, emissive: '#a77b39', emissiveIntensity: .22 });
  const shutters = ['#526b62', '#40514e', '#656455', '#56626a'].map((color, i) => textured(color, 412 + i, 'shutter', .78));
  const paint = material('#b6aa78', .94);
  const fadedPaint = material('#777962', .9);
  const tar = material('#202b2a', .92);
  const lamp = new THREE.MeshStandardMaterial({ color: '#ecc78b', emissive: '#ffd397', emissiveIntensity: 2.7, roughness: .4 });
  const water = new THREE.MeshStandardMaterial({ color: '#596765', roughness: .12, metalness: .57, transparent: true, opacity: .65, depthWrite: false });

  box(asphalt, 0, -.14, -63, 15.6, .24, 240);
  box(darkStone, 0, -.34, -61, 140, .18, 300);
  collisionBoxes.push({ center: [0, -.14, -63], half: [7.8, .12, 120] });
  collisionBoxes.push({ center: [0, -.34, -61], half: [70, .09, 150] });
  // Varied repairs are embedded in the surface, with thin reflective monsoon puddles.
  for (let i = 0; i < 32; i++) {
    box(patchedRoad, range(-5.5, 5.5), -.009, range(-165, 45), range(.7, 3.3), .011, range(1, 6), range(-.12, .12));
  }
  for (let i = 0; i < 26; i++) {
    const radius = range(.35, 1.15), geometry = new THREE.CircleGeometry(radius, 24);
    const vertices = geometry.attributes.position;
    for (let j = 1; j < vertices.count; j++) {
      vertices.setXY(j, vertices.getX(j) * range(.85, 1.17), vertices.getY(j) * range(1.3, 3.8));
    }
    geometry.computeVertexNormals();
    add(geometry, water, range(-6.4, 6.4), .014 + i * .0001, range(-148, 40), -Math.PI / 2, 0, range(0, Math.PI));
  }
  for (let z = 34; z > -155; z -= 8.8) {
    if (random() > .21) box(paint, -.12, .008, z, .11, .01, 3.2);
    if (random() > .24) box(fadedPaint, .12, .009, z, .08, .011, 3.2);
  }
  for (let side of [-1, 1]) {
    box(stone, side * 9.5, .07, -60, 3.7, .4, 234);
    collisionBoxes.push({ center: [side * 9.5, .07, -60], half: [1.85, .2, 117] });
    collisionBoxes.push({ center: [side * 7.86, .17, -60], half: [.115, .16, 117] });
    box(gutter, side * 7.72, -.003, -60, .29, .026, 237);
    for (let z = 54; z > -174; z -= 2) {
      box(random() > .44 ? trim : darkStone, side * 7.86, .17, z, .23, .32, 1.95);
      if (Math.floor(z) % 22 === 0) {
        box(metal, side * 7.64, .04, z, .36, .06, .9);
        for (let j = 0; j < 7; j++) box(dark, side * 7.62, .078, z - .36 + j * .12, .29, .009, .055);
      }
    }
    box(fadedPaint, side * 6.9, .007, -60, .065, .012, 225);
  }
  // The fractured paint of the old pedestrian crossing at the near intersection.
  for (let x = -5.8; x < 6.5; x += 1.14) {
    box(paint, x, .013, 12.6, .57, .013, 3.4 + range(-.3, .3));
    for (let j = 0; j < 4; j++) box(asphalt, x + range(-.2, .2), .023, 12.6 + range(-1.6, 1.6), range(.08, .31), .012, range(.09, .3));
  }

  const shops: [string, string, string][] = [
    ['DECCAN CAFE', 'IRANI CHAI  ·  BAKERY  ·  EST. 1978', '#304a43'],
    ['ROYAL MEDICAL', 'PHARMACY & GENERAL STORES', '#354a4b'],
    ['NIZAM STORES', 'RICE  ·  SPICES  ·  PROVISIONS', '#645744'],
    ['AZIZ & SONS', 'ELECTRICALS • REPAIRS • SPARES', '#34454b'],
    ['HOTEL MEHFIL', 'PURE HYDERABADI CUISINE', '#574540'],
    ['SRI SAI MOTORS', 'TWO WHEELER SERVICE CENTRE', '#455650'],
    ['NEW CITY OPTICALS', 'EYE CARE & CONTACT LENSES', '#4b514b'],
    ['SAHARA TEXTILES', 'COTTONS • SILKS • DRESS MATERIAL', '#625c49'],
    ['METRO HARDWARE', 'TOOLS  ·  PAINTS  ·  SANITARY', '#3d504b'],
    ['NOOR BAKERY', 'FRESH BREAD & OSMANIA BISCUITS', '#566151'],
    ['ASHOK TRADERS', 'WHOLESALE GENERAL MERCHANTS', '#645145'],
    ['CITY BOOK HOUSE', 'BOOKS • STATIONERY • XEROX', '#4c5552'],
  ];
  const signMaterials = shops.map((shop, index) => new THREE.MeshStandardMaterial({ map: shopTexture(...shop, index * 718), roughness: .91 }));
  const buildingTops: { x: number; y: number; z: number; w: number; d: number }[] = [];
  let buildingIndex = 0;

  for (const side of [-1, 1]) {
    let frontZ = 40;
    let index = 0;
    while (frontZ > -158) {
      const length = index === 1 && side === -1 ? 16 : range(10.8, 16.7);
      const z = frontZ - length / 2;
      const floors = index === 0 ? 3 : 2 + Math.floor(random() * 4);
      const h = 3.9 + floors * 3.05;
      const depth = range(10, 17), facade = side * range(10.2, 11.6), x = facade + side * depth / 2;
      const wall = walls[(buildingIndex * 3 + index) % walls.length];
      const band = index % 3 === 0 ? trim : stone;
      buildingTops.push({ x, y: h, z, w: depth, d: length });
      box(wall, x, h / 2, z, depth, h, length);
      collisionBoxes.push({ center: [x, h / 2, z], half: [depth / 2, h / 2, length / 2] });
      // One sill proxy per facade replaces the many individual shopfront steps.
      collisionBoxes.push({ center: [facade - side * .65, .29, z], half: [.65, .075, (length - .5) / 2] });
      box(darkStone, facade - side * .035, 1.3, z, .12, 2.5, length - .1);
      box(band, facade - side * .14, 3.35, z, .65, .26, length + .2);
      box(band, x, h + .05, z, depth + .45, .22, length + .4);
      box(wall, facade - side * .02, h + .56, z, .32, .95, length + .2);
      box(band, facade - side * .04, h + 1.02, z, .48, .14, length + .45);
      box(wall, x, h + .58, z - length / 2, depth, 1.02, .28);
      box(wall, x, h + .58, z + length / 2, depth, 1.02, .28);
      // Worn shopfronts sit within deep jambs under the first-floor slab.
      const bays = Math.max(2, Math.floor(length / 3.65));
      const bayWidth = (length - .5) / bays;
      for (let bay = 0; bay < bays; bay++) {
        const bz = z - length / 2 + .25 + bayWidth * (bay + .5);
        box(shutters[(index + bay) % shutters.length], facade - side * .065, 1.43, bz, .08, 2.66, bayWidth - .22);
        box(stone, facade - side * .19, 1.6, bz + bayWidth / 2, .42, 3.1, .2);
        box(metal, facade - side * .115, .31, bz, .05, .12, bayWidth - .33);
        box(rust, facade - side * .14, 1.24, bz, .07, .07, .22);
        box(stone, facade - side * .65, .29, bz, 1.3, .15, bayWidth - .13);
        if (random() > .58) {
          box(metal, facade - side * .79, 3.13, bz, 1.58, .1, bayWidth - .1);
          box(shutters[index % shutters.length], facade - side * 1.48, 2.99, bz, .08, .25, bayWidth - .1);
          for (const az of [-1, 1]) rod(rust, new THREE.Vector3(facade - side * .1, 2.3, bz + az * (bayWidth / 2 - .15)), new THREE.Vector3(facade - side * 1.4, 3.11, bz + az * (bayWidth / 2 - .15)), .024);
        }
      }
      facadePanel(signMaterials[(buildingIndex + (side === 1 ? 4 : 0)) % signMaterials.length], facade - side * .506, 3.92, z, length - .55, 1.03, side);
      box(metal, facade - side * .37, 3.92, z, .24, 1.17, length - .35);

      const windowCount = Math.max(2, Math.floor(length / 3.8));
      const windowSpacing = (length - 1.1) / windowCount;
      for (let floor = 0; floor < floors; floor++) {
        const y = 5.45 + floor * 3.05;
        box(band, facade - side * .04, y + 1.32, z, .15, .1, length - .2);
        for (let wi = 0; wi < windowCount; wi++) {
          const wz = z - length / 2 + .55 + (wi + .5) * windowSpacing;
          const windowWidth = index % 4 === 0 ? 1.72 : 1.39;
          box(dark, facade - side * .047, y, wz, .1, 1.86, windowWidth + .22);
          box(random() > .84 ? windowWarm : random() > .52 ? deadGlass : glass, facade - side * .112, y, wz, .04, 1.59, windowWidth);
          for (const edge of [-1, 1]) {
            box(band, facade - side * .155, y, wz + edge * (windowWidth / 2 + .065), .23, 1.96, .11);
            box(band, facade - side * .18, y + edge * .94, wz, .26, .13, windowWidth + .3);
          }
          box(metal, facade - side * .145, y, wz, .06, 1.63, .045);
          box(metal, facade - side * .145, y - .22, wz, .06, .04, windowWidth);
          box(band, facade - side * .42, y + 1.02, wz, .85, .115, windowWidth + .7);
          if (random() > .45) {
            const balconyWidth = windowWidth + .87;
            box(stone, facade - side * .62, y - 1.04, wz, 1.3, .19, balconyWidth);
            const railX = facade - side * 1.23;
            for (const railY of [y - .9, y - .19]) box(metal, railX, railY, wz, .04, .045, balconyWidth);
            for (let k = 0; k < 10; k++) box(metal, railX, y - .54, wz - balconyWidth / 2 + k * balconyWidth / 9, .032, .75, .035);
            for (const edge of [-1, 1]) {
              box(metal, facade - side * .65, y - .19, wz + edge * balconyWidth / 2, 1.2, .045, .04);
              box(metal, facade - side * .65, y - .88, wz + edge * balconyWidth / 2, 1.2, .045, .04);
            }
            if (floor === 0 && wi % 2 === 0) {
              box(shutters[(wi + index) % shutters.length], railX + side * .055, y - .51, wz + .14, .022, .59, .81);
            }
          } else if (random() > .55) {
            box(stone, facade - side * .43, y - .63, wz + 1.19, .74, .58, .72);
            box(metal, facade - side * .812, y - .63, wz + 1.19, .025, .4, .55);
            for (let line = 0; line < 6; line++) box(dark, facade - side * .83, y - .8 + line * .065, wz + 1.19, .018, .018, .5);
          }
        }
      }
      // A small number of architectural pilasters break up long surfaces.
      for (const edge of [-1, 1]) box(band, facade - side * .15, (h + 4.4) / 2, z + edge * (length / 2 - .22), .35, h - 4.4, .3);
      if (index % 2 === 0) {
        cylinder(rust, facade - side * .31, h / 2, z + length / 2 - .65, .052, h - .3, 8);
        for (let y = 1; y < h; y += 2) box(metal, facade - side * .24, y, z + length / 2 - .65, .25, .05, .15);
      }
      const tankX = x + range(-2, 2), tankZ = z + range(-length / 3, length / 3);
      box(stone, tankX, h + .2, tankZ, 2.45, .45, 2.45);
      cylinder(dark, tankX, h + 1.43, tankZ, 1.02, 2.05, 18);
      cylinder(metal, tankX, h + 2.48, tankZ, .78, .13, 18);
      for (let y = h + .7; y < h + 2.3; y += .4) cylinder(darkStone, tankX, y, tankZ, 1.04, .042, 18);
      box(wall, x + side * 2, h + 1.31, z - length * .26, 3.4, 2.65, 3.2);
      box(stone, x + side * 2, h + 2.69, z - length * .26, 3.7, .15, 3.5);
      if (index % 3 === 0) {
        cylinder(metal, x, h + 3.1, z + length * .3, .025, 5, 6);
        rod(metal, new THREE.Vector3(x, h + 5, z + length * .3 - .7), new THREE.Vector3(x, h + 5, z + length * .3 + .7), .018);
        rod(metal, new THREE.Vector3(x - .5, h + 4.6, z + length * .3), new THREE.Vector3(x + .5, h + 4.6, z + length * .3), .014);
      }
      frontZ -= length + range(.8, 2.2);
      index++; buildingIndex++;
    }
  }

  // Service poles, sagging overhead cable bundles and warm residual grid lighting.
  const lights: THREE.Light[] = [];
  for (let z = 28, index = 0; z > -151; z -= 26, index++) {
    const side = index % 2 === 0 ? -1 : 1, x = side * 8.78;
    cylinder(darkStone, x, 3.73, z, .14, 7.5, 10, .075);
    collisionBoxes.push({ center: [x, 3.73, z], half: [.16, 3.75, .16] });
    cylinder(stone, x, .7, z, .18, 1.4, 10);
    box(metal, x, 6.36, z, 1.43, .085, .1);
    for (const offset of [-.57, 0, .57]) cylinder(trim, x + offset, 6.52, z, .055, .23, 8);
    const end = new THREE.Vector3(x - side * 1.6, 7.34, z);
    rod(metal, new THREE.Vector3(x, 6.65, z), end, .04);
    box(metal, end.x, 7.32, z, .86, .12, .29);
    box(lamp, end.x, 7.25, z, .64, .025, .18);
    if (index < 3) {
      const light = new THREE.PointLight('#e7b677', 10, 15, 2);
      light.position.set(end.x, 7.05, z); lights.push(light);
    }
    for (let offset = 0; offset < 3; offset++) {
      const nextX = -side * 8.78;
      const curve = new THREE.CatmullRomCurve3([
        new THREE.Vector3(x + offset * .16, 6.58 + offset * .13, z),
        new THREE.Vector3((x + nextX) / 2 + offset * .16, 5.18 + offset * .09, z - 13),
        new THREE.Vector3(nextX + offset * .16, 6.58 + offset * .13, z - 26),
      ]);
      add(new THREE.TubeGeometry(curve, 20, .012, 4, false), dark, 0, 0, 0);
    }
    const cross = new THREE.CatmullRomCurve3([
      new THREE.Vector3(-11.1, 9.1, z - 4), new THREE.Vector3(0, 7.72, z - 4.9), new THREE.Vector3(11.1, 8.9, z - 5.6),
    ]);
    add(new THREE.TubeGeometry(cross, 22, .016, 4, false), dark, 0, 0, 0);
  }

  // A distant former civic gateway gives the street a unique old-city silhouette.
  const landmarkZ = -169;
  const landmark = walls[2];
  for (const side of [-1, 1]) {
    box(landmark, side * 12, 7, landmarkZ, 10, 14, 7);
    box(trim, side * 12, 14.16, landmarkZ, 10.5, .38, 7.6);
    box(landmark, side * 12, 15.4, landmarkZ, 9.4, 2.1, 6.5);
    for (const tx of [side * 8, side * 16]) {
      cylinder(landmark, tx, 13.7, landmarkZ, 1.19, 18.5, 12);
      cylinder(trim, tx, 21.7, landmarkZ, 1.47, .38, 16);
      cylinder(trim, tx, 23, landmarkZ, 1.35, .22, 16);
      cylinder(landmark, tx, 22.4, landmarkZ, .94, 1.3, 12);
      add(new THREE.SphereGeometry(1.4, 20, 12, 0, Math.PI * 2, 0, Math.PI / 2), trim, tx, 23.2, landmarkZ);
      cylinder(metal, tx, 25.1, landmarkZ, .035, 1.15, 8);
      for (let az = 0; az < 8; az++) {
        const angle = az / 8 * Math.PI * 2;
        box(dark, tx + Math.sin(angle) * .95, 22.37, landmarkZ + Math.cos(angle) * .95, .34, .86, .05, angle);
      }
    }
  }
  box(landmark, 0, 15.32, landmarkZ, 15, 2.6, 7);
  box(trim, 0, 16.78, landmarkZ, 33, .31, 7.6);
  // Actual arched masonry, with an open passage, rather than a painted doorway.
  const archShape = new THREE.Shape();
  archShape.moveTo(-7, 0); archShape.lineTo(-7, 8);
  archShape.absarc(0, 8, 7, Math.PI, 0, true);
  archShape.lineTo(7, 0); archShape.lineTo(6.1, 0); archShape.lineTo(6.1, 8);
  archShape.absarc(0, 8, 6.1, 0, Math.PI, false);
  archShape.lineTo(-6.1, 0); archShape.closePath();
  add(new THREE.ExtrudeGeometry(archShape, { depth: 7.3, bevelEnabled: false, curveSegments: 28 }), trim, 0, 0, landmarkZ - 3.7);

  // Beyond the art block: layered district massing keeps every vista grounded.
  for (let i = 0; i < 50; i++) {
    const side = random() > .5 ? 1 : -1, x = side * range(29, 87), z = range(-245, 35);
    const w = range(8, 18), d = range(8, 24), h = range(15, 46);
    box(walls[i % walls.length], x, h / 2, z, w, h, d);
    box(stone, x, h + .15, z, w + .35, .35, d + .35);
    if (i % 2 === 0) box(darkStone, x, h + 1, z, w * .3, 1.9, d * .3);
    for (let y = 5; y < h - 2; y += 3.3) {
      box(darkStone, x - side * (w / 2 + .035), y, z, .075, 1.4, d * .88);
      for (let wz = z - d / 2 + 1; wz < z + d / 2; wz += 2.8) box(stone, x - side * (w / 2 + .08), y, wz, .14, 1.6, .22);
    }
  }

  for (const [mat, geometries] of batches) {
    const geometry = mergeGeometries(geometries, false);
    for (const source of geometries) source.dispose();
    if (!geometry) continue;
    geometry.computeBoundingSphere();
    const mesh = new THREE.Mesh(geometry, mat);
    mesh.castShadow = mat !== water && mat !== asphalt && mat !== patchedRoad;
    mesh.receiveShadow = true;
    mesh.name = mat === asphalt ? 'Weathered asphalt' : mat === water ? 'Monsoon puddles' : 'Batched street architecture';
    group.add(mesh);
  }
  return { group, roadMaterials: [asphalt, patchedRoad, water], lights,
    bounds: { minX: -7, maxX: 7, minZ: -154, maxZ: 34 } };
}
