# HIL-02 · Reference-refined v2

Real, editable 3D geometry of the stepped Kaldran hillside retaining-wall apartment asset. This is the **revised** package, not the earlier generic blockout.

## Files

- `HIL-02_LOD0.glb` : **329,878 triangles**. Highest geometric detail. Embedded high-resolution PBR maps.
- `HIL-02_LOD1.glb` : **165,714 triangles**. Lower geometry and smaller embedded maps.
- `HIL-02_LOD2.glb` : **34,292 triangles**. Optimized long-view geometry.
- `HIL-02_HLOD.glb` : **1,636 triangles**. Lightweight distant proxy.
- `HIL-02_collision.glb` : **6,492 triangles**. Simplified collision geometry, not physics-tested.
- `HIL-02_build.py` : Full procedural and editable source for the three render LODs, source PBR maps and manifest.
- `HIL-02_generate_aux.py` : Collision-proxy and HLOD geometry generator.
- `HIL-02_make_blend.py` : Create native editable `.blend` by importing LOD0 **on a machine with Blender installed**.
- `HIL-02_GodotLoader.gd` : Godot 4 integration template (untested).
- `HIL-02_validate.py`, `HIL-02_QA_results.json`, `HIL-02_validation.md` : Test implementation, real exported-file results and limitations.
- `Textures/` : Source base-color, normal and packed roughness/metallic/AO maps for all material families.
- `Previews/` : Screenshots of the real exported LOD0 mesh, front/rear/roof/side/hero/lobby and details.
- `HIL-02_MultiView_Reference.png` : Supplied image authority.

## Installation

Import a GLB directly into Blender or Godot as glTF 2.0. Dimensions use metres, exported coordinate system is Y-up and the building datum is 0.0 metres, with some below-ground foundation mesh. Textures are embedded in GLBs.

**Not certified as an exact replica.** This rebuild makes significant reference-matching changes but fine fenestration, landscape, rear elevation, gameplay navigation and engine implementation require human review. There is no native `.blend` until the supplied Blender script is executed locally. See `HIL-02_validation.md` for transparent acceptance notes.
