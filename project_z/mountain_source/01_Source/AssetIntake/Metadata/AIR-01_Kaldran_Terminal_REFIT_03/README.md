# PROJECT Z / AIR-01 REFIT 03 / International Airport Terminal

This package contains editable, actual 3D GLB geometry derived from the user-supplied reference board.

**Contents:**
- AIR-01_LOD0.glb, AIR-01_LOD1.glb, AIR-01_LOD2.glb, AIR-01_HLOD.glb
- AIR-01_collision.glb, Collision/AIR-01_colliders.json
- Textures (base, normal, ORM + wayfinding), source Python scripts, Blender `.blend` importer bootstrap, Godot scene integration starter, manifest, validation and mesh QA images.

**Use:** Import LOD0 in Blender/Godot as GLB. In Blender run `AIR-01_make_blend.py` to save as a `.blend`. This helper needs Blender installed. Animations target named door nodes and are in glTF clip metadata. Godot runtime and physics testing remain necessary.

**Rebuild:** Python + numpy, scipy, trimesh and Pillow: run `python build_air01_v3.py`, then `python finish_v3.py` to build validation/collisions/HLOD. `render_vtk.py` uses optional VTK to render QA previews from a reimported GLB.

**Caution:** The reference image is a concept composite with approximate dimensions. Geometry resembles it substantially more than Refits 01/02, but 100% appearance has not been validated. Preview lighting is intentionally neutral for geometric assessment.
