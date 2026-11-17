# Ultra Graphics performance

Godot 4.7.2 Forward+ over Vulkan on an NVIDIA GeForce RTX 2050. The test requested 1280 × 720 and disabled VSync. These are 45 consecutive frame intervals for a static P06 camera during rain, after a 16-frame warm-up at each preset. The export and gameplay verification were running on the same machine during this sample.

| Preset | Median | 95th percentile | Godot graphics memory estimate |
| --- | --- | --- | --- |
| Low | 9.83 ms | 14.26 ms | 2,989 MiB |
| Medium | 56.16 ms | 63.33 ms | 2,996 MiB |
| High | 80.30 ms | 85.99 ms | 3,048 MiB |

Low is the fresh-install default. Existing users can keep their saved preference or switch in Settings. These samples cover one view and do not establish sustained frame-rate or VRAM headroom across the entire map.
