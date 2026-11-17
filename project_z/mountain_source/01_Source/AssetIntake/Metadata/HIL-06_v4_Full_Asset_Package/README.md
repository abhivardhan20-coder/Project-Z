# HIL-06 v4 | Local Grocery and Pharmacy Shop

**Type:** actual editable glTF 2.0 mesh, not an image-generation recreation. Reference-driven, procedural. No claim of 100% photographic fidelity.

## Quick use

- Import `HIL-06_LOD0.glb` into Blender via File > Import > glTF 2.0 or into Godot 4's project. Retain the imported node structure.
- Switch to `LOD1`, `LOD2`, or `HLOD` based on camera distance. No automatic Godot LOD scene was tested in this runtime.
- Place `HIL-06_Collision.glb` or create collision shapes from `HIL-06_colliders.json`. The GLB collision model is separate from visible render meshes.
- Set door pivots to their closed frame 0, then connect animations and appropriate door colliders in Godot. Door mechanics have not undergone in-engine gameplay testing.
- For native Blender save on a machine with Blender installed, run `blender -b --python Source/convert_glb_to_blend.py` in the package directory. The converter was not run here.
- Rebuild the glTFs from source via Python (numpy, Pillow, OpenCV installed) using `python Source/build_hil06.py`.

## Verified counts and import

| LOD | Triangles | Meshes | Embedded textures | 3D geometry check |
|---|---:|---:|---:|---|
| LOD0 | 222,507 | 359 | 32 | Pass |
| LOD1 | 113,078 | 356 | 32 | Pass |
| LOD2 | 41,946 | 313 | 32 | Pass |
| HLOD | 12,576 | 90 | 20 | Pass |

The LOD1 and LOD2 budgets are respectively 50.8% and 18.9% of LOD0. Triangles counted after independently re-importing exports. Zero detected degenerate or non-finite triangle meshes in four LODs.

## Changes vs v3

- Hand-shaped varied rubble-cut stone courses on four elevations instead of all square tile blocks.
- Corner balcony floor slab, railings, planters and leaf meshes continue onto the building's side.
- More substantial volumetric planters and shrub silhouette; muted olive and golden foliage variants.
- Refined dark window glass, window gaskets, latch detail, metal storefront thresholds.
- Physically modeled side shutter, weathered concrete ramp/stair surfaces and sconce housings.
- Roof seams/roughness revised, disconnected upstand deliberately removed.
- High frequency details retained in store interior shelving, POS checkout, pharmacy signage and stockroom.
- More legible studio preview with ambient occlusion; the actual model GLB has no baked studio background.

## Reference-fidelity and limitations

The uploaded reference is a 2D photorealistic concept board, not calibrated photogrammetry or CAD; unknown sides remain approximations. This package does **not** perfectly match the reference. Glass reflections, architectural proportions, foliage shapes, weathering, shelf brands and renderer realism are visibly different. For genuine AAA photoreal reproduction, an artist should continue with Blender modeling, calibrated cameras, high-resolution scanned PBR materials, and in-engine lighting QA.

**Missing required deliverable:** Native `HIL-06_source.blend` because Blender was not available. Godot 4 import was also not tested. These limitations are not labeled as passes.

The output folder includes the original reference, GLBs, texture sources, source generator, collision data, independent QA evidence, and actual GLB viewport previews (not image-generation substitution).
