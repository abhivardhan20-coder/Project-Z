# HIL-01 V3 — Balanced download

This reduced-download package preserves **all 311,788 LOD0 render triangles** and the same facade/interior/door geometry as V3 high-resolution GLB. It differs **only in texture sizes**: embedded basecolor, normal and ORM PNG maps were reduced to a maximum of **1024 × 1024**, rather than the 2048px highest-resolution primary materials in the complete V3 package. No material files need external relinking.

Choose Blender **Material Preview** or **Rendered**, since Solid View can look textureless. Godot/Blender native import QA and physical collisions remain unverified. See `HIL-01_validation.md` for the model's limitations; the per-file checksums in `HIL-01_independent_QA.json` apply to the *full* original V3 model, not the balanced file. Use `HIL-01_BALANCED_QA.json` for the balanced GLB's own checksum.
