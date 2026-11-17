# Project Z: Kaldran City | AIR-05 Aircraft Maintenance Hangar

This package contains **real editable 3D geometry**, not an image-to-3D billboard: animated GLB pivot hierarchies, real roof sheet folds, large structural clear-span steel trusses, an aircraft portal, suspended crane system, stairs/mezzanine, PBR materials, separate LODs and a stripped-down far-distance HLOD shell.

## Pick a file

- `AIR-05_LOD0.glb`: high-detail model with door animation and lean collision proxies, around 540K actual render triangles.
- `AIR-05_LOD1.glb`: optimized mid-range version (around 50% of LOD0 render triangles).
- `AIR-05_LOD2.glb`: distant version (around 12% of LOD0 render triangles).
- `AIR-05_HLOD.glb`: minimal textured-free distant silhouette (696 triangles).
- `AIR-05_MultiView_Reference.png`: the exact user-supplied reference board.
- `AIR-05_generate.py`: procedural *editable, rerunnable* full-detail model generator, using NumPy, Pillow and Trimesh.
- `AIR-05_make_blend.py`: one-shot Blender converter. Requires Blender installed; executes `blender -b --python AIR-05_make_blend.py` and writes `AIR-05_source.blend`. This `.blend` cannot be bundled because Blender is not available in the current runtime.
- `AIR-05_Godot_import_notes.md`: import, animation and collision instructions.
- `AIR-05_manifest.json`, `AIR-05_validation.md`: factual post-export machine checks and limits.
- `Previews/`: VTK offline technical renders. **Not** Godot editor screenshots or an engine import test.

## Major modeled details

Main enclosed footprint 88m wide × 60m deep, sloping roof with a ridge at 18.5m, 16.4m side eaves; around 19.575m highest ventilator cap. Airfield-side clear central opening is 58.44m wide with doors parked, and ~13.25m high conservatively. Eight animated sliding leaves (4 on each side), separate 0.45m track spacing, roller/wheel assemblies and overhead guide rail. Roof supported by transverse 88m clear-span trusses, with secondary purlins, profiled sheets, three longitudinal roof skylight bands viewed across X, eight louvered vents and functional-scale service access geometry. Interior has overhead crane, catwalk, 28-step staircase, machinery and service stripe patterns.

## Rig playback

Open a GLB in a compatible glTF2 viewer and look for `AIR05_HangarDoors_OPEN_CLOSE_OPEN_8s`, with keys at t=0 (open), t=4 (closed), t=8 (open). Engines may need you to actively choose/play this track. Collision proxies are geometry only: add native Godot collider components to the prescribed objects, and animate each leaf collider with its leaf pivot.

## Honest limits

The engine and Blender executables are missing from the runtime. **No verified native `.blend`, Godot import, physics collision simulation, or Godot editor capture is supplied.** UV maps are valid but basic per-face procedural mappings, and the PBR material images are 1K or 512px rather than professionally art-directed 4K hero assets. Treat this as a solid reproducible procedural mesh production baseline to polish/test, not as a certification of AAA-quality authored hero materials or aircraft clearance for any specific aircraft.
