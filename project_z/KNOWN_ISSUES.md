# Known issues

- Art is at development quality. Hillview has received the first Slow Roads-inspired pass for coherent roads, terrain and scenery. The outer districts still rely on procedural shells and need further art direction. City sound is synthesized.
- Navigation uses nearby streamed blocks and fallback steering. The P06 bridge and representative street crossings have route tests. Infected routing through doors and on upper floors still needs an in-game pass.
- A first-time human playthrough, the 30–45 minute target duration, and all graphics profiles require manual sign-off. The integration test advances between distant locations programmatically and uses direct damage for the final siege deaths.
- The red Carmine GT is drivable in the main city. The legacy pilot scene has its own drivable sedan. External Blender source files for the original local asset library were unavailable.
- Dedicated skyline geometry, a full street and environmental storytelling pass, occluder authoring, shared texture atlas work, and an independent production art review remain open.
- The exported development package uses raw GLBs to avoid importing the full library at startup in the editor build workflow. Initial asset creation can stall briefly. The camera and the imported P06 objects remain higher-cost than surrounding blocks.
