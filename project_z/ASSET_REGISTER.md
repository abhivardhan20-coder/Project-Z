# Asset register

| Group | Source or generator | Usage |
| --- | --- | --- |
| Hillview apartment, storefront and curbs | Local Project Z modular and midrise GLBs | P06 hero facade, paving, stair detailing, room surfaces |
| PZ-188 | Local animated infected GLB | One validated skin and six idle, movement, attack, impact and death clips |
| PZ-196 and PZ-141 | Local sedan GLBs | Original pilot driving model and neighborhood prop. The city uses a shared, material-batched PZ-196 mesh for parked cars. |
| Street furniture and clutter | Local lamp, bench, jacket, bicycle, suitcase, shelf, bed and table GLBs | P06 and original scenes |
| Additional district props | Local oak LOD2, bus shelter, ambulance and transformer yard GLBs | Instanced vegetation and Civic/Utility landmarks |
| District buildings, interior kits, terrain and paving | Runtime GDScript and spatial shaders | Shared procedural materials and collision, far building representations |
| Survivor | Local PZ-156 Urban character | Textured civilian with procedural limb animation and the standard movement capsule |
| Road and terrain surfaces | CC0 Poly Haven Asphalt Track, Leafy Grass and Aerial Grass Rock | 1K diffuse maps for asphalt, verge and the surrounding hills |
| Street props | CC0 Poly Haven Fire Hydrant and Concrete Road Barrier 02 | Hillview curbside hydrants and Old Market relief barriers |
| Safehouse and district furniture | 11 CC0 Poly Haven GLBs in `assets/interiors` | Interactive cabinet, workbench, generator, water barrel, radio, day bed and lidded crates. Fluorescent fixtures, toolbox, shelves and plastic crates furnish the safehouse and district interiors. |
| Interior materials | CC0 Poly Haven White Plaster 02 and Tiled Floor 001 | Safehouse walls, ceiling and tiles |
| Sound | Runtime synthesis | Wind, rain, footsteps, pickup, doors, infected, impacts and infrastructure cues |

`python tools/asset_validation/validate_glb.py` checks the 98 source GLBs for valid GLB 2.0 containers, scene roots, geometry, external dependency paths and the infected skin and clips. It also checks direct GLB references in scripts. Inspection of all asset bounds, authoring pivots, mesh LOD levels and collision coverage remains pending.
