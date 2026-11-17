# HIL-09  |  Residential Parking and Garage Shed

**Project Z: Kaldran City  •  Hillview & Residential  •  Asset 21 / 81**

This is a real polygonal architecture package based on the supplied single HIL-09 multiview reference, **not** a textured flat picture or standalone render. The main model contains one usable parking level, a front opening with stone piers, an accessible pedestrian stair opening on the west side, a continuous reinforced-concrete roof slab, retaining stones, louvres, parking markings, realistic individual pavers, railing, plants, HVAC, pipework and utility details.

## Package manifest
- `HIL-09_LOD0.glb` detailed mesh with embedded PBR maps (must have >150,000 triangles).
- `HIL-09_LOD1.glb` mid-distance mesh (40–55% of LOD0).
- `HIL-09_LOD2.glb` distant mesh (10–20% of LOD0).
- `HIL-09_collision.glb` separate lightweight broad-phase wall/floor/stair/rail proxies.
- `HIL-09_HLOD.glb` extra low-triangle remote architectural silhouette with real geometry.
- `HIL-09_source.py` **true editable procedural source** for deterministic reconstruction using Python, trimesh, NumPy, Pillow, and SciPy.
- `HIL-09_blender_setup.py` Blender import-and-save script that creates `HIL-09_source.blend` when executed on a Blender machine.
- `HIL-09_preview.py` independent CPU raster previews of the exported GLB geometry; previews are NOT Godot import screenshots.
- `Textures/` original procedural albedo, packed ORM and normal material maps, also embedded in the GLBs.
- `References/` exact attached HIL-09 multiview image.
- `Previews/` 6 geometry viewpoints and contact sheet.
- `HIL-09_manifest.json`, `HIL-09_validation.md`, `HIL-09_QA.json`, `HIL-09_verify.py`: counts, roundtrip evidence and repeatable validation.

**Unavailable here:** Blender and Godot binaries. Accordingly `HIL-09_source.blend` and an actual Godot engine import screenshot are **not included**. Do not substitute a fake .blend file or rendered screenshot as proof. Blender users can run the provided setup script to generate the .blend, then test the native files.

## Scale and coordinate system
- Design intent ~28.0 m (frontage) × 16.0 m (depth), height about 6.0 m.
- Source Python is X-width, Y-depth, Z-up. GLB is baked **Y-up** as required by glTF, with front looking in +Z direction and depth running toward negative Z.
- Ground datum ~0 m, parking floor about +0.18 m in source Z-up.
- World-space bounds are recorded in the JSON manifest. Decorative stone/vines/rim may extend a few tenths of a metre beyond the nominal slab footprint.
- No arbitrary Kaldran masterplan yaw, GPS position or terrain elevation is baked into the root.

## Blender
Open the ZIP folder in Blender-capable workstation and run:

```sh
blender --background --python HIL-09_blender_setup.py
```

The script imports all LOD meshes, the collider file, separates named categories, establishes an editable asset root, creates a sample barrier pivot action, cameras and lights, then saves `HIL-09_source.blend`. Blender import and animation curves are **not verified** on this execution machine. The source `.py` is a complete replacement if you need to regenerate GLBs or tweak the model.

## Godot 4 integration procedure
1. Import `HIL-09_LOD0.glb` via Godot 4's glTF scene importer at scale **1.0**. Inspect Y-up axes and metres, recalculate normals only when required. Materials should bind to built-in glTF base-color / ORM / normal textures; set mipmapping, anisotropy and screen-space ambient occlusion in the game environment as appropriate.
2. Import `HIL-09_collision.glb` separately and convert low-resolution meshes into `StaticBody3D`/`CollisionShape3D` or trimesh collision proxies. Disable render for collision meshes and verify roof, columns, stair treads, and side walls; importantly, do NOT insert collision into front garage entry or pedestrian stair opening.
3. Keep `Doors_Moving_*` graphics under an animated barrier pivot. Arm opening and path need final game-scale clearance verification, and Godot animation/collision must be authored and tested in-engine. The GLBs themselves contain **no keyframe tracks**.
4. Import LOD1 and LOD2 as separate lower-detail variants. Use `VisibilityRange` / Godot `GeometryInstance3D` ranges or a script-based LOD switch. Do not display all three LODs simultaneously.
5. For actual level production, place parked cars as **independent instanced vehicle assets** (context cars were omitted from this building geometry), and connect the sloped streets and courtyard to local gameplay heightmap.
6. Profile on target GPU and tune texture streaming. LOD0 is a close-up architecture asset, not a whole-city instance tier.

## Verification policy
See `HIL-09_validation.md`. Triangles were counted from exported, re-imported GLBs and agreed exactly. UV and material textures are embedded and external originals are included. Actual Godot renderer/collision import, Blender save, and working barrier interaction are untested here; those are handoff acceptance tasks, not claimed successes.
