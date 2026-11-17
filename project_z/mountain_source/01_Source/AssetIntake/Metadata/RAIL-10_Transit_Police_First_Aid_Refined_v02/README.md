# Project Z: Kaldran City | RAIL-10, Transit Police and First-Aid Office

## Revised source-model package (v02)

This is an **editable three-dimensional, reference-guided reconstruction**, not a photograph or a claim that its renders are indistinguishable from the illustrative multi-view sheet. The accompanying previews are derived from the **actual RAIL-10 GLB mesh** with a separate VTK preview renderer. The full model uses glTF Y-up / front facing -Z, and the procedural generator authors Z-up / front facing -Y.

### Improvements from v01

- Concrete structural corner masses are now properly dominant on the front, with physical panel joints, precast anchors, heavy slab-edge spandrels and deep cornices.
- The public frontage has a more substantial canopy, soffit light housings, two independent secured glazed entrances, and large blue police and red first-aid signs.
- Actual extruded 3D glyph geometry, shield emblem and first-aid cross have been added, while sign artwork remains embedded as PBR image textures.
- The visible left side includes a slatted service shutter and recessed glass vestibule; rear has its own secure door and loading shutter.
- Rooftop mechanical equipment has prominent screened maintenance housings, fans, railings, clamps and ducts rather than the earlier minimalist roof components.
- Ground-floor reception has fluted timber casework, metal trim, queuing stanchions, feature wall, actual screens, desks, and seating. Treatment has a gurney, an ECG display face, service rail, supplies, glazing, cabinetry, clinical partitions and washable surfaces.
- Distinct UV map layers, more refined bevel normals, higher-resolution embedded PBR map prototypes, and separately named hinge pivots.

### Package layout

- `RAIL-10_LOD0.glb`, `RAIL-10_LOD1.glb`, `RAIL-10_LOD2.glb`: textured editable GLB meshes.
- `RAIL-10_HLOD.glb`: distant silhouette from LOD2 without creating unrelated hidden geometry.
- `RAIL-10_COLLISION.glb`: simplified static collision boxes and stair treads. **Not a Godot capsule-navigation proof.**
- `RAIL-10_manifest.json`, `RAIL-10_validation.md`, `RAIL-10_QA_report.json`: independent geometry checks and documented limitations.
- `Source/RAIL10_build.py`: full deterministic parametric geometry including construction and PBR maps.
- `Source/RAIL10_vtk_previews.py`: actual imported GLB preview rendering with VTK.
- `Source/validate_assets.py`: inspect imported GLB assets for geometry, UVs and PBR channels.
- `Source/create_blend.py`: conversion into organized native `.blend` when Blender is installed. No native `.blend` is claimed to exist in this ZIP.
- `Godot4/`: example collision/door scripts and import instructions. Godot was unavailable for runtime import testing.
- `Previews/`: front, rear, right, roof, closeup, reception, treatment, and hero mesh images.
- `RAIL-10_MultiView_Reference.png`: the user's comparison sheet.

### Dependencies and generation

```bash
pip install numpy pillow trimesh shapely matplotlib vtk
python Source/RAIL10_build.py
python Source/validate_assets.py
python Source/RAIL10_vtk_previews.py
```

To produce a Blender file from the textured GLBs, run with Blender installed:

```bash
blender --background --python Source/create_blend.py
```

### What is not complete

- Not independently certified as 100% geometrically/pixel-wise indistinguishable from the supplied concept art; the sheet is not a dimensioned drawing. Full photorealistic look requires final materials, environment lighting and interior dressing.
- Materials are packaged PBR prototype textures (512–1024 px for materials and 2048 x 512 sign artwork), not 4K production maps.
- No Blender `.blend` save or Godot 4 navigation/door/collision gameplay test was performed here because neither executable was available.
- External stair height and station connection require site-specific masterplan validation. Exterior camera/canopy overlap and on-foot clearances still require live gameplay QA.

**Use this asset as a materially improved mesh source, not final AAA reference-parity acceptance.**
