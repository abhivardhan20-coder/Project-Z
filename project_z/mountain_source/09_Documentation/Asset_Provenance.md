# Asset provenance

The central terrain, parameters, masks, generated rocks, scene assembly and prototype surface code were created for this task. No proprietary game terrain or assets were extracted. The supplied reference artwork is retained under `01_Source/References` for this user's project review; its rights are not relicensed by this package.

| Component | Source and terms | Use |
|---|---|---|
| Terrain3D 1.1.0 | [Official release](https://github.com/TokisanGames/Terrain3D/releases/tag/v1.1.0-stable), MIT | Windows x64 extension and editor plugin; bundled notice in `07_Godot/addons/terrain_3d/LICENSE.txt` |
| Native terrain shader base | Terrain3D `extras/shaders/minimum.gdshader`, same MIT license | Extended with the shared Project Z surface include |
| Rock Face 03 | [Poly Haven](https://polyhaven.com/a/rock_face_03), [CC0](https://polyhaven.com/license) | Diffuse, OpenGL normal, roughness; 1K originals and 512 px packed runtime maps |
| Rocky Terrain | [Poly Haven](https://polyhaven.com/a/rocky_terrain), CC0 | Diffuse, OpenGL normal, roughness; ground texture set |
| Pine Sapling Small | [Poly Haven](https://polyhaven.com/a/pine_sapling_small), CC0 | Retained earlier source; replaced in runtime by the user's mature conifers |
| Grass Medium 01 | [Poly Haven](https://polyhaven.com/a/grass_medium_01), CC0 | Bundled source for future ground dressing |
| Shrub 01 | [Poly Haven](https://polyhaven.com/a/shrub_01), CC0 | Bundled source for future ground dressing |
| Qwantani Dusk 2 Pure Sky | [Poly Haven](https://polyhaven.com/a/qwantani_dusk_2_puresky), CC0; Greg Zaal and Jarod Guest | Photographic sky input copied from the existing project |
| Kloofendal Overcast Pure Sky | [Poly Haven](https://polyhaven.com/a/kloofendal_overcast_puresky), CC0; Greg Zaal | Photographic sky input copied from the existing project |
| Sky/weather template code | Existing local Project Z project | Adapted for the standalone mountain scene; original project terms apply |
| Remaining thirteen texture pairs | Generated for this prototype | Procedural material studies, not photogrammetry |
| Existing city foreground | Existing `project_z` assets | Used only in the optional integration scene; see that project's `LICENSES.md` |
| Supplied Kaldran models | User-provided Godot assets and Kaldran Part 1 / Part 2 archives; original source terms retained | 56 families / 79 optimized GLBs; see [integration and exact source register](User_Asset_Integration.md). These models are not reclassified as CC0. |

`04_Materials/Photogrammetry/sources.json` contains exact download URLs and verified source MD5 hashes. `Asset_Hashes.json` records SHA-256 hashes for bundled third-party media and native binaries. CC0 permits reuse; no attribution requirement is implied, but source credits are retained for provenance.

`fetch_surfaces.py --offline` repacks the bundled source images without network access. Its default network mode can re-fetch the same named materials. `fetch_terrain3d.py` is the optional original Windows-only acquisition script; normal builds use the already bundled plugin. Other operating systems need the corresponding official Terrain3D binaries and separate validation.
