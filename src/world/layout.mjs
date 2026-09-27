/** Coordinate-addressed generation: exploring in a different order never changes a place. */
export const CHUNK_SIZE=96;
export const DEFAULT_SEED=7307;
export function hash(seed,x,z,salt=0) {
  let h=(seed^Math.imul(x,374761393)^Math.imul(z,668265263)^Math.imul(salt,1274126177))>>>0;
  h=Math.imul(h^(h>>>13),1274126177);return (h^(h>>>16))>>>0;
}
export function random(seed) {
  return ()=>{seed=(seed+0x6D2B79F5)|0;let t=Math.imul(seed^(seed>>>15),1|seed);t^=t+Math.imul(t^(t>>>7),61|t);return ((t^(t>>>14))>>>0)/4294967296;};
}
export function chunkAt(x,z){return {cx:Math.floor(x/CHUNK_SIZE),cz:Math.floor(z/CHUNK_SIZE)};}
export function chunkKey(cx,cz){return `${cx}:${cz}`;}
export function biomeAt(seed,cx,cz) {
  if(Math.abs(cx)>2||Math.abs(cz)>2) {
    const distance=Math.hypot(cx*96,cz*96),local=hash(seed,cx,cz,12)%100;
    if(local<9&&distance<1000)return 'lake';
    if(distance>760)return local<24?'forest':'mountain';
    return local<58?'forest':'hills';
  }
  if(cx===0&&cz===0)return 'urban';
  if(cx===0&&cz===-1)return 'lake';
  if(cx===-1&&cz===0)return 'residential';
  if(cx===1&&cz===-1)return 'park';
  const regional=hash(seed,Math.floor(cx/3),Math.floor(cz/3),81)%100;
  const local=hash(seed,cx,cz,12)%100;
  if(local<13 || regional>77&&local<40)return 'lake';
  if(local<28 || regional>77)return 'park';
  return regional<43?'urban':'residential';
}
const NAMES=['Salar Nagar','Old Market','Neem Colony','Deccan Heights','Nizam Gardens','Konda Ward','Charbagh','Nallapur'];
export function planChunk(seed,cx,cz) {
  const salt=hash(seed,cx,cz,42),rng=random(salt),biome=biomeAt(seed,cx,cz);
  const name=NAMES[hash(seed,Math.floor(cx/3),Math.floor(cz/3),9)%NAMES.length];
  const rural=Math.abs(cx)>2||Math.abs(cz)>2;
  const plan={key:chunkKey(cx,cz),cx,cz,seed:salt,worldSeed:seed,rural,biome,name:biome==='lake'?`${name} Lake`:biome==='park'?`${name} Gardens`:biome==='forest'?`${name} Forest`:biome==='hills'?`${name} Foothills`:biome==='mountain'?`${name} Highlands`:name,buildings:[],lake:null};
  if(rural) {
    if(biome==='lake') {
      const x=cx*96+48,z=cz*96+48;
      plan.lake={x,z,rx:22+rng()*6,rz:21+rng()*7,level:regionalHeight(seed,x,z)-.35,depth:2.8+rng()};
    }
    // Sparse rest houses replace city blocks. Mountain meadows remain predominantly open.
    if(!plan.lake&&(hash(seed,cx,cz,71)%5===0||cx===3&&cz===0)) {
      const x=cx*96+48+(rng()-.5)*12,z=cz*96+48+(rng()-.5)*12;
      plan.buildings.push({id:`b:${cx}:${cz}:0`,x,y:regionalHeight(seed,x,z),z,width:12+rng()*3,depth:11+rng()*3,
        floors:1,rotation:Math.floor(rng()*4)*Math.PI/2,kind:'house',enterable:true,shelter:true,variant:3,seed:hash(salt,0,0,4)});
    }
    return plan;
  }
  if(biome==='lake') {
    plan.lake={x:cx*96+48+(rng()-.5)*6,z:cz*96+48+(rng()-.5)*6,rx:27+rng()*6,rz:26+rng()*7,level:-.35,depth:2.5+rng()*.8};
    // A modest lakeside rest house, on dry land beyond the shoreline.
    plan.buildings.push({id:`b:${cx}:${cz}:0`,x:cx*96+18,z:cz*96+17,width:12,depth:11,floors:1,rotation:Math.PI,
      kind:'house',enterable:true,shelter:true,variant:3,seed:hash(salt,0,0,4)});
  } else if(biome==='park') {
    plan.buildings.push({id:`b:${cx}:${cz}:0`,x:cx*96+24,z:cz*96+22,width:18,depth:14,floors:1,rotation:Math.PI,
      kind:'clinic',enterable:true,shelter:true,variant:2,seed:hash(salt,0,0,4)});
  } else {
    for(let i=0;i<4;i++) {
      const col=i%2,row=Math.floor(i/2),starter=cx===0&&cz===0&&i===0;
      const kind=starter?'shop':biome==='residential'?(rng()<.65?'house':'apartment'):['shop','apartment','clinic','warehouse'][Math.floor(rng()*4)];
      const enterable=starter||i===1||rng()<.62;
      plan.buildings.push({id:`b:${cx}:${cz}:${i}`,x:cx*96+(col?72:24)+(rng()-.5)*3,z:cz*96+(row?72:24)+(rng()-.5)*3,
        width:kind==='house'?18+rng()*3:22+rng()*6,depth:kind==='house'?17+rng()*3:21+rng()*6,
        floors:kind==='warehouse'?1:kind==='house'?1+Math.floor(rng()*2):2+Math.floor(rng()*3),
        rotation:col?Math.PI/2:-Math.PI/2,kind,enterable,shelter:enterable&&(starter||i===1||kind==='house'),variant:Math.floor(rng()*6),seed:hash(salt,i,0,4)});
    }
  }
  return plan;
}
export function lakeRadius(lake,x,z) {
  const dx=(x-lake.x)/lake.rx,dz=(z-lake.z)/lake.rz,angle=Math.atan2(dz,dx);
  return Math.hypot(dx,dz)/(1+.045*Math.sin(angle*3)+.035*Math.cos(angle*5));
}

const smooth=t=>{t=Math.max(0,Math.min(1,t));return t*t*(3-2*t);};
/** Continuous world-space value noise: no per-chunk noise resets or flattened tile borders. */
export function terrainNoise(seed,x,z,scale=1) {
  x/=scale;z/=scale;const ix=Math.floor(x),iz=Math.floor(z),fx=smooth(x-ix),fz=smooth(z-iz);
  const a=hash(seed,ix,iz,123)/4294967295,b=hash(seed,ix+1,iz,123)/4294967295;
  const c=hash(seed,ix,iz+1,123)/4294967295,d=hash(seed,ix+1,iz+1,123)/4294967295;
  return (a+(b-a)*fx)*(1-fz)+(c+(d-c)*fx)*fz;
}

/** Broad foothills and mountain ridges are shared by near terrain and the distant horizon. */
export function regionalHeight(seed,x,z) {
  const distance=Math.max(Math.abs(x-48),Math.abs(z-48));
  // Preserve the complete original five-by-five starting district, including its road elevations.
  if(distance<=252)return 0;
  const outskirts=smooth((distance-252)/290),mountains=smooth((distance-490)/650);
  const hills=12+terrainNoise(seed+7,x,z,290)*32+terrainNoise(seed+31,x,z,110)*8;
  const ridge=1-Math.abs(terrainNoise(seed+331,x,z,760)*2-1);
  const broad=terrainNoise(seed+913,x,z,940);
  const peaks=38+Math.pow(ridge,1.8)*95+broad*55+terrainNoise(seed+51,x,z,220)*12;
  return outskirts*hills+mountains*peaks;
}

/** Sparse walking routes remain continuous over chunk seams and follow terrain gradients. */
export function ruralTrailX(seed,z) {
  return Math.sin((Math.abs(z)-288)/170)*19*Math.min(1,Math.max(0,(Math.abs(z)-260)/100));
}
export function ruralTrailZ(seed,x) {return ruralTrailX(seed,x);}

export function terrainHeight(plan,x,z) {
  if(plan.rural) {
    let height=regionalHeight(plan.worldSeed??DEFAULT_SEED,x,z);
    if(plan.lake) {
      const r=lakeRadius(plan.lake,x,z);
      if(r<1)height=plan.lake.level-plan.lake.depth*(1-r*r);
      else if(r<1.4){const blend=smooth((r-1)/.4);height=plan.lake.level+(height-plan.lake.level)*blend;}
    }
    // Foundation grading blends back into the shared terrain outside each accessible house.
    for(const b of plan.buildings) {
      const c=Math.cos(b.rotation),s=Math.sin(b.rotation),dx=x-b.x,dz=z-b.z;
      const qx=Math.abs(c*dx-s*dz)-b.width/2-2,qz=Math.abs(s*dx+c*dz)-b.depth/2-2;
      const distance=Math.max(qx,qz);
      if(distance<9){const blend=smooth(distance/9);height=(b.y??0)+(height-(b.y??0))*blend;}
    }
    return height;
  }
  const u=x-plan.cx*96,v=z-plan.cz*96,edge=Math.min(u,v,96-u,96-v);
  if(edge<=10 || plan.biome==='urban'||plan.biome==='residential')return 0;
  for(const b of plan.buildings)if(Math.abs(x-b.x)<Math.max(b.width,b.depth)/2+3&&Math.abs(z-b.z)<Math.max(b.width,b.depth)/2+3)return 0;
  const fade=Math.min(1,(edge-10)/7);
  let height=(.48+.4*Math.sin(x*.074+plan.seed%12)*Math.cos(z*.059)+.35*Math.sin((x+z)*.034))*fade;
  if(plan.lake) {
    const r=lakeRadius(plan.lake,x,z);
    if(r<1)return plan.lake.level-plan.lake.depth*(1-r*r);
    if(r<1.25)return plan.lake.level+(height-plan.lake.level)*(r-1)/.25;
  }
  return height;
}
