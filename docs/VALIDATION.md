# Release 0.4.0 validation — 28 September 2026

## Automated checks

`npm test` passes **71 tests**, with no failures or skipped tests. The final recorded run completed in approximately ten seconds on the development machine. The package and lockfile identify this release as **0.4.0**.

The suite covers:

- Interpolated rendering at 60, 90, and 144 Hz; stable walking camera height and rotation; safe camera retraction through doors; level box-floor support and triangulated-ground stability; interpolation reset after teleport or pause.
- Closed entrance panels, E interactions and collision in all four orientations, player clearance during the swing, immediate collision updates, door persistence across unload/reload, and migration of older saves with no door field.
- Continuous world-space foothill and mountain elevations, seam equality on both axes, graded rural foundations, sparse country routes, and deterministic terrain progression beyond the preserved city.
- Identical synchronous/cooperative generated geometry, instance transforms, collision and targets; yielding to the host; partial-build geometry disposal; stale-generation cancellation; and prevention of late collider commits after disposing a world.
- Shadow anchors stay aligned to whole texels in light space at all quality settings and at elevated terrain positions.
- Coordinate-addressed world generation, repeatable seeds, exploration-order independence, negative chunk coordinates, connected roads, and the starter region's shelter and lake basin.
- Generated building doors at every street orientation, walkable approaches to furniture and interactions, deterministic loot, geometry disposal, and continued validity of shared materials after a neighbouring building unloads.
- Actual Rapier movement through a generated junction and beyond the old street boundary into another district. The starter shop test enters through its physical doorway, collects pantry supplies, walks to the bed, sleeps until 07:00, and verifies that an exterior wall prevents remote bed interaction.
- Streaming from the initial region to a region 960 metres away and back. The active region remains bounded to 25 chunks; retired ground and interactions disappear; returned collider and target counts match the original region; searched supplies remain hidden; and final disposal removes the registered chunk colliders.
- Version 2 save validation, corruption handling, bounded identifiers and records, distant and underwater positions, preserved world seeds, legacy save migration without deleting the original, persistent loot, inventory limits, consumables, overnight rest, day rollover, and immediate persistence of a confirmed world reset.
- Fixed-step character movement, wall sliding, jumping, steps, crouch/headroom, stamina, valid and blocked mantles, camera sweeps, swimming buoyancy, and collision retirement that preserves the player.
- Benchmark statistics and quality presets. Legacy Phase 1 route, interaction, and save tests remain as regression coverage; the active game now uses the procedural world and exploration session.

Scene tests replace Canvas2D painting with a test surface while constructing the real generated geometry, collision proxies, Rapier world, motor, and interactions. They validate traversal and state, **not GPU output, visual quality, frame rate, or browser input routing**. TypeScript source is loaded through Node's native type stripping and a test-only TypeScript loader where browser-style module resolution is required.

For default seed 7307, the initial 25 loaded chunks contain **1,986 static colliders, 165 interaction targets, 1,085 meshes, and approximately 619,748 triangles before camera culling**. These are generated resource totals, not per-frame draw calls or VRAM measurements. The streaming test verifies collider and interaction counts return to their original values after leaving and revisiting the region.

## Production build

`npm run build` passes TypeScript checking and Vite production bundling. Production JavaScript is 2,958.53 kB (1,015.83 kB gzip), including Three.js and Rapier's bundled WASM; CSS is 32.90 kB (7.83 kB gzip). Vite reports its standard large-chunk advisory. Download splitting and asset-cache profiling remain future work.

## Browser QA

Release 0.4.0 checks used the production preview. A generated shop began with its door shut and an Open door prompt. E opened the visible panel and persisted its identifier; a restored open door closed through E from a clear approach and removed the identifier. An attempted close from the swing area was rejected with the expected clearance message. Short keyboard walks and strafes were exercised around the entrance; refresh-rate and indoor floor stability are quantified by the automated motion tests rather than subjective frame-rate observations in the throttled embedded browser.

The foothill checkpoint at approximately (700, 51, -100) rendered continuous sloping ground, vegetation, rocks, and a distant mountain backdrop on both WebGPU and forced WebGL2, with no console errors. Initial sky and rain state were corrected to match the saved clock/weather immediately. The test session used a separate localhost origin for final fixtures, and the original 127.0.0.1 playthrough was restored and preserved. The final build removed the temporary checkpoint HTML. Current visual records are `docs/afterfall-doors.png` and `docs/afterfall-mountains.png`. The hidden test tab was throttled to approximately one frame per second; its screenshots are visual evidence, not performance measurements.

The following checks were also recorded for the preceding 0.3.0 procedural-world release; the relevant simulation paths remain covered by the current automated suite:

The production preview was inspected in Codex's Chromium browser with WebGPU. Walking through the starter shop's generated doorway reached its floor. The pantry interaction added water and food to inventory and saved its searched identifier. A shelter bed advanced the night to 07:00, restored stamina, and persisted the shelter identifier and next day. The torch visibly illuminated the interior. The generated lake, shoreline, overlook, vegetation, buildings, survivor, minimap, and clock rendered correctly. The full map accepted a destination and displayed its distance in the exploration HUD. A confirmed New world with seed 42 rebuilt the scene and reset its inventory, clock, and position; the original seed was restored after testing. No renderer errors were reported during these checks.

Temporary checkpoint fixtures placed the survivor near doors, supplies, beds, and the lake for focused rendered checks. Synthetic keyboard events and DOM actions through the browser developer interface were used where embedded input coordinates were unreliable. These checks complement the physical traversal and 960-metre streaming tests; they do not constitute a manual end-to-end walk across the world.

After the final optimized build, both WebGPU and forced WebGL2 rendered the generated lake region, survivor, terrain, trees, buildings, and HUD without console errors. The optimized architecture preserved its visible world placement. The user's original save was restored byte-for-byte, the temporary `dist/qa-world.html` fixture was removed, and the browser was returned to the normal WebGPU URL. `docs/afterfall-openworld.png` records the lake view from the final WebGPU build; `docs/afterfall-interior.png` records the pantry interior checked earlier in the same release.

## Performance qualification remains open

Focused CPU measurements with Canvas2D drawing stubbed recorded cooperative generation slices with median **4.39 ms**, p95 **6.63 ms**, and maximum **9.18 ms** across six warmed chunks. Before subdivision, representative city/lake generation took approximately **57–66 ms** in one call. These measurements exclude real texture painting, GPU uploads, shader compilation, and rendering. They demonstrate smaller CPU tasks, not a guaranteed frame time. Generation targets a four-millisecond cooperative budget; individual operations and host scheduling can exceed it.

In the fixed-input motion regression, raw 60 Hz physics rendered at 90/144 Hz previously alternated between zero and roughly 58 mm movement per frame. Interpolated constant-speed frame displacement varies by less than 1e-12 m in the test. Corrected level-floor camera height varies by less than 1.4e-8 m and rotation by less than 4.3e-8 radians. These numerical checks are for controlled flat-floor fixtures, not all possible terrain or hardware.

No sustained 60 FPS at 1080p claim is established by these automated checks. Embedded-preview observations are affected by focus, throttling, viewport size, and the host GPU; they do not replace comparable standalone browser measurements.

Use the README's benchmark procedure in foreground standalone Chrome and Edge on known hardware. Record backend, internal render resolution, quality, weather, clock, world seed, location, average FPS, 1% low, GPU timing, and repeated-run variation. Separately profile chunk generation and retirement, long traversal, dense interior views, lakes, dynamic shadows, and memory over repeated travel. JavaScript heap and renderer resource counts are not VRAM measurements.

## Scope

Phase 2 is a procedural-exploration pre-alpha. It adds connected streets, streamed terrain and collision, enterable furnished ground floors, loot, beds, overnight rest, lakes and swimming, changing daylight, a torch, generated maps and waypoints, seeded world reset, and persistent exploration records.

Upper-floor traversal, destruction, mining, construction, crafting, combat, zombies, NPCs, comprehensive injury/hunger/thirst systems, and LLM integration remain unimplemented. Production art and animation, greater environmental and layout variety, accessibility/input expansion, streaming hitch budgets, broad GPU coverage, and sustained performance qualification remain outstanding. Passing the suite does not establish production readiness.
