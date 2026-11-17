# PROJECT Z · Kaldran City · AIR-09 (Refined v2)

## Asset output

This is an **actual 3D model reconstruction**, not a concept render. The facade, raised roof volumes, service bay interior, fuel tank exteriors, canopy pumps, fences, handrails, grates and metal mechanisms are separate material-group meshes using embedded PBR materials. Openings in the front service garage, rear garage, clerestory and control window areas are modeled as 3D geometry.

The model **significantly improves** the earlier simplified shell: stepped service block + low glazed fuel-control room, compact canopy with fuel pumps, one genuinely open service bay and one shuttered bay, smooth capped external fuel tanks in concrete spill-bund with a narrow yellow-railed access walk and staircase, a fenced secure compound, HVAC equipment and industrial service interior.

The attached reference board has a 52 × 28 m site dimension and a stated 8.8 m above-ground height. This revision now matches those overall datum dimensions (plus 0.21 m of below-grade site mesh). All high and low roof parts were reconciled into one buildable roof arrangement rather than using independent shapes for different reference views.

## Delivered production files

- `AIR-09_LOD0.glb` · **245,008** evaluated mesh triangles, 152 material-group mesh objects
- `AIR-09_LOD1.glb` · **103,996** triangles (42.4% of LOD0)
- `AIR-09_LOD2.glb` · **44,084** triangles (18.0% of LOD0)
- `AIR-09_HLOD.glb` · **492** triangles, very distant real-geometry silhouette approximation
- `AIR-09_collision.glb` and `AIR-09_collision_proxies.json` · 53 lean static collision proxies
- `refine_air09.py` and `geometry_helpers.py` · procedural source script in metres
- `Textures/` · 20 tileable metallic-roughness material families, including albedo, ORM and tangent-space normal maps, 512px each. GLB materials embed the maps; loose maps are supplied to edit them.
- `Blender_Import_Save_Source.py` · Blender 4+ conversion script to generate `AIR-09_source.blend` on a machine with Blender
- `AIR09_CollisionBuilder.gd` · simplified collision builder in a sibling scene node
- `Godot_Import_Smoke_Test.gd` · Godot 4 offline import smoke-test script to run locally
- `AIR-09_validation.json`, `AIR-09_validation.md`, `AIR-09_manifest.json` · verification metrics
- `Previews/` · isolated neutral-render model views plus reference comparison; none are Godot gameplay screenshots

## Recreate and work with the asset

Requires Python 3.11+, NumPy, Trimesh and Pillow. From this directory:

```bash
python refine_air09.py
python build_collision.py
python build_hlod.py
python validate_refined.py
```

To generate `.blend`, install Blender 4+ and run:

```bash
blender --background --python Blender_Import_Save_Source.py
```

To test glTF import in Godot, create a Godot 4 project and copy the LODs plus `Godot_Import_Smoke_Test.gd` into the project root. Then run `godot --headless --path . --script res://Godot_Import_Smoke_Test.gd`.

## Important qualifications

- The 3D reference is **concept art**, not CAD; exact hidden construction, fine paint wear, machine schematics, rear room elevations and environment placements cannot be reconstructed 100% without more authority. See `Previews/AIR-09_reference_comparison.png` for a side-by-side review.
- **Blender and Godot executables were not available** in the generation environment. Their native import, lighting, runtime, animation and physics results are NOT claimed as tested. `.blend` is not included, because a real native `.blend` could not be produced here. We provide the actual GLB plus conversion script instead.
- This build focuses on architectural fidelity and actual detailed geometry, **not final-game photorealistic material matching**. 512px procedural tiles are a placeholder for PBR hero textures at 2K–4K resolution. For a final AAA material pass, paint unique dirt masks, decal atlases, trim sheets and engine-verified glass and wet-ground roughness.
- The 16 named shutter slats are keyframed upward. This is a reusable open-close visual clip, not a mechanical rolling curtain simulator. Doors do not have live collision synchronized to animation. The model has working glTF keyframes verified structurally but not tested in Godot or Blender.
- Collision waypoints were checked against static collision AABBs, **not** against a game character capsule or navmesh.
- Fuel equipment is static in-game decoration and has no interactive fuel transfer or hazard simulation.
- The optional HLOD is for distant rendering only. It is a solid silhouette proxy and not an interior mesh.

## Change summary from v1

The v1 export spent most geometry on fencing and roof screws and retained a generic single-height facade, an oddly separate office and a tank platform that covered the fuel vessels. This version changes the core building massing, reconstructs office/canopy relationships, moves tools clear of the bay, clears side and rear punched windows, exposes the fuel tanks and uses the requested overhead roof equipment/rails and pump structure.
