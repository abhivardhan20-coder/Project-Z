# RAIL-04 V5 - Railway Operations and Signal Block

This package contains **real Godot-compatible glTF 2.0 geometry** with three LODs, collision proxy, UV-mapped procedural PBR materials, stair meshes, named moving doors and editable Python procedural modeling source.

Main file: RAIL-04_LOD0.glb. Three distance levels use separate roots. The building's authored footprint is 48 x 22m; antennas and exterior stairs extend beyond the datum.

IMPORTANT: This is NOT certified as an exact visual match to the reference concept, and Blender / Godot engine checks were not performed here. See RAIL-04_validation.md and comparison image for limitations.

Godot 4: Copy all root-level files and the Textures folder into res://RAIL04/ or equivalent; maintain relative filenames in the supplied .tscn, or adjust .tscn paths. Open RAIL-04_Godot_Import.tscn. The RAIL-04_Controller.gd script provides a set_door_open(door_id, opened) method for opening named leaf pivots, but is untested. All collision is from the dedicated collision proxy, not the 266k render mesh. You still need to test playability and add door collision/trigger logic.

Blender: Run from this extracted directory:
    blender --background --python RAIL-04_import_to_blender.py
The script imports the textured LOD0 GLB and saves an editable RAIL-04_source.blend. The .blend file is not pre-generated.

Procedural regeneration (Python):
    pip install numpy trimesh Pillow scipy vtk
    python RAIL-04_source.py
This can take time depending on your hardware; pre-authored maps in Textures/ are reused automatically.

Evidence:
  Previews/RAIL-04_v5_Reference_Comparison.jpg
  RAIL-04_v5_QA.json
  RAIL-04_aperture_check.json
  RAIL-04_validation.md

The mesh is an original interpretation of the user's multi-view reference for Project Z: Kaldran City.
