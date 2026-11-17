# Kaldran city and mountains

Open `project.godot` or run `Play_Project_Z.cmd`. The normal city scene now includes
the shared mountain range and the supplied asset districts in one Godot project.

Start or continue a game, press Escape, then choose **Travel to Mountain Trail**.
The pause menu changes to **Return to Kaldran City** on the trail. Your player,
inventory and First Light story state are retained. Saving and continuing from
the trail is supported. Travel returns to the city position where you left.

`Review_Mountains.cmd` opens the aerial/reference review scene in this same project:
1–5 reference views, 6 walking trail, F free flight, Q/E down/up, H hide panel.

## Editing

- `scenes/Districts/`: editable supplied buildings, infrastructure and props.
- `scenes/editable_sector.tscn`: editable Terrain3D sector, elevations ASL.
- `Terrain_Regions/`: one canonical set of native and distant terrain resources.
- `assets/User/` and `assets/Baked/`: supplied optimized models and runtime meshes.
- `Data/`: height fields and reproducible placements.
- `mountain_source/`: preserved generation sources, provenance, references and QA.

The city uses height zero at 320 m ASL. Native terrain regions are translated in
memory for city gameplay; source files retain their ASL elevations. The playable
areas are the existing city and Crown Approach. The intervening regional landscape
and other asset districts remain scenery; the travel menu connects the playable areas.

## Seam fix

The old hole extended to within 6 m of the native boundary. Coarse clipmap triangles
with missing neighbours exposed sky. The fix uses a 320/384 m inset, 64 m overlap,
and a moving coverage guard. The outer height collar follows the same 64 m triangles
as the distant mesh. The trail core is unchanged. High altitude free flight retains
the complete distant surface, including the 8,002 m case.

## Rebuild and validation

Run `mountain_source/01_Source/GenerationScripts/rebuild.py --godot PATH --validate`
to rebuild outputs here. Export hand sculpted native regions before rebuilding.
The integration regression is `tests/mountain_merge.gd`; run with `-- --city-test`
to isolate saves in `.godot/city-tests`. Reports and engine captures are under
`mountain_source/09_Documentation` and `08_Reference_Validation/Merged`.
Earlier reports are historical snapshots from before consolidation.
