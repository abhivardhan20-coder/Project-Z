# AIR-06 v3 | Airport Operations and Administration Block

Project Z: Kaldran City | Reference fidelity geometry repair, November 2026.

## What was fixed in v3

The sloped front operations window previously stopped at two open lateral ends, exposing the room. This was architecturally wrong. Both left and right glass end returns are now real watertight panel assemblies and are connected to the 3-storey concrete building with physical piers and upper-floor concrete edge returns. The repair includes:

- 8 physical glass panels across the projecting wedge sides, with separate framing, seals and metal clips.
- 10 grouped concrete supports across the two sides, including a ground-floor side wall, floor-edge spandrel, roof return, sill and back pier on **each** end.
- Updated collision mesh proxy end walls and HLOD silhouettes.
- Old materials, textures and all 4 door animations retained. The original node meshes and all base material/accessor descriptors are preserved.

## Verified exports

| Model | Measured triangle count | LOD0 ratio |
|---|---:|---:|
| AIR-06_LOD0.glb | 431,616 | 100% |
| AIR-06_LOD1.glb | 185,860 | 43.06% |
| AIR-06_LOD2.glb | 64,752 | 15.00% |
| AIR-06_HLOD.glb | 1,756 | 0.41% |

All 3 LOD GLBs passed actual `trimesh.load()` reimport validation: nondegenerate triangles, UVs, finite bounds and embedded PBR materials. LOD0 preserves the original 4 named glTF animation clips.

## Key files

- `Previews/AIR-06_v3_Before_After_Side_Corners.jpg` is a real-geometry before/after render comparison of both corrected side openings.
- `Previews/right_return.png` and `Previews/left_return.png` are closer geometry inspections.
- `Source/generate_air06.py` + `Source/refinement_patch.py` + `Source/side_returns_v3.py` form the editable Python geometry generator.
- `Source/patch_glb_v3.py` demonstrates a faster binary glTF injection pipeline, with prior v2 GLBs expected in sibling `AIR-06_Refined` or supplied using environment variable `AIR06_V2_SOURCE`.
- `AIR-06_Collision_Proxies.glb` contains separate proxy meshes (which require physics setup in Godot).
- `Source/Open_in_Blender.py` creates a native `.blend` from the exported LOD0 GLB once run in Blender 4.x.
- `AIR-06_v3_geometry_proof.json` contains mesh-level bounds/triangle deltas, material/animation preservation checks and SHA-256 checksums.
- `AIR-06_validation.md` explains what was tested and what remains untested.

## Rebuild in Python

Install Python 3, NumPy, Pillow, trimesh and SciPy, then:

```bash
python Source/generate_air06.py --lod 0
python Source/generate_air06.py --lod 1
python Source/generate_air06.py --lod 2
python Source/build_support.py
python Source/validate_air06.py
```

The fully regenerated mesh source has not been round-tripped through Blender or Godot here. The delivered v3 GLBs themselves **have** been reimported and validated as actual mesh files.

## Scope and limits

The target reference is a concept sheet, not a ground-truthed CAD dataset. This correction addresses the user-identified glass and concrete gaps specifically, not unrelated textures or photorealism. Nominal building body 48 x 26 m, roof 11.4 m, top antenna 16.9 m. Y-up, meters, front at negative Z. No native `.blend` created because Blender is absent. Godot scene import, collisions, traversal and door gameplay remain untested in-engine.
