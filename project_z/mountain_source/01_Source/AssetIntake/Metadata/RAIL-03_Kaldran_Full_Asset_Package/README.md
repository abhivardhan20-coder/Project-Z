# RAIL-03: Passenger platform and trackside canopy

This is a **real 3D mesh asset**, not a render-only reconstruction or a concept image. It is made for the fictional Kaldran City rail station in Project Z, using the user's supplied RAIL-03 multi-view board. The package contains LOD0, LOD1, LOD2, HLOD, static collision proxies, six rebased 30m modular GLBs, PBR material maps, deterministic procedural mesh source and seven actual mesh preview renders.

## Primary deliverables

| File | Content |
| --- | --- |
| `RAIL-03_LOD0.glb` | Full mesh, 390,224 tris, 196 meshes |
| `RAIL-03_LOD1.glb` | Mid-distance, 176,040 tris |
| `RAIL-03_LOD2.glb` | Reduced, 46,540 tris |
| `RAIL-03_HLOD.glb` | Distant silhouette, 4,656 tris |
| `RAIL-03_Collision.glb` | Separate non-rendering collision proxy geometry |
| `Modules/RAIL-03_30m_Module_00..05.glb` | Six locally rebased 30m sections |
| `Textures/` | Standalone generated PBR BaseColor, NormalGL and ORM maps; maps also embedded in GLB |
| `Source/build_RAIL03.py` | Rebuild and edit original geometry parametrically |
| `Source/make_blend_in_Blender.py` | Import meshes and save native `RAIL-03_source.blend` on a computer with Blender |
| `Source/RAIL03_Godot4_Loader.gd` | Example Godot4 LOD loader and collision setup, untested in engine |
| `RAIL-03_manifest.json` | Exact dimensions, triangle budgets and build caveats |
| `RAIL-03_validation.md` | Quality assurance and comparison to source board |
| `QA/` | Original board copy, JSON verification & hashes |
| `Previews/` | Seven real-geometry offscreen views and a contact sheet |

**Not supplied:** a pre-generated `.blend` file, Godot engine-import screenshot, certified accessibility and railway safety checks. Neither Blender nor Godot could be run in the available environment, so these are explicitly marked as unverified rather than claimed completed.

See `Source/Import_Guide.md` for Blender and Godot steps. Use actual `.glb` geometry to inspect, edit, materialize and place the asset. The top-level package has no city surroundings or unrelated dressing.
