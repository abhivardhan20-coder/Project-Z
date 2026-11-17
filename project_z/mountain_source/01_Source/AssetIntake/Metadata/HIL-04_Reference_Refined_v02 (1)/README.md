# HIL-04 | Reference-refined corner mixed-use residential-over-retail

**Project Z: Kaldran City / asset HIL-04.** The package contains real editable 3D meshes generated and exported as GLBs with embedded PBR texture sets. It is an upgraded reconstruction of the previously delivered HIL-04 package, not an image substitution.

## Building and scope

Reference-authoritative approximately **24 × 18 m core footprint**, six architectural levels (~22m roof edge) with five residential storeys above a corner shop and separate residential lobby. Geometry is authored as Z-up meters and converted at the GLB root to glTF Y-up. The roof-access enclosure and mechanical equipment rise to approximately 23.1m; eaves, plants, balcony projections and awnings extend past the footprint. No unverified map/site rotation is applied.

The primary geometry comprises an angled retail corner with separate shop/lobby entry openings, shop glazing and security shutter, five continuous curved-corner residential balconies, smaller wing/courtyard balconies, AC condensers, parapet/roof equipment, planter pots and hanging vines, facade stone courses, PBR plaster/metal/glass finishes, and an enterable shop and lobby zone. Upper apartments are structural shells by design.

## Files

- `HIL-04_LOD0.glb`, `HIL-04_LOD1.glb`, `HIL-04_LOD2.glb`: render-ready exported detailed geometry with embedded textures, UV coordinates, and independent shop/lobby door animation tracks.
- `HIL-04_HLOD.glb`: extremely low-cost distant silhouette.
- `Collision/HIL-04_collision.glb`: separately imported lightweight colliders for the chamfered ground footprint, storefront perimeter with two openings, lobby separation, stairs, upper floors, balcony floors and balustrades. Keep hidden when rendering and configure Godot physics shapes separately.
- `Textures/`: reusable material color, normal and ORM (occlusion/roughness/metallic) texture maps. Resolution varies between 128 and 1024 px; these are procedural and must be replaced/retouched for truly photoreal hero shots.
- `References/`: exact original HIL-04 reference image.
- `Previews/`: reference, imported GLB screenshots, comparison sheet and interior previews.
- `Scripts/build_hil04.py`: full reproducible parametric geometry source; **changes to this script will rebuild all LOD meshes**.
- `Scripts/create_native_blend.py`: run with Blender to import and save the GLB as editable native `.blend`.
- `Scripts/verify_release.py`: run for independent release checks, and review `HIL-04_release_checks.json`, `HIL-04_manifest.json` and `HIL-04_validation.md`.

## Import and export guidance

Import `HIL-04_LOD0.glb` in Godot 4 or Blender. Keep the shared asset root rather than splitting scene meshes indiscriminately. Use `Shop_Door_Pivot` and `Lobby_Door_Pivot` as separate animation targets and replace static collider placeholders for doors with engine-native moving collision objects. Both have an embedded `_Open_Close` track. Preserve door gap clearance before adding physics. Do not render or count the separate collision GLB as visible geometry.

**Native Blender source:** The Blender executable was not available in the build environment. In Blender-equipped shell:

```bash
blender -b --python Scripts/create_native_blend.py
```

This command is intended to create `HIL-04_source.blend` by importing GLB. It has not been run or validated here and a native `.blend` is **not** bundled.

**Actual Godot test:** There is no Godot installation here. GLB parsing, UV consistency, triangle totals and a VTK glTF import were tested. Godot physics, visual materials, collision layers and animation playback still require in-editor validation. The reference board is concept art with multiple artistic views rather than measured CAD, so **100% image correspondence cannot be honestly claimed**.
