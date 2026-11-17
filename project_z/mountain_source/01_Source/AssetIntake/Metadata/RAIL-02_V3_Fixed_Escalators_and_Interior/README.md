# Project Z Kaldran City | RAIL-02 V3 Connected Passenger Concourse

This is a **real procedural 3D model**, not a rendered reference image. V3 is focused on repairing the user-reported floating escalator landings and creating actually open upper-floor stair routes. It **is not an indistinguishable match** to the image concept.

## Files
- RAIL-02_LOD0.glb, RAIL-02_LOD1.glb, RAIL-02_LOD2.glb — actual UV/material 3D meshes, all GLB readback verified
- RAIL-02_collision.glb — 464 simplified collider proxy meshes, adjusted for upper-floor openings and landing connections
- RAIL-02_HLOD.glb — long-distance shell, unchanged from V2
- RAIL-02_rebuild.py, rail02_enrichment.py — editable procedural source for all mesh LODs (Python+numpy+trimesh+pillow)
- RAIL-02_RebuildCollision.py, RAIL-02_V2_collision_base.glb — regenerated proxy collision script and source input
- Blender_Make_Source.py — generate native Blender source locally when Blender is available
- RAIL-02_StationConcourse.tscn and RAIL-02_StationController.gd — proposed Godot 4 scene and door/gate logic, **unexecuted in engine**
- Textures/ — material texture masters (some GLB textures embedded)
- RAIL-02_placements.json — pivots, step entrances and route points
- RAIL-02_manifest.json, RAIL-02_validation.md, RAIL-02_CirculationQA.json — measurements and status
- V3_*.png, RAIL-02_V3_ContactSheet.jpg, RAIL-02_MultiView_Reference.png — actual VTK GLB preview and supplied board

## Rebuild
```sh
python RAIL-02_rebuild.py
python RAIL-02_RebuildCollision.py
```
Dependencies: `pip install trimesh numpy pillow`. Work within this folder to preserve default relative paths.

## Import Godot 4
Add files to a Godot project; open `RAIL-02_StationConcourse.tscn`. Ground floor Y=0, upper finish Y=8.82m, asset orientation glTF Y-up and negative Z for public entrance. Use separate collider proxies instead of visual polygon collision. Run your own capsule navigation and game-performance audit: those are **not verified here**.

## Blender
With Blender installed:
```sh
blender --background --python Blender_Make_Source.py -- /absolute/path/to/RAIL-02_V3_FIXED
```
This creates the native .blend file **locally**, not in this package.

## Remaining art requirements
Compared with the supplied cinematic reference, the model still needs more rigorous station photomatching, refined limestone textures/paneling, architectural illumination, realistic glass transmission, service-counter detailing and careful in-engine lighting. Triangle counts are not a substitute for that work.
