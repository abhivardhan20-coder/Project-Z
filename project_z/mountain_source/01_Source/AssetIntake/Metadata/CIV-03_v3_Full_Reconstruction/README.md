# CIV-03 | Government Ministry Office Wing | v3

**Deliverable:** genuine, independently editable 3D mesh geometry, three glTF 2.0 GLB LODs and full Python procedural geometry source, for Blender/Godot 4 import. The building is a best-effort **reconstruction** from a concept illustration, not an identical digital twin. Source reference `CIV-03_MultiView_Reference.png` is bundled unchanged.

## Actual validation results

| Mesh | Exported and reimported render triangles | Relative detail | Mesh batches |
|---|---:|---:|---:|
| `CIV-03_v3_LOD0.glb` | 421,932 | 100% | 188 |
| `CIV-03_v3_LOD1.glb` | 179,684 | 42.59% | 156 |
| `CIV-03_v3_LOD2.glb` | 55,220 | 13.09% | 123 |

Measured v3 LOD0 bounds (trimesh GLB scene re-import): **X width 60.06 m, Y height 37.93 m, Z depth 36.82 m**. The reference annotation is approximate 60 × 36 × 38 m. Coordinates **X right / +Y up / -Z front**, ground approximately Y=0.

The v3 independent verification passed: genuine GLB 2.0 binary structure, readback geometry, UVs on all render meshes, normal+metallic roughness PBR map bindings, the two named entrance-door hinge nodes, finite vertices, no nearly-zero-area triangles (1e-10 threshold), and correct LOD percentage gates. Validation is reproducible with `python CIV-03_Validate_v3.py`.

**Untested/not provided:** running Blender and saving a native `.blend` scene (Blender unavailable), Godot 4 engine import and collision walk test (Godot unavailable), actual LOD switching in Godot, animation/physics fit playtest, and an independently verified 100% visual correspondence score. `CREATE_BLEND_example.py` is a script to create a Blender file after installation, **not** the `.blend` itself.

## Architecture built from the reference sheet

* Six recessed glazed office-window bays on both sides of a central three-bay, finned Art Deco risalit; individual exterior stone jambs, transoms, pressure plates, decorative stones, and sill details.
* Front limestone colonnade with 14 dressed, fluted columns and a clear central 4.56m nominal double-leaf swinging entrance. Burgundy civic banners, bronze brackets and stone entrance reveals.
* Limestone pilasters, carved cornice profiles, actual ashlar blocks on solid stone, parapets, stepped corner roof pavilions, inset framed roof skylight, standing seams and rooftop ventilation equipment.
* Rear and side office windows and masonry; an actual selected main public lobby with tiled marble floor, carpet, coffered ceiling, chandeliers, public security turnstiles, reception desk, a rear portal, and U-shaped multi-storey stairs. Other floors are lightweight office shells.
* PBR metal/roughness materials with embedded baseColor, normal and ORM maps. Basecolor stone textures were revised from the previous almost-white maps to restrained warm gray-limestone albedo and darker glass. The separately editable `Textures/` folder contains 512px and 1024px procedural maps, **not 4K photographs**.

## Important known mismatches

The image is a **stylized reference board**, not a set of survey measurements. In particular the front elevation panel illustrates proportions under nonuniform display scaling compared to the stated 60m × 38m dimensions. This model preserves physical metre proportions. It is much more architecturally complete than the earlier v2 but **does not** visually match the reference photograph or orthographic perfectly. Unresolved differences include: exact exterior stone carvings, cap and coping shapes, richer window illumination/reflections, lobby furniture/finishes, side roof setbacks, and professional scene lighting. Nothing in these GLBs should be presented as a photogrammetric recreation.

The v3 front/roof/lobby previews are renders from the actual exported geometry (VTK glTF import) with basic studio lights. They lack the real reference's wet-road scene, mountains, entourage and cinematic global illumination. These backgrounds are intentionally **not** baked into the 3D asset.

## Folder overview

- `CIV-03_v3_LOD0.glb`, `CIV-03_v3_LOD1.glb`, `CIV-03_v3_LOD2.glb`: packaged importable real 3D meshes.
- `CIV-03_Build_v3.py`: complete procedural 3D authoring source; `Base_Build.py`: geometry and texture/export utilities.
- `Make_Materials_v3.py`: procedural appearance source for signature limestone and glazing textures.
- `Textures/`: stand-alone PBR textures (also embedded in GLBs).
- `CREATE_BLEND_example.py`: **must** be run using Blender 4.x to generate `CIV-03_v3_source.blend` on your machine; not tested here.
- `Godot/CIV-03_Godot_Scene.tscn`, `Godot/CIV-03_Godot_Controller.gd`: intended Godot 4 scene, opening-door animation and economical collision-proxy generation. **Needs actual in-engine testing**.
- `CIV-03_v3_QA_readback.json`, `CIV-03_v3_validation.md`, `CIV-03_v3_manifest.json`, `CIV-03_Validate_v3.py`: exported data and checks.
- `Previews/` studio geometry screenshots, reference comparison and overview image.

## Blender and Godot

Blender (4.x) direct import: File → Import → glTF 2.0 → `CIV-03_v3_LOD0.glb`. Imported meshes are editable. Import each LOD separately to avoid rendering all three at once. Run `blender --background --python CREATE_BLEND_example.py` in the unpacked folder to assemble three named LOD collections and save a native source `.blend` using your Blender installation. The resulting `.blend` file is not currently in this package.

Godot (4.x): copy the content of this folder so the GLB path is `res://CIV-03_v3_LOD0.glb`; open `res://Godot/CIV-03_Godot_Scene.tscn`. It loads the GLB and runs an untested proxy collision/door script. **Before deploying:** verify GLB node hierarchy, test door swing, staircase step-up, 0.56m capsule clearances and material alpha ordering in a real Godot project. The script is source for integration, not evidence that those gameplay tests passed.

## Rebuild and reproducibility

`python -m pip install numpy scipy pillow trimesh` (in a separate Python environment); `python CIV-03_Build_v3.py`, followed by `python CIV-03_Validate_v3.py`. In a fresh folder run `python Make_Materials_v3.py` after the initial `Textures/` have been generated if you want to restyle the limestone/glass textures. `Render_v3.py` requires a working Python VTK environment and offscreen OpenGL.

The resulting GLBs have many separate material/category batches to preserve editability, and their LOD0 batch count should be considered an optimization target for actual Godot rendering. The v3 structure is not a closed/manifold solid across all materials: windows, separate dressings, interior glass, and doors are independent building components, as intended for game scene architecture.
