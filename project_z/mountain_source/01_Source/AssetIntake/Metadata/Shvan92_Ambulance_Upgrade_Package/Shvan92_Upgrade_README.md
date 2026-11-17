# Shvan '92 Ambulance: functional doors and medical interior

## Contents
- `Shvan92_Ambulance_Functional_Doors_Medical_Upgrade.glb`: edited game asset, preserving the original 14 images, 8 authored materials, scene alignment, exterior, wheels, steering, hood, trim and light bar.
- `Shvan92_Door_Controller.gd`: optional Godot 4 controller for smooth interactive opening and closing of the six panels. No custom plugin required.
- `Shvan92_Validation_Report.json`: machine-readable validation including geometry and animation pose results.
- `upgrade_ambulance.py`, `validate_ambulance.py`: source scripts to reproduce and inspect the upgrade (require Python, numpy, trimesh, scipy).

## Added moving doors
Six named nodes, rigged using original surfaces and UVs, open at the original seams:

| Part | Node | Fully open |
|---|---|---|
| Driver front door | `PZ_Cab_Driver_Hinge` | 80° outward |
| Passenger front door | `PZ_Cab_Passenger_Hinge` | 80° outward |
| Left rear door | `PZ_Rear_Left_Hinge` | 115° outward |
| Right rear door | `PZ_Rear_Right_Hinge` | 115° outward |
| Left side cargo door | `PZ_Cargo_Driver_Slider` | 0.22 m outward, 1.16 m rearward |
| Right side cargo door | `PZ_Cargo_Passenger_Slider` | 0.22 m outward, 1.16 m rearward |

The original body, glass and inner trim faces are extracted and parented under the relevant hinge/slider. The original surfaces have **not** been duplicated over the doorway. In the fully closed pose the exterior geometry remains unchanged.

## GLB animation names
`PZ_All_Doors_Open`, `PZ_All_Doors_Close`, `PZ_Rear_Doors_Open`, `PZ_Rear_Doors_Close`, `PZ_Cab_Doors_Open`, `PZ_Cab_Doors_Close`, `PZ_Cargo_Doors_Open`, `PZ_Cargo_Doors_Close`, and `PZ_Doors_Inspection_Demo`.

Each opening/closing clip runs 1.25 seconds and supports generic glTF animation viewers. The demo opens, holds, closes. Only one door-control method (embedded animation player or game script) should drive a door at any time.

## New ambulance compartment objects
- Medical stretcher with blue mattress, sheet, pillow, safety straps, guard rails, underframe, wheeled casters, towing handle and floor locking tracks.
- High-level equipment cabinet with doors, latches, bins and small supply drawers.
- ECG/vital-sign monitor with screen, trace, buttons and wall arm.
- Oxygen cylinder with valves, regulator, two brackets and connectors.
- IV pole, hooks, two hanging fluid bags and short tubes.
- Emergency bag, wall AED kit, marked medical crosses, extinguisher and first-aid supplies.
- Cabin ceiling LED fixture *meshes* and extra safety bars. No functional electrical/siren system has been added.

The medical props are textured with new compact PBR materials whose styling is consistent with the source model's relatively low-polygon character. They do not replace the original interior mesh.

## Godot 4 integration
1. Import the upgraded `.glb` into your Godot project. Select it and preview the named clips in the animation editor.
2. Create a `Node3D` wrapper and instantiate the imported ambulance scene as a child.
3. Attach `Shvan92_Door_Controller.gd` to the wrapper. This script searches for the six imported GLB door nodes by exact names.
4. Call `toggle_group("Rear")`, `toggle_group("Cab")`, `toggle_group("Cargo")`, or `toggle_group("All")` from your interaction system. For one door, call `set_door_open("Rear_Left", true)` or `false`.
5. Keep an imported `AnimationPlayer` from concurrently controlling the same door nodes. Connect in-game physics colliders separately if you need collision-aware door interactions. The GLB provides animated geometry, not automatic input handlers or physics constraints.

## Validation
Passed automated checks:
- GLB structure and accessor data are readable and finite.
- All original buffer bytes, texture images and original PBR material definitions are preserved.
- Exactly **25,943 original visible triangles** are retained in their original positions when doors are closed (maximum measured triangle-centroid displacement below `1e-14 m`).
- Six real moving door assemblies include original painted body, inside trim and front door glazing as applicable.
- Nine GLB animation clips contain monotonically increasing timestamps, quaternion-safe rotations and exact original rest transforms.
- Full-open geometry movement was independently transformed and checked numerically for all six doors.
- The added equipment fits inside the original vehicle bounds, which remain unchanged.

**Testing scope:** These checks validate geometry, playback keyframe data and sample poses in Python/glTF. A live test in your specific Godot project and character-collision setup was not possible in this environment. Door physics, collision avoidance against a game character and AI/pathfinding must be tested inside the game engine after import. It would be inaccurate to declare those untested engine systems perfect.

## Model credit and license
Original model: **Shvan '92 Ambulance - Low Poly model**, by **Daniel Zhabotinsky**, published at https://sketchfab.com/3d-models/shvan-92-ambulance-low-poly-model-2856dd3c61f940909dced9a5c0379484. Creative Commons Attribution 4.0 (CC BY 4.0): https://creativecommons.org/licenses/by/4.0/. This is a modification of the original model; attribution to the original artist remains required.
