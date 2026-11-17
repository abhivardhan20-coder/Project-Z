# Project Z: Kaldran City | HIL-03 Apartment Entrance and Stairwell

**Deliverable:** a procedurally reconstructed, physically modeled GLB asset using the supplied architectural multiview reference. This is an editable 3D asset, **not** an image-generated model. It is **not a pixel-perfect reconstruction** and should be treated as a reference-driven prototype requiring an artist's final pass before AAA sign-off.

## Files

- `HIL-03_LOD0.glb`: 247,448 triangles, fully modeled main asset, scene-separated meshes, PBR materials, and entrance-door animation.
- `HIL-03_LOD1.glb`: 99,550 triangles, approximately 40.23% of LOD0.
- `HIL-03_LOD2.glb`: 26,516 triangles, approximately 10.72% of LOD0.
- `HIL-03_Collision.glb`: 540-triangle collision proxies in a separate scene, to be instantiated as static collision meshes in Godot.
- `HIL-03_source.py`: editable procedural source. Rebuilds GLBs, PBR texture maps, and manifest using Python.
- `HIL-03_make_blend.py`: use in a local Blender installation to import editable GLBs and save a `.blend` project; native `.blend` not created here because Blender is not installed.
- `HIL-03_Godot4_Setup.gd`: example runtime scene/physics setup. Godot functionality **not tested** in this environment.
- `HIL-03_manifest.json`, `HIL-03_test_results.json`, `HIL-03_validation.md`: provenance, meshes, evaluations and explicit testing limitations.
- `Textures/`: original procedurally generated base color, tangent-space normal and ORM maps plus signage decals.
- `Previews/`: PNG renders taken from **imported GLB geometry**, not AI image renders.
- `References/HIL-03_MultiView_Reference.png`: original provided image reference.

## Scale and axes

Building's **nominal structural shell** is 6.20 m wide by 5.60 m deep, with a 8.90 m roof high point. Fully rendered bounding boxes are larger because of protruding plants and exterior trim; see `HIL-03_manifest.json` for exact re-import scene bounds. Asset's ground datum is at Y=0. GLB/Godot uses X right, Y vertical, Z toward street/front. The source model uses X right, Y toward rear, Z vertical and applies a conversion on export. **No masterplan yaw or height offset was baked in.**

The vestibule has physically separate double glazed door leaves, rail frames, handle bars and a ~0.65-m recessed threshold. Ground-floor interior includes 25 individual mailboxes, a lift door, signs, lighting, and stairs. Two actual switchback stair flights per 3.0-m storey are present. Textures and signs are original generated materials.

## Running in Blender on your own machine

Install Blender 4.x. In a terminal from the extracted directory, run:

```bash
blender -b -P HIL-03_make_blend.py -- "/absolute/path/to/HIL-03_package"
```

It is designed to save `HIL-03_source.blend` next to the GLBs. **This conversion was not run or verified here.** The GLBs themselves are directly importable/editable by Blender's glTF importer.

## Running in Godot 4

Place all four GLBs and the `HIL-03_Godot4_Setup.gd` in a project's `res://` directory. Create a Node3D and attach the script. The script loads LOD0 and converts nonrender collision proxy meshes to static concave collision shapes. LOD1/LOD2 are intended for the game's own distance-based LOD manager, not automatic runtime switching. Trigger `play_entrance_door_cycle()` from an interactable. Verify door-swing, collision layers/masks, material transparency, navigation meshes, stair ascent, and expected scene scale **in Godot** before production use. The environment that built this package did not have Godot installed.

The door opening animation swings out toward the street by approximately 88°; reserve at least 1.1 m clear exterior space for the open leaves. The reference does not specify exact opening direction, so this choice avoids clipping into the stair volume.

## Checks

To repeat GLB checks without Blender/Godot, install `numpy trimesh pillow scipy` and run `python HIL-03_verify.py`. They validate glTF 2.0 binary buffers/material references, actual face totals, animation targets, scene vertical bounds, and independent GLB re-import. The checks are documented in `HIL-03_validation.md`. Mesh count **does not prove** that architectural fidelity is perfect.
