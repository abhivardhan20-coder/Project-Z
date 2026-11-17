# AIR-10 · Evacuation command and screening cabins · Refined v2

## Source of truth
The supplied AIR-10_MultiView_Reference.png controls one 12.0 x 4.0 meter command cabin,
plus screening and triage cabins of similar size. This is a real geometry deliverable,
not a reference-board rendering.

## Files
- AIR-10_LOD0.glb: 420,834 render triangles, 203 meshes.
- AIR-10_LOD1.glb: 184,086 render triangles.
- AIR-10_LOD2.glb: 63,194 render triangles.
- AIR-10_CollisionProxies.glb: 46 low-triangle proxies, including canopy columns and roof.
- AIR-10_source_generator.py: underlying procedural mesh generator.
- AIR-10_source_refined.py: v2 modifications, preferred reproducible build entry point.
- AIR-10_create_blend.py: run within Blender 4.x to create AIR-10_source.blend.
- AIR-10_Godot4_Controller.gd / AIR-10_Checkpoint.tscn: Godot integration starting points.
- Textures/: 87 PNGs; mapped materials embedded inside GLB files.
- Previews/: flat-shaded geometry previews, UV-texture previews and reference comparison.
- AIR-10_validation.md and AIR-10_manifest.json: measured validation and limits.

## Regenerate geometry
`python AIR-10_source_refined.py`

## Generate editable native Blender file on a workstation
`blender --background --python AIR-10_create_blend.py`

## Godot 4 quick-start
Copy the GLBs, controller and .tscn into your Godot project. Open AIR-10_Checkpoint.tscn,
inspect imported hierarchy, collision and door pivots. Do a physics/animation pass before shipping.

## Honesty/limitations
No Blender or Godot executable on this host, so no native .blend file and no true Godot import,
physics, material or animation runtime validation. UV/mesh/GLB structure is re-import verified.
Exterior texture maps remain 256–512 px (1024 px for mission-display art), below desired AAA
2K/4K map resolution. Photo-like match to the rainy dusk reference also depends on proper
real-time lighting, reflections, wet ground materials and surrounding airport environment,
which are not part of this modular cabin asset. The board is an approximate multi-view concept,
not a measured photogrammetric survey; a literal 100% match cannot be demonstrated.
