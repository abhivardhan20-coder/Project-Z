# CIV-01 | Capitol Assembly Hall, v02

A **real 3D asset pack** for Kaldran City, built from the supplied concept reference, not a 2D image export.

**Not a final photogrammetric 1:1 model.** Visual details and interiors are approximated.

## Contents
- CIV-01_LOD0.glb (431,756 visible triangles)
- CIV-01_LOD1.glb (178,548 triangles)
- CIV-01_LOD2.glb (54,148 triangles)
- CIV-01_HLOD.glb (3,248 triangles)
- Textures/ (15 procedural 1024px PBR tri-map sets)
- CIV-01_collision.json (119 box collision proxies)
- CIV-01_Godot4_Importer.gd (Godot helper; *not runtime tested*)
- CIV-01_build.py + CIV-01_refine_v02.py (editable, deterministic Python procedural source)
- CIV-01_make_blend.py (Blender GLB->native .blend conversion helper; not executed)
- CIV-01_MultiView_Reference.png, previews, comparison, manifests and QA

## Use in Blender 4.x
Import `CIV-01_LOD0.glb` as glTF 2.0. Keep original node hierarchy; two active door pivot nodes should remain.
To save a native .blend with Blender installed:

`blender --background --python CIV-01_make_blend.py -- CIV-01_LOD0.glb CIV-01_source.blend`

The .blend was **not** included because Blender was not available in the export environment.

## Use in Godot 4.x
Copy GLB, collision JSON and Godot importer into project resource folder; put helper script on a new `Node3D` and set exported file paths. Load only LOD0 at close distance. Configure LOD switch logic, PBR lighting, environment reflection probes and collision layers. Call `open_main_doors()` on the importer node to rotate door leaves.

**Not tested:** Godot editor/import, real character navigation, stairs with capsule, door hinge collision. The helper may need adaption to your project.

## Regenerate geometry
Install Python dependencies: `pip install numpy scipy pillow trimesh`.
Run inside extracted pack: `python CIV-01_refine_v02.py --out . --texsize 1024`. This recreates the GLB meshes, but the post-export embedded animation and PBR fixes must be run afterwards:

`python CIV-01_embed_animation.py CIV-01_LOD0.glb CIV-01_LOD1.glb CIV-01_LOD2.glb`

`python CIV-01_finalize_pbr.py CIV-01_LOD0.glb CIV-01_LOD1.glb CIV-01_LOD2.glb CIV-01_HLOD.glb`

If re-generating collision JSON, apply `python CIV-01_patch_collision_v02.py` afterwards. Then run `python CIV-01_verify_v02.py .`.

## Limits
This is v02 parametric reconstruction, **not** a guarantee of 100% image matching. Section and roof drawings on reference are illustrative; parts not specified in the board are interpreted. See `CIV-01_validation.md`.
