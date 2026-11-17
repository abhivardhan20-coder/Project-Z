# RAIL-09 | Kaldran City Park-and-Ride Garage

## What is included

- **RAIL-09_LOD0.glb**: editable triangulated real 3D mesh with embedded PBR textures.
- **RAIL-09_LOD1.glb**, **RAIL-09_LOD2.glb**: lower-detail assets with the same exterior layout and functional openings.
- **RAIL-09_COLLISION.glb**: independent, low-detail collision proxy geometry (import as collision-only, not as visible duplicate walls).
- **RAIL-09_generate.py**: complete procedural source geometry in meters; use it for Blender conversion, dimensions, component changes and regeneration.
- **RAIL-09_blender_import_save.py**: run inside Blender 4.x to produce `RAIL-09_source.blend`, preserving GLB geometry, transforms, material assets and UVs.
- **RAIL-09_Godot_interactions.gd**: example Godot 4 barrier-gate and pedestrian-door controller with named pivots; **not tested in Godot**.
- **Textures/**: sRGB base-color PNGs, neutral normal maps and linear ORM maps (512px modules) plus sign-decal textures.
- **Previews/**: images rendered from the re-imported LOD0 GLB, not images substituted for geometry.
- **References/**: exact user-supplied multi-view reference, preserved for source comparison.
- **RAIL-09_manifest.json** and **RAIL-09_validation.md**: quantitative assembly checks and limitations.
- **RAIL-09_ramp_calculations.md** / **.json** and **RAIL-09_ramp_qa.py**: endpoint, ramp-slope, headroom, vehicle-road, column and collision normal checks.
- **Previews/08_verified_ramp_route_math.png**: corrected drivable route schematic generated using the actual road equations.

## Assembly and orientation

- glTF 2.0, **Y up, meters**, front arrivals on **-Z**. Full design footprint nominally 84 m × 40 m and height to stair tower cap 18.6 m. Root transform is at the site planning ground datum, with slab underside approximately 0.25 m below Y=0.
- The **glass stair/elevator tower is on the left** of the arrival elevation. The **stacked vehicle-access semicircular ramp is on the right** of the arrival elevation.
- Enclosed parking decks at Y = 0.0, 4.1, 8.2, 12.3 m. Open roof parking at Y = 16.4 m; roof parapets and glazed stair cap extend above. Garage + roof counts differ from the ambiguous deck numbering in the reference.
- **CORRECTED v02 ROAD GEOMETRY:** Four external, concentric vertical 180° ramps of radius 14m, each 4.5m wide, all rising in the same projected direction. Their centreline arc length is 43.98m, with a **4m flattened approach and departure grade transition**, average grade ~9.3%, maximum centreline grade ~10.31% and maximum inner-edge grade ~12.3%. **Each intermediate deck contains a real flat 180° return route** connecting arrival and next departure across the main slab. Calculated minimum vertical separation of the two road slabs is **3.846m**. The narrowest conservative column setback from indoor driving surface is **0.806m**. The exterior ramp support columns have been relocated to keep the lanes physically open. The selected playable deck is **P2, Y=4.1 m**, with unobstructed central vehicle aisle, markings, ceiling, light fixtures, guardrails, parking stops and nearby stair access.
- Railings, steel grids, columns, glazing, painted parking markings, drains, barriers, hardware and stairs are actual geometric mesh. No photograph is mapped as a facade.
- Named moving nodes are `HINGE_Doors_Moving_PedestrianLeaf__glass_dark`, `HINGE_Doors_Moving_BarrierBoom__white`, and `HINGE_Doors_Moving_BarrierReflectors__red`. The gate boom and reflectors have the same pivot transform and should rotate in parallel. **There is no GLB animation track**; Godot script is provided instead.

## Notes about reference matching

This is a significant **procedural geometric reconstruction**, not a hand-sculpted photogrammetric copy. The four open bays, left glazed stair core, right U-turn access ramp, entrance canopy, signage, parking bays and visible engineering assemblies follow the board. Exact reference photographic likeness, finish fidelity, and every minute architectural detail are **not verified**. The board itself conflicts about length (front 84 m / side 56 m) and levels (1.9 m deck vs 2.6 m clearance). Architectural dimensions 84 × 40 × 18.6 m and functional clearance take priority.

## Using Blender

Open Blender, `File > Import > glTF 2.0`, select `RAIL-09_LOD0.glb`. Alternatively run:

```bash
blender -b --factory-startup --python RAIL-09_blender_import_save.py
```

This creates `RAIL-09_source.blend` next to the exports. The original build environment **did not have Blender installed**, so there is intentionally **no fabricated `.blend` file** in the ZIP. The source mesh can be edited via imported geometry; procedural changes can be made in `RAIL-09_generate.py`.

## Using Godot 4

1. Copy `RAIL-09_LOD0.glb` into your Godot project and open the imported scene. Import `RAIL-09_COLLISION.glb` as a separate sibling collision scene.
2. Set the visible LOD and collision nodes at matching origins, identity rotation, identity scale. Keep the collision geometry invisible and convert to static bodies using the included GDScript's `setup_collision()` or Godot import collision configurations.
3. Attach `RAIL-09_Godot_interactions.gd` to their common parent. Call `set_entry_barrier_open(true)` or `set_pedestrian_door_open(true)` from gameplay signals. Call with `false` to close.
4. Test actual player navigation, collision and moving-leaf clearances in Godot, especially the newly continuous ramp-to-deck landings, 180-degree internal returns, vehicle swept path and door threshold. These runtime checks could not be performed here.
5. Swap the provided LOD scenes using the project's distance system. Avoid drawing more than one LOD at once.

## Limitations

- Automated **GLB re-import and triangle counts** have been run; **Blender scene save and Godot 4 runtime import/gameplay were not available**.
- The reference board is partly schematic; geometry cannot be certified as indistinguishable from a perspective rendering.
- **512px reusable module textures**, not the requested 2K/4K asset set; the two typography decals are higher resolution.
- There is **no HLOD impostor**, native GLB animation clip, or baked lighting; LOD2 is the distant geometry stand-in.
- The delivery contains a procedural `.py` source plus a Blender conversion script, not an already-saved native `.blend`.

## v02 ramp repair verification

The road system in v01 was visually disconnected. An initial attempt using laterally offset alternating ramps failed clearance tests (1.14m between overlapping rising road sections). It has been **rejected and replaced** by same-direction stacked ascents, connected via **flat internal U-shaped returns**. Corrected throat meshes and collision surfaces, no blocking right-side facade panels or roof rail at the roof entry, safer relocated columns, and solid deck-top alignment are included. GLB serialization/re-import, top-road normals, collision-face normals, numerical grade limits and structural pier setbacks were checked. This is **not** a swept-vehicle collision test or successful Godot 4 import. See `RAIL-09_ramp_calculations.md`.
