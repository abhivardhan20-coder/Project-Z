import * as THREE from 'three/webgpu';
import { uniform, mix, positionLocal, mx_noise_float, vec3 } from 'three/tsl';
import { stableShadowAnchor, shadowLightPosition } from './shadow-anchor';

const LOOKS: Record<string, { sky: string; horizon: string; fog: string; sun: string; strength: number; ambient: number; exposure: number }> = {
  dusk: { sky: '#455352', horizon: '#c5aa80', fog: '#a39780', sun: '#ffd5a0', strength: 3.1, ambient: 1.65, exposure: 1.02 },
  dawn: { sky: '#607a84', horizon: '#e4bf9a', fog: '#b9b5a7', sun: '#ffe0bf', strength: 3.5, ambient: 2.1, exposure: 1.05 },
  overcast: { sky: '#4a646c', horizon: '#9daaa8', fog: '#879a99', sun: '#d4e6de', strength: 1.4, ambient: 2.4, exposure: 1.08 },
  night: { sky: '#071017', horizon: '#172b32', fog: '#12262b', sun: '#84a8cc', strength: 0.55, ambient: 0.8, exposure: 0.8 },
};

export class Atmosphere {
  readonly sun = new THREE.DirectionalLight('#ffd5a0', 3.1);
  private hemi = new THREE.HemisphereLight('#c2d3cd', '#342d21', 1.65);
  private skyCanvas = document.createElement('canvas');
  private skyTexture: THREE.CanvasTexture;
  private zenith = uniform(new THREE.Color(LOOKS.dusk.sky));
  private horizon = uniform(new THREE.Color(LOOKS.dusk.horizon));
  private zenithTarget = new THREE.Color(LOOKS.dusk.sky);
  private horizonTarget = new THREE.Color(LOOKS.dusk.horizon);
  private particles: THREE.LineSegments;
  private geometry = new THREE.BufferGeometry();
  private rainMaterial = new THREE.LineBasicMaterial({ color: '#b3c8c8', transparent: true, opacity: 0.17, depthWrite: false });
  private positions = new Float32Array(2000 * 6);
  private seeds = new Float32Array(2000 * 3);
  private currentWetness = 1;
  private targetWetness = 1;
  private weather = 'rain';
  private time = 'dusk';
  private count = 1200;
  private targetFog = 0.012;
  private targetSun = 3.1;
  private targetAmbient = 1.65;
  private targetExposure = 1.02;
  private fogColor = new THREE.Color(LOOKS.dusk.fog);
  private sunColor = new THREE.Color(LOOKS.dusk.sun);
  private skyDome:THREE.Mesh;
  private clockHour=-1;
  private shadowAnchor=new THREE.Vector3();

  constructor(private scene: THREE.Scene, private renderer: THREE.WebGPURenderer, private roadMaterials: THREE.MeshStandardMaterial[], private lamps: THREE.Light[]) {
    this.scene.fog = new THREE.FogExp2(LOOKS.dusk.fog, 0.012);
    this.skyCanvas.width = 1024; this.skyCanvas.height = 512;
    this.skyTexture = new THREE.CanvasTexture(this.skyCanvas);
    this.skyTexture.mapping = THREE.EquirectangularReflectionMapping;
    this.skyTexture.colorSpace = THREE.SRGBColorSpace;
    this.scene.background = new THREE.Color(LOOKS.dusk.fog);
    const skyMaterial = new THREE.MeshBasicNodeMaterial({ side:THREE.BackSide, fog:false, depthWrite:false });
    const altitude = positionLocal.y.div(1200).clamp(0,1).pow(0.6);
    const clouds = mx_noise_float(positionLocal.mul(vec3(0.00368,0.01125,0.00245))).mul(0.055);
    skyMaterial.colorNode = mix(this.horizon,this.zenith,altitude).add(clouds).max(0);
    const skyDome = this.skyDome = new THREE.Mesh(new THREE.SphereGeometry(2200,48,24),skyMaterial);
    skyDome.name = 'Atmospheric sky dome';
    skyDome.renderOrder = -10;
    scene.add(skyDome);
    this.scene.environment = this.skyTexture;
    this.scene.environmentIntensity = 0.36;
    this.paintSky();
    this.sun.position.set(-36, 48, -87);
    this.sun.target.position.set(0, 0, -28);
    this.sun.castShadow = true;
    this.sun.shadow.mapSize.set(2048,2048);
    this.sun.shadow.camera.left = -64; this.sun.shadow.camera.right = 64;
    this.sun.shadow.camera.top = 64; this.sun.shadow.camera.bottom = -64;
    this.sun.shadow.camera.near = 1; this.sun.shadow.camera.far = 320;
    this.sun.shadow.bias = -0.00015; this.sun.shadow.normalBias = 0.09;
    this.sun.shadow.radius = 3;
    // Main loop updates shadows while playing; stationary title views reuse them.
    this.sun.shadow.autoUpdate = false;
    this.sun.shadow.needsUpdate = true;
    scene.add(this.sun, this.sun.target, this.hemi);
    let seed = 8703;
    const rand = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };
    for (let i=0; i<this.seeds.length; i++) this.seeds[i] = rand();
    this.geometry.setAttribute('position', new THREE.BufferAttribute(this.positions,3).setUsage(THREE.DynamicDrawUsage));
    this.geometry.setDrawRange(0, this.count * 2);
    this.particles = new THREE.LineSegments(this.geometry,this.rainMaterial);
    this.particles.frustumCulled = false;
    scene.add(this.particles);
  }

  set(weather: string, time: string) {
    this.weather = weather; this.time = LOOKS[time] ? time : 'dusk';
    this.targetWetness = weather === 'rain' ? 1 : weather === 'fog' ? 0.6 : 0.14;
    this.targetFog = weather === 'fog' ? 0.027 : weather === 'rain' ? 0.012 : 0.007;
    const look = LOOKS[this.time];
    this.targetSun = look.strength; this.targetAmbient = look.ambient; this.targetExposure = look.exposure;
    this.fogColor.set(look.fog); this.sunColor.set(look.sun);
    this.zenithTarget.set(look.sky); this.horizonTarget.set(look.horizon);
    this.paintSky();
  }

  setQuality(count: number) { this.count = count; this.geometry.setDrawRange(0, count * 2); }

  get wetness() { return this.currentWetness; }

  /** Smooth clock-driven lighting; sky, rain and shadow coverage travel with exploration. */
  setClock(hour:number,weather:string) {
    const h=((hour%24)+24)%24;
    if(Math.abs(h-this.clockHour)<.035&&weather===this.weather)return;
    const initial=this.clockHour<0;
    this.clockHour=h;
    const next=h<5.5||h>=19.5?'night':h<8?'dawn':h<17.5?'overcast':'dusk';
    if(next!==this.time||weather!==this.weather)this.set(weather,next);
    const daylight=Math.max(0,Math.sin((h-6)/12*Math.PI));
    if(next==='overcast') {
      this.targetSun=2.2+daylight*1.8;this.targetAmbient=2.3;
      this.zenithTarget.set('#7b9caa');this.horizonTarget.set('#d6d2b7');
      this.fogColor.set('#acb5ac');this.sunColor.set('#fff1d8');this.targetExposure=1.04;
    }
    this.targetFog=weather==='fog'?.012:weather==='rain'?.004:.0015;
    if(initial) {
      // Begin with the saved sky/weather rather than fading from a rainy dusk.
      const fog=this.scene.fog as THREE.FogExp2;
      fog.density=this.targetFog;fog.color.copy(this.fogColor);
      this.currentWetness=this.targetWetness;
      this.sun.intensity=this.targetSun;this.sun.color.copy(this.sunColor);
      this.hemi.intensity=this.targetAmbient;this.renderer.toneMappingExposure=this.targetExposure;
      this.zenith.value.copy(this.zenithTarget);this.horizon.value.copy(this.horizonTarget);
      this.rainMaterial.opacity=weather==='rain'?.2:0;this.particles.visible=weather==='rain';
    }
  }

  private paintSky() {
    const ctx = this.skyCanvas.getContext('2d')!;
    const look = LOOKS[this.time];
    const gradient = ctx.createLinearGradient(0,0,0,512);
    gradient.addColorStop(0,look.sky); gradient.addColorStop(0.35,look.sky);
    gradient.addColorStop(0.52,look.horizon); gradient.addColorStop(0.65,look.fog); gradient.addColorStop(1,'#292d26');
    ctx.fillStyle = gradient; ctx.fillRect(0,0,1024,512);
    let seed = 773;
    const rand = () => { seed = (seed*1664525+1013904223)>>>0; return seed/4294967296; };
    for(let i=0;i<110;i++) {
      const x = rand()*1024, y = 80+rand()*150, radius=30+rand()*100;
      const cloud = ctx.createRadialGradient(x,y,0,x,y,radius);
      cloud.addColorStop(0, this.time==='night' ? 'rgba(10,17,24,.18)' : 'rgba(33,47,49,.10)'); cloud.addColorStop(1,'rgba(30,40,43,0)');
      ctx.save(); ctx.translate(x,y); ctx.scale(2.7,0.34); ctx.translate(-x,-y);
      ctx.fillStyle=cloud; ctx.fillRect(x-radius,y-radius,radius*2,radius*2); ctx.restore();
    }
    this.skyTexture.needsUpdate = true;
  }

  update(dt: number, elapsed: number, camera: THREE.Camera) {
    this.skyDome.position.copy(camera.position);
    const shadow=this.sun.shadow,sc=shadow.camera;
    stableShadowAnchor(camera.position,sc.right-sc.left,sc.top-sc.bottom,shadow.mapSize.x,shadow.mapSize.y,this.shadowAnchor);
    if(!this.sun.target.position.equals(this.shadowAnchor)) {
      this.sun.target.position.copy(this.shadowAnchor);
      shadowLightPosition(this.shadowAnchor,this.sun.position);shadow.needsUpdate=true;
    }
    const blend = 1-Math.exp(-dt*0.65);
    this.currentWetness = THREE.MathUtils.lerp(this.currentWetness,this.targetWetness,blend);
    const fog = this.scene.fog as THREE.FogExp2;
    fog.density = THREE.MathUtils.lerp(fog.density,this.targetFog,blend);
    fog.color.lerp(this.fogColor,blend);
    this.sun.color.lerp(this.sunColor,blend);
    this.zenith.value.lerp(this.zenithTarget,blend);
    this.horizon.value.lerp(this.horizonTarget,blend);
    this.sun.intensity = THREE.MathUtils.lerp(this.sun.intensity,this.targetSun,blend);
    this.hemi.intensity = THREE.MathUtils.lerp(this.hemi.intensity,this.targetAmbient,blend);
    this.renderer.toneMappingExposure = THREE.MathUtils.lerp(this.renderer.toneMappingExposure,this.targetExposure,blend);
    for(const material of this.roadMaterials) material.roughness = 0.92-this.currentWetness*0.65;
    for(const lamp of this.lamps) lamp.intensity = THREE.MathUtils.lerp(lamp.intensity,this.time==='night'?18:5,blend);
    this.rainMaterial.opacity = THREE.MathUtils.lerp(this.rainMaterial.opacity,this.weather==='rain'?0.2:0,blend);
    this.particles.visible = this.rainMaterial.opacity > 0.003;
    if(!this.particles.visible) return;
    const x=camera.position.x, z=camera.position.z;
    for(let i=0;i<this.count;i++) {
      const s=i*3, p=i*6;
      const px=(this.seeds[s]*70 + elapsed*1.3)%70-35+x;
      const py=(this.seeds[s+1]*30-elapsed*(17+this.seeds[s+2]*7)%30+30)%30+camera.position.y-8;
      const pz=this.seeds[s+2]*76-60+z;
      this.positions[p]=px; this.positions[p+1]=py; this.positions[p+2]=pz;
      this.positions[p+3]=px+0.07; this.positions[p+4]=py-0.42; this.positions[p+5]=pz;
    }
    this.geometry.attributes.position.needsUpdate=true;
  }
}
