# RAIL-10 — Godot 4 integration (not engine-tested here)

1. Copy `RAIL-10_LOD0.glb`, `RAIL-10_LOD1.glb`, `RAIL-10_LOD2.glb`, `RAIL-10_HLOD.glb`, and `RAIL-10_COLLISION.glb` to your Godot `res://` asset folder. Godot imports the glTF Y-up geometry into Node3D scenes.
2. Instantiate **LOD0 once for this building** near the player. The imported hierarchy includes the five named `*_Pivot` door nodes. Add `RAIL10_doors.gd` to its root and call `set_door_open(...)` on interaction. Door pivots have world hinges and local animated-body colliders. Confirm swing direction in Godot before making doors interactive.
3. Separately instantiate `RAIL-10_COLLISION.glb` as a child of a Node3D, attach `RAIL10_collision_setup.gd` to that Node3D, and keep the resulting static concave triangle mesh collision. Do NOT enable automatic concave collision on LOD0; it would make doors and reception obstructed.
4. For distant views, replace render LOD0 with LOD1/LOD2/HLOD using your chunk/visibility manager; preserve the separately loaded collision proxy. Godot 4 mesh internal LOD generation is a valid alternative, but do not show multiple render LODs together.
5. GLB is Y-up, and the front forecourt faces **-Z**. Intended building shell footprint 28 × 16 metres; canopy, stair and public paving extend beyond it. Ground datum at `Y=0`; finished entrance floor at approximately `Y=.425`.
6. Verify normals, alpha sorting on glazing, all texture imports, GI/ambient, door swings, collision navmesh and capsule clearance with a 0.56m diameter × 1.75m character capsule. This was **not** performed by the generator.
7. The provided `.blend` creation script needs Blender. A Blender `.blend` file is not bundled because native Blender was unavailable.

## Known limitations

- The front forecourt is set level with the interior finished floor. Connecting it to the *actual* Kaldran city curb/road elevation requires the masterplan elevations; this package does not assume the street height.
- Material textures are true base-color/normal/ORM maps but **prototype 256/512px**. Upgrade to authored 2K/4K textures for AAA close-up quality.
- Doors have authored pivots, no animation tracks baked into GLB; example `gd` animates opening at runtime.
- All engine testing and reference likeness verification beyond visual cross-comparison must be performed in Blender/Godot.
