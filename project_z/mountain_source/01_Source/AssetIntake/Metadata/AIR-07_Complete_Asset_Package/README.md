# AIR-07 • Airport Fire-and-Rescue Station

This is a 3D scene package, not a photomontage. The four large shutters, concrete structure, safety railing, antenna, roof service equipment, skylights, garage floor/ceiling, observation room and site-side stair are meshes. **No fire engines are included.**

## Files

- `AIR-07_LOD0.glb`, `AIR-07_LOD1.glb`, `AIR-07_LOD2.glb`: optimized geometry levels with PBR textures inside each GLB.
- `AIR-07_generator.py`: editable procedural construction source; reconstructs all render geometry and three LODs.
- `AIR-07_blender_import.py`: run with Blender 4.x to create `AIR-07_source.blend`. The `.blend` was not created here because Blender is not installed.
- `AIR-07_collision_proxies.glb` and `AIR-07_collision_boxes.json`: actual simplified static collider meshes and their physics box bounds, in a separate GLB to avoid counting hidden colliders toward the visible render budget.
- `AIR-07_Godot4_Station.gd`: Godot 4 loading/physics/animated shutter helper. Its engine behavior has **not been run-tested** here.
- `Textures/`: 17 procedural texture sets; base color, normal and packed ORM maps. GLBs have them embedded.
- `Previews/`: screenshots rendered **from the re-imported GLB**, not the reference image or generated fake facades.
- `AIR-07_manifest.json` and `AIR-07_validation.md`: triangle counts, dimensions, discrepancies, tests, and known limitations.

## Usage

**Godot 4:** Import `AIR-07_LOD0.glb` into the project and add `AIR-07_Godot4_Station.gd` to a new Node3D. Assign the imported GLB scene to `model_scene` in the Inspector, and point `collision_json_path` to the JSON file. Use `open_response_bay_1()`/`close_response_bay_1()` to operate the segmented overhead shutter. Godot test required in your own runtime. Keep LODs from being rendered simultaneously.

**Blender 4:** Open the GLB directly, or in a terminal run `blender --background --python AIR-07_blender_import.py` from the package folder to save a native editable `.blend`. Blender can import the mesh, materials, node hierarchy and glTF animation; original procedural editing is in `AIR-07_generator.py`.

**Rebuild GLBs:** `python AIR-07_generator.py` (requires numpy, trimesh and Pillow). Generate collider GLB with `python generate_collision_proxies.py`.

## Reference interpretation and limitations

- Chose **45 × 24 m** for the main building because the orthographic dimensions panel says approximately 45 m length, 24 m depth, 8.8 m height. The reference's section implies 45 m garage **plus** 24 m additional watch room, inconsistent with those dimensions.
- Main building shell reaches roughly 8.8 m excluding rooftop guardrail, equipment and antenna. The 14.4 m antenna is not part of the architectural height.
- The rear orthographic shows solid wall with windows and personnel access. To honor it, rear vehicle exit doors were **not invented**. The garage therefore supports direct access through its four *front* bays but is **not drive-through**. This is a deliberate noncompliance with one conflicting text requirement.
- Only B01 is animated; B02–B04 are fixed closed at delivery. Fire engines and city surroundings are excluded.
- PBR textures are procedural and modest-resolution preview quality, not scanned 4K photogrammetry. The GLB previews use a flat-colored inspection renderer, so they do not demonstrate the full final PBR look.
- A native `.blend`, true Blender lighting render, and running Godot physics/import validation require local Blender/Godot executables.
