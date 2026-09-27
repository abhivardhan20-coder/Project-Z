import * as THREE from 'three/webgpu';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';

export interface SurvivorPose {
  position: { x: number; y: number; z: number };
  speed: number;
  yaw: number;
  grounded: boolean;
  crouched: boolean;
  locomotion: string;
  stamina: number;
}

type Profile = [height: number, width: number, depth: number, zOffset?: number];
type Part = THREE.Group;
type Material = THREE.MeshStandardMaterial;

/** A closed, tailored surface. Elliptical cross sections avoid capsule-shaped limbs. */
function tailored(profiles: Profile[], segments = 18, creasing = .006): THREE.BufferGeometry {
  const positions: number[] = [], uvs: number[] = [], indices: number[] = [];
  for (let row = 0; row < profiles.length; row++) {
    const [y, width, depth, offset = 0] = profiles[row];
    for (let column = 0; column <= segments; column++) {
      const a = column / segments * Math.PI * 2;
      const fold = 1 + Math.sin(a * 5 + row * 1.7) * creasing / Math.max(.04, width);
      positions.push(Math.sin(a) * width * fold, y, Math.cos(a) * depth * fold + offset);
      uvs.push(column / segments, row / (profiles.length - 1));
      if (row < profiles.length - 1 && column < segments) {
        const n = row * (segments + 1) + column;
        indices.push(n, n + 1, n + segments + 1, n + 1, n + segments + 2, n + segments + 1);
      }
    }
  }
  // Profiles are ordered from bottom to top. Their winding faces outward.
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
  geometry.setIndex(indices);
  geometry.computeVertexNormals();
  return geometry;
}

function clothTexture(base: [number, number, number], seed: number): THREE.CanvasTexture {
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = 256;
  const context = canvas.getContext('2d')!;
  const pixels = context.createImageData(256, 256);
  let n = seed;
  const random = () => { n = Math.imul(1664525, n) + 1013904223 | 0; return (n >>> 0) / 4294967296; };
  for (let y = 0; y < 256; y++) for (let x = 0; x < 256; x++) {
    const index = (y * 256 + x) * 4;
    const weave = ((x + (y % 4)) % 4 === 0 ? 5 : 0) + (y % 3 === 0 ? 2 : 0);
    const noise = (random() - .5) * 12 + weave;
    const wear = Math.sin(x * .025 + Math.cos(y * .037)) * Math.sin(y * .046) * 5;
    for (let channel = 0; channel < 3; channel++) pixels.data[index + channel] = base[channel] + noise + wear;
    pixels.data[index + 3] = 255;
  }
  context.putImageData(pixels, 0, 0);
  // Faint irregular rain-darkened marks, with no repeated icon or artificial lettering.
  for (let index = 0; index < 24; index++) {
    const x = random() * 256, y = random() * 256, radius = 9 + random() * 34;
    const stain = context.createRadialGradient(x, y, 0, x, y, radius);
    stain.addColorStop(0, 'rgba(12,15,10,.09)'); stain.addColorStop(1, 'rgba(12,15,10,0)');
    context.fillStyle = stain; context.fillRect(x - radius, y - radius, radius * 2, radius * 2);
  }
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
  texture.anisotropy = 4;
  return texture;
}

function clothRelief(): THREE.CanvasTexture {
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = 128;
  const ctx = canvas.getContext('2d')!;
  ctx.fillStyle = '#979797'; ctx.fillRect(0, 0, 128, 128);
  for (let i = 0; i < 128; i += 4) {
    ctx.fillStyle = '#aaaaaa'; ctx.fillRect(i, 0, 1, 128);
    ctx.fillStyle = '#858585'; ctx.fillRect(0, i + 1, 128, 1);
  }
  const texture = new THREE.CanvasTexture(canvas);
  texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
  texture.repeat.set(2, 2);
  return texture;
}

/** The model faces +Z; its root is the ground contact point, in metres. */
export class SurvivorCharacter {
  readonly group = new THREE.Group();
  private readonly hips = new THREE.Group();
  private readonly torso = new THREE.Group();
  private readonly head = new THREE.Group();
  private readonly upperArms = [new THREE.Group(), new THREE.Group()];
  private readonly forearms = [new THREE.Group(), new THREE.Group()];
  private readonly thighs = [new THREE.Group(), new THREE.Group()];
  private readonly shins = [new THREE.Group(), new THREE.Group()];
  private readonly feet = [new THREE.Group(), new THREE.Group()];
  private readonly batches = new Map<Part, Map<Material, THREE.BufferGeometry[]>>();
  private readonly materials = new Set<Material>();
  private readonly textures = new Set<THREE.Texture>();
  private readonly geometries = new Set<THREE.BufferGeometry>();
  private phase = 0;
  private elapsed = 0;
  private stride = 0;
  private crouch = 0;
  private airborne = 0;
  private climb = 0;
  private landing = 0;
  private previousGrounded = true;
  private initialized = false;

  constructor() {
    this.group.name = 'Survivor — field jacket / expedition pack';
    this.group.add(this.hips);
    this.hips.add(this.torso);
    this.torso.add(this.head);
    this.head.position.set(0, .635, .015);

    const relief = clothRelief(); this.textures.add(relief);
    const fabric = (color: [number, number, number], seed: number, roughness = .94) => {
      const map = clothTexture(color, seed); this.textures.add(map);
      return this.material({ map, bumpMap: relief, bumpScale: .0011, roughness });
    };
    const jacket = fabric([80, 86, 66], 21, .9);
    const reinforcement = fabric([60, 66, 54], 12);
    const trousers = fabric([49, 53, 48], 49);
    const canvas = fabric([91, 78, 59], 79);
    const webbing = fabric([43, 44, 35], 31);
    const leather = this.material({ color: 0x312f27, roughness: .78 });
    const rubber = this.material({ color: 0x191e1b, roughness: .94 });
    const seam = this.material({ color: 0x797860, roughness: 1 });
    const metal = this.material({ color: 0x7e8077, roughness: .57, metalness: .58 });
    const rust = this.material({ color: 0x985744, roughness: .97 });
    const skin = this.material({ color: 0x86634e, roughness: .78 });

    // Tailored jacket: rounded shoulders, a narrower waist, and a slightly flared hem.
    this.add(this.torso, tailored([
      [-.035, .16, .11], [-.023, .2, .139], [.015, .205, .143], [.1, .184, .135],
      [.20, .18, .13], [.29, .207, .142], [.39, .231, .146], [.465, .246, .132],
      [.51, .213, .109], [.545, .112, .081], [.55, .077, .074],
    ], 22, .0028), jacket);
    this.add(this.torso, tailored([[.526, .084, .075], [.56, .092, .082], [.598, .086, .08], [.613, .075, .071]], 18, .001), reinforcement);
    this.box(this.torso, webbing, [.017, .48, .012], [0, .248, .147], .005);
    this.line(this.torso, [[.012, .49, .116], [.012, .36, .151], [.012, .17, .144], [.012, .018, .149]], seam, .0017);
    this.box(this.torso, metal, [.009, .025, .005], [0, .455, .15], .002);
    // Upper back yoke and stitched elbow/shoulder reinforcement.
    this.add(this.torso, tailored([[.389, .231, .144], [.415, .235, .146], [.466, .247, .134], [.48, .231, .121]], 22, .0015), reinforcement, [0, 0, -.003]);
    this.line(this.torso, [[-.21, .387, -.075], [-.15, .397, -.132], [0, .4, -.15], [.15, .397, -.132], [.21, .387, -.075]], seam, .0015);
    for (const side of [-1, 1]) {
      this.box(this.torso, reinforcement, [.129, .102, .015], [side * .115, .11, .134], .018, [0, side * .09, side * .045]);
      this.box(this.torso, jacket, [.133, .031, .018], [side * .115, .153, .143], .009, [0, side * .09, side * .045]);
      this.line(this.torso, [[side * .059, .147, .15], [side * .113, .15, .154], [side * .17, .148, .141]], seam, .0014);
      this.box(this.torso, reinforcement, [.1, .068, .012], [side * .12, .345, .143], .012);
      this.box(this.torso, jacket, [.105, .022, .014], [side * .12, .374, .148], .006);
    }
    this.box(this.torso, rust, [.046, .023, .003], [-.127, .368, .158], .003);

    // Hip section stays visible between the jacket and the articulated legs.
    this.add(this.hips, tailored([[-.091, .142, .092], [-.061, .176, .119], [.007, .181, .128], [.041, .159, .112]], 20, .002), trousers);
    this.add(this.hips, tailored([[.01, .181, .128], [.034, .178, .126]], 20, 0), webbing);
    this.box(this.hips, metal, [.033, .026, .012], [0, .026, .13], .004);

    for (let index = 0; index < 2; index++) {
      const side = index === 0 ? -1 : 1;
      const upperArm = this.upperArms[index], forearm = this.forearms[index];
      this.torso.add(upperArm); upperArm.position.set(side * .235, .459, 0);
      upperArm.add(forearm); forearm.position.set(0, -.303, 0);
      this.add(upperArm, tailored([
        [-.319, .057, .06], [-.281, .068, .066], [-.235, .076, .073], [-.192, .078, .076],
        [-.125, .09, .082], [-.053, .095, .086], [.006, .081, .076], [.037, .038, .04], [.041, .002, .002],
      ], 18, .0025), jacket);
      this.ellipsoid(upperArm, reinforcement, [.075, .105, .024], [side * .035, -.237, -.057]);
      this.line(upperArm, [[side * .04, .015, -.071], [side * .063, -.1, -.076], [side * .04, -.2, -.076]], seam, .0013);
      if (index === 0) {
        this.box(upperArm, rust, [.008, .056, .046], [-.095, -.097, 0], .003);
        this.box(upperArm, seam, [.009, .007, .032], [-.1, -.09, .003], .001);
      }
      this.add(forearm, tailored([
        [-.278, .044, .041], [-.248, .053, .047], [-.192, .056, .055], [-.123, .071, .064],
        [-.065, .074, .069], [-.008, .063, .059], [.026, .044, .045],
      ], 18, .0028), jacket);
      this.add(forearm, tailored([[-.291, .044, .042], [-.263, .048, .043], [-.248, .05, .046]], 16, .001), webbing);
      // Short leather gloves, with exposed fingertips and a separated natural thumb.
      this.ellipsoid(forearm, leather, [.047, .067, .035], [0, -.337, .007]);
      this.ellipsoid(forearm, skin, [.035, .029, .029], [0, -.385, .012]);
      this.ellipsoid(forearm, leather, [.02, .043, .019], [-side * .036, -.336, .035], [-.27, 0, -side * .32]);
      this.line(forearm, [[-.029, -.316, .036], [0, -.318, .043], [.029, -.316, .036]], seam, .0012);
      if (index === 0) {
        this.box(forearm, rubber, [.063, .027, .01], [0, -.264, .045], .005);
        this.box(forearm, metal, [.026, .019, .003], [0, -.264, .052], .004);
      }

      const thigh = this.thighs[index], shin = this.shins[index], foot = this.feet[index];
      this.hips.add(thigh); thigh.position.set(side * .102, -.031, 0);
      thigh.add(shin); shin.position.set(0, -.402, 0);
      shin.add(foot); foot.position.set(0, -.39, 0);
      this.add(thigh, tailored([
        [-.427, .064, .066], [-.385, .079, .079], [-.325, .087, .084], [-.25, .094, .092],
        [-.151, .101, .099], [-.065, .104, .11], [.018, .095, .1], [.038, .036, .039],
      ], 18, .0025), trousers);
      this.box(thigh, reinforcement, [.045, .152, .125], [side * .086, -.22, 0], .014, [0, 0, side * .025]);
      this.box(thigh, trousers, [.05, .033, .133], [side * .089, -.16, 0], .01);
      this.line(thigh, [[side * .104, -.173, .056], [side * .106, -.248, .055], [side * .096, -.287, .055]], seam, .0012);
      this.ellipsoid(thigh, reinforcement, [.067, .079, .018], [0, -.366, .07]);
      this.add(shin, tailored([
        [-.405, .049, .051], [-.367, .062, .065], [-.324, .067, .068], [-.244, .068, .083, -.014],
        [-.174, .075, .086, -.01], [-.081, .075, .076], [-.027, .069, .071], [.019, .055, .057],
      ], 18, .0028), trousers);
      this.line(shin, [[side * .065, -.055, -.025], [side * .072, -.21, -.027], [side * .06, -.35, -.021]], seam, .0012);
      this.add(shin, tailored([[-.378, .061, .064], [-.347, .065, .067]], 16, .001), reinforcement);

      // Fitted ankle boots, sculpted toe box, rubber welt, laces, heel counter.
      this.box(foot, rubber, [.135, .044, .262], [0, -.103, .049], .018);
      this.box(foot, leather, [.122, .081, .24], [0, -.059, .044], .033);
      this.add(foot, tailored([[-.061, .06, .075, -.027], [-.008, .061, .067, -.031], [.072, .055, .061, -.034], [.092, .053, .06, -.034]], 18, .0005), leather);
      this.box(foot, rubber, [.126, .034, .071], [0, -.066, .132], .014);
      this.box(foot, rubber, [.107, .07, .022], [0, -.034, -.077], .01);
      this.box(foot, webbing, [.075, .108, .014], [0, .016, .036], .01, [-.26, 0, 0]);
      for (let lace = 0; lace < 4; lace++) {
        const y = -.015 + lace * .02, z = .066 - lace * .007;
        this.line(foot, [[-.027, y, z], [.027, y + .011, z - .003]], seam, .0017);
        this.line(foot, [[.027, y, z], [-.027, y + .011, z - .003]], seam, .0017);
      }
      this.line(foot, [[-.053, -.078, .105], [-.055, -.078, .155], [0, -.078, .177], [.055, -.078, .155], [.053, -.078, .105]], seam, .0014);
    }

    // A soft balaclava and raised hood make the face plausible at gameplay distance.
    this.ellipsoid(this.head, webbing, [.087, .124, .093], [0, .081, .006]);
    this.ellipsoid(this.head, skin, [.071, .04, .014], [0, .112, .089]);
    this.ellipsoid(this.head, webbing, [.077, .059, .025], [0, .051, .09]);
    this.ellipsoid(this.head, skin, [.018, .024, .021], [0, .09, .1]);
    // Shadowed brows/eyes, deliberately no bright artificial eye whites.
    for (const side of [-1, 1]) {
      this.ellipsoid(this.head, rubber, [.021, .006, .004], [side * .037, .119, .103]);
      this.line(this.head, [[side * .017, .135, .1], [side * .033, .139, .101], [side * .057, .132, .095]], leather, .0035);
    }
    this.hood(jacket, reinforcement, seam);

    // Pack, side bellows, top flap, lower rolled shelter, and sewn webbing.
    this.box(this.torso, canvas, [.312, .366, .152], [0, .283, -.21], .06);
    this.box(this.torso, reinforcement, [.314, .075, .151], [0, .427, -.211], .027);
    this.box(this.torso, canvas, [.217, .176, .038], [0, .215, -.298], .024);
    this.box(this.torso, reinforcement, [.229, .04, .043], [0, .295, -.303], .01);
    for (const side of [-1, 1]) {
      this.box(this.torso, canvas, [.059, .17, .112], [side * .169, .229, -.207], .022);
      this.ribbon(this.torso, [[side * .106, .097, -.29], [side * .108, .28, -.325], [side * .112, .457, -.266], [side * .117, .487, -.181]], webbing, .024);
      this.ribbon(this.torso, [[side * .126, .103, .116], [side * .152, .278, .153], [side * .157, .434, .125], [side * .13, .52, .032], [side * .125, .49, -.108], [side * .12, .426, -.21]], webbing, .029);
      this.box(this.torso, rubber, [.034, .035, .012], [side * .148, .305, .164], .003);
      this.box(this.torso, metal, [.027, .026, .007], [side * .108, .126, -.309], .003);
    }
    this.ribbon(this.torso, [[-.148, .33, .167], [0, .32, .162], [.148, .33, .167]], webbing, .015, true);
    this.box(this.torso, rubber, [.03, .022, .012], [.015, .321, .174], .004);
    this.line(this.torso, [[-.125, .288, -.307], [-.124, .144, -.301], [0, .124, -.307], [.124, .144, -.301], [.125, .288, -.307]], seam, .0015);
    this.box(this.torso, rust, [.052, .025, .004], [-.056, .221, -.319], .003);
    this.box(this.torso, seam, [.033, .004, .002], [-.056, .222, -.323], .001);
    this.ellipsoid(this.torso, reinforcement, [.19, .049, .061], [0, .075, -.226]);
    for (const side of [-1, 1]) this.box(this.torso, webbing, [.019, .096, .08], [side * .111, .075, -.244], .007);

    this.finalize();
  }

  private material(parameters: THREE.MeshStandardMaterialParameters): Material {
    const material = new THREE.MeshStandardMaterial(parameters);
    this.materials.add(material);
    return material;
  }

  private add(parent: Part, geometry: THREE.BufferGeometry, material: Material,
    position: number[] = [0, 0, 0], rotation: number[] = [0, 0, 0], scale: number[] = [1, 1, 1]) {
    const matrix = new THREE.Matrix4().compose(
      new THREE.Vector3(...position),
      new THREE.Quaternion().setFromEuler(new THREE.Euler(...rotation)),
      new THREE.Vector3(...scale),
    );
    geometry.applyMatrix4(matrix);
    // Normalize attributes before merging rounded boxes, parametric seams and profiles.
    const normalized = geometry.index ? geometry.toNonIndexed() : geometry;
    if (normalized !== geometry) geometry.dispose();
    for (const name of Object.keys(normalized.attributes)) if (!['position', 'normal', 'uv'].includes(name)) normalized.deleteAttribute(name);
    let materials = this.batches.get(parent);
    if (!materials) this.batches.set(parent, materials = new Map());
    let geometries = materials.get(material);
    if (!geometries) materials.set(material, geometries = []);
    geometries.push(normalized);
  }

  private box(parent: Part, material: Material, dimensions: [number, number, number], position: number[], radius = .008, rotation?: number[]) {
    this.add(parent, new RoundedBoxGeometry(...dimensions, 1, Math.min(radius, ...dimensions.map(v => v / 2))), material, position, rotation);
  }

  private ellipsoid(parent: Part, material: Material, scale: number[], position: number[], rotation?: number[]) {
    this.add(parent, new THREE.SphereGeometry(1, 16, 10), material, position, rotation, scale);
  }

  private line(parent: Part, points: number[][], material: Material, radius: number) {
    const curve = new THREE.CatmullRomCurve3(points.map(p => new THREE.Vector3(...p)));
    this.add(parent, new THREE.TubeGeometry(curve, Math.max(4, points.length * 3), radius, 4, false), material);
  }

  private ribbon(parent: Part, points: number[][], material: Material, width: number, horizontal = false) {
    const curve = new THREE.CatmullRomCurve3(points.map(p => new THREE.Vector3(...p)));
    const positions: number[] = [], uvs: number[] = [], indices: number[] = [];
    const steps = points.length * 4;
    for (let i = 0; i <= steps; i++) {
      const p = curve.getPoint(i / steps);
      // A narrow closed strip, rather than a round rope, reads as woven webbing.
      for (const [across, depth] of [[-1, -1], [1, -1], [1, 1], [-1, 1]]) {
        positions.push(p.x + (horizontal ? 0 : across * width / 2), p.y + (horizontal ? across * width / 2 : 0), p.z + depth * .002);
        uvs.push(across > 0 ? 1 : 0, i / steps);
      }
      if (i < steps) for (let j = 0; j < 4; j++) {
        const a = i * 4 + j, b = i * 4 + (j + 1) % 4;
        indices.push(a, b, a + 4, b, b + 4, a + 4);
      }
    }
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
    geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
    geometry.setIndex(indices); geometry.computeVertexNormals();
    this.add(parent, geometry, material);
  }

  private hood(outer: Material, inner: Material, seam: Material) {
    const positions: number[] = [], uvs: number[] = [], indices: number[] = [];
    const rows: Profile[] = [[-.006, .108, .103, -.012], [.037, .12, .122, -.019], [.096, .124, .128, -.019], [.162, .106, .117, -.016], [.206, .073, .083, -.012], [.227, .025, .027, -.012], [.23, .001, .001, -.012]];
    const segments = 22;
    for (let row = 0; row < rows.length; row++) for (let col = 0; col <= segments; col++) {
      const a = .72 + col / segments * (Math.PI * 2 - 1.44);
      const [y, x, z, offset = 0] = rows[row];
      positions.push(Math.sin(a) * x, y, Math.cos(a) * z + offset);
      uvs.push(col / segments, row / (rows.length - 1));
      if (row < rows.length - 1 && col < segments) {
        const n = row * (segments + 1) + col;
        indices.push(n, n + 1, n + segments + 1, n + 1, n + segments + 2, n + segments + 1);
      }
    }
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
    geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
    geometry.setIndex(indices); geometry.computeVertexNormals();
    this.add(this.head, geometry, outer);
    for (const side of [-1, 1]) {
      const edge = rows.map(([y, x, z, offset = 0]) => [side * Math.sin(.72) * x, y, Math.cos(.72) * z + offset]);
      this.line(this.head, edge, inner, .009);
      this.line(this.head, edge.map(([x, y, z]) => [x, y, z + .007]), seam, .0014);
      this.line(this.head, [[side * .077, .018, .073], [side * .071, -.032, .097], [side * .075, -.075, .114]], inner, .0021);
    }
    this.line(this.head, [[0, -.005, -.116], [0, .1, -.148], [0, .19, -.114], [0, .228, -.028]], seam, .0015);
  }

  private finalize() {
    for (const [parent, materials] of this.batches) for (const [material, inputs] of materials) {
      const geometry = mergeGeometries(inputs, false);
      for (const input of inputs) input.dispose();
      if (!geometry) throw new Error('Unable to assemble survivor geometry.');
      geometry.computeBoundingSphere();
      this.geometries.add(geometry);
      const mesh = new THREE.Mesh(geometry, material);
      mesh.castShadow = true; mesh.receiveShadow = true;
      parent.add(mesh);
    }
    this.batches.clear();
  }

  update(dt: number, state: SurvivorPose): void {
    const delta = Math.min(.05, Math.max(0, dt));
    const smooth = 1 - Math.exp(-delta * 12);
    this.elapsed += delta;
    const speed = Math.max(0, state.speed);
    const running = THREE.MathUtils.smoothstep(speed, 2.4, 5.5);
    const sprinting = THREE.MathUtils.smoothstep(speed, 5.4, 7.5);
    const moving = THREE.MathUtils.smoothstep(speed, .04, .6);
    this.stride += (moving - this.stride) * smooth;
    this.crouch += ((state.crouched ? 1 : 0) - this.crouch) * smooth;
    this.airborne += ((state.grounded ? 0 : 1) - this.airborne) * (1 - Math.exp(-delta * 9));
    this.climb += ((/climb|vault/i.test(state.locomotion) ? 1 : 0) - this.climb) * smooth;
    if (!this.previousGrounded && state.grounded) this.landing = .09;
    this.previousGrounded = state.grounded;
    this.landing *= Math.exp(-delta * 11);

    // Feet stay registered to the physics root. Only orientation/animation interpolates.
    this.group.position.set(state.position.x, state.position.y, state.position.z);
    if (!this.initialized) { this.group.rotation.y = state.yaw; this.initialized = true; }
    const yawDelta = Math.atan2(Math.sin(state.yaw - this.group.rotation.y), Math.cos(state.yaw - this.group.rotation.y));
    this.group.rotation.y += yawDelta * (1 - Math.exp(-delta * 15));
    this.phase += delta * (5.3 + Math.min(speed, 8) * 1.37) * this.stride * (1 - this.airborne * .7);
    const phase = this.phase;
    const gait = this.stride * (1 - this.airborne) * (1 - this.climb);
    const breathe = Math.sin(this.elapsed * (2 + (100 - Math.min(100, state.stamina)) * .007));
    const sway = Math.sin(phase);
    // Deep clearance crouch: lower the pelvis and fold the torso forward, rather
    // than scaling the body. The folded pose fits the 1.05 m movement capsule.
    this.hips.position.set(Math.sin(this.elapsed * .8) * .004 * (1 - gait) + sway * gait * .012,
      .944 - this.crouch * .523 - this.landing - gait * (.013 + running * .034 + sprinting * .012)
        + Math.cos(phase * 2) * gait * (.007 + running * .006) + breathe * .0025, -this.crouch * .13);
    this.hips.rotation.set(0, sway * .045 * gait, sway * .02 * gait);
    this.torso.rotation.set(.04 + this.crouch * .85 + running * gait * .075 - this.airborne * .065 - this.climb * .18,
      -sway * .075 * gait, -sway * .023 * gait);
    this.torso.position.y = breathe * .0015;
    this.head.rotation.set(-.025 - this.crouch * .2 - running * gait * .04, -sway * .022 * gait, Math.sin(this.elapsed * .67) * .013 * (1 - gait));

    for (let index = 0; index < 2; index++) {
      const side = index === 0 ? -1 : 1;
      const cycle = phase + index * Math.PI;
      const swing = Math.sin(cycle);
      const lift = Math.pow(Math.max(0, Math.cos(cycle)), 1.7) * (.055 + running * .11 + sprinting * .035) * gait;
      const footForward = swing * (.135 + running * .125 + sprinting * .04) * gait * (1 - this.crouch * .7) + this.crouch * .13;
      const footDown = this.hips.position.y - .031 - .126 - lift;
      // Two-bone sagittal IK holds the sole on the floor during stance, and preserves
      // actual limb lengths while lowering the body into a crouch or landing.
      const distance = THREE.MathUtils.clamp(Math.hypot(footDown, footForward), .05, .791);
      const kneeAngle = Math.PI - Math.acos(THREE.MathUtils.clamp((.402 ** 2 + .39 ** 2 - distance ** 2) / (2 * .402 * .39), -1, 1));
      const hipAngle = Math.atan2(-footForward, footDown) - Math.acos(THREE.MathUtils.clamp((.402 ** 2 + distance ** 2 - .39 ** 2) / (2 * .402 * distance), -1, 1));
      const airHip = -.37 + index * .23;
      const hip = THREE.MathUtils.lerp(hipAngle, airHip, this.airborne);
      const knee = THREE.MathUtils.lerp(kneeAngle, .63 + index * .15, this.airborne);
      this.thighs[index].rotation.set(hip - this.climb * (.95 + index * .28), 0, side * .009);
      this.shins[index].rotation.x = knee + this.climb * .9;
      this.feet[index].rotation.x = (-hip - knee) * (1 - this.airborne) - this.airborne * .18 + lift * 1.6;
      this.upperArms[index].rotation.set(swing * (.22 + running * .32 + sprinting * .14) * gait * (1 - this.crouch * .55) - this.crouch * .45 - this.airborne * .32 - this.climb * (1.7 - index * .3),
        0, side * (.095 + this.crouch * .045 + this.airborne * .07) + breathe * .004);
      this.forearms[index].rotation.set(-.12 - running * gait * .78 - this.crouch * 1.2 - this.airborne * .7 - this.climb * .45 - Math.max(0, swing) * .13 * gait, 0, 0);
      if(state.locomotion==='swim') {
        const stroke=Math.sin(this.elapsed*2.4+index*Math.PI);
        this.upperArms[index].rotation.set(-.85+stroke*.5,side*.55,side*.48);
        this.forearms[index].rotation.x=-.6;
        this.thighs[index].rotation.x=stroke*.22;
        this.shins[index].rotation.x=.25+Math.max(0,-stroke)*.2;
      }
    }
  }

  dispose(): void {
    for (const geometry of this.geometries) geometry.dispose();
    for (const material of this.materials) material.dispose();
    for (const texture of this.textures) texture.dispose();
    this.geometries.clear(); this.materials.clear(); this.textures.clear();
    this.group.removeFromParent();
    this.group.clear();
  }
}
