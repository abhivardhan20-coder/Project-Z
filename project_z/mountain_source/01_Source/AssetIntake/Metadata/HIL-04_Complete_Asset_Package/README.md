# HIL-04 | Corner mixed-use residential-over-retail

**Project Z: Kaldran City, asset 16/81.** This package contains **real 3D mesh assets**, not generated render substitutes. Geometry reconstructs a single 24 × 18 m chamfered building, five residential levels over retail and an independently accessible apartment lobby.

## Import

- Import `HIL-04_LOD0.glb` into Blender or Godot 4. GLB world-root transform converts the generator's Z-up geometry to glTF Y-up correctly.
- Use `HIL-04_LOD1.glb` and `HIL-04_LOD2.glb` for reduced-detail assets and `Collision/HIL-04_collision.glb` for simplified collision shapes. **Do not automatically render the collision proxies.**
- UVs and PBR base color/normal/ORM textures are embedded inside GLBs. Reusable copies reside in `Textures/`.
- The two separate door pivots `Shop_Door_Pivot` and `Lobby_Door_Pivot` are in the `Doors_Moving` group. Each has an embedded `*_Open_Close` glTF animation track. Bind these in your gameplay script to interactions; assign door collision on a separate moving body if needed.
- An accessible ground-level grocery storefront and residential lobby are modeled; upper residences are lightweight shells, not enterable apartment interiors.

## Native Blender source

This runtime has **no Blender binary**, so it cannot generate or prove a native `.blend`. The package contains `Scripts/create_native_blend.py`, a small import/save script. Run in a system with Blender installed:

```sh
blender -b --python Scripts/create_native_blend.py
```

This will create `HIL-04_source.blend` from the editable LOD0 geometry. A native `.blend` is **not included** until that command is run.

## Scope and validation

- See `HIL-04_manifest.json` and `HIL-04_validation.md` for triangle counts, bounds, GLB reimport results, and limitations.
- Preview images are **screenshots of imported 3D geometry** captured with VTK, not the input reference or generated facade pictures.
- The reference board is an artistic multi-view sheet rather than measured CAD. This is an approximation aligned to its major forms, not a 100% geometric match. Minor details, panel counts and layouts must still pass visual art review.
- A Godot 4 editor and physics world are not available in this runtime. Engine import, walk-through navigation and collision/door-swing behavior have **not** been verified in Godot.
