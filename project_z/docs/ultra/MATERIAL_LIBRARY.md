# Material library

`scripts/graphics/materials.gd` creates and caches presets. The gallery displays Asphalt, Exposed concrete, Brick, Interior plaster, Interior tile, Interior wood, Painted steel, Automotive paint, exterior glass and standing water.

Base color is sRGB. Normal maps use OpenGL +Y. ORM is linear RGB with occlusion in R, roughness in G and metallic in B. A missing ORM map uses neutral occlusion and leaves roughness and metallic under the preset controls. Projection scales are in metres per repeat. Close normals fade by distance. The High profile uses the optional second normal sample.

The runtime preserves original source files. Existing diffuse and normal maps are read through normal Godot import when available and through embedded asset bytes in the Windows export. Road marks and oil stains use deterministic procedural masks. `scripts/graphics/decals.gd` is the editable generator for those 96 px RGBA masks.

Use `python tools/asset_validation/pack_orm.py --ao ao.png --roughness rough.png --metallic metal.png --output packed.png` with Pillow installed to create a lossless packed texture. Assign it to the material's `orm` parameter and enable `has_orm`. Omitting occlusion or metallic supplies white and black respectively.
