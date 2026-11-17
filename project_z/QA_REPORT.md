# QA report

Godot 4.7.2 stable was executed on Windows. Run the tests in [Build instructions](BUILD_INSTRUCTIONS.md).

| Check | Result and coverage |
| --- | --- |
| Normal startup and movement | Reproduced and fixed the empty title panel. The startup regression clicks New Game through the viewport, sends the physical W key at the default spawn, opens Pause with Escape and clicks Resume. It passed headlessly and with the RTX 2050 renderer. |
| Furnished safehouse | Verified the starter case can be searched from spawn, opens after looting, and restores its lid state. Checked all six modeled interaction fixtures, the storage panel, the clear lobby aisle, the fluorescent lights and the radio indicator. |
| P06 traversal | 36 checks passed in the Windows resource pack. The standard capsule crossed both curb transitions, reached the shop and apartment through the door openings, passed four bridge checkpoints, stepped up a regular curb without jumping, and turned north and south at all three P06 junctions. Three sedans passed orientation and ground clearance checks. |
| World generation | 100 distinct 100 m blocks with the expected bounds. The final seed generates 120 ordinary parcels, nine landmark shells and nine interiors. Tested movement on P06, pumping-station and police-annex approaches. Verified unloading beyond the retention band. |
| Survival and mission | 43 integration assertions passed, including equipment, all four recipes, storage, nonduplicating loot, infrastructure, mission stage gates, infected damage, death recovery and completion. The test uses programmatic travel between distant sites and direct damage to finish the siege. |
| Persistence | Verified door and generator state, mid-mission checkpoint, defeated-actor persistence, mission completion, corrupted-primary recovery and fresh-game reset. |
| Assets | 98 GLB source containers passed the supplied asset validator. Godot constructed and rendered the safehouse furniture and primary hero assets. |
| Release | The official Windows x86-64 template exported a standalone executable and pack. The executable initialized First Light and rendered with OpenGL 3.3 on the RTX 2050. The restricted test environment did not allow the shader cache in the standard Windows profile. |
| Packaging | Both ZIPs passed CRC checks. Separate extractions of the Windows ZIP and source ZIP both initialized the city in headless smoke tests. |
| Visual review | Inspected GPU captures of daytime P06, Civic and Old Market in rain. The hero street reads more clearly than the outer districts. Character art and several buildings remain development assets. |

Manual checks still required before production approval include all enterable interiors and lofts, a walkable full-city loop, camera/door edge cases, long-running navigation and cross-tile pursuit, a first-time human mission playthrough, and a multi-session check of all quality settings.
