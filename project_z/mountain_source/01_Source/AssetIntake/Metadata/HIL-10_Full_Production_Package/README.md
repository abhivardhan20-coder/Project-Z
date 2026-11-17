# HIL-10 | Playground Shelter & Community Pavilion

Real, editable, multi-mesh 3D reconstruction of the supplied Project Z: Kaldran City HIL-10 architectural reference sheet.

## Contents

- `HIL-10_LOD0.glb` - highest-resolution art scene (>150,000 real triangles)
- `HIL-10_LOD1.glb` - medium-detail art scene
- `HIL-10_LOD2.glb` - optimized distant scene
- `HIL-10_collision.glb` - independently simplified physics geometry, not part of art tri counts
- `HIL-10_HLOD.glb` - if present, very distant art scene
- `HIL-10_source.py` - deterministic procedural editable scene-authoring source in meters
- `HIL-10_build_blend_in_Blender.py` - local Blender command to generate `HIL-10_source.blend`
- `Textures/` - texture exports with `_basecolor.png`, `_normal.png`, `_orm.png` suffixes
- `Previews/` - six CPU-shaded orthographic views from the actual export geometry
- `HIL-10_manifest.json` - measured geometry and files
- `HIL-10_validation.md` - actual verification results and limitations
- `HIL-10_Godot4_Import.md` - engine import guidance
- `HIL-10_MultiView_Reference.png` - exact uploaded user reference, preserved unchanged

## Blender editable source

The GLBs consist of separate named meshes and PBR materials and can be imported and edited in Blender. To create the native `.blend` file using a local Blender 4.x installation:

```bash
blender --background --python HIL-10_build_blend_in_Blender.py
```

The creation environment did **not** include Blender or Godot 4. Therefore, no `.blend` file is falsely represented as generated, and no Blender/Godot engine validation is claimed. The parametric Python source is supplied and the GLB contents were checked with an independent glTF import.

## Design / reference mapping

- Pavilion 12 x 8 meters, single sloped 2.7-3.9 m roof with standing seam metal top and exposed timber framing; columns on two transverse rows
- Real paving slabs, structural footings, timber benches, noticeboard cards, light housings, railing, access ramp, tactile buttons
- Painted timber play tower with pitched roof, formed trough slide, climbing wall with holds and twin swings
- 3D stone-block retaining wall, edge drainage channel, colored curved EPDM rubber surfaces with 3D aggregates, shrubs and site paving
- Static state; no opening doors or animated machinery in reference, so no unnecessary rig

Surface material textures are generated procedurally without licensed logos or external image assets. They are authored as glTF-compatible color, tangent-space normal and ORM textures. The largest maps are 2048 x 2048 pixels rather than the reference prompt's preferred 4K hero sets.

All geometry is a reference reconstruction, not engineering survey data and not a verified installed masterplan fit. No unverified yaw, foundations on terrain, or Godot navmesh has been baked into the source.
