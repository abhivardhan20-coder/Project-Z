# Shader reference

| Shader | Where it runs | Behavior |
| --- | --- | --- |
| `surface.gdshader` | Bridge, pavement, interior floors, pump housing, car paint, lab | World-aligned or model UVs, base color, optional normal and ORM maps, RNM micro normals, and wetness |
| `facade.gdshader` | City buildings | Masonry and plaster textures, seam-free world projection, siding, wet streak variation |
| `city_ground.gdshader` | City terrain, roads, foothills | Road masks and markings, slope color blending, distance detail, rain darkening and procedural puddles |
| `foliage.gdshader` | Streamed vegetation with supported leaf materials | Cutout alpha, camera-distance wind falloff and wet leaves |
| `glass.gdshader` | Civic, market and utility interior front windows | Grazing reflection and rain streaks |
| `water.gdshader` | Hillview drainage channel and lab | Fresnel tint, crossing waves and rain normal ripples |
| `sky.gdshader` | City and lab | Day/night gradient, sun and cloud layers |

The shared include defines the weather uniforms, noise, view-space derivative normals and reoriented normal blending. The derivative basis allows mapped surfaces to use existing geometry without baking tangents into new mesh assets.
