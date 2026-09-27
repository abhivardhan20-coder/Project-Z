import test from 'node:test';
import assert from 'node:assert/strict';
import { Vector3 } from 'three/webgpu';
import { stableShadowAnchor, shadowLightPosition } from '../src/world/shadow-anchor.ts';

test('moving sun coverage remains on whole shadow texels at every quality and altitude',()=>{
  const direction=new Vector3(-36,48,-59).normalize();
  const right=new Vector3().crossVectors(new Vector3(0,1,0),direction).normalize();
  const up=new Vector3().crossVectors(direction,right).normalize();
  for(const resolution of [512,1024,2048,4096])for(const height of [0,22,250]) {
    let previous=null;
    for(let i=0;i<180;i++) {
      const position=new Vector3(7.5+i/60,height,-14+i/100);
      const anchor=stableShadowAnchor(position,128,128,resolution,resolution,new Vector3());
      for(const axis of [right,up]) {
        const texel=anchor.dot(axis)*resolution/128;
        assert.ok(Math.abs(texel-Math.round(texel))<1e-8,'fractional texels would make the shadow crawl');
      }
      assert.ok(anchor.distanceTo(position)<128/resolution,'coverage stays close to the camera');
      if(previous)assert.ok(anchor.distanceTo(previous)<.4,'no eight-metre shadow jump');
      previous=anchor;
      const light=shadowLightPosition(anchor,new Vector3());
      assert.ok(light.sub(anchor).normalize().distanceTo(direction)<1e-10);
    }
  }
});
