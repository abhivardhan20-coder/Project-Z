# Ultra Graphics QA

- The prior project was backed up before editing. Godot 4.7.2 initialized Forward+ over Vulkan on the RTX 2050 using the prior scene. That baseline emitted tangent warnings on several imported assets. The imported and standalone asset paths now share the same tangent compatibility check.
- The Ultra Graphics test exercises the eight exposed state checks, including rain accumulation and drying, sheltered rain, dry interior finishes, and changes in renderer workload. The graphics-enabled run also captures the lab and clear and rainy P06 views.
- The original UltraSurface ZIP was absent from the workspace and Downloads. The new surface shader was built from the available material and texture sources.
- See [remaining work](KNOWN_ISSUES.md) for visual and tooling limitations.
