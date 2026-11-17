# Integration guide

Use the main city scene for gameplay or open `scenes/graphics/shader_lab.tscn` directly in Godot. Copy the shader include and the three global declarations in `project.godot` when reusing the shaders in another project.

Request shared presets through `scripts/graphics/materials.gd`. Use explicit model categories for car, survivor and infected conversion. The converter overrides selected materials and preserves the imported mesh, UVs, skeleton, textures and animations. Imported meshes without tangents retain their diffuse, metallic and roughness maps and skip incompatible tangent normal maps.

Run `python tools/asset_validation/validate_glb.py` to verify local model dependencies. Run `godot --path . --script res://tests/ultra_graphics.gd` in a graphics session for the scene, weather and preset test. Add `--rendering-method gl_compatibility` for the fallback. The same test works headlessly for state and material checks.

For Windows packaging use the existing build tool, followed by `python tools/build/package.py --ultra`. See [build instructions](../../BUILD_INSTRUCTIONS.md) for the export template.
