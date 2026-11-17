# RAIL-01 v02 | Central Arch Station grand roof

This ZIP contains **actual 3D geometry** reconstructed from `RAIL-01_MultiView_Reference.png`. It is not an AI-produced picture.

## Open it

- Open `RAIL-01_LOD0.glb` in Blender 4.x, or drag the `.glb` into an existing Godot 4 project. The export is glTF 2.0, Y-up, meters.
- Use `RAIL-01_LOD1.glb`, `RAIL-01_LOD2.glb` for reduced render meshes, and `RAIL-01_HLOD.glb` for a far-distance silhouette.
- Put the `.glb` and `RAIL-01_Godot4.tscn` into the same `res://` directory, then open the scene to get simplified physics colliders. **Not tested in Godot here.**
- In Blender, run `blender --background --python RAIL-01_make_blend.py` from this extracted folder; it will create `RAIL-01_source.blend`, preserving separately named editable objects and materials. **A native `.blend` is not in this ZIP.**
- The full editable procedural geometry authoring script is `RAIL-01_build_refined.py` (Python, trimesh, Pillow, numpy). Run with Python to regenerate. Auxiliary helper scripts can regenerate collisions, previews, HLOD and checks.
- Review `RAIL-01_validation.md` for verified counts, visual comparison, unresolved issues and exclusions.

## Main outputs

- Real geometry: LOD0 / LOD1 / LOD2 / HLOD GLB
- Collision mesh: `RAIL-01_collision.glb`; playable proxy colliders: `RAIL-01_Godot4.tscn`
- Generation: `RAIL-01_build_refined.py`, `RAIL-01_make_blend.py`, `RAIL-01_generate_godot_scene.py`
- Materials: `Textures/` with albedo, normal and ORM textures; they are also embedded in the GLBs
- Proof: `RAIL-01_manifest.json`, `RAIL-01_verification_results.json`, `RAIL-01_validation.md`, `RAIL-01_verify.py`
- Inspectable views: `Previews/RAIL-01_refined_six_view.jpg` and six full-resolution angles

## Honest production caveat

This is a stronger **parametric reference reconstruction**, not a survey-accurate / 100% pixel-matched building, engineering-approved construction model or completed in-engine QA asset. Do not use triangle count as a substitute for reviewing proportions and platform collision in Godot.
