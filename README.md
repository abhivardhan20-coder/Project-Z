# AFTERFALL

Phase 2 adds a streamed procedural world to the third-person survivor foundation: connected streets, enterable buildings, gardens, lakes, scavenging, and places to spend the night in a fictional Indian metropolis inspired by Hyderabad. This remains a pre-alpha game. The original product brief and future milestones are preserved in [docs/PRODUCT_REQUIREMENTS.md](docs/PRODUCT_REQUIREMENTS.md).

The survivor uses a Rapier capsule controller with collision, steps, jumping, checked ledge climbing, crouching, stamina, swimming, and a collision-aware follow camera. The world includes furnished interiors, abandoned vehicles, instanced vegetation, wet road surfaces, changing daylight, rain and fog, a torch, shadows, bloom, generated ambience and footsteps, and renderer diagnostics. Three.js 0.180 uses WebGPU first, with a WebGL2 fallback. Scene geometry, props, textures, and audio are generated locally. Optional Google Fonts have system-font fallbacks; scene assets require no remote downloads.

## Procedural world

A world seed and integer chunk coordinates determine each 96 × 96 metre district. Returning to a district recreates the same geography regardless of the order in which it was explored. The original central city retains connected streets, residential blocks, parks, and lakes. Beyond its outskirts, continuous world-space terrain rises into woodland, foothills, and mountain ridges, with sparse rest houses and walking trails. Ground geometry and collision use the same height samples. Distant terrain extends the mountain skyline beyond the active collision window.

The streamer maintains a 5 × 5 active chunk window around the survivor. As you move, it generates nearby chunks and releases distant meshes and colliders. Loot and discovery records are stored separately, so unloading and revisiting a building does not replenish a searched container. Shared landscape textures and materials are reused across chunks.

Selected shops, homes, apartments, clinics, and warehouses have accessible, furnished ground-floor interiors. Every accessible entrance begins with a closed door. Press E to open or close it; the visible panel and collision move together, and the door remembers its state across travel and reloads. Stand clear of the panel's swing before moving it. Some interiors contain beds. Other buildings have fixed shutters and remain scenery; upper floors, destruction, construction, mining, and crafting are not implemented. Save validation currently bounds horizontal coordinates to ±1,000,000 world units and limits discovery, loot, and door record lists to 10,000 entries each.

## Run

Use **Node.js 22.18 or newer** and npm; Node.js 24 LTS is recommended. The test suite imports TypeScript source using native type stripping and a test-only loader for browser-style module resolution. In the project directory:

```sh
npm install
npm run dev
```

Open the local URL printed by Vite in desktop Chrome or Edge with hardware acceleration enabled. WebGPU needs a secure context; localhost is supported. To explicitly test WebGL2, append `?renderer=webgl` to that URL.

```sh
npm run build
npm run preview
npm test
```

`build` performs TypeScript checks and writes the production bundle to `dist/`. `preview` serves that bundle. `npm test` covers deterministic generation, terrain continuity, versioned saves and migration, persistent loot, sleep and inventory rules, character physics, camera collision, generated-scene traversal, benchmark calculations, and quality settings. Scene tests stub canvas painting while exercising real geometry, collision proxies, Rapier movement, and interactions; they do not validate GPU output or visual quality.

## Play

Select **Enter the district**, or **Continue journey** when a valid local save exists.

| Control | Action |
| --- | --- |
| W / A / S / D, or arrow keys | Move |
| Shift, held | Sprint while stamina permits |
| C | Toggle crouch; standing requires clear headroom |
| Space | Jump, or climb a reachable ledge with a clear landing |
| Left mouse drag | Orbit the follow camera |
| Mouse wheel | Adjust camera distance |
| Left Alt | Toggle slow walking |
| E | Use the nearby interaction shown on screen |
| I | Open or close the pack |
| M | Open or close the world map; scroll to zoom, click to set a waypoint |
| F | Toggle the torch |
| H | Show or hide movement controls |
| Esc | Close an open dialog, or return to the title menu |

Movement is relative to the camera. Sprinting drains stamina; slowing down restores it. Entering deep lake water switches to swimming with the same movement controls. Open the pack to use drinking water or preserved food to recover stamina; supplies are not consumed when stamina is already full. Field dressings can be carried, but injury treatment is not implemented. Dialogs pause gameplay.

Follow any connected street and use the map to locate open buildings, shelters, and lakes. The HUD suggests nearby supplies during the day and shelter at night. Approach an accessible container and press **E** when its interaction appears. Collected contents stay in your pack, and searched containers remain empty after travel or reload. A map waypoint overrides the suggested destination until you reach it or select another.

The day clock advances one game minute per second of active simulation, making a full day 24 minutes. Open a shelter door with **E**, walk inside, and close it behind you. Find a bed and press **E** to sleep. After the short rest transition, the clock advances to the next 07:00, stamina is restored, and progress is saved. Use the torch to explore after dark.

**System** changes quality, weather, time of day, sound, and diagnostic visibility. **New world** in System opens a confirmation and seed field before replacing your exploration save. Seeds range from 0 to 4,294,967,295; using the same seed recreates the same geography with fresh progress. The default seed is 7307. The title menu also retains the automatic inspection-camera benchmark.

## Local saves

Progress saves approximately every eight seconds of active play, after successful interactions, when opening a dialog or returning to the title, and when the page is hidden or left. Saves contain the world seed, position, camera direction, stance, stamina, inventory, searched containers, open doors, discoveries, day and time, and last shelter. Grounded and swimming positions can be saved; an interrupted jump or climb restores the last stable saved position. Existing saves without door records load with doors closed. An older saved position buried under newly generated countryside is lifted onto the terrain while preserving horizontal position and supplies.

Saves use versioned browser `localStorage` under `afterfall.world.v2`. Loading validates the version, seed, coordinate bounds, numeric values, item limits, identifiers, and record counts. Malformed or unsupported saves start a fresh world. When no v2 save exists, a valid Phase 1 `afterfall.journey.v1` save migrates its water, field dressings, and stamina into the new world's starting position. The original v1 save remains intact; its old route and position do not apply to the generated world. When browser storage is unavailable, play continues and the HUD reports **Saving unavailable**.

This is a single local save per browser profile and site origin; it does not synchronize across devices. Different ports, hostnames, or profiles have separate saves, and clearing site data removes them.

## Benchmark at 1080p

1. Run the production preview. Use a 1920 × 1080 browser content viewport, 100% browser zoom, and consistent OS scaling. Record the device pixel ratio: quality presets change internal render resolution, so a 1080p viewport alone does not guarantee a 1080p render buffer.
2. Record GPU, browser version, viewport, display refresh rate, world seed, location, quality, weather, lighting, and the **actual backend displayed in the footer**. Enable diagnostics before starting.
3. Close other GPU-heavy applications. Keep the browser visible and focused, with dialogs closed. Select **Run benchmark**; it excludes a two-second warm-up and measures a fixed 30-second camera route.
4. Record average FPS, 1% low FPS, average frame time, and sampled frames. The 1% low is calculated from the mean of the slowest 1% of frame durations. Repeat with identical settings; test the forced WebGL2 URL separately.

Changing settings, resizing, or hiding the tab cancels the run. Results reflect the current device and may be limited by display synchronization. Diagnostics include per-frame draw calls and triangles across rendering passes. GPU timing reads hardware timestamps when available and shows **Unavailable** otherwise. **JS heap is JavaScript memory, not VRAM**; it also shows unavailable when the browser does not expose it. Geometry and texture counts are resource counts, not GPU memory measurements.

The inspection benchmark measures its loaded camera route. Test sustained gameplay, chunk-boundary traversal, repeated loading and unloading, dense interiors, and lakes separately. Earlier embedded-browser observations varied widely with browser throttling and do not establish sustained 60 FPS at 1080p. Standalone Chrome/Edge measurements on known hardware remain necessary; see [docs/VALIDATION.md](docs/VALIDATION.md) for recorded validation and its limits.

## Source layout

| File | Responsibility |
| --- | --- |
| `src/main.ts` | Renderer startup, fallback, post-processing, orchestration, benchmark loop |
| `src/world/layout.mjs` | Coordinate-addressed district plans, biomes, seeds, lake shapes, and terrain heights |
| `src/world/streamer.ts` | Active chunk window, generation queue, retirement, targets, and persistent loot visibility |
| `src/world/chunk.ts` | Roads, terrain geometry and colliders, lakes, vegetation, vehicles, and street dressing |
| `src/world/chunk-materials.ts` | Shared landscape surfaces, water ripples, and wetness |
| `src/world/horizon.ts` | Coarse distant foothills and mountains, with coverage around the loaded terrain window |
| `src/world/building.ts` | Exterior and interior architecture, furnishing, loot, beds, and collision proxies |
| `src/world/types.ts` | Shared procedural plans, generated visuals, and interaction targets |
| `src/world/atmosphere.ts` | Sky, changing daylight, lighting, rain, fog, and surface wetness |
| `src/world/collision.ts` | Rapier world, streamed colliders, static proxies, and camera queries |
| `src/player/motor.ts` | Fixed-step capsule movement, stamina, crouching, jumping, ledge climbing, and swimming |
| `src/player/input.ts` | Keyboard, drag-camera, zoom, and sampled interaction input |
| `src/player/follow-camera.ts` | Smoothed third-person camera with obstacle sweeps |
| `src/player/character.ts` | Procedural survivor and movement animation |
| `src/game/exploration.ts` | Nearby interactions, discovery, persistent loot, inventory, day clock, sleep, and saving |
| `src/game/world-save.mjs` | Version 2 validation, browser storage, and legacy save migration |
| `src/engine/camera.ts` | Cinematic title and benchmark camera routes |
| `src/engine/audio.ts` | Generated environmental ambience, footsteps, and interaction cues |
| `src/engine/statistics.mjs` | Frame summaries and quality presets |
| `src/ui/interface.ts`, `src/style.css` | Survivor HUD, inventory, controls, dialogs, diagnostics, and presentation |
| `src/ui/world-map.ts`, `src/ui/world-map.css` | Generated minimap, full map, and waypoint selection |
| `tests/` | Generation, saves, exploration, movement, streaming, and benchmark checks |

The authored Phase 1 street, props, journey, reflection, rules, and save modules remain in the repository for legacy validation and save migration. The active game uses the procedural streamer and exploration session.

## Remaining work

The premium open-world visual target remains an art and engineering target. Production art and character animation, greater layout variety, richer environmental damage, more interior content, accessibility and input expansion, and further lighting refinement remain future work. GPU compatibility, sustained 1080p performance, streaming hitch budgets, and hardware coverage are not certified, and no frame-rate guarantee is made. Passing the automated suite does not certify production readiness.

Combat, zombies, NPC simulation, comprehensive injury/hunger/thirst systems, construction, crafting, destructible terrain, and LLM integration are not implemented. These remain later phases of the product brief; the current release focuses on procedural exploration, scavenging, and overnight shelter.
