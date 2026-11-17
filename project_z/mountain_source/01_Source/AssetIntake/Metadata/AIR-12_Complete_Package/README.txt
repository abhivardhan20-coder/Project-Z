PROJECT Z / KALDRAN CITY / AIR-12 / AIRPORT ROADSIDE SERVICE STATION

WHAT IS HERE
- AIR-12_LOD0.glb: detailed physically modeled 3D asset; two animated door leaf nodes.
- AIR-12_LOD1.glb, AIR-12_LOD2.glb: lighter geometry for runtime LOD use.
- AIR-12_COLLISION.glb: low-poly collision proxies; do not draw.
- AIR-12_build.py: the complete editable procedural mesh construction source.
- AIR-12_make_blend.py: run inside Blender 4 to make a native AIR-12_source.blend.
- AIR-12_Godot_DoorTrigger.gd: optional Godot 4 automatic door trigger.
- Textures/: loose PBR files also embedded in GLBs, no extra files needed to view GLB.
- Previews/: multiple real GLB mesh render angles.
- AIR-12_manifest.json / AIR-12_validation.md: dimensions, checks, limitations.
- AIR-12_MultiView_Reference.png: original user-supplied image reference.

BLENDER
Blender is NOT available on the generating system, so no .blend file can be verified.
Open Blender, Scripting, select AIR-12_make_blend.py, Run Script. Or:
  blender -b -P AIR-12_make_blend.py
The helper imports LOD0 and saves AIR-12_source.blend in this directory.
Do not assume a native .blend was already generated.

GODOT 4
1. Copy GLBs into a Godot project. Import LOD0 as a scene.
2. Confirm the animated nodes Door_Left_Moving / Door_Right_Moving.
3. Create Area3D at front main entrance with trigger collision shape,
   attach AIR-12_Godot_DoorTrigger.gd, and connect its body_entered/body_exited
   signals to the matching methods.
4. Assign imported AnimationPlayer in Inspector. Test door clearances in engine.
5. Import AIR-12_COLLISION.glb separately; convert/provide StaticBody3D
   concave or convex collision as appropriate in your game (not automatic).
6. Use your Godot LOD switching strategy, swapping only visible geometry,
   and preserve entrance collision and moving door nodes separately.

VALIDATION LIMITS
Triangle counts are verified by reimporting exported GLBs in trimesh.
Godot and Blender are not installed here; in-engine import/playback is NOT tested.
This is a procedural reference-based reconstruction, not a surveyed 1:1 scan.
