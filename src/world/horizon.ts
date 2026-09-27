import * as THREE from 'three/webgpu';
import { chunkAt, regionalHeight, terrainNoise } from './layout.mjs';

/** Coarse world-space terrain beyond the physical chunk window. It never enters collision. */
export class TerrainHorizon {
  readonly group=new THREE.Group();
  private mesh:THREE.Mesh;
  private geometry=new THREE.BufferGeometry();
  private material=new THREE.MeshStandardMaterial({color:'#a0a28d',vertexColors:true,roughness:1});
  private center='';
  private revision=-1;
  private tileKeys:string[]=[];
  private cells=74;
  private centerX=0;
  private centerZ=0;
  private samples=new Map<string,Float32Array>();
  constructor(private seed:number) {
    this.group.name='Distant foothills and mountain ridges';
    this.mesh=new THREE.Mesh(this.geometry,this.material);this.mesh.receiveShadow=false;this.mesh.castShadow=false;this.group.add(this.mesh);
  }
  update(x:number,z:number,loaded?:ReadonlyMap<string,unknown>,revision=0) {
    const {cx,cz}=chunkAt(x,z),key=`${cx}:${cz}`;
    if(key===this.center){if(revision!==this.revision)this.updateHoles(loaded,revision);return;}
    this.center=key;this.centerX=cx;this.centerZ=cz;
    const positions:number[]=[],colors:number[]=[],normals:number[]=[],color=new THREE.Color(),rockColor=new THREE.Color('#9c9b84'),usedSamples=new Set<string>();
    // 48m cells across a 3.5km window cost approximately 10,000 triangles and one draw call.
    const extent=18,cells=(extent*2+1)*2,row=cells+1,minX=(cx-extent)*96,minZ=(cz-extent)*96;
    this.cells=cells;this.tileKeys=[];
    for(let j=0;j<=cells;j++)for(let i=0;i<=cells;i++) {
      const wx=minX+i*48,wz=minZ+j*48,sampleKey=`${wx}:${wz}`;usedSamples.add(sampleKey);
      let sample=this.samples.get(sampleKey);
      if(!sample) {
        const height=regionalHeight(this.seed,wx,wz),dx=regionalHeight(this.seed,wx+6,wz)-regionalHeight(this.seed,wx-6,wz),dz=regionalHeight(this.seed,wx,wz+6)-regionalHeight(this.seed,wx,wz-6);
        const length=Math.hypot(dx,12,dz);
        color.set('#647756').lerp(rockColor,Math.min(.88,height/280)*.75+terrainNoise(this.seed+59,wx,wz,170)*.13);
        sample=new Float32Array([height,-dx/length,12/length,-dz/length,color.r,color.g,color.b]);this.samples.set(sampleKey,sample);
      }
      positions.push(wx,sample[0],wz);normals.push(sample[1],sample[2],sample[3]);colors.push(sample[4],sample[5],sample[6]);
      if(i===cells||j===cells)continue;
      const tileX=Math.floor((wx+24)/96),tileZ=Math.floor((wz+24)/96);
      this.tileKeys.push(`${tileX}:${tileZ}`);
    }
    // A moving horizon keeps only its current lattice; revisiting the world cannot grow this cache.
    for(const key of this.samples.keys())if(!usedSamples.has(key))this.samples.delete(key);
    const geometry=new THREE.BufferGeometry();geometry.setAttribute('position',new THREE.Float32BufferAttribute(positions,3));geometry.setAttribute('normal',new THREE.Float32BufferAttribute(normals,3));geometry.setAttribute('color',new THREE.Float32BufferAttribute(colors,3));geometry.setIndex(new THREE.BufferAttribute(new Uint32Array(cells*cells*6),1).setUsage(THREE.DynamicDrawUsage));geometry.computeBoundingSphere();
    this.mesh.geometry=geometry;this.geometry.dispose();this.geometry=geometry;
    this.updateHoles(loaded,revision);
  }
  private updateHoles(loaded:ReadonlyMap<string,unknown>|undefined,revision:number) {
    this.revision=revision;const attribute=this.geometry.index!,indices=attribute.array as Uint32Array,row=this.cells+1;let count=0;
    for(let j=0;j<this.cells;j++)for(let i=0;i<this.cells;i++) {
      const key=this.tileKeys[j*this.cells+i];
      if(loaded?loaded.has(key):(()=>{const [x,z]=key.split(':').map(Number);return Math.abs(x-this.centerX)<=2&&Math.abs(z-this.centerZ)<=2;})())continue;
      const a=j*row+i,b=a+1,c=a+row,d=c+1;indices.set([a,c,b,b,c,d],count);count+=6;
    }
    attribute.needsUpdate=true;this.geometry.setDrawRange(0,count);
  }
  dispose(){this.group.removeFromParent();this.geometry.dispose();this.material.dispose();this.group.clear();this.samples.clear();}
}
