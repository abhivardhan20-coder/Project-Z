import {planChunk,chunkAt,CHUNK_SIZE,regionalHeight,ruralTrailX,ruralTrailZ} from '../world/layout.mjs';
import type {ChunkPlan} from '../world/types';

export class WorldMap {
  waypoint:{x:number;z:number}|null=null;
  private plans=new Map<string,ChunkPlan>();
  private x=0;private z=0;private yaw=Math.PI;
  private seed=7307;
  private mini=document.querySelector<HTMLCanvasElement>('.world-minimap')!;
  update(seed:number,x:number,z:number,yaw:number) {
    if(seed!==this.seed){this.seed=seed;this.plans.clear();this.waypoint=null;}
    this.x=x;this.z=z;this.yaw=yaw;this.draw(this.mini,105);
  }
  private plan(cx:number,cz:number) {
    const key=`${cx}:${cz}`;let plan=this.plans.get(key);
    if(!plan){plan=planChunk(this.seed,cx,cz) as ChunkPlan;this.plans.set(key,plan);}
    if(this.plans.size>120){const first=this.plans.keys().next().value;if(first)this.plans.delete(first);}
    return plan;
  }
  open(canvas:HTMLCanvasElement,onMark:(message:string)=>void) {
    let span=310;this.draw(canvas,span);
    canvas.addEventListener('wheel',event=>{
      event.preventDefault();span=Math.max(155,Math.min(1240,span*Math.exp(Math.max(-200,Math.min(200,event.deltaY))*.002)));
      this.draw(canvas,span);
    },{passive:false});
    canvas.addEventListener('click',event=>{
      const rect=canvas.getBoundingClientRect();
      const fit=Math.min(rect.width/canvas.width,rect.height/canvas.height),w=canvas.width*fit,h=canvas.height*fit;
      this.waypoint={x:this.x+((event.clientX-rect.left-(rect.width-w)/2)/w-.5)*span*2,
        z:this.z+((event.clientY-rect.top-(rect.height-h)/2)/h-.5)*span*2*canvas.height/canvas.width};
      this.draw(canvas,span);onMark(`Destination marked · ${Math.round(Math.hypot(this.waypoint.x-this.x,this.waypoint.z-this.z))} m`);
    });
  }
  private draw(canvas:HTMLCanvasElement,span:number) {
    const ctx=canvas.getContext('2d');if(!ctx)return;
    const width=canvas.width,height=canvas.height,scale=width/(span*2),mini=width===300;
    ctx.clearRect(0,0,width,height);ctx.fillStyle='#11251f';ctx.fillRect(0,0,width,height);
    ctx.save();ctx.translate(width/2,height/2);ctx.scale(scale,scale);ctx.translate(-this.x,-this.z);
    const a=chunkAt(this.x-span,this.z-span),b=chunkAt(this.x+span,this.z+span);
    for(let cx=a.cx;cx<=b.cx;cx++)for(let cz=a.cz;cz<=b.cz;cz++) {
      const p=this.plan(cx,cz),x=cx*CHUNK_SIZE,z=cz*CHUNK_SIZE;
      ctx.fillStyle=p.biome==='urban'?'#29322a':p.biome==='residential'?'#24352a':'#1d382b';ctx.fillRect(x,z,96,96);
      if(p.rural) {
        for(let u=0;u<96;u+=16)for(let v=0;v<96;v+=16) {
          const elevation=regionalHeight(this.seed,x+u+8,z+v+8);
          const light=24+Math.min(18,elevation*.075);
          ctx.fillStyle=`hsl(${p.biome==='forest'?111:p.biome==='mountain'?65:89} 17% ${light}%)`;
          ctx.fillRect(x+u,z+v,16,16);
        }
        ctx.save();ctx.beginPath();ctx.rect(x,z,96,96);ctx.clip();
        ctx.strokeStyle='#a5a184';ctx.lineWidth=1.5;ctx.setLineDash([2,2]);ctx.beginPath();
        for(let v=0;v<=96;v+=8){const tx=ruralTrailX(this.seed,z+v);if(v===0)ctx.moveTo(tx,z+v);else ctx.lineTo(tx,z+v);}
        for(let u=0;u<=96;u+=8){const tz=ruralTrailZ(this.seed,x+u);if(u===0)ctx.moveTo(x+u,tz);else ctx.lineTo(x+u,tz);}
        ctx.stroke();ctx.setLineDash([]);ctx.restore();
      } else {ctx.strokeStyle='#697267';ctx.lineWidth=2;ctx.strokeRect(x,z,96,96);}
      if(p.lake){ctx.fillStyle='#326c73';ctx.beginPath();ctx.ellipse(p.lake.x,p.lake.z,p.lake.rx,p.lake.rz,0,0,Math.PI*2);ctx.fill();}
      for(const house of p.buildings) {
        ctx.save();ctx.translate(house.x,house.z);ctx.rotate(-house.rotation);
        ctx.fillStyle=house.enterable?'#929b7f':'#485b48';ctx.fillRect(-house.width/2,-house.depth/2,house.width,house.depth);
        if(house.enterable){ctx.fillStyle='#dacfaa';ctx.fillRect(-2,house.depth/2-2,4,4);}
        if(house.shelter){ctx.fillStyle='#e2c47d';ctx.beginPath();ctx.arc(0,0,mini?3:3.7,0,Math.PI*2);ctx.fill();}
        ctx.restore();
      }
      if(!mini&&span<500){ctx.fillStyle='#a8b5a0';ctx.font='3.8px sans-serif';ctx.textAlign='center';ctx.fillText(p.name,x+48,z+48);}
    }
    if(this.waypoint) {
      ctx.strokeStyle='#f9af72';ctx.lineWidth=1.3;ctx.setLineDash([3,3]);ctx.beginPath();ctx.moveTo(this.x,this.z);ctx.lineTo(this.waypoint.x,this.waypoint.z);ctx.stroke();ctx.setLineDash([]);
      ctx.fillStyle='#f9af72';ctx.beginPath();ctx.arc(this.waypoint.x,this.waypoint.z,3,0,Math.PI*2);ctx.fill();
    }
    ctx.translate(this.x,this.z);ctx.rotate(-this.yaw);
    ctx.fillStyle='#ff7756';ctx.strokeStyle='#f1e9c9';ctx.lineWidth=.6;ctx.beginPath();ctx.moveTo(0,4.5);ctx.lineTo(-3,-3.5);ctx.lineTo(0,-1.7);ctx.lineTo(3,-3.5);ctx.closePath();ctx.fill();ctx.stroke();ctx.restore();
    ctx.fillStyle='#dce3cf';ctx.font=mini?'16px sans-serif':'12px sans-serif';ctx.textAlign='center';ctx.fillText('N',width/2,mini?22:20);
  }
}
