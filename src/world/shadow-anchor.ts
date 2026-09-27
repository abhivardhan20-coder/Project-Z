import { Vector3 } from 'three/webgpu';

// Snap in the light's image plane, not in world X/Z: world-grid snapping changes
// the fractional shadow texel and makes otherwise stationary floors shimmer.
const direction = new Vector3(-36, 48, -59).normalize();
const right = new Vector3().crossVectors(new Vector3(0, 1, 0), direction).normalize();
const up = new Vector3().crossVectors(direction, right).normalize();

export function stableShadowAnchor(position:{x:number;y:number;z:number}, width:number, height:number,
  resolutionX:number, resolutionY:number, target:Vector3) {
  const sx=width/resolutionX,sy=height/resolutionY;
  const x=Math.round((position.x*right.x+position.y*right.y+position.z*right.z)/sx)*sx;
  const y=Math.round((position.x*up.x+position.y*up.y+position.z*up.z)/sy)*sy;
  const z=position.x*direction.x+position.y*direction.y+position.z*direction.z;
  return target.copy(right).multiplyScalar(x).addScaledVector(up,y).addScaledVector(direction,z);
}

export function shadowLightPosition(anchor:Vector3,target:Vector3) {
  return target.copy(anchor).addScaledVector(direction,140);
}
