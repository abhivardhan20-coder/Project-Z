# Supplied asset integration

Integrated **56 asset families / 79 optimized GLBs** from the two Kaldran archives and the local Godot asset project. Originals remain unchanged. The delivered copy contains 607 authored object placements, 3,115 distant buildings, 4,527 conifers, 1,290 rocks and 6,229 understory/deadwood placements (15,768 placement records in total). Streaming and distance detail select which are active.

## What was placed

| Scene | Supplied assets |
|---|---|
| Airport | Terminal, canopy, gate pier, control tower, parking garage, evacuation cabins and tents; road, cars, police, buses, ambulance, luggage and wreckage |
| Railway | Grand arch, concourse, platform canopy, signal building, bus shelter, footbridge, park-and-ride, transit police, twelve train carriages and evacuation traffic |
| Hillside | Balcony and terraced apartments, corner housing, rowhouses, shops, parking shed, playground pavilion, trees and street props |
| Capitol | Assembly hall, ministry wings, midrise blocks, boulevard trees, traffic and emergency staging |
| Crown Approach | Mature pine LODs, winter pines, alpine fir, juniper, fern, grass, lichen, four granite/moss forms, logs, stumps and roots; radio hut/tower and static cable station |

## Adaptations

- Embedded textures are limited to 512 px for most mid/far assets and 1024 px for selected close assets. Geometry, material slots and metre scale are preserved in the copied GLBs.
- Native meshes combine static parts by material/vertex format and generate mesh LODs, normals and tangents. Unused custom vertex channels are removed. Source animations remain in the GLBs; these background placements use static geometry.
- AIR08 had shared children under orphan source parents. The copied hierarchy is made a valid tree without changing visible geometry.
- HIL10, the alpine kit, radio hut/tower, and three local vehicles require an up-axis correction. Native pivots are normalized to ground centre, with the same family offset retained across LODs.
- The alpine atlas uses bottom-up V coordinates. Correcting its UVs and tangent handedness restores the foliage cutouts instead of sampling opaque stone tiles.
- The road kit is widened across the street and aligned to a graded longitudinal profile. Traffic follows that profile. Foundations bridge uneven ground beneath larger buildings; the terrain source itself is unchanged.
- Buildings have authored LOD/HLOD distance bands. Distant buildings use saved instance buffers, verified after loading. The four main districts load asynchronously, with distant landmarks present while their detailed scenes are unloaded.
- Trees and rocks stream in 64 m cells. Near trees and deadwood/rocks have collision. Understory avoids the trail and steep slopes. Terrain snow blends continuously; the provided winter tree model switches during the winter phase.

## Editable files

- `07_Godot/Scenes/Districts/`: Airport, Railway, Hillside, Capitol, Alpine and Background scenes. Building and prop nodes can be moved directly in Godot.
- `07_Godot/Data/asset_placements.json`: reproducible placement authority; `Data/Sector/undergrowth.json` holds trail dressing.
- `07_Godot/Assets/User/catalog.json`: exact original local path or archive/package/member, original and adapted SHA-256, texture changes and model statistics.
- `07_Godot/Assets/Baked/catalog.json`: native resource, combined surface counts, normalized bounds and source correspondence.
- `01_Source/AssetIntake/Excluded_Packages.json`: packages left out; `Unused_Modules.json`: evaluated facade pieces that were not needed. Other local asset families were not copied.

## Verification and limits

Source integrity failures: []. Native asset check failures: []. Runtime failures: []. The asset test checks normals, normal-map tangents, selected metre-scale/up-axis dimensions, resource links, and 8 persisted distant transforms. The full runtime test captures all five views and eight weather presets and checks standing, walking, boundary collision and terrain/district streaming.

See `Performance_Report.md` for actual 1080p static frame samples, including the four detailed urban views. They are not a complete traversal, load-time or full-game benchmark.

The distant city remains sparse, repetitive context with simplified supplied HLODs. Source-model art, street composition, weathering, terrain detail and lighting do not yet match the photographic references. Urban streets are review compositions, not a completed navigable city; the tested walking gameplay remains the mountain sector. The cable station is a static landmark, not an operating transport system.

ChatGPT Library-only models were not accessed. Computer use stopped when browser URL verification could not be completed; all integrated models come from the supplied local sources. No source generation script from an asset archive was executed.

User-provided models retain their source terms and are not reclassified as CC0. The existing third-party terrain/material/sky credits remain in `Asset_Provenance.md`.

## Family register

| Family | Variants | Original source |
|---|---|---|
| AIR01 | lod1, lod2, hlod | AIR-01_Kaldran_Terminal_REFIT_03.zip |
| AIR02 | lod2 | AIR-02_Reference_Faithful_Rebuild_v2_1.zip |
| AIR03 | lod2, hlod | AIR-03_Reference_Reconstruction_v3.zip |
| AIR04 | lod2, hlod | AIR-04_Kaldran_Control_Tower_3D_Package.zip |
| AIR08 | lod2, hlod | AIR-08_Terminal_Parking_Structure_V03.zip |
| AIR10 | lod2 | AIR-10_Refined_v2_Production.zip |
| AIR11 | lod2 | AIR-11_Production_Package.zip |
| AMBULANCE | single | Shvan92_Ambulance_Upgrade_Package.zip |
| BARRIER | local | ProjectZ_CBW26_CrashBarrierWreckage.glb |
| BENCH | local | PZ_GCR_12_Platform_Bench_Bin.glb |
| BUS | local | PROJECT_Z_City_Bus.glb |
| CABLE_STATION | local | PROJECT_Z_Mountain_Cable_Car_Station.glb |
| CIV01 | lod1, lod2, hlod | CIV-01_Kaldran_Capitol_Assembly_Hall_v02.zip |
| CIV03 | lod2 | CIV-03_v3_Full_Reconstruction.zip |
| FERN | local | FERN_02_Woodland_Fan.glb |
| FIR | local | PZ_ALP_02_Young_Alpine_Fir_2p2m.glb |
| FIR_LOW | local | PZ_ALP_LOD1_12_Alpine_Fir.glb |
| GRASS | local | PZ_ALP_07_Dry_Tussock_Grass_Silver.glb |
| HIL01 | lod0, hlod | HIL-01_V3_BALANCED.zip |
| HIL02 | lod1, lod2, hlod | HIL-02_ReferenceRefined_v2_FULL.zip |
| HIL03 | lod2 | HIL-03_Asset_Package.zip |
| HIL04 | lod1, lod2, hlod | HIL-04_Reference_Refined_v02.zip |
| HIL05 | lod2, hlod | HIL-05_Powered_Storefront_Full_Package.zip |
| HIL06 | lod2, hlod | HIL-06_v4_Full_Asset_Package.zip |
| HIL07 | lod2 | HIL-07_Refined_Complete_Package.zip |
| HIL09 | lod2, hlod | HIL-09_Full_Asset_Package.zip |
| HIL10 | lod2, hlod | HIL-10_Full_Production_Package.zip |
| JUNIPER | local | PZ_ALP_05_Low_Juniper_Shrub.glb |
| LICHEN | local | PZ_ALP_08_Crust_Lichen_GroundPatch.glb |
| LOG | local | PZ_FallenWood_01_FallenPine_Log_3p6m.glb |
| MIDRISE | local | PZ_Midrise_SIX_FLOOR_Assembly_Reference.glb |
| OAK | local | PROJECT_Z_Temperate_Oak_Tree_LOD2.glb |
| PINE0 | local | ProjectZ_PINE10_Conifer_Summer_LOD0.glb |
| PINE1 | local | ProjectZ_PINE10_Conifer_Summer_LOD1.glb |
| POLICE | local | PROJECT_Z_Police_Patrol_Sedan.glb |
| RADIO_HUT | local | PZ_RAD_03_Accessible_Maintenance_Hut.glb |
| RADIO_TOWER | local | PZ_RAD_01_Telecom_Lattice_Tower_29m.glb |
| RAIL01 | lod1, lod2, hlod | RAIL-01_v02_REFINED_FULL_PACKAGE.zip |
| RAIL02 | lod2, hlod | RAIL-02_V3_Fixed_Escalators_and_Interior.zip |
| RAIL03 | lod2, hlod | RAIL-03_Kaldran_Full_Asset_Package.zip |
| RAIL04 | lod2 | RAIL-04_Refined_Doors_and_Facade_v5.zip |
| RAIL06 | lod2, hlod | RAIL-06_ReferenceRefined_v2_Godot4.zip |
| RAIL08 | lod2, hlod | RAIL-08_Refined_v04_FULL.zip |
| RAIL09 | lod2 | RAIL-09_Kaldran_Park_and_Ride_Garage_v02_Connected_Ramps.zip |
| RAIL10 | lod2, hlod | RAIL-10_Transit_Police_First_Aid_Refined_v02.zip |
| ROAD | local | PROJECT_Z_Road_Straight_Asphalt_10m.glb |
| ROCK1 | local | PZ_R02_Angular_Fieldstone_Granite.glb |
| ROCK2 | local | PZ_R06_Layered_Shale_Boulder_Granite.glb |
| ROCK3 | local | PZ_R07_Fractured_Outcrop_Granite.glb |
| ROCK4 | local | PZ_R08_Massive_Moss_Boulder_Moss.glb |
| ROOTS | local | PZ_FallenWood_08_ExposedRootSnarl_1p8m.glb |
| SEDAN | local | PROJECT_Z_Unbranded_2026_Sedan_CloseUp.glb |
| STUMP | local | PZ_FallenWood_06_Splintered_RottenStump_1p1m.glb |
| SUITCASE | local | KAL-01_v03_Suitcase_Open_Hero.glb |
| TRAIN | local | PROJECT_Z_Metro_Train_Carriage.glb |
| WINTER_PINE | local | ProjectZ_PINE10_Conifer_Winter_LOD1.glb |
