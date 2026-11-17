# Development log · 13 November 2026

| Phase | Files and scenes | Implemented and tested | Remaining work |
| --- | --- | --- | --- |
| 0 · Foundation | `project.godot`, `kaldran_city.tscn`, `player.gd` | Godot 4.7.2 launch, third-person controller, adjustable camera and controls | Rigged survivor and full stance/camera regression |
| 1 · P06 | `p06.gd`, `pilot_hillview.gd`, `tests/p06.gd` | North curb overlap fixed. Capsule verified from road through both ramps, shop, apartment and bridge | Manual upper-floor and scene-composition pass |
| 2 · City | `layout.gd`, `terrain.gd`, `streaming.gd` | One square kilometre, 100 blocks, four districts, streamed collision and near/far geometry. Tested a distant unload | Citywide pedestrian loops and landmark polish |
| 3 · Interiors | `architecture.gd`, `interaction.gd`, safehouse fixtures | Nine interiors built. Tested P06, annex and pump thresholds, doors, containers, storage and generator lighting | Door animation sweep and the other interior routes |
| 4 · Survival | `state.gd`, `infected.gd`, `survival.json` | Four recipes, survival, AI combat, structured saves, backup and reload | Sustained AI pathfinding and manual ranged-combat pass |
| 5 · First Light | `mission.gd`, `tests/city_integration.gd` | Six stages through safehouse completion with persistent flags | Full player playthrough and duration validation |
| 6 · Art and audio | `street_dressing.gd`, city shaders, `atmosphere.gd`, `audio.gd` | P06 imports, weather, directional lighting, synthesized sound, GPU capture review, additional district props | Final art, sound, character rigs, atlas and skyline |
| 7 · Performance and release | `tests/benchmark.gd`, export preset, build and packaging tools | RTX 2050 development probes and Windows export smoke check | Long-run GPU, CPU and navigation profiling and external release QA |

Next implementation task is a P06 mesh/material batching pass followed by a continuous first-time playthrough with traversal, navigation and timing recorded.
