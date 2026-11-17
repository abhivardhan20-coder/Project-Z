# Project Z : Kaldran City / AIR-02 / REBUILT v2.1

A fresh 3D reconstruction intended to match the provided 180m x 60m multi-panel terminal canopy reference more closely than the previous GLB. This is not a render pretending to be a model.

## Open / edit

- `AIR-02_LOD0.glb` — high-detail 513,624 triangle master
- `AIR-02_LOD1.glb` — medium 239,784 triangle model
- `AIR-02_LOD2.glb` — low 89,600 triangle model
- `AIR-02_colliders.glb` — simplified static collision source only
- `AIR-02_rebuild.py` + `AIR-02_mesh_core.py` — editable procedural geometry source; Python + numpy + trimesh + pillow + opencv-python
- `AIR-02_build_blend.py` — import delivered GLBs into Blender 4.x and save a source BLEND (not run in this environment)
- `Textures/` — PBR base color, packed ORM, normal map sources
- `Previews/` — real-GLB diagnostic images, NOT Godot renders
- `AIR-02_MultiView_Reference.png` — original reference board
- `AIR-02_validation.md` — exact geometry checks + remaining mismatch disclosure
- `AIR-02_manifest.json` — checksums and bounds

## Regenerate from source

For reproducibility and lower peak RAM usage, run separately:

`AIR02_LODS=0 python AIR-02_rebuild.py`
`AIR02_LODS=1 python AIR-02_rebuild.py`
`AIR02_LODS=2 python AIR-02_rebuild.py`
`python AIR-02_validate.py`

The source generates each LOD with the same analytical roof formula and reusable structure.

## Status and candor

Actual GLB geometry, PBR links, UV0, NORMAL, relative LOD budgets and binary reimport are validated. Native Blender source and a Godot editor test are NOT validated. The reference's front-vs-section roof conflict has a visible compromise described in validation, so this cannot be represented as 100% visually exact.
