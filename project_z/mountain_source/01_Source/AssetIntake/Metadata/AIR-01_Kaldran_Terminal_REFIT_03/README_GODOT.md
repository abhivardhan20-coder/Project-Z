# Godot 4 import guide (manual QA required)

1. Copy the entire AIR-01 folder into `res://AIR-01/`.
2. Create a new Node3D scene and attach `Godot/AIR-01_terminal_loader.gd`.
3. Run the scene and inspect the imported scene tree and default light/material setup.
4. Enable `play_door_test_on_start` to play the imported 18-channel door clip.
5. Test all four landside sliding doors and gate A1 at both endpoints; inspect hinge axes and glTF animation import.
6. Inspect generated collision proxies (do not also render the separate `AIR-01_collision.glb`).
7. Walk the intended route: central entrance, check-in, right stair, upper concourse, Gate A1.
8. Validate navmesh independently and check 3rd-person capsule clearances; bake neither a fake navmesh nor untested Godot results into this package.

The GLB geometry is glTF Y-up. JSON collider coordinates are authoring Z-up. No Godot editor or headless import was available in the build environment.
