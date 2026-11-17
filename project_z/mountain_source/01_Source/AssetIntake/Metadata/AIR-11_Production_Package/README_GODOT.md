# AIR-11 / Godot 4 usage

Copy `AIR-11_LOD0.glb`, `AIR-11_LOD1.glb`, `AIR-11_LOD2.glb` to `res://` and copy the `Godot4/` directory to `res://Godot4/`.

Open `res://Godot4/AIR-11_Tent.tscn`; distance-based LOD and basic collision boxes are supplied by `AIR-11_TentController.gd`. The parent scene is the reusable **single module**. For a three-module example, open `res://Godot4/AIR-11_Extended_ThreeTentAssembly.tscn`; each section is the same reusable tent module with linkage panels selectively hidden. Because the prefab reuses the same triage furnishings for all three labels, customise the treatment and support furnishings if distinct interiors are required.

**Important: unverified in engine.** Godot 4 is not installed where the GLBs were generated. Confirm imported animation clip name, GLB node hierarchy, material transparency, light appearance, and script parse before integrating. The source GLB retains two animated entry-flap pivots and the clip `AIR-11_EntryFlaps_Open_Close_Open`. File textures are embedded in GLBs. `AIR-11_collision.glb` is a visual proxy reference, not automatically imported physics. Script-generated collision is separate and uses simple boxes.

Size units: metres. Model front at local Z=0 and back at local Z=12; positive Y is up. All position/rotation alignments to P05/D15 require your actual terrain/masterplan coordinates.
