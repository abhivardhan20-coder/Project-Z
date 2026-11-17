extends RefCounted

const GEO := preload("res://scripts/city/geometry.gd")
const PLAN := preload("res://scripts/city/layout.gd")
const MODELS := preload("res://scripts/neighborhood/neighborhood_assets.gd")
const FURNITURE := preload("res://scripts/city/interior_assets.gd")
const FINISH := preload("res://scripts/graphics/materials.gd")
const REFERENCE := preload("res://scripts/city/reference_models.gd")
const BARRIER := "res://assets/city/concrete_road_barrier_02.glb"
const OAK := "res://assets/props/nature/pz_127_temperate_broadleaf_tree/PROJECT_Z_Temperate_Oak_Tree_LOD1.glb"
const SUITCASE := "res://assets/pilot/hillview/KAL-01_v03_Suitcase_Open_Hero.glb"
const AMBULANCE := "res://assets/vehicles/road/pz_145_ambulance/PZ_Greyhaven_EMS_Ambulance_07.glb"
const OPEN_SEDAN := "res://assets/pilot/PZ-196_PZ141_Driving_Sedan_v01.glb"
const BENCH := "res://assets/props/interiors_and_street_props/pz_122_street_bench_and_trash_can/PZ_StreetBench.glb"
const HILLVIEW_PROPS := "res://assets/pilot/hillview/"


static func hillview(parent: Node3D, layout: PLAN, models: MODELS) -> void:
	var site := Node3D.new()
	site.name = "HillviewEvacuationPoint"
	parent.add_child(site)
	for row: Array in [[-307.4, -7.75, 0.12, 1.22], [-285.0, -8.25, -1.2, 0.87], [-274.0, 7.4, 0.94, 0.86]]:
		var at := _site(layout, row[0], row[1])
		var tree := _prop(site, models, OAK, at, row[2])
		tree.scale = Vector3.ONE * float(row[3])
		GEO.box(tree, Vector3(0, 1.0, 0), Vector3(0.55, 2.0, 0.55), null, true)
	for x: float in [-284.6, -280.5, -277.85]:
		var at := _site(layout, x, -7.55)
		_prop(site, models, BARRIER, at, 0.07 + sin(x) * 0.13)
		GEO.box(site, at + Vector3.UP * 0.34, Vector3(1.55, 0.68, 0.46), null, true)
	for row: Array in [[-304.8, -7.7, 0.8], [-300.0, -7.85, 1.0], [-285.5, -8.9, 1.15], [-281.8, -11.8, 1.1], [-272.6, 7.2, 0.88]]:
		var plant := _prop(site, models, "res://assets/vegetation/flowering_shrub.glb", _site(layout, row[0], row[1]), float(row[0]))
		plant.scale = Vector3.ONE * float(row[2])
	var ambulance_at := _site(layout, -280.3, -9.65)
	var ambulance := _prop(site, models, AMBULANCE, ambulance_at, 0.0)
	ambulance.rotation.x = -PI / 2.0
	for door: String in ["LEFT", "RIGHT"]:
		var hinge := ambulance.find_child("PIVOT_REAR_DOOR_HINGE_" + door, true, false) as Node3D
		if hinge:
			hinge.rotate_object_local(Vector3.BACK, deg_to_rad(83.0 if door == "LEFT" else -72.0))
	GEO.box(site, ambulance_at + Vector3.UP * 1.05, Vector3(6.3, 2.1, 2.1), null, true)
	REFERENCE.place(site, "stretcher", _site(layout, -276.4, -8.75), -0.2, Vector3.ZERO, true)
	var bend := _site(layout, -274.6, 5.55, 0.18)
	open_sedan(site, models, bend, PI / 2.0, false)
	var bench := _site(layout, -277.8, 7.18)
	_prop(site, models, BENCH, bench, PI)
	for i in 4:
		var bottle := bench + Vector3((i - 1.5) * 0.15, 0.04, -0.58 + sin(i) * 0.14)
		REFERENCE.place(site, "water_bottle", bottle, float(i))
	for i in 6:
		REFERENCE.place(site, "litter", _site(layout, -280.0 - i * 2.8, 4.67 - sin(i) * 0.65, 0.03), i * 0.91)
	_prop(site, models, HILLVIEW_PROPS + "KAL-01_v03_Draped_Jacket.glb", bench + Vector3(0.4, 0.24, 0.04), PI)
	_prop(site, models, HILLVIEW_PROPS + "KAL-01_v03_Bicycle_Fallen_Hero.glb", _site(layout, -278.4, 5.92, 0.17), PI + 0.32)
	_prop(site, models, SUITCASE, _site(layout, -282.0, 5.78, 0.19), 0.47)
	var shrub := "res://assets/vegetation/flowering_shrub.glb"
	for i in 7:
		var at := _site(layout, -274.5 - i * 0.61, 7.57)
		var plant := _prop(site, models, shrub, at, i * 2.4)
		plant.scale = Vector3.ONE * (0.76 + 0.19 * cos(i))
	var rail := GEO.material(Color("#4f5148"))
	var retaining := FINISH.surface("Exposed concrete")
	GEO.box(site, bench + Vector3(0, 0.21, 0.81), Vector3(6.1, 0.42, 0.36), retaining, true)
	GEO.box(site, bench + Vector3(0, 0.98, 0.81), Vector3(6.12, 0.065, 0.067), rail)
	for i in 14:
		GEO.box(site, bench + Vector3(-2.92 + i * 0.446, 0.70, 0.81), Vector3(0.041, 0.57, 0.041), rail)
	_prop(site, models, SUITCASE, _site(layout, -307.0, -5.9, 0.16), -0.84)
	FURNITURE.furnish(site, "cardboard_box_01", _site(layout, -306.2, -5.5, 0.15), -0.75, 0.65, false)
	FURNITURE.furnish(site, "wooden_military_crate", _site(layout, -302.2, -7.15), 0.33, 0.74, true)
	FURNITURE.furnish(site, "medical_box", _site(layout, -279.1, -7.6), 0.37, 0.82, false)
	FURNITURE.furnish(site, "plastic_crate_02", _site(layout, -285.7, -8.0), 0.47, 0.89, true)
	FURNITURE.furnish(site, "trashbag", _site(layout, -309.5, -6.55, 0.15), 0.75, 0.64, false)
	var light_at := _site(layout, -286.3, -8.05)
	_worklight(site, light_at, 0.46)
	var pole := _site(layout, -278.0, -8.4)
	GEO.box(site, pole + Vector3.UP, Vector3(0.065, 2.0, 0.065), GEO.material(Color("#4d5350")))
	GEO.box(site, pole + Vector3.UP * 1.78, Vector3(1.82, 0.63, 0.065), GEO.material(Color("#424d4a")))
	GEO.sign(site, "EVACUATION  /  P06", pole + Vector3(0, 1.78, 0.039), 0.0, 0.0043)
	_litter(site, layout)


static func civic(parent: Node3D, layout: PLAN, models: MODELS) -> void:
	var site := Node3D.new()
	site.name = "CivicReliefStaging"
	parent.add_child(site)
	for x: float in [165.4, 167.5, 169.6]:
		var at := Vector3(x, layout.height(x, -132.7), -132.7)
		_prop(site, models, BARRIER, at, 0.07)
		GEO.box(site, at + Vector3.UP * 0.34, Vector3(1.55, 0.68, 0.46), null, true)
	for row: Array in [["wooden_military_crate", 166.5, -130.65, 0.87], ["medical_box", 167.1, -131.4, 0.95], ["trashbag", 168.2, -130.25, 0.83]]:
		var x: float = row[1]
		var z: float = row[2]
		FURNITURE.furnish(site, row[0], Vector3(x, layout.height(x, z), z), x * 0.27, row[3], true)
	_worklight(site, Vector3(165.4, layout.height(165.4, -130.3), -130.3), PI)
	var approach_z := -140.0 + PLAN.road_z_offset(151.5, -140.0)
	for spec: Array in [[151.5, approach_z + 5.3, 1.56, true], [173.0, -140.0 + PLAN.road_z_offset(173.0, -140.0) + 5.8, 1.35, false]]:
		open_sedan(site, models, Vector3(spec[0], layout.height(spec[0], spec[1]) + 0.035, spec[1]), spec[2], spec[3])
	_signal(site, Vector3(172, layout.height(172, -132.8), -132.8), true)
	_signal(site, Vector3(179, layout.height(179, -145.6), -145.6), false)
	var shelter_at := Vector3(158.0, layout.height(158.0, -132.3), -132.3)
	_prop(site, models, "res://assets/roads/streets/pz_048_bus_stop_shelter/PZ_MorrowTransit_BusShelter_COMPLETE.glb", shelter_at, PI * 0.5)
	_prop(site, models, SUITCASE, shelter_at + Vector3(1.85, 0.02, -0.43), 0.84)
	_prop(site, models, OAK, Vector3(157.2, layout.height(157.2, -130.4), -130.4), 0.4)
	for spec: Array in [[183.0, -118.0, 0.14, true], [197.0, -119.6, -0.35, false]]:
		open_sedan(site, models, Vector3(spec[0], layout.height(spec[0], spec[1]) + 0.03, spec[1]), spec[2], spec[3])
	for x: float in [180.8, 198.4]:
		var at := Vector3(x, layout.height(x, -126.0), -126.0)
		_prop(site, models, BARRIER, at, 0.16)
		_worklight(site, at + Vector3(0.45, 0.0, -1.58), 1.3)
	for x: float in [179.0, 203.0]:
		_prop(site, models, OAK, Vector3(x, layout.height(x, -115.0), -115.0), x * 0.02)
	var boulevard := layout.height(190.0, -120.0)
	GEO.box(site, Vector3(190, boulevard + 0.059, -119.5), Vector3(21.8, 0.12, 17.8), FINISH.surface("Asphalt"), true)
	for d: float in [-0.12, 0.12]:
		for i in 10:
			GEO.box(site, Vector3(190.0 + d, boulevard + 0.123, -127.15 + i * 1.68),
				Vector3(0.086, 0.011, 1.62), GEO.material(Color("#aa8755")))
	FURNITURE.furnish(site, "trashbag", Vector3(188.1, boulevard + 0.12, -117.0), 0.36, 0.82, false)
	_prop(site, models, SUITCASE, Vector3(190.7, boulevard + 0.12, -117.5), -0.47)
	var signal_at := Vector3(186.2, boulevard + 0.12, -124.2)
	var gate := Node3D.new()
	gate.position = signal_at
	gate.rotation.y = PI * 0.5
	site.add_child(gate)
	_signal(gate, Vector3.ZERO, false)


static func open_sedan(parent: Node3D, models: MODELS, at: Vector3, yaw: float, boot: bool) -> void:
	var pose := Node3D.new()
	pose.name = "AbandonedOpenSedan"
	pose.position = at
	pose.rotation.y = yaw
	parent.add_child(pose, true)
	var car := models.instantiate(OPEN_SEDAN)
	pose.add_child(car)
	var door := car.find_child("DriverDoor", true, false) as Node3D
	if door:
		door.rotation.y = deg_to_rad(49.0)
	if boot:
		var trunk := car.find_child("Trunk", true, false) as Node3D
		if trunk:
			trunk.rotation.x = deg_to_rad(54.0)
	_merge_sedan(pose, car)
	GEO.box(pose, Vector3.UP * 0.68, Vector3(1.81, 1.36, 4.72), null, true)


static func overlook(parent: Node3D, layout: PLAN, models: MODELS) -> void:
	var root := Node3D.new()
	root.name = "BasinOverlook"
	parent.add_child(root)
	var pine := "res://assets/props/nature/pz_128_conifer_tree/ProjectZ_PINE10_Conifer_Summer_LOD1.glb"
	for position: Vector2 in [Vector2(-454, -347), Vector2(-453, -333), Vector2(-446, -351),
			Vector2(-437, -337), Vector2(-445, -329), Vector2(-463, -352), Vector2(-441, -344),
			Vector2(-432, -330), Vector2(-435, -349), Vector2(-447, -355)]:
		var tree := _prop(root, models, pine, Vector3(position.x, layout.height(position.x, position.y), position.y), position.y)
		tree.scale = Vector3.ONE * (0.75 + sin(position.x) * 0.14)
	var stone := FINISH.surface("Exposed concrete")
	for i in 6:
		var p := PLAN.OVERLOOK + Vector2(1.2 + i * 0.7, 1.48 + sin(i) * 0.75)
		var rough := GEO.box(root, Vector3(p.x, layout.height(p.x, p.y) + 0.11, p.y),
			Vector3(1.1, 0.52, 0.73), stone)
		rough.rotation = Vector3(0.11 + sin(i * 1.3) * 0.27, i * 0.78, cos(i) * 0.28)


static func _merge_sedan(pose: Node3D, car: Node3D) -> void:
	var origin := car.global_transform.affine_inverse()
	var batches := {}
	for piece: MeshInstance3D in car.find_children("*", "MeshInstance3D", true, false):
		if not piece.mesh or not piece.is_visible_in_tree():
			continue
		var relative := origin * piece.global_transform
		for i in piece.mesh.get_surface_count():
			var finish := piece.get_active_material(i)
			if not batches.has(finish):
				var buffer := SurfaceTool.new()
				buffer.begin(Mesh.PRIMITIVE_TRIANGLES)
				buffer.set_material(finish)
				batches[finish] = buffer
			batches[finish].append_from(piece.mesh, i, relative)
	var combined := ArrayMesh.new()
	for surface: SurfaceTool in batches.values():
		surface.commit(combined)
	car.free()
	var display := MeshInstance3D.new()
	display.mesh = combined
	display.visibility_range_end = 120.0
	pose.add_child(display)


static func _signal(parent: Node3D, at: Vector3, north: bool) -> void:
	var pole := GEO.material(Color("#4d5353"))
	var dark := GEO.material(Color("#222626"))
	var light := StandardMaterial3D.new()
	light.albedo_color = Color("#b41c12")
	light.emission = Color("#ec2911")
	light.emission_enabled = true
	light.emission_energy_multiplier = 1.6
	var reach := -1.0 if north else 1.0
	GEO.box(parent, at + Vector3.UP * 2.28, Vector3(0.13, 4.56, 0.13), pole)
	GEO.box(parent, at + Vector3(0, 4.53, reach * 2.07), Vector3(0.09, 0.09, 4.2), pole)
	for z: float in [1.9, 3.65]:
		var head := at + Vector3(0, 4.17, reach * z)
		GEO.box(parent, head, Vector3(0.28, 0.58, 0.24), dark)
		GEO.box(parent, head + Vector3(-0.148, 0.17, 0), Vector3(0.04, 0.142, 0.142), light)


static func _site(layout: PLAN, x: float, offset: float, lift: float = 0.016) -> Vector3:
	var z := PLAN.bridge_center(x) + offset
	return Vector3(x, layout.height(x, z) + lift, z)


static func _prop(parent: Node3D, models: MODELS, path: String, at: Vector3, yaw: float) -> Node3D:
	var model := models.instantiate(path)
	model.position = at
	model.rotation.y = yaw
	parent.add_child(model)
	return model


static func _worklight(parent: Node3D, at: Vector3, yaw: float) -> void:
	var stand := Node3D.new()
	stand.position = at
	stand.rotation.y = yaw
	parent.add_child(stand)
	var steel := GEO.material(Color("#716458"))
	var housing := GEO.material(Color("#373732"))
	var lens := StandardMaterial3D.new()
	lens.albedo_color = Color("#c5a677")
	lens.emission_enabled = true
	lens.emission = Color("#ffba68")
	lens.emission_energy_multiplier = 0.85
	GEO.box(stand, Vector3(0, 1.15, 0), Vector3(0.065, 2.3, 0.065), steel)
	GEO.box(stand, Vector3(0, 0.055, 0), Vector3(0.74, 0.11, 0.64), steel)
	for x: float in [-0.17, 0.17]:
		GEO.box(stand, Vector3(x, 2.26, 0), Vector3(0.31, 0.23, 0.10), housing)
		GEO.box(stand, Vector3(x, 2.26, 0.052), Vector3(0.24, 0.16, 0.016), lens)
	var lamp := SpotLight3D.new()
	lamp.position = Vector3(0, 2.22, 0.13)
	lamp.rotation_degrees = Vector3(-155.0, 0, 0)
	lamp.light_color = Color("#ffbe78")
	lamp.light_energy = 1.5
	lamp.spot_angle = 49.0
	lamp.spot_range = 14.0
	stand.add_child(lamp)


static func _litter(parent: Node3D, layout: PLAN) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = PLAN.SEED + 112
	var scatter := MultiMesh.new()
	scatter.transform_format = MultiMesh.TRANSFORM_3D
	scatter.use_colors = true
	scatter.mesh = BoxMesh.new()
	scatter.instance_count = 145
	var paper := StandardMaterial3D.new()
	paper.vertex_color_use_as_albedo = true
	paper.roughness = 0.9
	var colors := [Color("#8c8574"), Color("#b6b0a1"), Color("#75604a"), Color("#857055"), Color("#8b7446")]
	for i in scatter.instance_count:
		var anchor: float = [-308.6, -297.6, -285.8, -279.3, -272.6][i % 5]
		var x := anchor + rng.randfn(0.0, 1.9)
		var offset := rng.randf_range(-5.65, -3.38)
		var at := _site(layout, x, offset, 0.022 + (0.142 if offset < -4.58 else 0.0))
		var size := Vector3(rng.randf_range(0.04, 0.23), rng.randf_range(0.008, 0.024), rng.randf_range(0.04, 0.18))
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * Basis.from_scale(size)
		scatter.set_instance_transform(i, Transform3D(basis, at))
		scatter.set_instance_color(i, colors[rng.randi_range(0, colors.size() - 1)])
	var display := MultiMeshInstance3D.new()
	display.name = "WindblownPaperAndLeaves"
	display.multimesh = scatter
	display.material_override = paper
	display.visibility_range_end = 74.0
	display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(display)
