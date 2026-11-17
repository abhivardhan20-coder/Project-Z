# Performance report

The Hillview visual update was benchmarked separately on the same RTX 2050 at Medium, with a 1920 × 1080 window requested and 115 samples per view. During the final run, while the Windows export was also running, the daytime P06 view averaged 42.6 FPS (32.7 ms p95, 5,872 draw calls). The sedan approach averaged 67.8 FPS (18.4 ms p95). The night view averaged 105.6 FPS (12.0 ms p95). The wider city numbers below are from the earlier build.

Measured on the development Windows laptop with AMD Ryzen 7 7435HS and NVIDIA GeForce RTX 2050 Laptop GPU, driver 617.14. Godot 4.7.2 Compatibility, Medium preset, 1920 × 1080 window requested, VSync off. These short development probes used the final source with 40 warm-up frames and 115 measured frames per location.

| Scenario | Mean FPS | p95 frame ms | p99 frame ms | Avg draws | Avg primitives | Max agents |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Hillview P06 | 58.6 | 23.24 | 27.38 | 6,391 | 459,741 | 0 |
| Civic arterial | 203.1 | 9.48 | 12.34 | 934 | 210,007 | 3 |
| Police annex interior | 218.8 | 9.01 | 10.44 | 657 | 228,514 | 4 |
| Utility edge | 211.6 | 9.22 | 10.15 | 529 | 270,070 | 4 |
| Hillview at night | 101.4 | 14.55 | 15.56 | 2,735 | 202,673 | 0 |
| Market rain | 219.6 | 8.65 | 10.64 | 586 | 256,785 | 3 |
| Infected encounter | 119.3 | 13.61 | 14.54 | 1,882 | 250,992 | 2 |
| Chunk crossing | 63.4 | 18.29 | 19.16 | 6,048 | 524,235 | 2 |

Godot reported approximately 1.5–2.7 GiB render memory, 132–155 MiB static allocator memory and roughly one to five active physics objects in these snapshots. The static allocator excludes other process RAM. GPU frame time was unavailable. The sampled CPU process counter was unsuitable for per-frame attribution, and navigation cost was not isolated. One crossing reported a 72.6 ms recent chunk construction peak. The high-detail P06 frontage produced the highest draw count.

Reproduce with `godot --path . --script res://tests/benchmark.gd` in a graphics session. The script writes raw samples under `.godot/benchmark`. Low, Medium and High presets vary render scale, view distance, shadows, particles and the infected budget. This run does not establish sustained target FPS or final release performance.
