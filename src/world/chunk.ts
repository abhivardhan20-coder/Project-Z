import * as THREE from 'three/webgpu';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { createBuildingStages } from './building';
import { terrainHeight, lakeRadius, ruralTrailX, ruralTrailZ } from './layout.mjs';
import { landscapeMaterials } from './chunk-materials';
import type { ChunkPlan, ChunkVisual, BuildingVisual } from './types';
import type { CollisionBox } from './collision';

const SIZE=96;
type Point=[number,number,number];

/** Synchronous generation remains available for deterministic physics tests. */
export function createChunk(plan:ChunkPlan):ChunkVisual {
  const stages=createChunkStages(plan);
  let step=stages.next();while(!step.done)step=stages.next();
  if(!step.value)throw new Error('Synchronous chunk generation was cancelled');
  return step.value;
}

/** Build between render opportunities instead of blocking a frame for an entire district. */
export async function createChunkAsync(plan:ChunkPlan,shouldAbort:()=>boolean=()=>false):Promise<ChunkVisual|null> {
  const stages=createChunkStages(plan);
  try {
    while(true) {
      const deadline=performance.now()+4;
      do {
        if(shouldAbort()){stages.return(null);return null;}
        const step=stages.next();if(step.done)return step.value;
      }while(performance.now()<deadline);
      const scheduler=(globalThis as typeof globalThis & {scheduler?:{yield?:()=>Promise<void>}}).scheduler;
      if(scheduler?.yield)await scheduler.yield();
      else await new Promise<void>(resolve=>setTimeout(resolve,0));
    }
  }catch(error){stages.return(null);throw error;}
}

/** Deterministic, disposable scenery. Geometry and collision use the same world coordinates. */
function* createChunkStages(plan:ChunkPlan):Generator<void,ChunkVisual|null,void> {
  const group=new THREE.Group();group.name=`District ${plan.key} / ${plan.name}`;
  const boxes:CollisionBox[]=[],targets:ChunkVisual['targets']=[],water:THREE.Mesh[]=[];
  const lootVisuals:ChunkVisual['lootVisuals']=new Map();
  const doors:ChunkVisual['doors']=new Map();
  const ownGeometry:THREE.BufferGeometry[]=[],ownMaterials:THREE.Material[]=[],ownTextures:THREE.Texture[]=[];
  const ownInstances:THREE.InstancedMesh[]=[];
  const buildings:BuildingVisual[]=[],batches=new Map<THREE.Material,THREE.BufferGeometry[]>();
  const noShadowMaterials=new Set<THREE.Material>();
  let completed=false,disposed=false;
  const dispose=()=>{
    if(disposed)return;disposed=true;group.removeFromParent();
    for(const building of buildings)building.dispose();
    for(const mesh of ownInstances)mesh.dispose();
    for(const geometry of ownGeometry)geometry.dispose();
    for(const geometries of batches.values())for(const geometry of geometries)geometry.dispose();
    batches.clear();
    for(const material of ownMaterials)material.dispose();
    for(const texture of ownTextures)texture.dispose();
    group.clear();lootVisuals.clear();doors.clear();
  };
  try {
  const m=landscapeMaterials(),minX=plan.cx*SIZE,minZ=plan.cz*SIZE;
  const natural=!!plan.rural||plan.biome==='lake'||plan.biome==='park';
  const rural=!!plan.rural;
  let seed=plan.seed>>>0;
  const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
  const range=(a:number,b:number)=>a+(b-a)*random();
  const transform=new THREE.Object3D();
  let matrix=new THREE.Matrix4();

  function add(geometry:THREE.BufferGeometry,material:THREE.Material,p:Point=[0,0,0],r:Point=[0,0,0],s:Point=[1,1,1]) {
    transform.position.set(...p);transform.rotation.set(...r);transform.scale.set(...s);transform.updateMatrix();
    geometry.applyMatrix4(transform.matrix).applyMatrix4(matrix);geometry.clearGroups();
    if(geometry.index){const nonIndexed=geometry.toNonIndexed();geometry.dispose();geometry=nonIndexed;}
    const list=batches.get(material)??[];list.push(geometry);batches.set(material,list);
  }
  function box(material:THREE.Material,p:Point,size:Point,r:Point=[0,0,0]){add(new THREE.BoxGeometry(...size),material,p,r);}
  function cylinder(material:THREE.Material,p:Point,top:number,bottom:number,height:number,r:Point=[0,0,0],segments=7) {
    add(new THREE.CylinderGeometry(top,bottom,height,segments),material,p,r);
  }
  function rod(material:THREE.Material,a:Point,b:Point,radius:number,tip=radius) {
    const from=new THREE.Vector3(...a),to=new THREE.Vector3(...b),delta=to.clone().sub(from);
    const geometry=new THREE.CylinderGeometry(tip,radius,delta.length(),6);
    geometry.applyQuaternion(new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0,1,0),delta.normalize()));
    add(geometry,material,from.add(to).multiplyScalar(.5).toArray() as Point);
  }
  function at(x:number,y:number,z:number,angle:number,build:()=>void) {
    const previous=matrix;matrix=new THREE.Matrix4().makeRotationY(angle);matrix.setPosition(x,y,z);build();matrix=previous;
  }
  function occupied(x:number,z:number,margin=1.3) {
    return plan.buildings.some(building=>{
      const dx=x-building.x,dz=z-building.z,c=Math.cos(building.rotation),s=Math.sin(building.rotation);
      return Math.abs(dx*c-dz*s)<building.width/2+margin&&Math.abs(dx*s+dz*c)<building.depth/2+margin;
    });
  }
  const lake=plan.lake;
  const lakeDistance=(x:number,z:number)=>lake?lakeRadius(lake,x,z):100;
  const yAt=(x:number,z:number)=>terrainHeight(plan,x,z);

  // An exact two-metre height mesh is also the Rapier ground collider. Adjacent edges meet at zero.
  const steps=48,row=steps+1,vertices=new Float32Array(row*row*3),colors=new Float32Array(row*row*3),uvs=new Float32Array(row*row*2);
  const indices=new Uint32Array(steps*steps*6),tint=new THREE.Color();
  let offset=0;
  for(let iz=0;iz<=steps;iz++) {
  for(let ix=0;ix<=steps;ix++) {
    const x=minX+ix*2,z=minZ+iz*2,i=iz*row+ix,y=yAt(x,z),radius=lakeDistance(x,z);
    vertices.set([x,y,z],i*3);uvs.set([x*.33,z*.33],i*2);
    const mottling=(Math.sin(x*.18+z*.27)*Math.sin(z*.16-x*.21)+1)*.5;
    if(lake&&radius<1.14)tint.set(radius<.88?'#6b7867':'#ad9e74');
    else if(plan.biome==='mountain')tint.set('#7f8470').lerp(new THREE.Color('#a8a38b'),mottling*.74);
    else if(plan.biome==='forest')tint.set('#566c49').lerp(new THREE.Color('#7b8060'),mottling*.55);
    else if(natural)tint.set('#647553').lerp(new THREE.Color('#979470'),mottling*.58);
    else tint.set('#8b8c70').lerp(new THREE.Color('#667657'),mottling*.65);
    const edge=Math.min(ix*2,iz*2,SIZE-ix*2,SIZE-iz*2);if(edge<10&&!rural)tint.set('#858878');
    colors.set([tint.r,tint.g,tint.b],i*3);
    if(ix<steps&&iz<steps){const a=i,b=i+1,c=i+row,d=c+1;indices.set([a,c,b,b,c,d],offset);offset+=6;}
  }
  yield;
  }
  const terrainGeometry=new THREE.BufferGeometry();terrainGeometry.setAttribute('position',new THREE.BufferAttribute(vertices,3));
  terrainGeometry.setAttribute('normal',new THREE.BufferAttribute(new Float32Array(vertices.length),3));
  terrainGeometry.setAttribute('color',new THREE.BufferAttribute(colors,3));terrainGeometry.setAttribute('uv',new THREE.BufferAttribute(uvs,2));
  terrainGeometry.setIndex(new THREE.BufferAttribute(indices,1));terrainGeometry.computeVertexNormals();ownGeometry.push(terrainGeometry);
  // Border normals use the same global height samples on either side of a tile.
  // Interior vertices keep the inexpensive mesh normals.
  if(rural) {
    const normals=terrainGeometry.getAttribute('normal'),normal=new THREE.Vector3();
    for(let iz=0;iz<=steps;iz++)for(let ix=0;ix<=steps;ix++)if(ix===0||iz===0||ix===steps||iz===steps) {
      const x=minX+ix*2,z=minZ+iz*2;
      normal.set(yAt(x-.5,z)-yAt(x+.5,z),1,yAt(x,z-.5)-yAt(x,z+.5)).normalize();
      normals.setXYZ(iz*row+ix,normal.x,normal.y,normal.z);
    }
  }
  const terrainMesh=new THREE.Mesh(terrainGeometry,m.ground);terrainMesh.receiveShadow=true;terrainMesh.name='Continuous terrain / physical heightfield';group.add(terrainMesh);
  yield;

  // Every boundary is an open twelve-metre avenue shared equally with the next chunk.
  function surface(material:THREE.Material,x:number,z:number,width:number,depth:number,y:number) {
    const geometry=new THREE.PlaneGeometry(width,depth);geometry.rotateX(-Math.PI/2);
    const uv=geometry.getAttribute('uv');for(let i=0;i<uv.count;i++)uv.setXY(i,uv.getX(i)*width*.3,uv.getY(i)*depth*.3);
    add(geometry,material,[minX+x,y,minZ+z]);
  }
  if(!rural) {
  surface(m.asphalt,48,3,96,6,.035);surface(m.asphalt,48,93,96,6,.035);
  surface(m.asphalt,3,48,6,84,.035);surface(m.asphalt,93,48,6,84,.035);
  for(const [x,z,width,depth]of [[48,7.5,84,3],[48,88.5,84,3],[7.5,48,3,78],[88.5,48,3,78]]) {
    box(m.sidewalk,[minX+x,.065,minZ+z],[width,.23,depth]);
    boxes.push({center:[minX+x,.065,minZ+z],half:[width/2,.115,depth/2]});
  }
  // Ramped curb crossings remain traversable by the same capsule controller as the interiors.
  for(let i=18;i<84;i+=10) {
    surface(m.line,i,0,4,.105,.045);surface(m.line,0,i,.105,4,.045);
  }
  for(const edge of [0,96])for(const start of [13,79])for(let i=0;i<5;i++) {
    surface(m.line,start+i*.9,edge===0?2.6:93.4,.44,4.4,.045);
    surface(m.line,edge===0?2.6:93.4,start+i*.9,4.4,.44,.045);
  }
  for(const inset of [5.5,90.5]) {
    surface(m.line,48,inset,69,.08,.045);surface(m.line,inset,48,.08,69,.045);
  }
  // Narrow expansion joints and storm drains break up the pavement without extra colliders.
  for(const z of [22,70])for(const x of [6.17,89.83]) {
    box(m.steel,[minX+x,.187,minZ+z],[.3,.028,1.1]);
    for(let i=0;i<7;i++)box(m.concrete,[minX+x,.203,minZ+z-.45+i*.15],[.26,.012,.035]);
  }
  }

  yield;
  // Paths follow the same height samples as the surrounding landscape.
  function trail(a:[number,number],b:[number,number],width:number,material:THREE.Material=m.path) {
    const ax=minX+a[0],az=minZ+a[1],bx=minX+b[0],bz=minZ+b[1],length=Math.hypot(bx-ax,bz-az),segments=Math.ceil(length/2);
    const dx=-(bz-az)/length*width/2,dz=(bx-ax)/length*width/2,positions:number[]=[],normals:number[]=[],uv:number[]=[];
    for(let i=0;i<segments;i++) {
      const t0=i/segments,t1=(i+1)/segments,x0=ax+(bx-ax)*t0,z0=az+(bz-az)*t0,x1=ax+(bx-ax)*t1,z1=az+(bz-az)*t1;
      if(lakeDistance((x0+x1)/2,(z0+z1)/2)<1.08||occupied((x0+x1)/2,(z0+z1)/2,.05))continue;
      const corners:[[number,number],[number,number],[number,number],[number,number]]=[[x0-dx,z0-dz],[x0+dx,z0+dz],[x1-dx,z1-dz],[x1+dx,z1+dz]];
      for(const id of [0,1,2,1,3,2]){const [x,z]=corners[id];positions.push(x,yAt(x,z)+.045,z);normals.push(0,1,0);uv.push(id%2*width*.25,(i+(id>1?1:0))*.5);}
    }
    if(!positions.length)return;
    const geometry=new THREE.BufferGeometry();geometry.setAttribute('position',new THREE.Float32BufferAttribute(positions,3));geometry.setAttribute('normal',new THREE.Float32BufferAttribute(normals,3));geometry.setAttribute('uv',new THREE.Float32BufferAttribute(uv,2));geometry.computeVertexNormals();add(geometry,material);
  }
  if(!rural) {
    trail([9,48],[87,48],natural?2.1:3.5);trail([48,9],[48,87],natural?2.1:3.5);
    if(natural){trail([10,15],[27,37],1.8);trail([68,60],[85,81],1.8);}
  } else {
    // Two country lanes leave the town, winding over the actual physical ground.
    // All other rural chunks are open terrain rather than another repeated road block.
    for(let i=0;i<48;i++) {
      const x=minX+i*2,z=minZ+i*2;
      const seed=plan.worldSeed??7307,z0=ruralTrailZ(seed,x),z1=ruralTrailZ(seed,x+2),x0=ruralTrailX(seed,z),x1=ruralTrailX(seed,z+2);
      if(z0>=minZ&&z0<minZ+96)trail([i*2,z0-minZ],[i*2+2,z1-minZ],5.5,m.asphalt);
      if(x0>=minX&&x0<minX+96)trail([x0-minX,i*2],[x1-minX,i*2+2],5.5,m.asphalt);
    }
    // An occasional worn footpath crosses the meadow without closing off free traversal.
    if((plan.cx+plan.cz)%3===0) {
      const offset=Math.sin(minX*.008+(plan.worldSeed??7307)%9)*15;
      trail([0,48+offset],[48,48+Math.sin((minX+48)*.008+(plan.worldSeed??7307)%9)*15],1.8);
      trail([48,48+Math.sin((minX+48)*.008+(plan.worldSeed??7307)%9)*15],[96,48+Math.sin((minX+96)*.008+(plan.worldSeed??7307)%9)*15],1.8);
    }
  }

  yield;
  // Bake static architecture into one batch per shared material for the complete district.
  // Building groups retain their independent loot objects and original geometry ownership.
  for(const buildingPlan of plan.buildings) {
    const visual=yield* createBuildingStages(buildingPlan);
    if(!visual)return null;
    buildings.push(visual);group.add(visual.group);
    boxes.push(...visual.boxes);targets.push(...visual.targets);for(const [id,object]of visual.lootVisuals)lootVisuals.set(id,object);
    for(const [id,door]of visual.doors)doors.set(id,door);
    visual.group.updateMatrixWorld(true);
    const architecture:THREE.Mesh[]=[];
    visual.group.traverse(object=>{
      if(object instanceof THREE.Mesh&&object.name===`${buildingPlan.id}:architecture`&&!Array.isArray(object.material))architecture.push(object);
    });
    for(const mesh of architecture) {
      const material=mesh.material as THREE.Material;
      // Positions, normals and winding retain the source building's world transform.
      const geometry=mesh.geometry.clone().applyMatrix4(mesh.matrixWorld);
      if(!mesh.castShadow)noShadowMaterials.add(material);
      add(geometry,material);
      mesh.removeFromParent();
    }
    yield;
  }

  function bench(x:number,z:number,angle:number) {
    const y=yAt(x,z);at(x,y,z,angle,()=>{
      for(let i=0;i<4;i++)box(m.wood,[0,.47,-.24+i*.16],[1.9,.07,.13]);
      for(let i=0;i<3;i++)box(m.wood,[0,.73+i*.14,-.3],[1.9,.115,.07],[.13,0,0]);
      for(const side of [-.72,.72]){box(m.steel,[side,.23,0],[.07,.46,.51]);rod(m.steel,[side,.43,-.24],[side,1.02,-.35],.028);rod(m.steel,[side,.72,-.29],[side,.7,.28],.026);}
    });boxes.push({center:[x,y+.5,z],half:[1.0,.5,.32],rotationY:angle});
  }
  function lamp(x:number,z:number,angle:number) {
    at(x,0,z,angle,()=>{
      cylinder(m.concrete,[0,.2,0],.22,.29,.4);cylinder(m.steel,[0,3.1,0],.058,.095,6.05,undefined,8);
      rod(m.steel,[0,5.7,0],[.7,6.3,0],.053);rod(m.steel,[.7,6.3,0],[1.5,6.3,0],.047);
      box(m.steel,[1.56,6.26,0],[.69,.16,.33]);box(m.lamp,[1.56,6.17,0],[.53,.035,.26]);
      box(m.steel,[0,1.05,.115],[.16,.33,.13]);
    });boxes.push({center:[x,2.9,z],half:[.12,2.9,.12]});
  }
  if(!rural){lamp(minX+7.1,minZ+21,-Math.PI/2);lamp(minX+88.9,minZ+75,Math.PI/2);}
  if(!natural){lamp(minX+74,minZ+7.1,Math.PI);lamp(minX+21,minZ+88.9,0);}
  // District signage is local to its tile; its canvas is released with the tile.
  const signCanvas=document.createElement('canvas');signCanvas.width=512;signCanvas.height=128;
  const signContext=signCanvas.getContext('2d')!;signContext.fillStyle='#2e4b42';signContext.fillRect(0,0,512,128);
  signContext.strokeStyle='#a8b6a6';signContext.lineWidth=4;signContext.strokeRect(9,9,494,110);
  signContext.fillStyle='#dfdfc8';signContext.font='600 32px Arial';signContext.textAlign='center';signContext.fillText(plan.name.toUpperCase(),256,57,469);
  signContext.fillStyle='#a8b4a3';signContext.font='19px Arial';signContext.fillText(natural?'MUNICIPAL GREENWAY':'MUNICIPAL DISTRICT',256,93);
  const signTexture=new THREE.CanvasTexture(signCanvas);signTexture.colorSpace=THREE.SRGBColorSpace;ownTextures.push(signTexture);
  const signMaterial=new THREE.MeshStandardMaterial({map:signTexture,roughness:.82,side:THREE.DoubleSide});ownMaterials.push(signMaterial);
  const signY=yAt(minX+9.4,minZ+10.5);
  cylinder(m.steel,[minX+9.4,signY+1.55,minZ+10.5],.04,.045,3.1);add(new THREE.PlaneGeometry(2.2,.55),signMaterial,[minX+9.4,signY+2.9,minZ+10.5]);
  boxes.push({center:[minX+9.4,signY+1.5,minZ+10.5],half:[.05,1.5,.05]});

  function vehicle(x:number,z:number,angle:number,variant:number) {
    at(x,.04,z,angle,()=>{
      const paint=m.paint[variant%4];box(m.rubber,[0,.39,0],[1.64,.23,3.92]);box(paint,[0,.65,0],[1.82,.47,4.08]);
      box(paint,[0,1.12,-.18],[1.59,.65,2.02]);box(m.glass,[0,1.15,.87],[1.43,.44,.025],[.18,0,0]);box(m.glass,[0,1.16,-1.205],[1.41,.42,.025],[-.16,0,0]);
      box(paint,[0,1.475,-.19],[1.64,.06,2.04]);box(paint,[0,.94,1.48],[1.78,.08,1.05]);box(paint,[0,.95,-1.6],[1.76,.07,.83]);
      for(const side of [-1,1]) {
        for(const z of [-.68,.34])box(m.glass,[side*.805,1.16,z],[.026,.42,.83]);
        box(paint,[side*.823,1.13,-.18],[.039,.57,.075]);box(m.steel,[side*.945,1.1,.74],[.21,.12,.22]);
        for(const z of [-1.3,1.29]){cylinder(m.rubber,[side*.865,.43,z],.37,.37,.21,[0,0,Math.PI/2],12);cylinder(m.steel,[side*.982,.43,z],.215,.215,.025,[0,0,Math.PI/2],10);}
        box(m.lamp,[side*.59,.74,2.053],[.42,.17,.035]);box(m.rust,[side*.66,.74,-2.054],[.3,.19,.035]);
        box(m.steel,[side*.85,.85,-.45],[.036,.035,.2]);
      }
      box(m.steel,[0,.54,2.085],[1.71,.13,.14]);box(m.steel,[0,.55,-2.08],[1.7,.13,.14]);
      for(let i=0;i<5;i++)box(m.rubber,[-.23+i*.115,.69,2.068],[.065,.12,.027]);
      for(let i=0;i<6;i++)add(new THREE.PlaneGeometry(range(.1,.35),range(.08,.21)),m.rust,[range(-.7,.7),.986,range(.98,1.85)],[-Math.PI/2,0,range(-1,1)]);
    });boxes.push({center:[x,.8,z],half:[.99,.8,2.15],rotationY:angle});
  }
  if(!rural)vehicle(minX+3.5,minZ+range(34,64),range(-.07,.07),plan.seed%4);
  if(!natural)vehicle(minX+range(34,70),minZ+92.5,Math.PI/2+range(-.09,.09),(plan.seed+2)%4);

  // Low-cost overhead wiring, with sag, gives streets a coherent vertical scale.
  function utilityPole(x:number,z:number) {
    cylinder(m.wood,[x,3.9,z],.11,.17,7.8,undefined,8);box(m.wood,[x,7.1,z],[2.2,.14,.14]);
    for(const xOffset of [-.88,0,.88]){cylinder(m.glass,[x+xOffset,7.27,z],.07,.08,.22,undefined,6);
      let previous:Point=[x+xOffset,7.4,z];for(let i=1;i<=8;i++){const t=i/8,next:Point=[x+xOffset,7.4-Math.sin(Math.PI*t)*1.18,z+96*t];rod(m.steel,previous,next,.012);previous=next;}}
    boxes.push({center:[x,3.9,z],half:[.17,3.9,.17]});
  }
  if(!rural)utilityPole(minX+89.2,minZ+10);

  const leafMatrices:THREE.Matrix4[]=[],grassMatrices:THREE.Matrix4[]=[],rockMatrices:THREE.Matrix4[]=[];
  function instance(list:THREE.Matrix4[],p:Point,r:Point,s:Point) {
    transform.position.set(...p);transform.rotation.set(...r);transform.scale.set(...s);transform.updateMatrix();list.push(transform.matrix.clone());
  }
  function tree(x:number,z:number,scale:number) {
    const conifer=(plan.biome==='forest'&&random()<.52)||plan.biome==='mountain';
    const y=yAt(x,z),height=range(conifer?6.8:4.2,conifer?10.5:6.9)*scale,lean=range(-.12,.12),crown=height*.72;
    cylinder(m.bark,[x+lean*.5,y+height*.47,z],.10*scale,.22*scale,height*.94,[0,0,-lean/height],8);
    for(let i=0;i<6;i++) {
      const angle=i*Math.PI/3+range(-.3,.3),spread=range(1.2,2.1)*scale;
      const base:Point=[x,y+height*range(.48,.65),z],tip:Point=[x+Math.sin(angle)*spread,y+height*range(.84,1.02),z+Math.cos(angle)*spread];
      rod(m.bark,base,tip,.069*scale,.026*scale);
    }
    for(let i=0;i<52;i++) {
      const a=random()*Math.PI*2,level=range(.28,.96),r=Math.sqrt(random())*(conifer?(1-level)*3.1:2.35)*scale,vertical=range(-.65,1.25)*scale;
      instance(leafMatrices,[x+Math.sin(a)*r,conifer?y+height*level:y+crown+vertical+(1-r/(2.35*scale))*.7*scale,z+Math.cos(a)*r],
        [range(-.9,.9),range(0,Math.PI*2),range(-.8,.8)],[range(1.0,1.8)*scale,range(.95,1.6)*scale,1]);
    }
    boxes.push({center:[x,y+height*.42,z],half:[.22*scale,height*.42,.22*scale]});
  }
  const treeCount=plan.biome==='forest'?43:plan.biome==='mountain'?15:plan.biome==='hills'?24:natural?30:14;
  yield;
  const treePoints:Array<[number,number]>=[];
  for(let attempt=0;attempt<treeCount*12&&treePoints.length<treeCount;attempt++) {
    const x=minX+range(11,85),z=minZ+range(11,85);
    if(occupied(x,z,3.5)||lakeDistance(x,z)<1.15||(rural&&(Math.abs(x-ruralTrailX(plan.worldSeed??7307,z))<4||Math.abs(z-ruralTrailZ(plan.worldSeed??7307,x))<4))||(!rural&&(Math.abs(x-minX-48)<3||Math.abs(z-minZ-48)<3))||treePoints.some(([tx,tz])=>Math.hypot(tx-x,tz-z)<6))continue;
    treePoints.push([x,z]);tree(x,z,range(.72,1.18));
    yield;
  }
  // Verge trees mark the connected roads even in dense commercial districts.
  if(!natural)for(const [x,z]of [[10.1,39],[85.8,62]])if(!occupied(minX+x,minZ+z,2))tree(minX+x,minZ+z,.76);
  const grassCount=plan.biome==='mountain'?310:natural?880:410;
  for(let i=0;i<grassCount;i++) {
    const x=minX+range(9.5,86.5),z=minZ+range(9.5,86.5);
    if(occupied(x,z,.2)||lakeDistance(x,z)<1.035||(rural&&(Math.abs(x-ruralTrailX(plan.worldSeed??7307,z))<3||Math.abs(z-ruralTrailZ(plan.worldSeed??7307,x))<3))||(!rural&&(Math.abs(x-minX-48)<2||Math.abs(z-minZ-48)<2)))continue;
    instance(grassMatrices,[x,yAt(x,z)+.008,z],[0,range(0,Math.PI*2),0],[range(.42,1.2),range(.2,.72),1]);
    if(i%32===0)yield;
  }
  for(let i=0;i<(plan.biome==='mountain'?47:natural?33:9);i++) {
    const x=minX+range(11,85),z=minZ+range(11,85);if(occupied(x,z,1)||lakeDistance(x,z)<.98||(rural&&(Math.abs(x-ruralTrailX(plan.worldSeed??7307,z))<4||Math.abs(z-ruralTrailZ(plan.worldSeed??7307,x))<4)))continue;
    const size=range(.15,plan.biome==='mountain'?2.4:.6);instance(rockMatrices,[x,yAt(x,z)+size*.18,z],[range(0,3),range(0,6),range(0,3)],[size*1.7,size*.62,size]);
    if(size>.45)boxes.push({center:[x,yAt(x,z)+size*.24,z],half:[size*.6,size*.24,size*.55]});
  }

  if(lake) {
    // The shoreline formula is shared with the terrain sampler; water does not float over land.
    const segments=128,positions:number[]=[lake.x,lake.level,lake.z],uv:number[]=[.5,.5],waterIndices:number[]=[];
    for(let i=0;i<=segments;i++) {
      const a=i/segments*Math.PI*2,f=1+.045*Math.sin(3*a)+.035*Math.cos(5*a);
      positions.push(lake.x+Math.cos(a)*lake.rx*f,lake.level,lake.z+Math.sin(a)*lake.rz*f);uv.push(.5+Math.cos(a)*f*.5,.5+Math.sin(a)*f*.5);
      if(i<segments)waterIndices.push(0,i+2,i+1);
    }
    const geometry=new THREE.BufferGeometry();geometry.setAttribute('position',new THREE.Float32BufferAttribute(positions,3));geometry.setAttribute('uv',new THREE.Float32BufferAttribute(uv,2));geometry.setIndex(waterIndices);geometry.computeVertexNormals();ownGeometry.push(geometry);
    const waterMesh=new THREE.Mesh(geometry,m.water);waterMesh.name='Lake / rippled water';waterMesh.renderOrder=2;waterMesh.userData.surfaceLevel=lake.level;group.add(waterMesh);water.push(waterMesh);
    for(let i=0;i<105;i++) {
      const a=random()*Math.PI*2,f=(1+.045*Math.sin(3*a)+.035*Math.cos(5*a))*range(1.015,1.12);
      const x=lake.x+Math.cos(a)*lake.rx*f,z=lake.z+Math.sin(a)*lake.rz*f,y=yAt(x,z);if(occupied(x,z,1))continue;
      if(i%4===0){const size=range(.25,.72);instance(rockMatrices,[x,y+size*.18,z],[range(0,3),range(0,6),range(0,3)],[size*1.8,size*.72,size]);}
      else {for(let stem=0;stem<3;stem++){const sx=x+range(-.3,.3),sz=z+range(-.3,.3),height=range(.55,1.1);rod(m.reed,[sx,y,sz],[sx+.08,y+height,sz+.04],.014);cylinder(m.wood,[sx+.08,y+height-.09,sz+.04],.035,.036,.2,undefined,5);}}
      instance(grassMatrices,[x,y,z],[0,random()*Math.PI*2,0],[range(.75,1.6),range(.6,1.0),1]);
      if(i%8===0)yield;
    }
    // A small timber overlook has a physical deck, posts and a low handrail open at the entrance.
    const deckX=lake.x,deckZ=lake.z+lake.rz*1.025,deckY=Math.max(.15,yAt(deckX,deckZ))+.08;
    for(let i=0;i<12;i++)box(m.wood,[deckX,deckY,deckZ-1.65+i*.3],[4,.11,.27]);
    for(const dx of [-1.88,1.88])for(const dz of [-1.55,1.55]) {
      cylinder(m.wood,[deckX+dx,deckY-.2,deckZ+dz],.095,.12,1.5,undefined,7);
      cylinder(m.wood,[deckX+dx,deckY+.47,deckZ+dz],.05,.06,.97,undefined,6);
    }
    for(const dx of [-1.88,1.88]){rod(m.wood,[deckX+dx,deckY+1,deckZ-1.55],[deckX+dx,deckY+1,deckZ+1.55],.044);boxes.push({center:[deckX+dx,deckY+.47,deckZ],half:[.07,.53,1.62]});}
    rod(m.wood,[deckX-1.88,deckY+1,deckZ-1.55],[deckX+1.88,deckY+1,deckZ-1.55],.044);
    boxes.push({center:[deckX,deckY,deckZ],half:[2,.055,1.8]},{center:[deckX,deckY+.5,deckZ-1.55],half:[1.92,.5,.07]});
    // Two broad steps connect the bank to the overlook instead of requiring a perfect jump.
    const bankHeight=yAt(deckX,deckZ+2.3),rise=Math.max(0,deckY+.055-bankHeight);
    for(let i=0;i<2;i++){const top=bankHeight+rise*(i+1)/3,z=deckZ+2.6-i*.4;box(m.wood,[deckX,top-.1,z],[2,.2,.42]);boxes.push({center:[deckX,top-.1,z],half:[1,.1,.21]});}
    if(!occupied(minX+77,minZ+76,2))bench(minX+77,minZ+76,Math.PI*.23);
  } else if(!rural) {
    for(const [x,z,angle]of [[43,44,Math.PI/2],[52,53,-Math.PI/2]])if(!occupied(minX+x,minZ+z,1.7))bench(minX+x,minZ+z,angle);
  }

  // Street litter, municipal bins, worn bollards and broken paving lend the grid an inhabited scale.
  if(!rural)for(const [x,z]of [[10.0,12.4],[85.6,82.0]]) {
    cylinder(m.steel,[minX+x,.47,minZ+z],.32,.29,.89,undefined,10);cylinder(m.rubber,[minX+x,.91,minZ+z],.34,.34,.09,undefined,10);
    boxes.push({center:[minX+x,.46,minZ+z],half:[.33,.46,.33]});
  }
  for(let i=0;i<(rural?0:18);i++) {
    const edge=random()>.5,x=edge?range(6.3,9):range(14,84),z=edge?range(14,84):range(6.3,9);
    add(new THREE.PlaneGeometry(range(.09,.3),range(.09,.25)),i%4===0?m.rust:m.paper,[minX+x,.191,minZ+z],[-Math.PI/2,0,range(0,6.28)]);
  }
  if(natural)for(let i=0;i<5;i++) {
    const x=minX+range(13,83),z=minZ+range(13,83);if(occupied(x,z,2)||lakeDistance(x,z)<1.06)continue;
    rod(m.bark,[x,yAt(x,z)+.1,z],[x+range(1,2.5),yAt(x+1,z+1)+.12,z+range(-.6,.6)],.11,.055);
  }

  function finishInstances(name:string,geometry:THREE.BufferGeometry,material:THREE.Material,matrices:THREE.Matrix4[],shadows:boolean) {
    if(!matrices.length){geometry.dispose();return;}
    ownGeometry.push(geometry);const mesh=new THREE.InstancedMesh(geometry,material,matrices.length);mesh.name=name;ownInstances.push(mesh);
    matrices.forEach((matrix,index)=>mesh.setMatrixAt(index,matrix));mesh.instanceMatrix.needsUpdate=true;mesh.castShadow=shadows;mesh.receiveShadow=true;mesh.computeBoundingSphere();group.add(mesh);
  }
  yield;
  finishInstances('Instanced broadleaf canopy',new THREE.PlaneGeometry(1,1),m.leaves,leafMatrices,true);
  yield;
  const grassGeometry=new THREE.PlaneGeometry(1,1);grassGeometry.translate(0,.5,0);
  finishInstances('Instanced meadow and verge grass',grassGeometry,m.grass,grassMatrices,false);
  yield;
  finishInstances('Instanced weathered stones',new THREE.IcosahedronGeometry(1,0),m.stone,rockMatrices,true);
  yield;
  for(const [material,geometries]of batches) {
    const merged=mergeGeometries(geometries,false);for(const geometry of geometries)geometry.dispose();batches.delete(material);
    if(!merged)continue;merged.computeBoundingSphere();ownGeometry.push(merged);const mesh=new THREE.Mesh(merged,material);
    mesh.castShadow=!noShadowMaterials.has(material)&&material!==m.line&&material!==m.paper&&material!==m.asphalt&&material!==m.path;mesh.receiveShadow=true;group.add(mesh);
    yield;
  }
  completed=true;
  return {group,boxes,terrain:{vertices,indices},targets,water,lootVisuals,doors,dispose};
  }finally{if(!completed)dispose();}
}
