# AIR-03 V3 | Reference-guided gate pier reconstruction

**Master GLB:** `AIR-03_v3_LOD0.glb`. The GLB is real Y-up geometry with grouped editable meshes and PBR materials, not an image or an environment matte painting.

## Deliverables

- `AIR-03_v3_LOD0.glb`: 407,846 render triangles
- `AIR-03_v3_LOD1.glb`: 199,230 render triangles
- `AIR-03_v3_LOD2.glb`: 71,542 render triangles
- `AIR-03_v3_HLOD.glb`: 1,598 render triangles
- `AIR-03_v3_Godot.tscn`: 84 simplified collision proxies plus GLB reference
- `AIR-03_source_generator.py`, `reference_reconstruction_v3.py`, `signature.py`, `jetbridges.py`, `glb_animations.py`, `AIR_03_helpers.py`: complete parametric editable mesh source
- `AIR-03_import_to_Blender.py`: imports GLB to Blender and saves source .blend **on a machine with Blender 4.x**
- `Textures/`: tiled PBR sets and true G1–G4 and departure-info screen textures; textures also embedded in GLB
- `Previews/`, contact sheet and reference comparison: **derived from exported GLB geometry**, not Godot or Blender renders
- `AIR-03_v3_manifest.json`, `AIR-03_v3_validation_data.json`, `AIR-03_v3_validation.md`

## Rebuild

```bash
python AIR-03_source_generator.py
python AIR-03_HLOD_generator.py
python AIR-03_Godot_collision_builder.py
python AIR-03_validate.py
```

## Intended coordinates

X axis spans the 160 m pier, Z airside is negative, Y is vertical. Ground apron is Y=0 m, the boarding deck is Y=3.5 m and the upper concourse is Y=11 m. The nominal curved roof crowns near Y=18.5 m. Gate centers are X=-60, -20, +20 and +60 m.

The **actual exported bounds** are 162.06m X, 18.685m Y and 53.30m Z because of physical fascia extensions and jetbridges. Do not mistakenly interpret this as a 53m-wide terminal.

## Reconstruction changes relative to V2

Curved transparent end gables fill the arch up to roof structure; ground-level service frontage has masonry, openings, shutters and metal door frames; long elevations have stronger dark mullions and structural steel fins; roof skylight perimeters, actual supporting purlins and warm underside fixtures are in geometry; G2 lower gate has furnished counters, seating, wooden slats and flight info fixtures. Signs have the correct outward-facing UV orientation. Four real jetbridge connection structures remain open inside.

## Limitations / development status

**Do not call this a guaranteed 100% reconstruction.** The reference art is not fully measurable CAD and its hero perspective, orthos and section do not provide every missing depth and detail. The 3D geometry is more reference-guided than V2, but not photometrically identical. The sunset mountains, aircraft and apron vehicles are environmental context not included in this building asset. Embedded texture maps are procedural 768px: original stated 2K/4K requirement remains incomplete.

No Blender executable was present to actually save a .blend source and no Godot binary was present to run a real import or collision traversal. Runtime performance, door animation playback, navigation and true Godot glass rendering are **not verified**. Collisions are basic physics proxy geometry, not a built navigation mesh. All provided previews use an offline VTK visualization of the exported GLB geometry.
