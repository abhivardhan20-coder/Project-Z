# Performance report

Measured 2026-11-15T15:25:09 on AMD Ryzen 7 7435HS / NVIDIA GeForce RTX 2050; Godot 4.7.2-stable (official), forward_plus, 1920 × 1080.

These are short static runtime samples: 120 process-frame intervals per view/profile after a brief streaming settle. Frame time is wall time between process frames, not a GPU timestamp. The test does not disable display synchronization or control laptop power, temperature, clock speed or background activity. Results near 144 FPS may reflect the display cadence.

| View | Profile | Median ms | p95 ms | FPS from median | Reported video MiB | Draw calls | Rendered primitives |
|---|---|---:|---:|---:|---:|---:|---:|
| Airport | Development | 6.93 | 7.25 | 144.3 | 1707.3 | 1545 | 2,327,873 |
| Hillside | Development | 6.95 | 7.31 | 143.9 | 2308.3 | 2202 | 4,637,568 |
| Railway | Development | 7.56 | 7.77 | 132.3 | 1958.8 | 1169 | 1,518,032 |
| Capitol | Development | 7.29 | 8.04 | 137.2 | 1633.0 | 1904 | 2,861,870 |
| Panorama | Development | 6.93 | 7.32 | 144.2 | 815.3 | 2295 | 1,308,648 |
| Panorama | Cinematic | 8.50 | 8.82 | 117.7 | 941.4 | 2295 | 1,440,360 |
| PlayableSector | Development | 8.58 | 9.41 | 116.5 | 1225.2 | 1212 | 1,417,160 |
| PlayableSector | Cinematic | 13.68 | 15.52 | 73.1 | 1350.6 | 1515 | 2,277,786 |

The video-memory figure is Godot's allocation monitor, not the total GPU process residency reported by a driver. Rendered primitives are engine draw counters, not unique source triangles.

These measurements include the supplied asset pass. Urban views now contain real building and vehicle meshes; compare their frame times separately from the distant panorama. Streaming and resource compilation can produce stalls beyond the static medians.

## Profiles and working budgets

| Setting | Development | Cinematic |
|---|---|---|
| Distant LOD screen-error target | 4 px | 1.6 px |
| Native mesh size | 32 | 48 |
| MSAA | 2× | 4× |
| Shadow range / splits | 160 m / 2 | 300 m / 4 |
| Detailed vegetation / undergrowth range | 115 m | 180 m |
| SSAO / volumetric fog | Off | On |

Planning targets are 16.7 ms per frame for development and 33.3 ms for cinematic review at 1080p on this machine. The table above records whether each slice approaches those targets; p95 is relevant even when the median is fast. These are scene targets, not reserved costs for the complete game. Start-up, traversal stalls and worst-case visibility remain unbounded.

## Verified behavior

Runtime failure list: `[]`. During the test the streamer recorded 245 loads, 101 unloads and 170 LOD transitions. All 8 lighting presets rendered.

The full log verifies native terrain standing and ray collision, both sides of a native region boundary, a walk driven by W input, continued ground contact, near-region unload and distant-tile removal. Source QA verifies 264 byte-identical shared tile edges, finite Float32 data and GLB headers/accessors.

Still required: a long instrumented traversal, cold-cache hitch timings, peak RAM/VRAM, worst-case weather and vegetation views, collision against every prop, NPC navigation, and performance of the complete city-plus-mountains gameplay workload. Native/distant interfaces and moving LODs also need a visual camera sweep; source continuity and one boundary test do not prove every runtime seam is invisible.

Raw evidence: `Engine_QA.json`, `Source_QA.json`, `Generation_Report.json`, `engine-qa.log`, `native-build.log` and `city-integration-qa.log`.
