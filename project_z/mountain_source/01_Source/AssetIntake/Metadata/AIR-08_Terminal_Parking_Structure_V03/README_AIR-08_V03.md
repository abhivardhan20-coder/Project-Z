# AIR-08 / V03: Terminal Parking Structure

**This is an actual 3D GLB asset, not an image.** Version 03 is a reference-constrained procedural rebuild with measured multi-LOD meshes, exported materials and authored collisions.

## Primary files

- `AIR-08_LOD0.glb`: the high-detail real 3D model (488,789 render triangles)
- `AIR-08_LOD1.glb`, `AIR-08_LOD2.glb`: optimized visual meshes, with physically correct architectural openings
- `AIR-08_HLOD.glb`: distant representation
- `AIR-08_collision.glb`: matched simplified physics collider volumes (separate asset)
- `AIR-08_generator.py` plus `AIR08_v3_details.py`: editable procedural source to regenerate the GLB models (requires Python, numpy, scipy, trimesh and Pillow)
- `AIR-08_make_blend.py`: run inside Blender 4.x to convert actual LOD0 geometry into `AIR-08_source.blend`; Blender was unavailable here so no `.blend` binary was included
- `AIR-08_Godot4.tscn` / `.gd`: import/integration starting point only, not engine-tested
- `Textures/`: physical PBR texture sources; `Reference/`: the user's unchanged image sheet
- `AIR-08_V03_reference_comparison.png`: source/model compare; `AIR-08_V03_preview_board.png`: 6-view mesh renders; `Previews/*.png`: individual 3D material render views
- `AIR-08_validation.md`: required detailed technical caveats and measured count table

## Workflows

Extract this folder into your Godot 4 asset repository. Import the primary GLB and collision GLB separately; avoid using visual high-poly meshes directly for static physics. For editing import `AIR-08_LOD0.glb` into Blender, or run:

`blender --background --python AIR-08_make_blend.py`

To regenerate geometry after editing source: `python AIR-08_generator.py --out .`; then `python AIR-08_collision_generator.py`, `python AIR-08_HLOD_generator.py`, `python AIR-08_validate.py`.

**Current limitations:** not a certified 100%-pixel-identical reconstruction, no native `.blend` binary, no Godot runtime collision test, no scanned 4K PBR material captures. Read the validation report before acceptance.
