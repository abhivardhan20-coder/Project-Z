# Render pipeline

Forward+ runs the primary Windows build. The Compatibility renderer shares the material code, surface weather and depth fog. Projected decals, screen-space reflections and volumetric fog require renderer support. This project gates those features to Forward+.

| Preset | Forward+ scale | GPU rain budget | Lighting and detail |
| --- | --- | --- | --- |
| Low | 65% | 75 | Daylight shadows off, base material detail |
| Medium | 80% | 230 | 48 m sunlight shadows, close normal maps |
| High | 100% | 390 | 120 m sunlight shadows, micro normals, SSAO, 24-step SSR, short volumetric fog, restrained bloom |

Color comes from the sky, ambient lighting and a filmic tone mapper. The city uses incremental sky reflection updates. The original regional light fixtures and gameplay-controlled safehouse power still drive the interior lighting.
