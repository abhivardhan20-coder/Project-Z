# Terrain design and generation plan

The central Spine is the first implementation region. Its long northern skyline is shared by the airport, residential, rail, civic and panoramic views. The capital occupies a lower basin at a nominal 320 m above sea level. World axes are +X east, -Z north and +Y up; one unit is one metre.

## Directed landforms

`01_Source/Parameters/geography.json` defines summit constraints, connected ridge chains, valley guide polylines, future region bounds and camera estimates. The principal central summit is constrained to 3,415 m, below the atlas's 3,742 m Frostfall maximum. Ridge widths and asymmetric cross-sections produce broad shoulders and steeper opposing faces. Small continuous domain warps and bounded fractures modify these structures; a seed does not determine the main geography.

The Crown and Eastreach guides cut U-shaped troughs; Mercy uses a V-shaped cross-section. Four sheltered cirque bowls interrupt the high slopes. These are geometric approximations for art direction. Arêtes, moraine systems and tributary networks need further manual refinement before geological acceptance.

The 32 m central source undergoes 18 thermal transport iterations and a D8 contributing-area incision pass. Each interior thermal transfer deposits its removed material downhill; borders are pinned. This bounded erosion pass is not a time-calibrated hydraulic or glacial simulation. Summit heights are smoothly restored after erosion. The exported flow mask represents the final downhill receiver graph, with unresolved closed depressions counted in `Generation_Report.json`.

## Working resolutions

| Layer | Source / extent | Runtime role |
|---|---|---|
| Island plan | 200 m; 94 × 108 km envelope | Region and biome planning only |
| Central source | 32 m; 1,537² Float32 samples | Authoritative skyline heightfield |
| Background tiles | 4,096 m tiles; 64/128/256 m mesh spacing | Screen-error-selected mesh LODs |
| Crown Approach | 2 m; 1,537² source samples | Native clipmap terrain and collision |
| Walking core | 1,024 × 1,024 m | Initial playable environment |
| Native collar | Total 3,072 × 3,072 m | Transition and collision buffer |

The near source adds restrained fracture detail to the central field, feathered over the outer 96 m. A 1,040 m contour is surveyed on the existing slope to form a narrow footpath. The final source QA reports the maximum earthwork and path deviation. The route follows elevation rather than imposing a deep switchback trench. The core is about 1.049 km², not exactly one square kilometre.

## Surface and ecology

The shared native/distant shader blends forest ground, meadow, rock and snow using world-space sampling. Rock projection is triplanar. Local color and normal detail fades with distance, while broad color variation remains. Two photographic CC0 material sets are packed into 512 px runtime maps; thirteen other material entries are procedural prototypes. All fifteen entries are supplied as native texture assets, but the custom surface shader does not expose fifteen independently painted landscape layers.

Snow retention combines elevation, slope, north aspect, curvature shelter, wind-facing exposure, macro variation and a continuously changing seasonal snow line. Wetness affects color and roughness. This is a plausible shader framework, not thermodynamic snow depth, deformable snow, a glacier model or meltwater simulation. Surface snow is not displaced geometry.

Trees use elevation and slope suitability with clustered density variation; rocks avoid the trail. The supplied vegetation masks also include moisture/biome context, but placement does not fully simulate soil, moisture and exposure. The asset pass replaces enlarged saplings and distant cones with supplied 10 m conifers, using their authored LODs plus generated mesh LODs. Supplied firs, juniper, ferns, grass, lichen, deadwood and granite dress the trail. Undergrowth excludes a 3.2 m corridor and steep slopes; deadwood has additional clearance.

## Runtime construction

Terrain3D 1.1.0 supplies editable native regions, clipmap LOD and dynamic near collision. Background meshes are separate threaded resources. Their LOD is selected from measured source-to-LOD height error projected into screen pixels, with hysteresis and a 0.45 second geometric transition. Shared source edges agree exactly; skirts cover T-junctions. That construction reduces cracks but does not prove all camera trajectories are free of artifacts.

Trees and rocks stream in 64 m cells within 1,550 m of the camera. Detailed-tree and understory ranges are 115 m and 180 m for development and cinematic modes. Rocks remain visible to 450 m; lower-detail conifers extend beyond. Near terrain enters at approximately 3.5 km and unloads beyond 4.8 km when the player is not walking. Distant terrain resources cover the northern visible region out to approximately 59 km.

The walker has a 1.8 m capsule, 46° floor limit, 0.5 m snap, 3.4 m/s walking and 7.2 m/s sprinting. Collision exists on native terrain, nearby rock bodies, trunks and the cliff asset. Far skyline meshes have no walking collision. Walking is constrained to the native collar; use flight to inspect the rest. NPC navigation is not baked: a future navigation bake must filter steep ground, cliffs and prop obstacles rather than treating all native terrain as walkable.

## Next production passes

1. Sculpt the exposed central rock faces and branching buttresses against the clay cameras; strengthen glacial landforms without moving the range independently per view.
2. Resolve closed drainage cells into lakes or drainage channels, then build visible river beds, banks and water surfaces.
3. Refine the supplied vegetation, dress scree and moraine deposits, and add material variation at human scale.
4. Refine the supplied district compositions, improve distant city density and infrastructure, and grade their interfaces with the basin.
5. Refine clouds, snow deposition and weather transitions, followed by long traversal profiling and visual LOD review.
6. Expand the 64 km² release region before implementing the other island regions at gameplay resolution.
