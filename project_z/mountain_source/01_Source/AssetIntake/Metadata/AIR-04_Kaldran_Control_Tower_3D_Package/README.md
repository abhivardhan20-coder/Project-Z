# AIR-04 | Project Z: Kaldran City

**Asset:** Air Traffic Control Tower, matching supplied AIR-04_MultiView_Reference.png. This package contains true triangle meshes with UVs and glTF-compatible PBR materials, not AI-generated asset images. Coordinates are **glTF/Godot Y-up** with the origin at the ground center. All lengths use meters. Final yaw and site coordinates are intentionally unassigned.

## Files

- `AIR-04_LOD0.glb`: full detailed airport tower.
- `AIR-04_LOD1.glb`, `AIR-04_LOD2.glb`: progressively optimized versions.
- `AIR-04_Collision.glb`: dedicated coarse collider meshes; **hide these meshes** in the renderer.
- `AIR-04_source.py`: complete, reproducible parametric geometry source. Source script accepts `--lod 0 1 2` and uses numpy, Pillow, trimesh.
- `AIR-04_create_blend.py`: Blender Python bridge to import the GLB and save an editable `.blend` using Blender on your computer. **Not executed here: Blender is not installed.**
- `AIR-04_Godot.tscn`, `AIR-04_Godot_Setup.gd`: Godot 4 scene stub and collider/warning-light setup, not engine-tested.
- `Textures/`: PNG base color (sRGB RGBA), ORM (linear R=AO, G=roughness, B=metallic), normal maps (linear), texture assets embedded in GLBs as well.
- `Previews/`: neutral VTK geometry inspection renders, not Blender or Godot screenshots.
- `AIR-04_validation.md`: recorded independent GLB re-import tests.

## Project import

Copy the `.glb`, `.tscn`, `.gd`, and `Textures/` to a single folder inside the Godot 4 project. Open `AIR-04_Godot.tscn`; the referenced GLBs should be imported by Godot automatically. Inspect collisions in the editor and only then mark the scene production-ready. The control cab and shaft access are modeled as **view-only service geometry**, not a validated playable staircase or functional elevator.

To produce a Blender-native file, open a terminal in the package folder and run:

```bash
blender --background --python AIR-04_create_blend.py
```

The script saves `AIR-04_source.blend` if Blender's glTF importer succeeds. Open it and manually check materials, pivots and UVs. The Python generator is the original parametric modeling source; Blender import creates an editable triangle-mesh version rather than recreating construction modifiers.

## Reference fidelity and caveats

- Orthographic dimensional priority: approx 56 m total height; approx 16 m ground footprint; approx 24 m glazed cab diameter.
- The 12-level service core, stair/elevator geometry, apron-facing windows, red warning lights and radar crown are physically modeled.
- Rounded beams, joints, railing hardware, service doors and cab consoles are actual polygonal geometry.
- The 4-panel reference is concept art, not a survey or engineering drawing. Some dimensions and all hidden construction details are inferred; this package is **not** an engineered airport facility.
- No site-specific exterior scenery, damage dressing, or real-world branding are included.
- 4K hero texture sets were *not* created; authored textures are 512 or 1024 px, using detail geometry for close-range definition.
- No automatic animation is attached; warning lights are emissive and optional real lights are added via Godot script. Radar structures are static meshes.

## Skyline HLOD

`AIR-04_HLOD.glb` has 2,562 triangles and retains the concrete taper, cab, radar and warning lights for remote skyline rendering. Use it beyond your scene's tested far LOD switching threshold, not as a close-up replacement. `AIR-04_make_HLOD.py` is the reproducible silhouette-model generator.
