# HIL-07 v02 • Refined low-rise townhouse and rowhouse

**Playable project:** Project Z / Kaldran City. **Building scale:** nominal six joined units across 52m, roughly 16m deep, 2 occupied storeys with pitched roof / attic volumes.

This is **real, modifiable, UV-unwrapped 3D geometry**, not a single rendered picture. It is a substantially revised procedural rebuild with hand-authored architectural details, with the known accuracy limitations fully disclosed in the validation file. It should not yet be called photorealistic or 100% source-conformant.

## Files

- `HIL-07_LOD0.glb` / `HIL-07_LOD1.glb` / `HIL-07_LOD2.glb`: independent importable +Y-up glTF assets, with embedded PBR maps.
- `HIL-07_CollisionProxies.glb`: separate grouped simplified walls, stairs, floors and fencing. Avoid using the entire visual mesh as a collision surface.
- `Textures/`: editable base color, normal and packed ORM raster maps.
- `Source/build_hil07_refined.py`: full expanded procedural mesh-generation source.
- `Source/export_driver.py`: recommended independent per-LOD exporter and roundtrip verifier. Run from the `Source/` directory or as a path.
- `Source/build_collision_proxies.py`: collision geometry construction.
- `Source/HIL-07_Blender_Import_Save.py`: import-and-save script for producing `.blend` locally using installed Blender.
- `Source/HIL-07_Godot4_Initializer.gd`: untested Godot 4 example that imports a LOD and static colliders.
- `Source/HIL-07_Door_Controller.gd`: untested hinge pivot example. No runtime animation is embedded in GLB.
- `Previews/`: exported geometry screenshots made in VTK, NOT Godot.
- `HIL-07_MultiView_Reference.png`: user-supplied authority board.
- `HIL-07_manifest.json`, `HIL-07_GLTF_Inspection.json` and `HIL-07_Validation.md`: export report and precise caveats.

## Godot 4 import

Place each GLB and the sample `.gd` scripts in your `res://` project root. Assign the initializer script to a new Node3D and adjust its displayed LOD. Test physics on your target engine/device, especially the third-house doorway, third-house furniture and stair handrails. The demo code has NOT been executed in Godot.

## Blender

Import the GLB via File > Import > glTF 2.0, or run from this directory: `blender -b --python Source/HIL-07_Blender_Import_Save.py`. This should save `HIL-07_source.blend` when Blender is installed; it was not executed here.

## Realistic acceptance status

The detailed glTF exports pass structural checks and triangle budget. 100% visual fidelity is not certified. A native `.blend`, baked 4K scanned material textures, exported animation track and tested engine import are NOT included. See the validation report before any signoff.
