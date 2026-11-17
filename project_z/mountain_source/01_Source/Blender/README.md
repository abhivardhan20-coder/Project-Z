# Blender interchange

No Blender installation was available for this build, so there is no unverified `.blend` deliverable. Import the real glTF 2.0 files from `06_Meshes` and `02_Terrain/Kaldran_Mountain_Spine`. Their source coordinate units are metres, with glTF Y up. Blender's glTF importer applies its normal axis conversion.

The central editing GLB is sampled at 128 m and the near-sector GLB at 16 m. Use the accompanying Float32 sources for finer sculpting or displacement. Native Godot Terrain3D regions are editable at 2 m. Godot shaders, streaming and physics are not transported by GLB; they remain in `07_Godot`.
