import './style.css';
import './ui/world-map.css';
import * as THREE from 'three/webgpu';
import { pass, uv, vec4, float, smoothstep } from 'three/tsl';
import { bloom } from 'three/addons/tsl/display/BloomNode.js';
import { Atmosphere } from './world/atmosphere';
import { InspectionCamera } from './engine/camera';
import { Ambience } from './engine/audio';
import { QUALITY, summarizeFrames } from './engine/statistics.mjs';
import { createInterface } from './ui/interface';
import { createCollisionWorld, type CollisionWorld } from './world/collision';
import { PlayerMotor } from './player/motor';
import { PlayerInput } from './player/input';
import { FollowCamera } from './player/follow-camera';
import { SurvivorCharacter } from './player/character';
import { ExplorationSession } from './game/exploration';
import { WorldStreamer } from './world/streamer';
import { WorldMap } from './ui/world-map';
import { chunkAt, terrainHeight } from './world/layout.mjs';
import { updateChunkMaterials } from './world/chunk-materials';
import { TerrainHorizon } from './world/horizon';

type Settings = { quality: string; weather: string; time: string; volume: number; diagnostics: boolean };
const settings: Settings = { quality: 'high', weather: 'clear', time: 'dusk', volume: 0.3, diagnostics: false };
const audio = new Ambience();
let controller: InspectionCamera;
let renderer: THREE.WebGPURenderer;
let atmosphere: Atmosphere;
let collision: CollisionWorld;
let motor: PlayerMotor;
let input: PlayerInput;
let followCamera: FollowCamera;
let survivor: SurvivorCharacter;
let world:WorldStreamer;
let horizon:TerrainHorizon;
let map:WorldMap;
let worldScene:THREE.Scene;
let backendName='WebGPU';
let targetsRevision=-1;
const journey = new ExplorationSession();
let ready = false;
let paused = false;
let benchmarkElapsed: number | null = null;
let benchmarkSamples: number[] = [];
let previousMode: 'showcase' | 'explore' = 'showcase';
let currentMode: 'showcase' | 'explore' = 'showcase';
const BENCHMARK_SECONDS = 30;
const WARMUP_SECONDS = 2;

const ui = createInterface({
  onEnter() {
    if (!ready) return;
    currentMode = 'explore'; controller.enabled=false; input.clear(); followCamera.reset(); ui.setMode('explore'); audio.start();
    renderer.domElement.focus({preventScroll:true});
    atmosphere.sun.shadow.needsUpdate=true;
    (renderer.domElement as HTMLCanvasElement).style.cursor = 'grab';
  },
  onExit() {
    if (!ready) return;
    saveProgress(); input.clear(); motor.resetMotion();
    cancelBenchmark();
    const cell=chunkAt(motor.state.position.x,motor.state.position.z);controller.setAnchor(cell.cx*96,cell.cz*96);
    currentMode = 'showcase'; controller.setMode('showcase'); ui.setMode('showcase');
    (renderer.domElement as HTMLCanvasElement).style.cursor = 'default';
  },
  onBenchmark() {
    if (!ready) return;
    if (benchmarkElapsed !== null) { cancelBenchmark(); return; }
    previousMode = currentMode; benchmarkSamples = []; benchmarkElapsed = 0;
    input.clear(); motor.resetMotion();
    currentMode = 'explore'; ui.setMode('explore'); controller.clear(); audio.start();
    ui.setBenchmark(0); ui.toast('30-second camera route · 2-second warm-up · keep this tab visible');
  },
  onSettingsChange(next) {
    if (!ready) return;
    if (benchmarkElapsed !== null) cancelBenchmark();
    else if(next.quality !== undefined || next.weather !== undefined || next.time !== undefined) ui.setBenchmark(null);
    Object.assign(settings,next);
    if(next.time!==undefined)journey.data.hour=({dawn:7,overcast:12,dusk:17.5,night:22} as Record<string,number>)[next.time]??17.5;
    applySettings(next);
    if (next.volume !== undefined) audio.start();
  },
  onPause(value) {
    paused = value; controller?.clear(); input?.clear(); motor?.resetMotion();
    if(value&&ready)saveProgress();
    if(!value&&currentMode==='explore')requestAnimationFrame(()=>renderer?.domElement.focus({preventScroll:true}));
  },
  onInventory() { if(ready)ui.showInventory(journey.inventory()); },
  onUseItem(id) {
    if(!ready)return;
    const result=journey.useItem(id,motor.state.stamina);motor.state.stamina=result.stamina;
    ui.toast(result.message);
    if(result.changed){audio.cue('collect');saveProgress();ui.refreshInventory(journey.inventory());}
  },
  onNewJourney(seed) {if(ready)void newWorld(seed);},
  onMap() {if(ready)map.open(ui.showWorldMap(),message=>ui.toast(message));},
});
ui.setSession(journey.hasSave);

function syncJourney() {
  world.setDoors(journey.data.openedDoors);
  world.update(motor.state.position,0,journey.data.looted);journey.setTargets(world.targets);targetsRevision=world.revision;
  atmosphere.sun.shadow.needsUpdate=true;
}
function saveProgress() { if(motor){journey.save(motor.state,input.yaw);ui.setSession(journey.hasSave);} }

async function newWorld(seed?:number) {
  cancelBenchmark();ready=false;input.enabled=false;input.clear();ui.setLoading('GENERATING YOUR WORLD');
  try {
    world.dispose();world.group.removeFromParent();horizon.dispose();journey.reset(seed);input.reset();map.waypoint=null;
    world=new WorldStreamer(journey.data.seed,collision,()=>{atmosphere.sun.shadow.needsUpdate=true;},true);worldScene.add(world.group);
    horizon=new TerrainHorizon(journey.data.seed);worldScene.add(horizon.group);
    world.setDoors(journey.data.openedDoors);
    await world.prime(journey.data.position);motor.setWaterLevel(null);motor.teleport(journey.data.position,false);
    motor.state.stamina=1;motor.state.yaw=Math.PI;syncJourney();followCamera.reset();saveProgress();
    currentMode='explore';ui.setMode('explore');ui.setReady(backendName);ready=true;audio.start();
    ui.toast('A new world. Open M to find buildings, shelters, and lakes.');
  } catch(error){ui.showError(`World generation failed: ${error instanceof Error?error.message:String(error)}`);}
}

function cancelBenchmark() {
  if (benchmarkElapsed === null) return;
  benchmarkElapsed = null; benchmarkSamples = [];
  currentMode = previousMode; controller.setMode('showcase'); followCamera.reset(); ui.setMode(currentMode); ui.setBenchmark(null);
  ui.toast('Benchmark cancelled');
}

function applySettings(changed?: Partial<Settings>) {
  const preset = QUALITY[settings.quality as keyof typeof QUALITY] ?? QUALITY.high;
  if (!changed || changed.quality !== undefined) {
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, preset.pixelRatio));
    renderer.setSize(window.innerWidth,window.innerHeight);
    renderer.shadowMap.enabled = preset.shadows;
    atmosphere.sun.castShadow = preset.shadows;
    if (atmosphere.sun.shadow.mapSize.x !== preset.shadowSize) {
      atmosphere.sun.shadow.mapSize.set(preset.shadowSize,preset.shadowSize);
      atmosphere.sun.shadow.map?.dispose(); atmosphere.sun.shadow.map = null;
      atmosphere.sun.shadow.needsUpdate = true;
    }
    atmosphere.setQuality(preset.particles);
  }
  if (!changed || changed.weather !== undefined || changed.time !== undefined) atmosphere.setClock(journey.data.hour,settings.weather);
  if (!changed || changed.weather !== undefined || changed.volume !== undefined) audio.set(settings.volume,settings.weather);
}

async function createRenderer() {
  const forced = new URLSearchParams(location.search).get('renderer') === 'webgl';
  let result = new THREE.WebGPURenderer({ antialias: true, forceWebGL: forced, trackTimestamp: true });
  try { await result.init(); }
  catch (firstError) {
    console.warn('WebGPU initialization failed; trying WebGL2.', firstError);
    try { result.dispose(); } catch { /* Partially initialized device. */ }
    result = new THREE.WebGPURenderer({ antialias: true, forceWebGL: true, trackTimestamp: true });
    await result.init();
  }
  return result;
}

async function start() {
  renderer = await createRenderer();
  renderer.setSize(window.innerWidth,window.innerHeight);
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1,1.35));
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.02;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  const canvas = renderer.domElement as HTMLCanvasElement;
  canvas.setAttribute('aria-label','AFTERFALL. WASD move, Shift sprint, C crouch, Space jump or climb, E interact, I inventory. Drag to look.');
  canvas.tabIndex=0;
  document.querySelector('#world')!.append(canvas);
  const backend = backendName = renderer.coordinateSystem === THREE.WebGPUCoordinateSystem ? 'WebGPU' : 'WebGL2';
  const scene = worldScene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(58,innerWidth/innerHeight,0.18,2600);
  const torch=new THREE.SpotLight('#ffe4bc',32,26,.53,.7,1.6);
  const torchTarget=new THREE.Object3D();torch.target=torchTarget;scene.add(torch,torchTarget);torch.visible=false;
  const torchDirection=new THREE.Vector3();
  controller = new InspectionCamera(camera,canvas);
  const savedCell=chunkAt(journey.data.position.x,journey.data.position.z);controller.setAnchor(savedCell.cx*96,savedCell.cz*96);
  atmosphere = new Atmosphere(scene,renderer,[],[]);
  collision=await createCollisionWorld([],[],false);
  world=new WorldStreamer(journey.data.seed,collision,()=>{atmosphere.sun.shadow.needsUpdate=true;},true);scene.add(world.group);
  horizon=new TerrainHorizon(journey.data.seed);scene.add(horizon.group);
  world.setDoors(journey.data.openedDoors);
  await world.prime(journey.data.position);
  horizon.update(journey.data.position.x,journey.data.position.z,world.loaded,world.revision);
  // Older worlds outside the city were flat. Keep their saved X/Z and inventory,
  // but lift a buried survivor onto the new hillside before creating the capsule.
  const restoredGround=terrainHeight(world.planAt(journey.data.position),journey.data.position.x,journey.data.position.z);
  if(journey.data.position.y<restoredGround-.15)journey.data.position.y=restoredGround+.1;
  motor=new PlayerMotor(collision,journey.data.position);
  motor.teleport(journey.data.position,journey.data.crouched);
  motor.state.stamina=journey.data.stamina;motor.state.yaw=journey.data.yaw;
  input=new PlayerInput(canvas);input.yaw=journey.data.yaw;input.setCrouched(motor.state.crouched);
  followCamera=new FollowCamera(camera,collision);
  survivor=new SurvivorCharacter();survivor.group.visible=false;scene.add(survivor.group);
  map=new WorldMap();
  syncJourney();
  applySettings();

  const post = new THREE.PostProcessing(renderer);
  const scenePass = pass(scene,camera);
  const sceneColor = scenePass.getTextureNode('output');
  const glow = bloom(sceneColor,0.13,0.45,1.2);
  const vignette = float(1).sub(smoothstep(0.22,0.82,uv().sub(0.5).length()).mul(0.22));
  post.outputNode = vec4(sceneColor.rgb.add(glow.rgb).mul(vignette),sceneColor.a);
  let lastTime=performance.now(), elapsed=0, statsTime=0, frames: number[]=[];
  let gpuMs: number|null=null, timingPending=false, gpuFrames=0;
  let renderedFrames=0, saveElapsed=0, footstepDistance=0, hudElapsed=0;
  let previousGrounded=false,wasPlaying=false;
  const idleInput={moveX:0,moveZ:0,sprint:false,walk:false,crouch:false,jump:false};

  window.addEventListener('resize', () => {
    camera.aspect = innerWidth/innerHeight; camera.updateProjectionMatrix();
    renderer.setSize(innerWidth,innerHeight);
    if(benchmarkElapsed !== null) cancelBenchmark();
  });
  document.addEventListener('visibilitychange', () => {
    controller.clear();input.clear();motor.resetMotion();audio.pause(document.hidden);
    if(document.hidden)saveProgress();
    if(document.hidden && benchmarkElapsed !== null) { cancelBenchmark(); ui.toast('Benchmark cancelled because the tab was hidden'); }
    lastTime=performance.now();
  });
  window.addEventListener('pagehide',saveProgress);
  window.addEventListener('blur',()=>{input.clear();motor.resetMotion();});
  canvas.addEventListener('webglcontextlost', event => {
    event.preventDefault(); renderer.setAnimationLoop(null); ready=false;
    ui.showError('The graphics device was interrupted. Reload to restore the environment.');
  });
  renderer.onDeviceLost = () => {
    renderer.setAnimationLoop(null); ready=false;
    ui.showError('The graphics device was interrupted. Reload to restore the environment.');
  };

  // Compile once before measuring. The benchmark also excludes its first two seconds.
  await renderer.compileAsync(scene,camera);
  lastTime=performance.now();
  renderer.setAnimationLoop(() => {
    const now=performance.now();
    const rawDt=(now-lastTime)/1000; lastTime=now;
    if(document.hidden) return;
    const dt=Math.min(rawDt,0.1);
    if(!paused) elapsed+=dt;
    const active=ready&&!paused&&!ui.isModalOpen();
    controller.enabled=false;
    input.enabled=active&&currentMode==='explore'&&benchmarkElapsed===null;
    if(benchmarkElapsed!==null && !paused && !ui.isModalOpen()) {
      benchmarkElapsed+=rawDt;
      if(benchmarkElapsed>WARMUP_SECONDS) benchmarkSamples.push(rawDt*1000);
      const progress=Math.max(0,(benchmarkElapsed-WARMUP_SECONDS)/BENCHMARK_SECONDS);
      ui.setBenchmark(Math.min(1,progress));
      if(progress>=1) {
        const result=summarizeFrames(benchmarkSamples);
        benchmarkElapsed=null;
        currentMode=previousMode; controller.setMode('showcase'); followCamera.reset(); ui.setMode(currentMode);
        ui.setBenchmark(null,{...result,context:`${backend} · ${canvas.width} × ${canvas.height} · ${settings.quality} · ${settings.weather} / ${settings.time}`});
      }
    }
    const cameraProgress=benchmarkElapsed===null?null:Math.max(0,(benchmarkElapsed-WARMUP_SECONDS)/BENCHMARK_SECONDS);
    const playing=currentMode==='explore'&&benchmarkElapsed===null;
    if(playing!==wasPlaying){atmosphere.sun.shadow.needsUpdate=true;wasPlaying=playing;}
    survivor.group.visible=playing;
    atmosphere.sun.shadow.autoUpdate=playing&&active;
    if(playing) {
      if(active) {
        world.update(motor.state.position,dt,journey.data.looted);
        if(world.error){ready=false;input.clear();ui.showError(`World streaming stopped: ${world.error.message}`);}
        if(targetsRevision!==world.revision){journey.setTargets(world.targets);targetsRevision=world.revision;}
        const cell=chunkAt(motor.state.position.x,motor.state.position.z);journey.visit(`${cell.cx}:${cell.cz}`);
        motor.setWaterLevel(world.waterLevel(motor.state.position));
        const resting=journey.restRemaining>0;
        motor.step(dt,resting?{...idleInput,crouch:motor.state.crouched}:input.sample());
        if(resting)motor.state.stamina=Math.min(1,motor.state.stamina+dt*.3);
        if(journey.update(dt)){motor.state.stamina=1;syncJourney();saveProgress();audio.cue('rest');ui.toast('Morning has arrived. Rested, saved, and ready to explore.');}
        const target=journey.nearby(motor.state.position,motor.state.crouched,collision);
        if(input.consumeInteraction()) {
          const result=journey.interact(target,motor.state.position,motor.state.crouched,collision);
          if(result){ui.toast(result.message);if(result.changed){syncJourney();saveProgress();audio.cue(result.door?'door':'collect');}}
        }
        footstepDistance+=motor.state.grounded?motor.state.speed*dt:0;
        if(footstepDistance>(motor.state.crouched?.95:motor.state.speed>4?2.1:1.65)) {
          footstepDistance=0;audio.footstep(motor.state.crouched?.35:1,settings.weather==='rain');
        }
        if(!previousGrounded&&motor.state.grounded)audio.footstep(.6,settings.weather==='rain');
        previousGrounded=motor.state.grounded;
        saveElapsed+=dt;if(saveElapsed>8){saveElapsed=0;saveProgress();}
      }
      const renderState=motor.getRenderState();
      survivor.update(active?dt:0,renderState);
      const cameraDistance=followCamera.update(dt,renderState.position,renderState.crouched,input);
      survivor.group.visible=cameraDistance>.7;
      torch.visible=input.flashlight;
      if(torch.visible){camera.getWorldDirection(torchDirection);torch.position.copy(camera.position).addScaledVector(torchDirection,.6);torchTarget.position.copy(torch.position).addScaledVector(torchDirection,12);}
      hudElapsed+=dt;
      if(hudElapsed>.1) {
        hudElapsed=0;
        const objective=journey.objective(motor.state.position);
        if(map.waypoint) {
          const distance=Math.hypot(map.waypoint.x-motor.state.position.x,map.waypoint.z-motor.state.position.z);
          if(distance<8){map.waypoint=null;ui.toast('You reached your marked destination.');}
          else{objective.title='Your marked destination';objective.detail=`${Math.ceil(distance)} m · follow your map · M to choose another destination`;}
        }
        const target=journey.nearby(motor.state.position,motor.state.crouched,collision);
        ui.setPlayer({...motor.state,objective:objective.title,objectiveDetail:objective.detail,
          interactLabel:target?.label??null,saveStatus:journey.saveStatus});
        ui.setWorldInfo(world.planAt(motor.state.position).name,journey.data.day,journey.data.hour,journey.data.seed,input.yaw,journey.restRemaining>0);
        map.update(journey.data.seed,motor.state.position.x,motor.state.position.z,input.yaw);
      }
    } else {torch.visible=false;if(active) controller.update(dt,elapsed,cameraProgress);}
    atmosphere.setClock(journey.data.hour,settings.weather);
    if(ready)horizon.update(motor.state.position.x,motor.state.position.z,world.loaded,world.revision);
    atmosphere.update(paused?0:dt,elapsed,camera);
    updateChunkMaterials(elapsed,atmosphere.wetness);
    try { post.render(); }
    catch(error) {
      console.error('AFTERFALL render failed',error);
      renderer.setAnimationLoop(null); ready=false;
      ui.showError(`Rendering was interrupted: ${error instanceof Error?error.message:'unknown graphics error'}`);
      return;
    }
    gpuFrames++;
    if(!timingPending && renderer.hasFeature('timestamp-query')) {
      timingPending=true;
      const measuredFrames=gpuFrames; gpuFrames=0;
      void renderer.resolveTimestampsAsync(THREE.TimestampQuery.RENDER).then(value=>{
        const average=(value ?? 0)/measuredFrames;
        gpuMs=Number.isFinite(average)&&average>0?average:null;
      }).catch(()=>{ gpuMs=null; }).finally(()=>{ timingPending=false; });
    }
    if(++renderedFrames===3) { ready=true; ui.setReady(backend); }
    frames.push(rawDt*1000); if(frames.length>120) frames.shift();
    statsTime+=rawDt;
    if(statsTime>0.5) {
      statsTime=0;
      const summary=summarizeFrames(frames);
      const info=renderer.info;
      const memory=(performance as Performance & {memory?:{usedJSHeapSize:number}}).memory;
      ui.setStats({ fps:summary.avgFps,frameMs:summary.avgFrameMs,
        drawCalls:info.render.drawCalls,triangles:info.render.triangles,gpuMs,
        memoryMB:memory?memory.usedJSHeapSize/1048576:null,
        geometries:info.memory.geometries,textures:info.memory.textures,backend });
    }
  });
}

void start().catch(error => {
  console.error('AFTERFALL initialization failed',error);
  ui.showError(`The environment could not start. ${error instanceof Error?error.message:'WebGPU or WebGL2 is required.'} Try a current desktop Chrome or Edge browser with hardware acceleration enabled.`);
});
