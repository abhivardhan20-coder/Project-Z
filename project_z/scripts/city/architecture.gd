extends RefCounted

const GEO := preload("res://scripts/city/geometry.gd")
const PLAN := preload("res://scripts/city/layout.gd")
const INTERACTION := preload("res://scripts/city/interaction.gd")
const FURNITURE := preload("res://scripts/city/interior_assets.gd")
const DRESSING := preload("res://scripts/city/location_dressing.gd")
const GRAPHICS := preload("res://scripts/graphics/materials.gd")
const FACADE := preload("res://materials/facade.gdshader")
const TOWER := preload("res://materials/ultra/distant_city.gdshader")
const ROOF := Color("#424d4d")
const FRAME := Color("#a19d8b")
const WINDOW := Color("#35494b")
const DOOR := Color("#4b635d")

var materials: Dictionary = {}
var callback: Callable
var stored: Dictionary
var layout: PLAN


func _init(plan: PLAN, handler: Callable, objects: Dictionary) -> void:
	layout = plan
	callback = handler
	stored = objects


func facade(zone: int, finish: int) -> Material:
	var key := Vector2i(zone, finish)
	if not materials.has(key):
		var palette := [
			["#b3a58f", "#b9b8a9", "#a08473", "#899687"],
			["#b6b4a7", "#818f8b", "#aeb5b6", "#8c8176"],
			["#9e6f59", "#beac8d", "#a08066", "#a6a58f"],
			["#839298", "#797c72", "#9e8275", "#8b9079"],
		]
		var material := ShaderMaterial.new()
		material.shader = FACADE
		material.set_shader_parameter("tint", Color(palette[zone][finish]))
		material.set_shader_parameter("masonry", zone == 2 and finish % 2 == 0)
		material.set_shader_parameter("siding", zone == 3)
		material.set_shader_parameter("brick_surface", FURNITURE.texture("brick_wall_001", "Diffuse"))
		material.set_shader_parameter("plaster_surface", FURNITURE.texture("white_plaster_02", "Diffuse"))
		material.set_shader_parameter("brick_normal", FURNITURE.texture("brick_wall_001", "nor_gl"))
		material.set_shader_parameter("plaster_normal", FURNITURE.texture("white_plaster_02", "nor_gl"))
		materials[key] = material
	return materials[key]


func shell(parent: Node3D, parcel: Dictionary, detail: bool, title: String = "") -> void:
	var center: Vector2 = parcel.center
	var size: Vector2 = parcel.size
	var levels: int = parcel.levels
	var zone: int = parcel.zone
	var base := _foundation(center, size)
	var height := levels * (4.15 if zone == 3 else 3.2)
	var position := Vector3(center.x, base, center.y)
	var surface := facade(zone, parcel.finish)
	var roof := GEO.material(ROOF)
	if title == "Municipal Hall":
		_municipal_hall(parent, position, size, height, surface, roof, detail)
		return
	if levels >= 9:
		_office_tower(parent, position, size, height, surface, detail)
		return
	GEO.box(parent, position + Vector3.UP * (height * 0.5 - 2.0), Vector3(size.x, height + 4.0, size.y), surface, detail)
	if parcel.get("infill", false):
		_infill(parent, parcel, position, height, surface, roof, detail)
		return
	if zone == 0 and levels <= 2:
		_pitched_roof(parent, position + Vector3.UP * height, size, roof, surface)
	else:
		GEO.box(parent, position + Vector3.UP * height, Vector3(size.x + 0.36, 0.28, size.y + 0.36), roof)
	if not detail:
		return
	var frame := GEO.material(FRAME)
	var glass := GEO.material(WINDOW)
	for level in levels:
		var floor_y := position.y + level * (height / levels)
		for side: float in [-1.0, 1.0]:
			for bay in maxi(1, floori(size.x / 4.0)):
				var lateral := (bay + 0.5) * 4.0 - floorf(size.x / 4.0) * 2.0
				var window := Vector3(center.x + lateral, floor_y + 1.83, center.y + side * size.y * 0.5)
				GEO.box(parent, window, Vector3(1.92, 1.35, 0.13), frame)
				var pane := glass if (level + bay + parcel.finish) % 4 != 0 else GEO.material(Color("#536268"))
				GEO.box(parent, window + Vector3.BACK * side * 0.09, Vector3(1.74, 1.15, 0.035), pane)
				GEO.box(parent, window + Vector3(0, -0.685, side * 0.14), Vector3(2.01, 0.095, 0.25), frame)
				if zone == 0 and level > 0 and bay % 2 == 0:
					GEO.box(parent, window + Vector3(0, -0.9, side * 0.72), Vector3(2.35, 0.17, 1.48), frame)
					GEO.box(parent, window + Vector3(0, -0.48, side * 1.39), Vector3(2.31, 0.67, 0.09), roof)
		var band := Vector3(center.x, floor_y + 0.16, center.y)
		GEO.box(parent, band, Vector3(size.x + 0.19, 0.16, size.y + 0.19), frame)
		if zone != 3:
			for side: float in [-1.0, 1.0]:
				for bay in maxi(1, floori(size.y / 4.0)):
					var lateral := (bay + 0.5) * 4.0 - floorf(size.y / 4.0) * 2.0
					var window := Vector3(center.x + side * size.x * 0.5, floor_y + 1.83, center.y + lateral)
					GEO.box(parent, window, Vector3(0.14, 1.29, 1.69), frame)
					GEO.box(parent, window + Vector3.RIGHT * side * 0.09, Vector3(0.035, 1.11, 1.49), glass)
	if zone == 0 or zone == 2:
		for side: float in [-1.0, 1.0]:
			var entry := position + Vector3(0.8, 1.05, side * (size.y * 0.5 + 0.065))
			GEO.box(parent, entry, Vector3(1.18, 2.1, 0.12), GEO.material(DOOR))
			GEO.box(parent, entry + Vector3(0, 1.12, side * 0.48), Vector3(1.65, 0.16, 1.05), roof)
	if zone in [1, 2, 3] and size.x >= 7.5:
		var unit_at := position + Vector3(size.x * 0.39, 0.81, -size.y * 0.5 - 0.2)
		FURNITURE.furnish(parent, "exterior_aircon_unit", unit_at, PI, 0.58, false)
	if zone == 0 or zone == 3:
		var vessel := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.82
		cylinder.bottom_radius = 0.82
		cylinder.height = 1.37
		cylinder.radial_segments = 12
		vessel.mesh = cylinder
		vessel.material_override = roof
		vessel.position = position + Vector3(size.x * 0.23, height + 0.81, -size.y * 0.24)
		parent.add_child(vessel)
	if title != "" and zone != 0:
		GEO.sign(parent, title, position + Vector3(0, 3.0, -size.y / 2.0 - 0.11), PI, 0.015)


func _office_tower(parent: Node3D, at: Vector3, size: Vector2, height: float, stone: Material, detail: bool) -> void:
	var glazing := ShaderMaterial.new()
	glazing.shader = TOWER
	glazing.set_shader_parameter("default_stone", Color("#596a77"))
	GEO.box(parent, at + Vector3.UP * 2.7, Vector3(size.x + 1.1, 5.4, size.y + 0.5), stone, detail)
	GEO.box(parent, at + Vector3.UP * (height * 0.5 + 1.0), Vector3(size.x, height, size.y), glazing, detail)
	GEO.box(parent, at + Vector3.UP * (height + 2.5), Vector3(size.x * 0.75, 3.3, size.y * 0.80), glazing)
	for side: float in [-1.0, 1.0]:
		GEO.box(parent, at + Vector3(side * size.x * 0.47, height * 0.5 + 0.88, size.y * 0.50),
			Vector3(0.45, height, 0.38), stone)


func _municipal_hall(parent: Node3D, position: Vector3, size: Vector2, height: float,
		stone: Material, roof: Material, detail: bool) -> void:
	var hall := Node3D.new()
	hall.name = "MunicipalHall"
	hall.position = position
	parent.add_child(hall)
	GEO.box(hall, Vector3.UP * (height * 0.5 - 2.0), Vector3(size.x, height + 4, size.y), stone, detail)
	GEO.box(hall, Vector3(0, height + 0.2, 0), Vector3(size.x + 0.75, 0.72, size.y + 0.75), stone)
	var tower := Vector3(0, height + 9.0, -4.7)
	GEO.box(hall, tower, Vector3(12.2, 18.0, 11.4), stone, detail)
	GEO.box(hall, tower + Vector3.UP * 10.9, Vector3(8.0, 4.0, 7.25), stone, detail)
	GEO.box(hall, tower + Vector3.UP * 13.1, Vector3(5.2, 0.48, 4.55), roof)
	GEO.box(hall, tower + Vector3.UP * 15.7, Vector3(0.27, 5.5, 0.27), roof)
	var glass := GEO.material(Color("#344956"))
	for x: float in [-3.1, -1.0, 1.0, 3.1]:
		GEO.box(hall, tower + Vector3(x, -0.4, 5.73), Vector3(1.33, 12.5, 0.07), glass)
	for side: float in [-1.0, 1.0]:
		for x: float in [10.8, 13.2, 15.6, 18.0, 20.4]:
			GEO.box(hall, Vector3(side * x, 7.2, size.y * 0.5 + 0.055), Vector3(1.6, 6.5, 0.1), glass)
	var front := size.y * 0.5
	GEO.box(hall, Vector3(0, 8.1, front + 1.9), Vector3(19.6, 1.3, 4.5), stone)
	GEO.box(hall, Vector3(0, 3.75, front + 0.06), Vector3(17.8, 7.5, 0.12), glass)
	for x: float in [-8.25, -5.5, -2.75, 0, 2.75, 5.5, 8.25]:
		GEO.box(hall, Vector3(x, 3.65, front + 3.55), Vector3(0.69, 7.3, 0.69), stone, detail)
	if detail:
		for x: float in [-6.85, 6.85]:
			GEO.box(hall, Vector3(x, 5.45, front + 3.93), Vector3(1.43, 3.44, 0.035), GEO.material(Color("#78544f")))
		GEO.sign(hall, "KALDRAN MUNICIPAL HALL", Vector3(0, 8.13, front + 4.2), 0.0, 0.011)


func _infill(parent: Node3D, parcel: Dictionary, base: Vector3, height: float,
		wall: Material, roof: Material, detail: bool) -> void:
	var size: Vector2 = parcel.size
	var zone: int = parcel.zone
	var pitched: bool = zone == 0 or (zone == 2 and parcel.finish == 3)
	if pitched:
		_pitched_roof(parent, base + Vector3.UP * height, size, roof, wall)
	else:
		GEO.box(parent, base + Vector3.UP * height, Vector3(size.x + 0.48, 0.29, size.y + 0.48), roof)
		if zone == 1 and parcel.levels >= 3:
			GEO.box(parent, base + Vector3(-size.x * 0.19, height + 0.53, 0), Vector3(3.25, 1.05, 3.05), roof)
	if not detail:
		return
	var direction: Vector2 = parcel.facing
	var facade := Node3D.new()
	facade.position = base + Vector3(direction.x * size.x * 0.5, 0, direction.y * size.y * 0.5)
	facade.rotation.y = atan2(direction.x, direction.y)
	parent.add_child(facade)
	var width := size.x if direction.x == 0 else size.y
	var glass := GEO.material(Color("#3e5257"))
	var trim := GEO.material(FRAME)
	var accent := GEO.material(Color(["#63786a", "#4a676f", "#7d594b", "#806947"][parcel.finish]))
	var floor_height := height / float(parcel.levels)
	for level in range(1 if zone in [1, 2, 3] else 0, parcel.levels):
		for bay in floori(width / 3.0):
			var at := Vector3((bay + 0.5) * 3.0 - floorf(width / 3.0) * 1.5, floor_height * level + 1.72, 0.034)
			GEO.box(facade, at, Vector3(1.69, 1.22, 0.10), trim)
			GEO.box(facade, at + Vector3.BACK * 0.063, Vector3(1.52, 1.06, 0.033), glass)
	# Side and rear windows give the block depth when seen from the next street.
	for side: Vector2 in [Vector2(-direction.y, direction.x), Vector2(direction.y, -direction.x), -direction]:
		var panel := Node3D.new()
		panel.position = base + Vector3(side.x * size.x * 0.5, 0, side.y * size.y * 0.5)
		panel.rotation.y = atan2(side.x, side.y)
		parent.add_child(panel)
		var run := size.x if side.x == 0 else size.y
		for level in parcel.levels:
			if zone == 3 and level == 0:
				GEO.box(panel, Vector3(0, 2.61, 0.059), Vector3(run * 0.64, 0.61, 0.105), glass)
			else:
				for slot: float in [-0.23, 0.23]:
					var window := Vector3(run * slot, floor_height * level + 1.76, 0.035)
					GEO.box(panel, window, Vector3(1.50, 1.13, 0.105), trim)
					GEO.box(panel, window + Vector3.BACK * 0.059, Vector3(1.33, 0.97, 0.030), glass)
	match zone:
		0:
			GEO.box(facade, Vector3(0, 1.04, 0.09), Vector3(1.04, 2.08, 0.13), accent)
			GEO.box(facade, Vector3(0, 2.28, 0.52), Vector3(2.32, 0.17, 1.24), roof)
			GEO.box(facade, Vector3(0, 0.13, 0.56), Vector3(2.20, 0.26, 1.14), trim)
			for x: float in [-0.98, 0.98]:
				GEO.box(facade, Vector3(x, 1.14, 1.03), Vector3(0.12, 2.26, 0.12), trim)
		1, 2:
			for x: float in [-0.27, 0.0, 0.27]:
				GEO.box(facade, Vector3(x * width, 1.39, 0.05), Vector3(width * 0.235, 2.30, 0.14), accent)
				GEO.box(facade, Vector3(x * width, 1.48, 0.14), Vector3(width * 0.215, 1.92, 0.055), glass)
			GEO.box(facade, Vector3(0, 2.69, 0.49), Vector3(width * 0.87, 0.21, 1.05), accent)
			if zone == 2:
				var names := ["TAILOR", "MARKET DELI", "BAKERY", "REPAIRS"]
				DRESSING.panel(facade, names[parcel.finish], Vector3(0, 2.98, 0.083), 2.45, 0, Color("#3d4843"))
		3:
			for x: float in [-0.25, 0.25]:
				var door_width := width * 0.35
				GEO.box(facade, Vector3(width * x, 1.49, 0.08), Vector3(door_width, 2.98, 0.12), roof)
				for rail: float in [0.40, 1.04, 1.68, 2.32, 2.96]:
					GEO.box(facade, Vector3(width * x, rail, 0.154), Vector3(door_width, 0.031, 0.038), accent)
			GEO.box(facade, Vector3(0, 3.16, 0.55), Vector3(width * 0.88, 0.18, 1.22), trim)


func _pitched_roof(parent: Node3D, origin: Vector3, size: Vector2, roof: Material, wall: Material) -> void:
	var rise := minf(2.35, size.y * 0.19)
	var span := size.y * 0.5 + 0.32
	for side: float in [-1.0, 1.0]:
		var panel := GEO.box(parent, origin + Vector3(0, rise * 0.5, side * span * 0.5),
			Vector3(size.x + 0.68, 0.19, Vector2(span, rise).length()), roof)
		panel.rotation.x = atan2(rise, span) * side
	var gables := SurfaceTool.new()
	gables.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		var face := origin + Vector3.RIGHT * side * size.x * 0.501
		gables.add_vertex(face + Vector3.BACK * side * size.y * 0.5)
		gables.add_vertex(face + Vector3.UP * rise)
		gables.add_vertex(face + Vector3.FORWARD * side * size.y * 0.5)
	gables.generate_normals()
	GEO.attach(parent, "Gables", gables.commit(), wall, false)


func interior(parent: Node3D, id: String) -> void:
	var entry: Array = PLAN.PLACES[id]
	var marker := layout.place(id)
	var wide := id == "warehouse" or id == "garage"
	var width := 18.0 if wide else 12.0
	var depth := 15.0 if wide else 10.0
	var ceiling := 4.4 if wide or id == "residential" else 3.2
	var floor_y := marker.y + 0.18
	var z := marker.z + depth * 0.5
	var face := facade(PLAN.district(marker.x, marker.z), 1)
	var floor_surface := DRESSING.floor_finish(id)
	var roof := GEO.material(ROOF)
	var trim := GEO.material(FRAME)
	var base := Vector3(marker.x, floor_y, marker.z)
	GEO.box(parent, Vector3(marker.x, floor_y - 0.135, z), Vector3(width, 0.27, depth), floor_surface, true)
	GEO.box(parent, Vector3(marker.x, floor_y - 1.65, z), Vector3(width - 0.14, 3.0, depth - 0.1), face, true)
	for side: float in [-1.0, 1.0]:
		GEO.box(parent, Vector3(marker.x + side * (width * 0.5 - 0.13), floor_y + ceiling * 0.5, z),
			Vector3(0.26, ceiling, depth), face, true)
		for span: Rect2 in DRESSING.front_wall(side, width, ceiling):
			var center := span.get_center()
			GEO.box(parent, base + Vector3(center.x, center.y, 0.12), Vector3(span.size.x, span.size.y, 0.24), face, true)
		_front_window(parent, base + Vector3(side * 3.7, 1.84, 0.12), trim)
	GEO.box(parent, base + Vector3(0, ceiling * 0.5, depth - 0.13), Vector3(width, ceiling, 0.26), face, true)
	GEO.box(parent, base + Vector3(0, (ceiling + 2.16) * 0.5, 0.12), Vector3(1.2, ceiling - 2.16, 0.24), face, true)
	GEO.box(parent, Vector3(marker.x, floor_y + ceiling + 0.12, z), Vector3(width + 0.4, 0.24, depth + 0.4), roof, true)
	var step_a := PackedVector3Array()
	var step_b := PackedVector3Array()
	for i in 6:
		var p := base + Vector3(0, 0, -2.0 + i * 0.4)
		p.y = lerpf(layout.height(p.x, p.z) + 0.055, floor_y, i / 5.0)
		step_a.append(p + Vector3.LEFT)
		step_b.append(p + Vector3.RIGHT)
	GEO.strip(parent, "EntranceRamp", step_a, step_b, floor_surface, true)
	GEO.sign(parent, entry[0], base + Vector3(0, 2.58, -0.17), PI, 0.011)
	var door := interact(parent, id + "_door", "door", "door", "", base + Vector3(0, 0, 0.12))
	door.create_door(1.19, 2.15, GEO.material(DOOR))
	door.restore(bool(stored.get(door.id, false)))
	DRESSING.build(parent, id, base, width, depth, ceiling)
	_add_supplies(parent, id, base, depth)
	if id == "residential" or id == "garage":
		_loft(parent, base, width, depth, roof)


func _front_window(parent: Node3D, at: Vector3, trim: Material) -> void:
	GEO.box(parent, at, Vector3(1.76, 1.06, 0.035), GRAPHICS.glass(), true)
	for side: float in [-1.0, 1.0]:
		GEO.box(parent, at + Vector3(side * 0.89, 0, 0), Vector3(0.11, 1.17, 0.31), trim)
		GEO.box(parent, at + Vector3(0, side * 0.55, 0), Vector3(1.92, 0.11, 0.34), trim)
	GEO.box(parent, at, Vector3(0.055, 1.06, 0.11), trim)


func interact(parent: Node3D, id: String, title: String, kind: String, verb: String, position: Vector3, contents: Dictionary = {}) -> INTERACTION:
	var item := INTERACTION.new()
	item.id = id
	item.title = title
	item.kind = kind
	item.verb = verb
	item.position = position
	item.contents = contents
	item.handler = callback
	item.active = bool(stored.get(id, false))
	parent.add_child(item)
	return item


func crate(parent: Node3D, id: String, title: String, position: Vector3, contents: Dictionary, yaw: float = 0.0) -> INTERACTION:
	var prop := FURNITURE.furnish(parent, "wooden_military_crate", position, yaw, 0.78)
	var item := interact(parent, id, title, "loot", "Search", position + Vector3.UP * 0.40, contents)
	item.blocker = prop.get_node_or_null("FurnitureCollision") as CollisionObject3D
	item.container_lid = prop.find_child("wooden_military_crate_lid", true, false) as Node3D
	if item.container_lid:
		item.lid_closed = item.container_lid.rotation.x
	item.restore(item.active)
	return item


func _foundation(center: Vector2, size: Vector2) -> float:
	var height := layout.height(center.x, center.y)
	for side_x: float in [-0.5, 0.5]:
		for side_z: float in [-0.5, 0.5]:
			height = maxf(height, layout.height(center.x + size.x * side_x, center.y + size.y * side_z))
	return height + 0.08


func _add_supplies(parent: Node3D, id: String, base: Vector3, depth: float) -> void:
	var supply := {
		"residential": {"cloth": 4, "food": 1}, "police": {"radio_parts": 1, "ammo": 12},
		"grocery": {"food": 3, "water": 3}, "clinic": {"bandage": 3, "medication": 1},
		"warehouse": {"scrap": 4, "fuel": 1}, "pump": {"filter_parts": 1, "water": 2},
		"garage": {"scrap": 3, "fuel": 2, "electronics": 2},
	}
	crate(parent, id + "_cache", "supply case", base + Vector3(-1.82, 0, depth - 2.25), supply[id])
	if id == "police" or id == "pump":
		var desk_at := base + Vector3(2.45, 0, depth - 2.1)
		var desk := FURNITURE.furnish(parent, "metal_office_desk", desk_at, PI)
		var note := interact(parent, id + "_note", "station log", "note", "Read", desk_at + Vector3.UP * 0.81)
		note.blocker = desk.get_node_or_null("FurnitureCollision") as CollisionObject3D
		GEO.box(parent, note.position, Vector3(0.28, 0.026, 0.21), GEO.material(Color("#c8bd96")))


func _loft(parent: Node3D, base: Vector3, width: float, depth: float, surface: Material) -> void:
	var stair_x := width * 0.5 - 1.83
	var step_z := depth - 6.0
	var z := depth - 0.85
	var floor_y := 2.18
	GEO.box(parent, base + Vector3(stair_x - 1.6, floor_y - 0.1, z - 0.27), Vector3(4.8, 0.2, 1.64), surface, true)
	var left := PackedVector3Array([base + Vector3(stair_x - 0.63, 0.0, step_z), base + Vector3(stair_x - 0.63, floor_y, z - 1.07)])
	var right := PackedVector3Array([base + Vector3(stair_x + 0.63, 0.0, step_z), base + Vector3(stair_x + 0.63, floor_y, z - 1.07)])
	GEO.strip(parent, "LoftStairCollision", left, right, null, true).hide()
	for i in 14:
		GEO.box(parent, base + Vector3(stair_x, (i + 0.5) * floor_y / 14.0 - 0.055, lerpf(step_z, z - 1.07, (i + 0.5) / 14.0)),
			Vector3(1.26, 0.12, (z - 1.07 - step_z) / 14.0), surface)
