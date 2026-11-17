# Project Z · Kaldran City · RAIL-07 Interior Refinement v02

This ZIP contains **actual 3D geometry in GLB 2.0**, independent geometry LODs, a separate mesh collision model, animation data, and an editable **parametric Python source**. It is a reference-led work-in-progress, **not** a 100% indistinguishable reproduction of the concept art.

## Files

- `RAIL-07_LOD0.glb`: 363,404 indexed visible render triangles, 316 meshes, embedded textures and named kiosk shutter animation.
- `RAIL-07_LOD1.glb`: 146,468 triangles, 40.30% of LOD0.
- `RAIL-07_LOD2.glb`: 36,876 triangles, 10.15% of LOD0.
- `RAIL-07_HLOD.glb`: 660 triangles, separate low-cost city horizon model.
- `RAIL-07_Collision.glb`: 1,236 triangles in isolated low-poly static collision surfaces. Upper-floor slab stair holes are verified.
- `RAIL-07_source.py`: complete procedural editable geometry source. Main controls are `make(lod)`, `kitchen_kiosk`, `food_service_bay`, `reference_interior_upgrade`, `stair` layout and `MATERIALS`.
- `rebuild.py`: recommended source rebuild entry point; regenerates three LODs, collision, HLOD, manifest and tests.
- `RAIL-07_make_blend.py`: script to **create** a `.blend` on a local Blender installation. No `.blend` has been generated in this environment.
- `RAIL-07_Godot4_Controller.gd`: suggested runtime LOD/collider/shutter integration, **not engine-tested**.
- `RAIL-07_manifest.json`, `RAIL-07_validation.md`: structural validation, exact bounds/triangles, limitations.
- `Textures/`: PBR materials and individually mounted food menu display textures (the GLBs include their textures).
- `Previews/`: generated diagnostic render previews, not claimed to be Godot screenshots.
- `RAIL-07_MultiView_Reference.png`: original supplied reference image.

## What's actually new in v02

Several nonselected glass-fronted shop bays are now open restaurants with service counters, coffee equipment, food showcases, refrigerators, illuminated menu boards, stainless working kitchens and red awnings. The playable food kiosk adds separate menu screens, slatted timber counter cladding, hood filters, POS, sink fixtures, equipment, display trays and additional kitchen lighting. The main arcade gains a ribbed acoustic ceiling, wall sconces, trim, and furnished retail frontages. Staircase openings were cut in the upper structural slabs and separate collision mesh; the adjacent shopfronts were removed to keep stair approaches visible.

## Blender workflow

1. Install Blender 4.x, unzip the archive and open the script folder.
2. Run `blender --background --python RAIL-07_make_blend.py` from that folder or import `RAIL-07_LOD0.glb` manually in Blender.
3. Save the Blender source. The provided command writes `RAIL-07_source.blend` locally. It has **not been executed here**, because Blender isn't installed in the authoring runtime.
4. Use source Python `rebuild.py` to regenerate procedural parts after changing dimensions/detail. Install `numpy trimesh Pillow scipy` into the authoring Python environment.

## Godot 4 workflow

1. Import GLBs into Godot using a project set to **meters, Y-up**. Building length extends along X; public frontage faces **-Z**.
2. Put the LOD GLBs, Collision GLB, and GDScript in `res://`, and set a Camera3D reference on the example controller. Validate `Node3D` transform before siting at masterplan P03/D13.
3. Build static collision from `RAIL-07_Collision.glb` **not** the dense render geometry. Check stair treads and landings, kiosk door and roof collision with the actual player capsule.
4. Inspect imported AnimationPlayer for `Kiosk_Shutter_Raise` and verify motion/collision. The GLB animation track exists, but playable physics synchronization has not been checked.
5. Configure materials in-engine and capture engine renders for asset review. The provided VTK previews are diagnostic flat-shaded captures.

## Reference dimensional discrepancy

The board specifies 72 × 18 m, 12 m roof height, two floors. Its interior section labels total about 23 m of cross-section width. These requirements conflict. This asset implements **6 m retail + 6 m circulation + 6 m retail = 18 m**. The roof follows the side elevation. Outdoor canopy/apron exceed the nominal building body, so full GLB bounds exceed 72 × 18 m.

## Outstanding constraints

- **Not a photorealistic 1:1 reference match.** Secondary areas, cinematic lighting, final materials, signage, exact trim proportions and hand-authored details still need art-direction.
- **No Godot import or real gameplay QA** because the Godot engine executable is not present. Collision stair sample checks were performed against proxy geometry only.
- **No `.blend` supplied** because Blender is not installed here. Editable GLBs and source/rebuild scripts are supplied in its place.
- Only **one food kiosk is the selected playable interior**; nearby upgraded service bays have genuine visible 3D interiors but remain efficient shells rather than fully authored walkable stores.
