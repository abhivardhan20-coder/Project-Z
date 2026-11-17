# RAIL-05 v03 Reference-Driven Terminal — quick start

This package contains genuine GLB geometry derived from your multi-view reference, with editable parametric source.

## Import in Godot 4
1. Extract the full folder (do not discard Textures or scripts).
2. Import `RAIL-05_LOD0.glb` as a scene, at scale 1.0; the glTF orientation is +Y up and front toward -Z. Unmodified GLB origin is at the ground datum.
3. Import `RAIL-05_CollisionProxies.glb` separately and convert only the intended simple proxy meshes to `StaticBody3D` collisions. Do not use display-detail meshes for physics.
4. Door objects are separated/named `Doors_Moving__...`; example GDScript is supplied but requires scene-node path and hinge QA.
5. Test entrance/boarding routes using the project's 0.56m diameter × 1.75m capsule. Verify ramps, stairs, bus paths and roof-clipping before placing in the world.
6. For distant placements, use LOD1 / LOD2, manually or with adapted `RAIL-05_Godot4_LODController.gd`.
7. The **optional elevated rail-link** is a standalone visual model. It is not a verified walkable link, and should be integrated only after rail asset alignment.

## Editable Blender scene
- Blender is not installed in the generation environment, so no native `.blend` is included.
- Use `Blender_Import_And_Save.py` from inside Blender or import the GLBs directly. Use `RAIL-05_source.py` to regenerate parametric geometry from Python.
- The source needs `numpy`, `trimesh`, `Pillow`, `scipy`, and uses the checked-in texture maps; `python build_one_lod.py 2/1/0` rebuilds the three LODs. Re-run `consolidate_release.py` then `RAIL-05_validate.py` afterward.

## Honesty about visual accuracy
The model is NOT yet indistinguishable from the reference board. A single concept sheet does not provide measured facade profiles or surface scans, and the CPU previews are not photoreal PBR renders. The supplied `RAIL-05_v03_Reference_Comparison.png` shows the actual remaining mismatch.
