import * as THREE from 'three/webgpu';
import { cameraPosition, normalWorld, positionWorld, reflector, smoothstep, uniform, uv, vec3 } from 'three/tsl';

/** A single shared, reduced-resolution planar pass for all of the street's puddles. */
export function createWetReflections(
  scene: THREE.Scene,
  streetGroup: THREE.Group,
): { setQuality(quality: string): void; setWetness(wetness: number): void } {
  const puddles = streetGroup.getObjectByName('Monsoon puddles');
  if (!(puddles instanceof THREE.Mesh)) {
    throw new Error('Wet reflections require the street mesh named "Monsoon puddles".');
  }

  const originalMaterial = puddles.material;
  const fallbackMaterials = Array.isArray(originalMaterial) ? originalMaterial : [originalMaterial];
  const fallbackOpacities = fallbackMaterials.map(material => material.opacity);

  // The merged circles sit at y=.014 to .0165. Keep the clipping plane just above
  // the asphalt and paint so they cannot occlude the mirrored buildings and trees.
  const target = new THREE.Object3D();
  target.name = 'Shared street reflection plane';
  target.position.y = 0.04;
  target.rotation.x = -Math.PI / 2;
  scene.add(target);
  target.updateMatrixWorld(true);

  const reflection = reflector({
    target,
    resolutionScale: 0.35,
    bounces: false,
    generateMipmaps: false,
    samples: 0,
  });
  const waterOpacity = uniform(0.85);
  const viewDirection = cameraPosition.sub(positionWorld).normalize();
  const facing = viewDirection.dot(normalWorld).abs().clamp(0, 1);
  const fresnel = facing.oneMinus().pow(3).mul(0.86).add(0.14);
  // Each merged CircleGeometry retains its local circular UVs. The final few
  // centimetres fade into the road instead of making a hard mirror cutout.
  const edgeFade = smoothstep(0.77, 1, uv().sub(0.5).length().mul(2)).oneMinus();

  const material = new THREE.MeshBasicNodeMaterial({
    transparent: true,
    depthWrite: false,
    depthTest: true,
    // The reflection pass already contains the scene's atmospheric fog.
    fog: false,
  });
  material.name = 'Monsoon planar reflections';
  material.colorNode = reflection.rgb.mul(vec3(0.8, 0.86, 0.83));
  material.opacityNode = waterOpacity.mul(fresnel).mul(edgeFade);
  puddles.material = material;

  return {
    setQuality(quality) {
      // Detaching the node material also removes the reflection pass on economy presets.
      puddles.material = quality === 'high' || quality === 'ultra' ? material : originalMaterial;
    },
    setWetness(wetness) {
      const amount = Number.isFinite(wetness) ? THREE.MathUtils.clamp(wetness, 0, 1) : 0;
      // A clear spell leaves a small residual sheen; rain brings the full reflection back.
      waterOpacity.value = 0.17 + amount * 0.68;
      fallbackMaterials.forEach((fallback, index) => {
        fallback.opacity = fallbackOpacities[index] * (0.2 + amount * 0.8);
      });
    },
  };
}
