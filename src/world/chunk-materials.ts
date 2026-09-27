import * as THREE from 'three/webgpu';

/** A single material/texture pool is shared by every streamed landscape tile. */
export interface LandscapeMaterials {
  asphalt:THREE.MeshStandardMaterial; sidewalk:THREE.MeshStandardMaterial; concrete:THREE.MeshStandardMaterial;
  ground:THREE.MeshStandardMaterial; path:THREE.MeshStandardMaterial; line:THREE.MeshStandardMaterial;
  steel:THREE.MeshStandardMaterial; rust:THREE.MeshStandardMaterial; wood:THREE.MeshStandardMaterial;
  bark:THREE.MeshStandardMaterial; stone:THREE.MeshStandardMaterial; rubber:THREE.MeshStandardMaterial;
  glass:THREE.MeshStandardMaterial; paint:THREE.MeshStandardMaterial[]; lamp:THREE.MeshStandardMaterial;
  leaves:THREE.MeshStandardMaterial; grass:THREE.MeshStandardMaterial; reed:THREE.MeshStandardMaterial;
  water:THREE.MeshPhysicalMaterial; sand:THREE.MeshStandardMaterial; paper:THREE.MeshStandardMaterial;
}

let pool:LandscapeMaterials|undefined;
const maps:THREE.Texture[]=[];
function texture(base:string,kind:'grain'|'asphalt'|'bark'|'pavers'='grain') {
  const c=document.createElement('canvas');c.width=c.height=256;const ctx=c.getContext('2d')!;
  let seed=8917;const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
  ctx.fillStyle=base;ctx.fillRect(0,0,256,256);
  for(let i=0;i<5800;i++) {
    ctx.fillStyle=random()>.44?`rgba(242,232,198,${random()*.14})`:`rgba(14,20,17,${random()*.22})`;
    ctx.fillRect(random()*256,random()*256,1+random()*3,kind==='bark'?3+random()*35:1+random()*3);
  }
  if(kind==='asphalt') {
    ctx.strokeStyle='rgba(11,18,18,.3)';ctx.lineWidth=.7;
    for(let i=0;i<8;i++) {let x=random()*256,y=random()*256;ctx.beginPath();ctx.moveTo(x,y);for(let j=0;j<6;j++){x+=(random()-.45)*24;y+=random()*22;ctx.lineTo(x,y);}ctx.stroke();}
  }
  if(kind==='pavers') {
    ctx.strokeStyle='rgba(32,37,32,.32)';ctx.lineWidth=2;
    for(let y=0;y<256;y+=64){ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(256,y);ctx.stroke();for(let x=(y/64%2)*64;x<=256;x+=128){ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(x,y+64);ctx.stroke();}}
  }
  const map=new THREE.CanvasTexture(c);map.colorSpace=THREE.SRGBColorSpace;map.wrapS=map.wrapT=THREE.RepeatWrapping;map.anisotropy=4;maps.push(map);return map;
}
function cutout(kind:'leaves'|'grass') {
  const c=document.createElement('canvas');c.width=c.height=128;const ctx=c.getContext('2d')!;
  let seed=kind==='leaves'?66391:1825;const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
  if(kind==='leaves') {
    for(let i=0;i<37;i++) {const a=random()*Math.PI*2,r=Math.sqrt(random())*47,x=64+Math.cos(a)*r,y=64+Math.sin(a)*r;
      ctx.save();ctx.translate(x,y);ctx.rotate(random()*Math.PI);ctx.fillStyle=`rgb(${87+random()*42|0},${100+random()*43|0},${58+random()*25|0})`;
      ctx.beginPath();ctx.ellipse(0,0,4+random()*5,9+random()*8,0,0,Math.PI*2);ctx.fill();ctx.restore();}
  } else {
    for(let i=0;i<35;i++){const x=16+random()*96,h=25+random()*96,w=1+random()*2,lean=(random()-.5)*39;
      ctx.fillStyle=`rgb(${91+random()*45|0},${99+random()*39|0},${53+random()*27|0})`;ctx.beginPath();ctx.moveTo(x-w,128);ctx.quadraticCurveTo(x+lean*.3,128-h*.6,x+lean,128-h);ctx.quadraticCurveTo(x+lean*.25+1,128-h*.48,x+w,128);ctx.fill();}
  }
  const map=new THREE.CanvasTexture(c);map.colorSpace=THREE.SRGBColorSpace;map.anisotropy=2;maps.push(map);return map;
}
function waterNormal() {
  const size=128,data=new Uint8Array(size*size*4);
  for(let y=0;y<size;y++) for(let x=0;x<size;x++) {
    const a=x/size*Math.PI*2,b=y/size*Math.PI*2,i=(y*size+x)*4;
    data[i]=128+Math.sin(a*5+b*3)*21+Math.cos(a*8-b*2)*9;data[i+1]=128+Math.cos(b*6+a*2)*21+Math.sin(b*9-a*4)*9;data[i+2]=247;data[i+3]=255;
  }
  const map=new THREE.DataTexture(data,size,size,THREE.RGBAFormat);map.wrapS=map.wrapT=THREE.RepeatWrapping;map.magFilter=THREE.LinearFilter;map.minFilter=THREE.LinearMipmapLinearFilter;map.generateMipmaps=true;map.needsUpdate=true;map.repeat.set(11,11);maps.push(map);return map;
}
export function landscapeMaterials():LandscapeMaterials {
  if(pool)return pool;
  const standard=(color:string,roughness=.9,metalness=0,map?:THREE.Texture)=>new THREE.MeshStandardMaterial({color,roughness,metalness,...(map?{map}: {})});
  const neutral=texture('#a4a69a'),concrete=texture('#a0a08d'),pavers=texture('#aca897','pavers');
  pool={
    asphalt:standard('#727c78',.66,.06,texture('#555e59','asphalt')),
    sidewalk:standard('#ccc6b4',.91,0,pavers),concrete:standard('#a5a895',.94,0,concrete),
    ground:new THREE.MeshStandardMaterial({color:'#c0ba9b',roughness:1,map:neutral,vertexColors:true}),
    path:standard('#bcb08a',.99,0,neutral),line:standard('#c5bfa3',.93),
    steel:standard('#39453e',.63,.6),rust:standard('#735241',.92,.25),wood:standard('#867459',.96,0,texture('#877d65','bark')),
    bark:standard('#80745a',1,0,texture('#897d66','bark')),stone:standard('#94978c',.98,0,concrete),
    rubber:standard('#202925',.98),glass:standard('#3e5b57',.23,.42),
    paint:['#576f69','#959681','#766552','#596471'].map(color=>standard(color,.63,.35,neutral)),
    lamp:new THREE.MeshStandardMaterial({color:'#d8c9a0',emissive:'#f0c67d',emissiveIntensity:.72,roughness:.4}),
    leaves:new THREE.MeshStandardMaterial({color:'#b3c1a0',map:cutout('leaves'),alphaTest:.38,alphaToCoverage:true,side:THREE.DoubleSide,roughness:1}),
    grass:new THREE.MeshStandardMaterial({color:'#acb098',map:cutout('grass'),alphaTest:.35,alphaToCoverage:true,side:THREE.DoubleSide,roughness:1}),
    reed:standard('#8b8d59',1),water:new THREE.MeshPhysicalMaterial({color:'#547e79',metalness:.13,roughness:.19,clearcoat:.75,clearcoatRoughness:.15,normalMap:waterNormal(),normalScale:new THREE.Vector2(.32,.32),transparent:true,opacity:.91,depthWrite:false}),
    sand:standard('#b9b094',1,0,neutral),paper:standard('#b5b49f',.97),
  };
  // Coplanar decals must never compete with the physical ground or each other in the depth buffer.
  for(const material of [pool.asphalt,pool.path]){material.polygonOffset=true;material.polygonOffsetFactor=-1;material.polygonOffsetUnits=-2;}
  pool.line.polygonOffset=true;pool.line.polygonOffsetFactor=-2;pool.line.polygonOffsetUnits=-4;
  return pool;
}

/** One update per frame, independent of how many streamed chunks share these textures. */
export function updateChunkMaterials(elapsed:number,wetness:number) {
  if(!pool)return;
  pool.asphalt.roughness=.9-Math.max(0,Math.min(1,wetness))*.56;
  pool.sidewalk.roughness=.94-Math.max(0,Math.min(1,wetness))*.2;
  if(pool.water.normalMap)pool.water.normalMap.offset.set((elapsed*.009)%1,(elapsed*.005)%1);
}

/** Call only when the complete world is released, never when an individual chunk unloads. */
export function disposeLandscapeResources() {
  if(!pool)return;
  for(const value of Object.values(pool))for(const material of Array.isArray(value)?value:[value])material.dispose();
  for(const map of maps)map.dispose();maps.length=0;pool=undefined;
}
