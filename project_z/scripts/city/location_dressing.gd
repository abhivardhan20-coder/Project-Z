extends RefCounted

const GEO := preload("res://scripts/city/geometry.gd")
const FURNITURE := preload("res://scripts/city/interior_assets.gd")
const GRAPHICS := preload("res://scripts/graphics/materials.gd")
const FINISHES := {
	"residential": ["wood_floor", "#a68b72", 2.2, "#ddd2bc", "#6d7868", "#ffe3bb", "FERN COURT  /  01"],
	"police": ["tiled_floor_001", "#a6acaa", 1.5, "#d8d9cf", "#536773", "#d8ebff", "RECORDS  /  CIVIC POLICE"],
	"grocery": ["tiled_floor_001", "#c1bbaa", 1.5, "#e0d7c3", "#88734a", "#fff2d3", "NORTHLINE  /  PROVISIONS"],
	"clinic": ["tiled_floor_001", "#bfcac9", 1.5, "#e1e5db", "#538082", "#e2f7ff", "EXAMINATION  /  02"],
	"warehouse": ["concrete_floor_02", "#97968b", 2.8, "#bab6a3", "#6c6555", "#fff0d0", "FREIGHT  /  LOADING BAY"],
	"pump": ["concrete_floor_02", "#8c958c", 2.8, "#b7beb0", "#4f695e", "#d7ebe6", "PUMP CONTROL  /  SERVICE ONLY"],
	"garage": ["concrete_floor_02", "#999587", 2.8, "#c8bfaa", "#625c4e", "#fff0da", "MOTOR WORKS  /  BAY 01"],
}


static func floor_finish(id: String) -> Material:
	var style: Array = FINISHES[id]
	return GRAPHICS.indoor_floor(style[0], Color(style[1]), style[2])


static func front_wall(side: float, width: float, height: float) -> Array[Rect2]:
	var spans: Array[Rect2] = [
		Rect2(0.60, 0, 2.22, height), Rect2(4.58, 0, width * 0.5 - 4.58, height),
		Rect2(2.82, 0, 1.76, 1.31), Rect2(2.82, 2.37, 1.76, height - 2.37),
	]
	if side < 0:
		for i in spans.size():
			spans[i].position.x = -spans[i].end.x
	return spans


static func build(parent: Node3D, id: String, base: Vector3, width: float, depth: float, height: float) -> void:
	var room := Node3D.new()
	room.name = "Furnishings"
	room.position = base
	parent.add_child(room)
	_envelope(room, FINISHES[id], width, depth, height)
	match id:
		"residential": _residence(room)
		"police": _police(room)
		"grocery": _grocery(room)
		"clinic": _clinic(room)
		"warehouse": _warehouse(room)
		"pump": _pump_station(room)
		"garage": _garage(room)


static func props(parent: Node3D, origin: Vector3, placements: Array) -> void:
	for placement: Array in placements:
		var scale: float = placement[3] if placement.size() > 3 else 1.0
		var solid: bool = placement[4] if placement.size() > 4 else true
		FURNITURE.furnish(parent, placement[0], origin + placement[1], placement[2], scale, solid)


static func panel(parent: Node3D, title: String, at: Vector3, width: float, yaw: float, color: Color) -> void:
	var board := GEO.box(parent, at, Vector3(width, 0.25, 0.024), GEO.material(color))
	board.rotation.y = yaw
	GEO.sign(board, title, Vector3(0, 0, 0.016), 0, 0.0038)


static func rug(parent: Node3D, at: Vector3, size: Vector2, color: Color) -> void:
	GEO.box(parent, at, Vector3(size.x, 0.012, size.y), GEO.material(color))
	var edge := GEO.material(color.lightened(0.18))
	for side: float in [-1.0, 1.0]:
		GEO.box(parent, at + Vector3(side * (size.x * 0.5 - 0.11), 0.007, 0),
			Vector3(0.045, 0.004, size.y - 0.16), edge)
		GEO.box(parent, at + Vector3(0, 0.007, side * (size.y * 0.5 - 0.10)),
			Vector3(size.x - 0.17, 0.004, 0.043), edge)


static func fixture(parent: Node3D, at: Vector3, color: Color, energy: float, reach: float) -> void:
	GEO.box(parent, at, Vector3(1.36, 0.075, 0.31), GEO.material(Color("#666c65")))
	var lens := StandardMaterial3D.new()
	lens.albedo_color = color
	lens.emission_enabled = true
	lens.emission = color
	lens.emission_energy_multiplier = 0.63
	GEO.box(parent, at - Vector3.UP * 0.045, Vector3(1.21, 0.04, 0.22), lens)
	var light := OmniLight3D.new()
	light.position = at - Vector3.UP * 0.21
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	parent.add_child(light)


static func _envelope(room: Node3D, style: Array, width: float, depth: float, height: float) -> void:
	var plaster := FURNITURE.finish("white_plaster_02", Color(style[3]), 1.9, 0.88)
	var wall_base := GEO.material(Color(style[4]))
	var trim := GEO.material(Color(style[4]).darkened(0.31))
	var wall_x := width * 0.5 - 0.28
	for side: float in [-1.0, 1.0]:
		GEO.box(room, Vector3(side * wall_x, height * 0.5, depth * 0.5), Vector3(0.036, height, depth - 0.48), plaster)
		GEO.box(room, Vector3(side * (wall_x - 0.026), 0.57, depth * 0.5), Vector3(0.035, 1.14, depth - 0.49), wall_base)
		GEO.box(room, Vector3(side * (wall_x - 0.046), 1.14, depth * 0.5), Vector3(0.041, 0.047, depth - 0.49), trim)
		GEO.box(room, Vector3(side * (wall_x - 0.051), 0.07, depth * 0.5), Vector3(0.052, 0.14, depth - 0.49), trim)
		var front_x := width * 0.25 + 0.30
		for span: Rect2 in front_wall(side, width, height):
			var center := span.get_center()
			GEO.box(room, Vector3(center.x, center.y, 0.26), Vector3(span.size.x, span.size.y, 0.036), plaster)
		GEO.box(room, Vector3(side * front_x, 0.57, 0.284), Vector3(width * 0.5 - 0.60, 1.14, 0.031), wall_base)
	GEO.box(room, Vector3(0, height * 0.5, depth - 0.275), Vector3(width - 0.52, height, 0.036), plaster)
	GEO.box(room, Vector3(0, 0.57, depth - 0.299), Vector3(width - 0.53, 1.14, 0.034), wall_base)
	GEO.box(room, Vector3(0, 0.07, depth - 0.326), Vector3(width - 0.55, 0.14, 0.05), trim)
	GEO.box(room, Vector3(0, height - 0.028, depth * 0.5), Vector3(width - 0.51, 0.052, depth - 0.48), GEO.material(Color("#bbb9ad")))
	panel(room, style[6], Vector3(0, 2.42, depth - 0.32), 3.15, PI, Color(style[4]).darkened(0.36))
	for side: float in [-1.0, 1.0]:
		for row: float in [0.26, 0.72]:
			fixture(room, Vector3(side * width * 0.24, height - 0.085, depth * row), Color(style[5]), 1.05, 7.7)
	var spill := OmniLight3D.new()
	spill.position = Vector3(0, 1.72, 0.62)
	spill.light_color = Color("#c7deef")
	spill.light_energy = 0.48
	spill.omni_range = 4.8
	room.add_child(spill)


static func _residence(room: Node3D) -> void:
	rug(room, Vector3(-3.55, 0.009, 3.76), Vector2(3.04, 3.02), Color("#696f62"))
	props(room, Vector3.ZERO, [
		["sofa_02", Vector3(-5.03, 0, 3.78), PI / 2],
		["coffee_table_round_01", Vector3(-3.63, 0, 3.7), 0.2, 0.76],
		["binder_notebook", Vector3(-3.62, 0.38, 3.74), 0.28, 1.0, false],
		["metal_office_desk", Vector3(-3.79, 0, 0.83), 0, 0.82],
		["television_02", Vector3(-3.83, 0.649, 0.83), 0, 1.22, false],
		["potted_plant_02", Vector3(-5.07, 0, 1.27), 0.4, 0.81],
		["dining_table", Vector3(3.13, 0, 2.6), 0],
		["dining_chair_02", Vector3(3.53, 0, 1.67), 0.16],
		["dining_chair_02", Vector3(2.6, 0, 3.55), PI - 0.19],
		["long_life_food", Vector3(3.38, 0.797, 2.53), 0.22, 0.85, false],
		["electric_stove", Vector3(5.21, 0, 1.11), -PI / 2],
		["vintage_electric_kettle", Vector3(5.21, 0.862, 1.14), -0.24, 1.0, false],
		["wooden_bookshelf_worn", Vector3(-4.88, 0, 9.40), PI, 0.95],
		["book_encyclopedia_set_01", Vector3(-4.88, 1.21, 9.32), PI, 0.92, false],
		["vintage_day_bed", Vector3(-4.95, 0, 7.62), PI / 2],
	])


static func _police(room: Node3D) -> void:
	for row: float in [2.45, 5.18]:
		props(room, Vector3(-4.03, 0, row), [
			["metal_office_desk", Vector3.ZERO, PI / 2],
			["dining_chair_02", Vector3(-0.98, 0, -0.08), PI / 2, 0.94],
			["classic_laptop", Vector3(0, 0.789, -0.16), -PI / 2, 0.83, false],
			["desk_lamp_arm_01", Vector3(-0.12, 0.789, 0.48), PI / 2, 0.67, false],
			["binder_notebook", Vector3(0.17, 0.789, 0.38), PI / 2, 0.86, false],
		])
	props(room, Vector3.ZERO, [
		["steel_frame_shelves_02", Vector3(5.23, 0, 3.3), -PI / 2],
		["steel_frame_shelves_02", Vector3(5.23, 0, 5.15), -PI / 2],
		["drawer_cabinet", Vector3(-4.92, 0, 9.36), PI],
		["drawer_cabinet", Vector3(-3.62, 0, 9.36), PI, 0.97],
		["drawer_cabinet", Vector3(-2.32, 0, 9.36), PI],
		["cardboard_box_01", Vector3(-3.62, 1.83, 9.36), 0.1, 0.87, false],
		["binder_notebook", Vector3(2.98, 0.793, 7.77), PI + 0.21, 1.0, false],
		["wall_clock", Vector3(4.64, 2.05, 9.66), PI, 1.0, false],
		["korean_fire_extinguisher_01", Vector3(5.3, 0, 1.25), -PI / 2, 1.0, false],
	])
	panel(room, "INCIDENT DESK", Vector3(-5.65, 1.93, 3.74), 1.68, PI / 2, Color("#394d59"))


static func stocked_shelf(room: Node3D, at: Vector3, yaw: float) -> void:
	FURNITURE.furnish(room, "steel_frame_shelves_02", at, yaw)
	var turn := Basis(Vector3.UP, yaw)
	for shelf_y: float in [0.134, 0.64, 1.15, 1.648]:
		FURNITURE.furnish(room, "long_life_food", at + turn * Vector3(-0.025, shelf_y, 0.105), yaw, 0.85, false)
		if shelf_y < 1.2:
			FURNITURE.furnish(room, "long_life_food", at + turn * Vector3(0.025, shelf_y, -0.075), yaw - 0.08, 0.84, false)


static func _grocery(room: Node3D) -> void:
	for z: float in [2.0, 3.45, 4.9, 6.35, 7.8]:
		stocked_shelf(room, Vector3(-5.21, 0, z), PI / 2)
	for z: float in [4.0, 5.45, 6.9, 8.35]:
		stocked_shelf(room, Vector3(5.23, 0, z), -PI / 2)
	for z: float in [4.32, 5.76]:
		stocked_shelf(room, Vector3(2.53, 0, z), -PI / 2)
	for x: float in [-4.85, -3.86, 1.62, 2.6, 3.58, 4.56]:
		stocked_shelf(room, Vector3(x, 0, 9.36), PI)
	props(room, Vector3.ZERO, [
		["metal_office_desk", Vector3(3.55, 0, 1.51), PI],
		["classic_laptop", Vector3(3.48, 0.789, 1.57), PI, 0.73, false],
		["industrial_storage_cart", Vector3(-3.86, 0, 7.81), 0.11, 0.66],
		["plastic_crate_02", Vector3(4.31, 0, 8.9), 0.14],
	])
	panel(room, "CHECKOUT", Vector3(3.63, 2.18, 1.49), 1.52, PI, Color("#595743"))
	panel(room, "CANNED GOODS", Vector3(-5.65, 1.99, 4.85), 1.8, PI / 2, Color("#595743"))


static func _clinic(room: Node3D) -> void:
	var metal := GEO.material(Color("#afb9b6"))
	GEO.box(room, Vector3(-4.66, 2.36, 5.84), Vector3(2.11, 0.042, 0.064), metal)
	for i in 15:
		var tint := Color("#739c95").lightened(0.032 * (i % 3))
		GEO.box(room, Vector3(-5.63 + i * 0.137, 1.56, 5.84 + 0.034 * (i % 2)), Vector3(0.139, 1.53, 0.043), GEO.material(tint))
	GEO.box(room, Vector3(-4.66, 1.56, 5.84), Vector3(2.02, 1.57, 0.13), null, true)
	props(room, Vector3.ZERO, [
		["sofa_02", Vector3(-5.13, 0, 2.24), PI / 2],
		["coffee_table_round_01", Vector3(-4.09, 0, 2.51), 0, 0.61],
		["binder_notebook", Vector3(-4.07, 0.305, 2.51), 0.25, 0.85, false],
		["wheelchair_01", Vector3(-4.66, 0, 4.57), PI * 0.28],
		["hospital_bed", Vector3(-4.99, 0, 7.54), PI / 2],
		["tool_cart", Vector3(-3.69, 0, 7.44), -PI / 2, 0.65],
		["medical_box", Vector3(-3.69, 0.632, 7.44), PI * 0.1, 0.76, false],
		["drawer_cabinet", Vector3(4.48, 0, 9.37), PI, 0.88],
		["metal_trash_can", Vector3(5.2, 0, 4.09), -0.68, 0.67],
		["metal_office_desk", Vector3(4.78, 0, 5.51), -PI / 2],
		["industrial_microscope", Vector3(4.86, 0.79, 5.26), -PI / 2, 1.0, false],
		["medical_box", Vector3(4.75, 0.79, 5.95), -PI / 2, 0.83, false],
		["steel_frame_shelves_02", Vector3(5.18, 0, 7.39), -PI / 2],
		["wall_clock", Vector3(3.64, 2.1, 9.66), PI, 1.0, false],
	])
	panel(room, "WAITING AREA", Vector3(-5.65, 1.87, 2.73), 1.62, PI / 2, Color("#3e605b"))
	panel(room, "LAB", Vector3(5.65, 2.05, 5.43), 1.0, -PI / 2, Color("#3e605b"))


static func _warehouse(room: Node3D) -> void:
	for side: float in [-1.0, 1.0]:
		for z: float in [3.35, 5.12, 6.89, 8.66, 10.43, 12.2]:
			var x := side * 8.12
			props(room, Vector3(x, 0, z), [
				["steel_frame_shelves_02", Vector3.ZERO, -side * PI / 2, 1.28],
				["plastic_crate_02", Vector3(side * -0.05, 0.18, -0.13), -side * PI / 2, 0.71, false],
				["cardboard_box_01", Vector3(0, 0.82, 0.14), -side * PI / 2, 0.92, false],
				["cardboard_box_01", Vector3(side * -0.04, 1.47, -0.14), -side * PI / 2 + 0.09, 0.81, false],
			])
	props(room, Vector3.ZERO, [
		["industrial_storage_cart", Vector3(-4.0, 0, 4.73), 0.28],
		["industrial_storage_cart", Vector3(4.29, 0, 8.63), -0.14],
		["wooden_military_crate", Vector3(-4.7, 0, 11.28), 0.12, 1.21],
		["wooden_military_crate", Vector3(-5.82, 0, 11.83), -0.09, 1.09],
		["Barrel_02", Vector3(5.57, 0, 13.0), 0.1],
		["Barrel_02", Vector3(6.26, 0, 13.32), 0.7],
	])
	_cargo(room, Vector3(-4.04, 0, 8.09), 0.14)
	_cargo(room, Vector3(4.86, 0, 5.02), -0.10)
	_cargo(room, Vector3(4.30, 0, 12.68), 0.20)
	_bay_lines(room, 2.72, 1.0, 11.9)


static func _cargo(room: Node3D, at: Vector3, yaw: float) -> void:
	var stack := Node3D.new()
	stack.position = at
	stack.rotation.y = yaw
	room.add_child(stack)
	var pallet := FURNITURE.finish("wood_floor", Color("#8d7860"), 1.92, 0.90)
	for board in 5:
		GEO.box(stack, Vector3((board - 2) * 0.22, 0.105, 0), Vector3(0.197, 0.046, 0.99), pallet)
	for runner in 3:
		GEO.box(stack, Vector3((runner - 1) * 0.4, 0.044, 0), Vector3(0.105, 0.088, 0.99), pallet)
	GEO.box(stack, Vector3(0, 0.51, 0), Vector3(1.09, 1.02, 0.99), null, true)
	for x: float in [-0.264, 0.264]:
		for z: float in [-0.242, 0.242]:
			FURNITURE.furnish(stack, "cardboard_box_01", Vector3(x, 0.13, z), PI / 2, 0.92, false)
	FURNITURE.furnish(stack, "cardboard_box_01", Vector3(-0.15, 0.43, -0.02), -0.21, 1.13, false)
	FURNITURE.furnish(stack, "cardboard_box_01", Vector3(0.34, 0.43, 0.08), 0.11, 1.02, false)
	FURNITURE.furnish(stack, "cardboard_box_01", Vector3(-0.07, 0.80, -0.08), 0.27, 0.72, false)


static func _pump_station(room: Node3D) -> void:
	var housing := GRAPHICS.surface("Painted steel").duplicate() as ShaderMaterial
	housing.set_shader_parameter("tint", Color("#4f6763"))
	housing.set_shader_parameter("wet_exposure", 0.0)
	var pipe := GEO.material(Color("#587b73"))
	var flange := GEO.material(Color("#334748"))
	for z: float in [3.15, 5.22]:
		var at := Vector3(-4.33, 0, z)
		GEO.box(room, at + Vector3.UP * 0.22, Vector3(2.05, 0.44, 1.06), housing, true)
		_pipe(room, at + Vector3(-0.86, 0.72, 0), at + Vector3(0.86, 0.72, 0), 0.29, pipe)
		_pipe(room, at + Vector3(0.51, 0.72, 0), at + Vector3(0.64, 0.72, 0), 0.36, flange)
		_pipe(room, at + Vector3(-0.81, 0.71, 0), at + Vector3(-0.81, 2.64, 0), 0.15, pipe)
		for collar: float in [1.03, 2.51]:
			var join := at + Vector3(-0.81, collar, 0)
			_pipe(room, join, join + Vector3.UP * 0.072, 0.21, flange)
	_pipe(room, Vector3(-5.14, 2.64, 1.25), Vector3(-5.14, 2.64, 8.93), 0.17, pipe)
	props(room, Vector3.ZERO, [
		["industrial_storage_cart", Vector3(4.7, 0, 3.11), PI / 2, 0.73],
		["Barrel_02", Vector3(5.02, 0, 5.08), 0.19],
		["Barrel_02", Vector3(5.02, 0, 5.78), 0.67],
		["drawer_cabinet", Vector3(5.19, 0, 8.74), -PI / 2, 0.91],
		["korean_fire_extinguisher_01", Vector3(5.4, 0, 1.19), -PI / 2, 1.0, false],
	])
	panel(room, "INTAKE PUMPS", Vector3(-5.65, 1.89, 4.16), 1.7, PI / 2, Color("#334748"))
	_bay_lines(room, 2.99, 1.0, 6.95)


static func _garage(room: Node3D) -> void:
	props(room, Vector3.ZERO, [
		["metal_office_desk", Vector3(-7.91, 0, 4.31), PI / 2],
		["drill_press_01", Vector3(-7.92, 0.79, 4.69), PI / 2, 1.0, false],
		["metal_tool_chest", Vector3(-7.93, 0.79, 3.95), PI / 2, 0.92, false],
		["tool_cart", Vector3(-6.2, 0, 5.77), -0.24],
		["steel_frame_shelves_02", Vector3(-8.21, 0, 7.57), PI / 2, 1.25],
		["steel_frame_shelves_02", Vector3(-8.21, 0, 9.66), PI / 2, 1.25],
		["metal_toolbox", Vector3(-8.21, 0.80, 7.57), PI / 2, 0.84, false],
		["plastic_crate_02", Vector3(-8.21, 0.18, 7.61), PI / 2, 0.84, false],
		["cardboard_box_01", Vector3(-8.21, 1.44, 9.67), PI / 2 + 0.12, 1.0, false],
		["drawer_cabinet", Vector3(-7.9, 0, 2.71), PI / 2],
		["Barrel_02", Vector3(-7.87, 0, 12.61), 0.27],
		["Barrel_02", Vector3(-7.12, 0, 12.67), 0.89],
		["industrial_storage_cart", Vector3(6.7, 0, 4.48), -PI / 2],
		["korean_fire_extinguisher_01", Vector3(7.95, 0, 7.47), -PI / 2, 1.0, false],
	])
	var steel := GEO.material(Color("#596766"))
	var runner := GEO.material(Color("#6d7167"))
	for side: float in [-1.0, 1.0]:
		GEO.box(room, Vector3(side * 1.52, 0.367, 6.18), Vector3(0.54, 0.016, 3.96), GEO.material(Color("#484845")))
		GEO.box(room, Vector3(side * 1.52, 0.29, 6.18), Vector3(0.65, 0.15, 4.25), runner, true)
		GEO.box(room, Vector3(side * 2.05, 1.51, 6.18), Vector3(0.30, 3.02, 0.36), steel, true)
		GEO.box(room, Vector3(side * 1.8, 0.16, 6.18), Vector3(1.01, 0.32, 0.65), steel, true)
		for i in 5:
			GEO.box(room, Vector3(side * 2.05, 0.40 + i * 0.16, 5.988), Vector3(0.26, 0.07, 0.019), GEO.material(Color("#ac9250")))
	GEO.box(room, Vector3(0, 3.03, 6.18), Vector3(4.39, 0.18, 0.29), steel)
	_bay_lines(room, 2.63, 1.0, 10.63)


static func _bay_lines(room: Node3D, half_width: float, front: float, back: float) -> void:
	var paint := GEO.material(Color("#ac9250"))
	for side: float in [-1.0, 1.0]:
		for z: float in [front, back - 1.0]:
			GEO.box(room, Vector3(side * half_width, 0.011, z + 0.5), Vector3(0.095, 0.013, 1.0), paint)
			GEO.box(room, Vector3(side * (half_width - 0.46), 0.011, z if z == front else z + 1.0),
				Vector3(0.98, 0.013, 0.095), paint)


static func _pipe(room: Node3D, start: Vector3, finish: Vector3, radius: float, surface: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = start.distance_to(finish)
	mesh.radial_segments = 16
	var pipe := MeshInstance3D.new()
	pipe.mesh = mesh
	pipe.material_override = surface
	pipe.position = (start + finish) * 0.5
	pipe.quaternion = Quaternion(Vector3.UP, (finish - start).normalized())
	room.add_child(pipe)
