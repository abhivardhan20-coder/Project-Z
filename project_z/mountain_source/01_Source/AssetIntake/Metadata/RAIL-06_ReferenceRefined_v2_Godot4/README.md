# RAIL-06 | Bus Shelter and Curbside Canopy, Reference Refinement V2

**Project Z / Kaldran City.** Updated procedural 3D GLB asset, not a picture or image plane. User-supplied board retained under `Source/RAIL-06_MultiView_Reference.png`.

## Import

1. Open `RAIL-06_LOD0.glb` using Blender's glTF import or drag it into Godot 4. GLB Y axis is vertical, with the curb toward local -Z. Real units are metres.
2. Use **LOD0** for close hero views, **LOD1/LOD2** for further distances, and **HLOD** for very distant representation. Do not instance all four LODs simultaneously.
3. Import `RAIL-06_collision.glb` as a **proxy**. The `COL_*` meshes identify occupied surfaces; convert them into simple `StaticBody3D` collision shapes in Godot. They are not configured physics collision nodes in the GLB by default.
4. Optional `RAIL-06_damaged_glass_variant.glb` contains a replacement end pane and fractures, not a second entire shelter. Remove/hide the original right end glass visually while this variant is active.
5. For an editable `.blend`, run Blender from this folder using `blender -b --python Source/import_and_save_blend.py`. Blender is **not installed here**, so the `.blend` is not included and its generation is not claimed to be tested.

## Reference decisions

- Eight modular bays over nominal 18 m, 3.6 m depth and about 3.55 m canopy top.
- Deep continuous aluminium front nose and curved steel support haunches; translucent panelized glass roof and clear tempered side/rear walls.
- Two anchored contoured benches to the left, digital mountain poster at left end, framed route timetable toward center right, trash bin and blue route sign at the far right.
- Cool powder-coated steel, subtle brushed trim, warm low-profile soffit lamps, blue-tinted translucent glass, tactile paving and roof drain fittings.
- Only a **single standalone shelter** is exported, no city/station, foliage, bus or decorative background.

## Delivery contents

- `RAIL-06_LOD0.glb`, `RAIL-06_LOD1.glb`, `RAIL-06_LOD2.glb`, `RAIL-06_HLOD.glb`
- `RAIL-06_collision.glb`, `RAIL-06_damaged_glass_variant.glb`
- `Source/build_rail06_refined.py` and `Source/_base_rail06.py` (Python, numpy, trimesh, Pillow)
- `Source/import_and_save_blend.py`, `Source/validate_rail06_v2.py`, and `Source/Godot4_import_notes.gd`
- `Textures/` with original authored PBR PNG maps and panel graphics
- `Previews/` technical images rendered directly from the export, plus a contact sheet
- `RAIL-06_manifest.json`, `RAIL-06_validation.md`, `Validation/measured_QA.json`

## Limitations

No actual Blender `.blend` file was produced. No native Godot import, physics test or lighting approval was possible. The source reference is a stylized multi-view illustration, not calibrated orthographic scan data. This asset is a stronger geometric reconstruction, but **perfect image-level identity is not claimed**. Glass reflections, metallic specular response, and warm lighting require a real Godot 4 WorldEnvironment and scene lights. Use the GLBs in-engine for final art QA.
