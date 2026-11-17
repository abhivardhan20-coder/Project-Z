# Import, editing and rebuilding

## Godot project

Open `07_Godot/project.godot` with Godot **4.7.2, Windows x64, Forward+**. Terrain3D 1.1.0 is already included and enabled. The default scene is `Scenes/mountain_prototype.tscn`. The first import prepares textures and GLBs; allow it to complete before running. A Vulkan-capable GPU is required by the tested configuration.

Open `Scenes/editable_sector.tscn` to inspect the native Terrain3D node. Its nine `.res` data regions are under `Terrain_Regions/CrownApproach`. The node uses 512-sample regions and 2 m vertex spacing. The editable regions are the near sector, not the 144 background mesh tiles. Use Terrain3D sculpting for local height edits, save the regions, and preserve a copy before regenerating.

The custom material is driven by height, normal, macro masks and the season/weather parameters. It is not the plugin's default painted-material shader. Painting a native control map will not automatically add another visible material layer. The supplied fifteen texture assets are a starting library; extend `Shaders/alpine_surface.gdshaderinc` when adding additional active layers.

## Authoritative inputs

| Edit | Location |
|---|---|
| Ridge points, summit elevations, valley guides, planning regions | `01_Source/Parameters/geography.json` |
| Landform and erosion rules | `01_Source/GenerationScripts/terrain_model.py` |
| Sector detail, contour trail, vegetation placement and mesh export | `01_Source/GenerationScripts/generate.py` |
| Snow, terrain color, normals, wetness | `07_Godot/Shaders/alpine_surface.gdshaderinc` |
| Eight weather/lighting presets | `07_Godot/Lighting/presets.json` |
| Runtime LOD and streaming | `07_Godot/Scripts/streamer.gd` |
| Manually traced reference spans and camera fit | `01_Source/GenerationScripts/calibrate_cameras.py` |
| Supplied model selection / texture copies | `01_Source/GenerationScripts/import_user_assets.py` |
| Static mesh batching, up axes and alpine atlas repair | `07_Godot/Scripts/bake_user_assets.gd` |
| District layout, graded roads and undergrowth | `01_Source/GenerationScripts/place_user_assets.py` |
| Fixed district origins and street headings | `01_Source/Parameters/district_layout.json` |
| Editable district scene generation | `07_Godot/Scripts/bake_districts.gd` |

Calibrated camera positions/targets are stored in `07_Godot/Data/world.json`. A full regeneration first resets that file from the source plan, then refits its lens and orientation. If keeping a hand-edited camera, update the input plan and either adjust the fit bounds or omit the calibration step.

Height sources are **little-endian IEEE Float32**, uncompressed metres above sea level. Rows advance south (+Z), columns east (+X), and data includes shared boundary samples. JSON sidecars describe origins, spacing and dimensions. No 8-bit height PNG is used as terrain authority. PNG masks are normalized control data, not elevation.

## Rebuild

Python 3.11 and the packages in `01_Source/GenerationScripts/requirements.txt` are required. The shipped project already contains the imported resources, texture sources, sky inputs and plugin. The normal rebuild works offline.

From this package directory, in PowerShell:

```powershell
python .\01_Source\GenerationScripts\rebuild.py --godot "C:\path\to\Godot_v4.7.2-stable_win64_console.exe" --validate
```

The tested sequence is:

1. Build the island planning maps, central Float32 field, masks, tiles, sector, procedural materials and GLBs.
2. Verify the bundled photographic source checksums and repack two material pairs at 512 px.
3. Prepare native shaders, camera wrappers and source masks.
4. Verify source bounds, GLB structure, all 264 shared tile edges and trail heights.
5. Import assets and bake 432 distant meshes, nine native terrain regions and the selected user mesh library.
6. Generate district placements and trail dressing, ground the hillside camera, fit all five cameras, and save the editable district scenes.
7. With `--validate`, verify the user assets and saved instance buffers, run graphical runtime checks at a fixed 1080p render resolution, and regenerate comparisons and measured reports.

The rebuild replaces generated files, including district scenes. It will overwrite sculpted native regions, edited GLB outputs, source rasters and generated material textures. Keep intentional art edits in a separate source layer or export them before rebuilding. The earlier terrain rebuild and the added asset/placement/baking stages were exercised separately; the central height source remains unchanged by the asset pass.

The normal rebuild uses the bundled optimized GLBs, and does not need the original archives. Run `import_user_assets.py` separately only when refreshing the selected copies from the original local files. That intake step uses the original paths recorded in its source. It never executes scripts bundled in the asset archives. See `User_Asset_Integration.md` for the selected families, adaptations and exclusions.

Open any scene in `07_Godot/Scenes/Districts` to edit the placed models. Each authored object remains an individual transform with a source-asset tag. Distant city buildings are MultiMesh batches; edit their source placements or use the MultiMesh buffer in the editor. The scripted ecology uses `Data/Sector/instances.json` and `Data/Sector/undergrowth.json`.

For a source-only check, run `validate_sources.py`. For runtime-only validation, launch Godot with `--path 07_Godot --script res://Tests/validate.gd`. `-- --quick` captures the panorama and walking sector with a reduced check set; it is not the full acceptance run.

## Existing city integration

Run `integrate_city.py`, or add `--integrate-city` to the rebuild command, with the original `project_z` directory adjacent to this package. It installs the mountain background addon and three review/test files. The separate scene is `project_z/scenes/world/kaldran_mountain_review.tscn`.

The integration maps city height zero to the mountain datum of 320 m ASL, replaces the old alpine ring in that review scene, extends the camera range, and adds a visual terrain collar. The city remains at its existing approximately 1 km layout scale. Its buildings and roads are not expanded to the proposed 64 km² release scale.

The city's original default scene is unchanged. The review launcher uses the game's existing `--city-test` mechanism for isolated save data. Integration terrain outside the original city has no gameplay collision; the collar is visual. Full travel from city to mountains needs future roads, region transitions, gameplay and collision work.

## GLB and Blender

The standalone central editing mesh is `06_Meshes/Distant_Mountains/Kaldran_Spine_128m.glb`; the near editing proxy is `02_Terrain/Kaldran_Mountain_Spine/Crown_Approach_source.glb` at 16 m sampling. Three boulder GLBs and a jointed cliff GLB are also included. Import these in Blender using glTF 2.0; the importer handles the Godot/glTF Y-up to Blender Z-up conversion. World distances are metres and the capital datum remains 320 m.

Blender was not installed in the working environment, so no `.blend` file or Blender round-trip test is claimed. The high precision Float32 sources and native Godot terrain are supplied for editing at higher fidelity than the lightweight GLB proxies.
