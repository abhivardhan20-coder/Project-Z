extends Node3D

const MODELS := preload("res://scripts/neighborhood/neighborhood_assets.gd")
const CATALOG := preload("res://scripts/neighborhood/neighborhood_catalog.gd")
const INTERACTION := preload("res://scripts/neighborhood/neighborhood_interaction.gd")
const FURNITURE := preload("res://scripts/city/interior_assets.gd")
const DRESSING := preload("res://scripts/city/location_dressing.gd")
const GEO := preload("res://scripts/city/geometry.gd")
const APARTMENT := "res://assets/buildings/points_of_interest/pz_032_midrise_apartment_shell/"
const STOREFRONT := "res://assets/buildings/modular_architecture/pz_013_brick_storefront_facade/PROJECT_Z_BrickStorefront.glb"
const CURB_KIT := "res://assets/roads/streets/pz_042_sidewalk_curb_and_ramp_kit/"
const PROPS := "res://assets/pilot/hillview/"
const BENCH := "res://assets/props/interiors_and_street_props/pz_122_street_bench_and_trash_can/PZ_StreetBench.glb"
const SHELF := "res://assets/props/interiors_and_street_props/pz_119_supermarket_shelf_kit/PZ_Market_Stocked_Shelf_2m.glb"
const DINING_TABLE := "res://assets/props/interiors_and_street_props/pz_115_dining_table_and_chair/PZ_Dining_Kitchen_Table.glb"

# Measured against the installed PZ-042 ramp and the two original facade openings.
const PAVEMENT_Y := 0.15
const FACADE_Z := 4.75
const SIDEWALK_LEFT := -4.0
const SIDEWALK_RIGHT := 29.0
const CURB_DEPTH := 0.245
const SHOP_X := -0.156
const LOBBY_X := 10.82
const STOREY_HEIGHT := 3.15
const STOREYS := 3
const STAIR_SHIFT := 7.4
const STAIR_FRONT := 9.95
const STAIR_BACK := 14.24
const STAIR_LEFT := 0.6
const STAIR_RIGHT := 4.33

var models: MODELS
var palette: Dictionary
var furnished_safehouse := false
var safehouse_tubes: Array[StandardMaterial3D] = []


func build(model_library: MODELS, materials: Dictionary, dress_safehouse: bool = false) -> void:
	models = model_library
	palette = materials
	furnished_safehouse = dress_safehouse
	_build_sidewalk()
	_build_lobby()
	_build_shop()
	_build_street_dressing()
	if furnished_safehouse:
		_finish_safehouse()
		_dress_hillview_frontage()


func _build_sidewalk() -> void:
	var start := SIDEWALK_LEFT
	for opening in [SHOP_X, LOBBY_X]:
		_build_curb_run(start, opening - 1.0)
		# The PZ-042 module rises along local -Z. Its low end meets the road.
		var ramp := _model(CURB_KIT + "PZ_Ramp_Crosswalk_2x2.glb", Vector3(opening + 1.0, 0.0, 0.0), PI)
		_mesh_collision(ramp, ["Monolithic_Ramp"])
		start = opening + 1.0
	_build_curb_run(start, SIDEWALK_RIGHT)
	_paving(SIDEWALK_LEFT, SIDEWALK_RIGHT, 2.0, FACADE_Z)


func _build_curb_run(start: float, finish: float) -> void:
	var cursor := start
	while cursor < finish - 0.001:
		var length := minf(2.0, finish - cursor)
		var curb := _model(CURB_KIT + "PZ_Curb_2m.glb", Vector3(cursor, 0.0, CURB_DEPTH))
		curb.scale.x = length / 2.0
		_mesh_collision(curb, ["Curb_Stone"])
		cursor += length
	_paving(start, finish, CURB_DEPTH, 2.0)


func _paving(left: float, right: float, front: float, back: float) -> void:
	_solid_box(Vector3((left + right) * 0.5, PAVEMENT_Y - 0.14, (front + back) * 0.5),
		Vector3(right - left, 0.28, back - front), palette["pavement"])


func _build_lobby() -> void:
	var base := Vector3(8.0, PAVEMENT_Y, FACADE_Z)
	var plaster := StandardMaterial3D.new()
	plaster.albedo_color = Color("#c2beb3")
	plaster.roughness = 0.85
	for level in STOREYS:
		var floor_origin := base + Vector3.UP * STOREY_HEIGHT * level
		var story := "Ground" if level == 0 else "Repeatable"
		var file := "GroundLobby_Storey" if level == 0 else "TypicalStorey_Repeatable"
		var floor_model := _model(APARTMENT + "PZ_Midrise_" + file + ".glb", floor_origin)
		floor_model.name = "HillviewFloor%d" % (level + 1)
		if level == 0:
			var hinge := floor_model.find_child("Story_Ground_GroundLobbyEntrance_HINGE_PIVOT", true, false) as Node3D
			# The source previews this leaf open. Reset it against the storey's axes.
			hinge.global_basis = floor_model.global_basis
			_entry("HillviewLobbyDoor", "apartment lobby door", hinge,
				Vector3(LOBBY_X, PAVEMENT_Y, FACADE_Z + 0.11), 1.34, 2.36)
		else:
			floor_model.find_child("Story_Repeatable_StructuralFloorSlab*", true, false).hide()
			floor_model.find_child("Story_Repeatable_StairFrontConnectionDeck", true, false).hide()
			_apartment_slab(floor_origin, plaster)
		_finish_lobby_floor(floor_model, story, floor_origin)
		_relocate_stairs(floor_model, story, floor_origin, level < STOREYS - 1, plaster)
		_stair_enclosure(floor_origin, plaster, level == STOREYS - 1)
		_mesh_collision(floor_model, ["Wall", "Slab", "Floor", "Surface", "Pane", "Partition",
			"Divider", "Separation", "BedroomSide", "BathroomSide", "OfficeSide", "BathSide",
			"KitchenCounterBlock", "Door_Leaf", "Casing", "SlidingGlassLeaf", "SlidingLeaf",
			"Guardrail", "CantileverDeck", "HalfLevelTurningLanding"])
		_furnish_apartment_floor(floor_origin, level)
	var roof := _model(APARTMENT + "PZ_Midrise_RoofCap.glb", base + Vector3.UP * STOREY_HEIGHT * STOREYS)
	_mesh_collision(roof, ["Slab", "Parapet"])


func _finish_lobby_floor(floor_model: Node3D, story: String, at: Vector3) -> void:
	var original := floor_model.find_child("Story_" + story + "_CoreCorridorSurface", true, false) as MeshInstance3D
	var tiles := original.get_active_material(0).duplicate() as BaseMaterial3D
	if furnished_safehouse and story == "Ground":
		tiles = FURNITURE.finish("tiled_floor_001", Color("#c4bbb0"), 1.51, 0.73)
	else:
		tiles.uv1_triplanar = true
	original.hide()
	_solid_box(at + Vector3(2.64, 0.013, 4.65), Vector3(4.84, 0.026, 8.86), tiles)


func _apartment_slab(at: Vector3, material: Material) -> void:
	# Replace the prefab's front stair/elevator openings with one rear stairwell.
	for rect: Rect2 in [
		Rect2(0.0, 0.0, 20.0, STAIR_FRONT),
		Rect2(0.0, STAIR_BACK, 20.0, 16.0 - STAIR_BACK),
		Rect2(0.0, STAIR_FRONT, STAIR_LEFT, STAIR_BACK - STAIR_FRONT),
		Rect2(STAIR_RIGHT, STAIR_FRONT, 20.0 - STAIR_RIGHT, STAIR_BACK - STAIR_FRONT),
	]:
		var center := rect.get_center()
		_solid_box(at + Vector3(center.x, -0.1, center.y), Vector3(rect.size.x, 0.2, rect.size.y), material)


func _relocate_stairs(floor_model: Node3D, story: String, at: Vector3, has_next_floor: bool, material: Material) -> void:
	var prefix := "Story_" + story + "_ElevatorAndUStair_"
	floor_model.find_child(prefix + "Doors", true, false).hide()
	var core := floor_model.find_child(prefix + "Core", true, false) as Node3D
	for node in core.get_children():
		var part := node as Node3D
		var name_string := String(part.name)
		if has_next_floor and ("Flight_" in name_string or "TurningLanding" in name_string or
				"Handrail" in name_string or "LandingInnerGuardRail" in name_string):
			part.position.z += STAIR_SHIFT
		else:
			part.hide()
	if has_next_floor:
		# The treads stay visible. A continuous surface supports the player capsule.
		_stair_ramp(at + Vector3(0.75, 0.0, STAIR_FRONT - 0.06),
			at + Vector3(0.75, STOREY_HEIGHT * 0.5, 13.19), 1.41, material)
		var upper_tread := at + Vector3(2.77, STOREY_HEIGHT, STAIR_FRONT + 0.32)
		_stair_ramp(at + Vector3(2.77, STOREY_HEIGHT * 0.5, 13.19),
			upper_tread, 1.41, material)
		_stair_surface(upper_tread, upper_tread - Vector3.BACK * 0.36, 1.41)
		for x in [0.69, 2.47, 4.24]:
			_solid_box(at + Vector3(x, 1.28, 11.52), Vector3(0.09, 2.54, 3.25))


func _stair_ramp(start: Vector3, finish: Vector3, width: float, material: Material) -> void:
	_stair_surface(start, finish, width)
	var side := Vector3.RIGHT * width
	var flight := finish - start
	var underside := BoxMesh.new()
	underside.size = Vector3(width, 0.13, flight.length())
	var lining := MeshInstance3D.new()
	lining.mesh = underside
	lining.material_override = material
	lining.position = (start + finish + side) * 0.5 - Vector3.UP * 0.11
	lining.rotation.x = atan2(-flight.y * signf(flight.z), absf(flight.z))
	add_child(lining)


func _stair_surface(start: Vector3, finish: Vector3, width: float) -> void:
	var side := Vector3.RIGHT * width
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(PackedVector3Array([start, start + side, finish,
		start + side, finish + side, finish]))
	_add_collider(Vector3.ZERO, shape)


func _stair_enclosure(at: Vector3, plaster: Material, top_floor: bool) -> void:
	var wall_height := STOREY_HEIGHT - 0.18
	for x in [STAIR_LEFT - 0.08, STAIR_RIGHT + 0.08]:
		_solid_box(at + Vector3(x, wall_height * 0.5, (STAIR_FRONT + STAIR_BACK) * 0.5),
			Vector3(0.16, wall_height, STAIR_BACK - STAIR_FRONT), plaster)
	_solid_box(at + Vector3(2.49, wall_height * 0.5, STAIR_BACK + 0.08),
		Vector3(4.55, wall_height, 0.16), plaster)
	_solid_box(at + Vector3(4.73, wall_height * 0.5, STAIR_FRONT + 0.08),
		Vector3(0.66, wall_height, 0.16), plaster)
	_solid_box(at + Vector3((STAIR_LEFT + STAIR_RIGHT) * 0.5, 2.71, STAIR_FRONT + 0.08),
		Vector3(STAIR_RIGHT - STAIR_LEFT, 0.47, 0.16), plaster)
	if top_floor:
		_solid_box(at + Vector3(1.66, 0.54, STAIR_FRONT), Vector3(2.13, 1.08, 0.12), palette["trim"])


func _furnish_apartment_floor(at: Vector3, level: int) -> void:
	for spot: Vector2 in [Vector2(2.8, 3.3), Vector2(2.6, 8.1), Vector2(7.5, 8.0),
			Vector2(12.2, 8.0), Vector2(17.0, 8.0), Vector2(9.4, 3.0), Vector2(15.6, 3.2),
			Vector2(8.4, 12.0), Vector2(16.4, 12.5)]:
		var fixture := at + Vector3(spot.x, 2.91, spot.y)
		if furnished_safehouse and level == 0 and spot.x < 4.0:
			continue
		_solid_box(fixture, Vector3(0.72, 0.06, 0.30), palette["ceiling_light"])
		_room_light(fixture - Vector3.UP * 0.16, 0.85, 4.9)
	_room_light(at + Vector3(2.47, 2.6, 13.1), 0.85, 5.4)
	var sofa := _model(CATALOG.PATHS["sofa"], at + Vector3(11.68, 0.025, 2.45), PI / 2.0)
	_mesh_collision(sofa, ["Sofa", "Seat", "Armrest", "Cushion"])
	var bed := _model(CATALOG.PATHS["bed"], at + Vector3(17.76, 0.025, 1.58))
	_mesh_collision(bed, ["Frame", "Mattress", "Bed"])
	var rear_sofa := _model(CATALOG.PATHS["sofa"], at + Vector3(5.76, 0.025, 10.75), -PI / 2.0)
	_mesh_collision(rear_sofa, ["Sofa", "Seat", "Armrest", "Cushion"])
	var table := _model(DINING_TABLE, at + Vector3(15.2, 0.025, 10.65))
	_mesh_collision(table, ["Table"])
	if furnished_safehouse:
		_dress_apartments(at, level)
	if level == 0 and not furnished_safehouse:
		var bench := _model(BENCH, at + Vector3(0.77, 0.025, 4.1), PI / 2.0)
		_mesh_collision(bench, ["Seat", "Back", "Leg", "Support"])
	_solid_box(at + Vector3(2.48, 2.68, STAIR_FRONT - 0.016),
		Vector3(1.8, 0.26, 0.04), palette["dark"])
	var sign := Label3D.new()
	sign.text = "STAIRS   /   LEVEL %02d" % (level + 1)
	sign.font_size = 52
	sign.pixel_size = 0.0035
	sign.outline_size = 5
	sign.modulate = Color("#e9d8aa")
	sign.position = at + Vector3(2.48, 2.68, STAIR_FRONT - 0.04)
	sign.rotation.y = PI
	add_child(sign)


func _dress_apartments(at: Vector3, level: int) -> void:
	var rug_color := [Color("#7b6757"), Color("#626d63"), Color("#766052")][level] as Color
	DRESSING.rug(self, at + Vector3(10.53, 0.052, 2.55), Vector2(2.54, 2.25), rug_color)
	DRESSING.rug(self, at + Vector3(7.03, 0.052, 10.73), Vector2(2.62, 2.18), rug_color.darkened(0.10))
	DRESSING.props(self, at, [
		["coffee_table_round_01", Vector3(10.59, 0.051, 2.53), 0.13, 0.64],
		["binder_notebook", Vector3(10.51, 0.37, 2.53), 0.47, 0.84, false],
		["potted_plant_02", Vector3(11.74, 0.05, 0.8), 0.2, 0.72],
		["metal_office_desk", Vector3(18.89, 0.05, 2.41), -PI / 2, 0.72],
		["desk_lamp_arm_01", Vector3(18.92, 0.62, 2.44), -PI / 2, 0.62, false],
		["coffee_table_round_01", Vector3(7.08, 0.051, 10.81), 0.13, 0.71],
		["dining_chair_02", Vector3(14.86, 0.05, 9.75), 0.1],
		["dining_chair_02", Vector3(15.42, 0.05, 11.59), PI - 0.13],
		["potted_plant_02", Vector3(17.95, 0.05, 10.49), 0.63, 0.70],
	])


func _finish_safehouse() -> void:
	var floor := PAVEMENT_Y + 0.028
	var ceiling := floor + 2.73
	var plaster := FURNITURE.finish("white_plaster_02", Color("#bbb7a4"), 1.0, 0.92)
	var ceiling_finish := plaster.duplicate() as StandardMaterial3D
	ceiling_finish.albedo_color = Color("#d8d3c3")
	ceiling_finish.normal_enabled = false
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color("#4c5c54")
	trim.roughness = 0.84
	var rail := StandardMaterial3D.new()
	rail.albedo_color = Color("#817d69")
	rail.roughness = 0.79
	# Line the interior face while preserving the existing window and doorway openings.
	_finish_wall(8.225, floor, ceiling, 5.00, 6.91, plaster)
	_finish_wall(8.225, floor, floor + 1.08, 6.91, 8.65, plaster)
	_finish_wall(8.225, floor + 2.39, ceiling, 6.91, 8.65, plaster)
	_finish_wall(8.225, floor, ceiling, 8.65, 14.65, plaster)
	_finish_wall(12.798, floor, ceiling, 7.02, 11.34, plaster)
	_finish_wall(12.798, floor, floor + 0.98, 11.34, 13.91, plaster)
	_finish_wall(12.798, floor + 2.37, ceiling, 11.34, 13.91, plaster)
	_finish_wall(12.798, floor, ceiling, 13.91, 14.65, plaster)
	for x: float in [8.24, 12.78]:
		_finish_wall(x, floor, floor + 0.095, 7.04, 14.59, trim)
		_finish_wall(x, floor + 0.91, floor + 0.959, 8.85, 14.59, rail)
	var lining := BoxMesh.new()
	lining.size = Vector3(4.56, 0.036, 9.69)
	var lid := MeshInstance3D.new()
	lid.mesh = lining
	lid.material_override = ceiling_finish
	lid.position = Vector3(10.51, ceiling, 9.78)
	add_child(lid)
	for z: float in [6.57, 9.68, 12.94]:
		var at := Vector3(10.51, ceiling - 0.021, z)
		var fixture := FURNITURE.library.piece(FURNITURE.FOLDER + "mounted_fluorescent_lights.glb", "mounted_fluorescent_lights_d")
		fixture.position = at
		add_child(fixture)
		for node in fixture.find_children("*", "MeshInstance3D", true, false):
			var light_mesh := node as MeshInstance3D
			for index in light_mesh.mesh.get_surface_count():
				var glass := light_mesh.get_active_material(index) as StandardMaterial3D
				if glass and "glass" in glass.resource_name:
					var tube := glass.duplicate() as StandardMaterial3D
					tube.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					tube.albedo_color = Color("#b8bcb1")
					tube.emission = Color("#fff1d3")
					tube.emission_energy_multiplier = 0.74
					safehouse_tubes.append(tube)
					light_mesh.set_surface_override_material(index, tube)
		_room_light(at - Vector3.UP * 0.18, 0.87, 4.55)
	var daylight := OmniLight3D.new()
	daylight.name = "WindowBounce"
	daylight.position = Vector3(8.58, 1.66, 7.72)
	daylight.omni_range = 4.3
	daylight.light_color = Color("#c6dded")
	daylight.light_energy = 0.46
	add_child(daylight)
	var entry_light := OmniLight3D.new()
	entry_light.name = "EntryWindowBounce"
	entry_light.position = Vector3(11.90, 2.12, 5.14)
	entry_light.omni_range = 5.45
	entry_light.light_color = Color("#dce9ed")
	entry_light.light_energy = 0.50
	add_child(entry_light)
	DRESSING.rug(self, Vector3(10.77, floor + 0.009, 7.89), Vector2(1.48, 1.92), Color("#60594e"))
	DRESSING.panel(self, "HILLVIEW  /  RESIDENT NOTICEBOARD", Vector3(8.258, floor + 1.88, 9.18),
		1.65, PI / 2, Color("#485349"))
	DRESSING.props(self, Vector3(0, floor, 0), [
		["potted_plant_02", Vector3(8.66, 0, 6.35), 0.24, 0.63],
		["wall_clock", Vector3(8.26, 2.18, 10.62), PI / 2, 1.0, false],
		["korean_fire_extinguisher_01", Vector3(12.53, 0, 10.97), -PI / 2, 0.91, false],
	])


func _finish_wall(x: float, bottom: float, top: float, start: float, finish: float, material: Material) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.014, top - bottom, finish - start)
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = Vector3(x, (bottom + top) * 0.5, (start + finish) * 0.5)
	add_child(mesh)


func _build_shop() -> void:
	# PZ-013 is authored Z-up. Rotate its street face toward the pilot road.
	var shop := _model(STOREFRONT, Vector3(0.0, PAVEMENT_Y - 0.06, FACADE_Z), PI)
	shop.name = "HillviewShopfront"
	shop.basis = shop.basis * Basis(Vector3.RIGHT, -PI / 2.0)
	var shutter := shop.find_child("PIVOT_Shutter_Curtain_SlideUp", true, false) as Node3D
	shutter.hide()
	var hinge := shop.find_child("PIVOT_Door_HingeRight", true, false) as Node3D
	_entry("HillviewShopDoor", "shop door", hinge,
		Vector3(SHOP_X, PAVEMENT_Y, FACADE_Z + 0.055), 0.892, 2.40)
	_mesh_collision(shop, ["Brick", "Glass", "Frame", "Reveal", "KickPlinth"])
	var middle := FACADE_Z + 3.65
	var height := PAVEMENT_Y + 1.78
	for side in [-1.0, 1.0]:
		_solid_box(Vector3(side * 2.89, height, middle), Vector3(0.22, 3.56, 7.3), palette["house_masonry"])
	_solid_box(Vector3(0.0, height, FACADE_Z + 7.19), Vector3(6.0, 3.56, 0.22), palette["house_masonry"])
	_solid_box(Vector3(0.0, PAVEMENT_Y + 3.64, middle), Vector3(6.28, 0.18, 7.55), palette["roof_a"])
	_solid_box(Vector3(0.0, PAVEMENT_Y - 0.14, middle), Vector3(6.0, 0.28, 7.3), palette["pavement"])
	var shelf := _model(SHELF, Vector3(1.78, PAVEMENT_Y, FACADE_Z + 4.7), -PI / 2.0)
	_mesh_collision(shelf, ["Shelf", "Frame"])
	if furnished_safehouse:
		_dress_shop(middle)
	else:
		_room_light(Vector3(0.0, PAVEMENT_Y + 2.9, middle))


func _dress_shop(middle: float) -> void:
	var origin := Vector3(0, PAVEMENT_Y, 0)
	var tile := FURNITURE.finish("tiled_floor_001", Color("#adad98"), 1.51, 0.73)
	GEO.box(self, origin + Vector3(0, 0.008, middle), Vector3(5.55, 0.015, 7.02), tile)
	DRESSING.fixture(self, origin + Vector3(0, 3.4, 7.1), Color("#fff1d4"), 1.04, 6.5)
	DRESSING.fixture(self, origin + Vector3(0, 3.4, 10.07), Color("#fff1d4"), 1.07, 6.7)
	DRESSING.props(self, origin, [
		["metal_office_desk", Vector3(1.85, 0, 6.65), PI, 0.96],
		["classic_laptop", Vector3(2.01, 0.76, 6.65), PI, 0.69, false],
		["long_life_food", Vector3(1.49, 0.76, 6.63), -0.08, 0.68, false],
		["metal_trash_can", Vector3(2.39, 0, 7.47), -0.13, 0.59],
		["wall_clock", Vector3(2.33, 2.12, 11.82), PI, 1.0, false],
	])
	DRESSING.panel(self, "HILLVIEW CORNER SHOP", origin + Vector3(0, 2.48, 11.81), 2.38, PI, Color("#536047"))
	DRESSING.rug(self, origin + Vector3(-0.19, 0.026, 5.66), Vector2(1.09, 0.75), Color("#53544a"))
	DRESSING.stocked_shelf(self, origin + Vector3(-1.02, 0, 11.62), PI)
	DRESSING.stocked_shelf(self, origin + Vector3(0.08, 0, 11.62), PI)


func _dress_hillview_frontage() -> void:
	DRESSING.props(self, Vector3(0, PAVEMENT_Y, 0), [
		["outdoor_table_chair_set_01", Vector3(-2.58, 0, 3.78), 0.23, 0.84],
		["planter_box_02", Vector3(2.53, 0, 4.15), 0],
		["planter_box_02", Vector3(13.21, 0, 4.19), 0],
		["potted_plant_02", Vector3(2.52, 0.43, 4.14), 0.29, 0.47, false],
		["potted_plant_02", Vector3(13.32, 0.43, 4.19), 0.71, 0.53, false],
		["metal_trash_can", Vector3(6.48, 0, 4.11), -0.29, 0.86],
		["trashbag", Vector3(6.01, 0, 4.21), -0.47, 0.68],
		["exterior_aircon_unit", Vector3(2.25, 2.52, 4.51), PI, 0.72, false],
	])


func _entry(node_name: String, title: String, leaf: Node3D, at: Vector3, width: float, height: float) -> void:
	var interaction := INTERACTION.new()
	interaction.name = node_name
	interaction.kind = INTERACTION.Kind.HINGE
	interaction.label_text = title
	interaction.position = at
	add_child(interaction)
	# Animate about a vertical Godot axis regardless of the source's orientation.
	var pivot := Node3D.new()
	interaction.add_child(pivot)
	pivot.global_position = leaf.global_position
	leaf.reparent(pivot, true)
	interaction.panels.append(pivot)
	interaction.hinge_open_angle = -PI / 2.0
	interaction.blocker = _solid_box(at + Vector3.UP * height * 0.5, Vector3(width, height, 0.14))


func _build_street_dressing() -> void:
	var bench_at := Vector3(16.8, PAVEMENT_Y, 3.8)
	var bench := _model(BENCH, bench_at, PI)
	_mesh_collision(bench, ["Seat", "Back", "Leg", "Support"])
	_model(PROPS + "KAL-01_v03_Draped_Jacket.glb", bench_at + Vector3(0.45, 0.13, 0.01), PI)
	var suitcase := _model(PROPS + "KAL-01_v03_Suitcase_Open_Hero.glb", Vector3(7.3, PAVEMENT_Y, 3.3), 0.42)
	_mesh_collision(suitcase, ["MAT_Suitcase"])
	var bicycle := _model(PROPS + "KAL-01_v03_Bicycle_Fallen_Hero.glb", Vector3(20.8, PAVEMENT_Y - 0.018, 1.25), 0.27)
	_mesh_collision(bicycle, ["MAT_Rubber", "MAT_PaintedMetal"])
	var sign := Label3D.new()
	sign.text = "HILLVIEW STEPS"
	sign.font_size = 48
	sign.outline_size = 5
	sign.pixel_size = 0.004
	sign.modulate = Color("#d7c39d")
	sign.position = Vector3(LOBBY_X + 2.0, PAVEMENT_Y + 2.7, FACADE_Z - 0.23)
	sign.rotation.y = PI
	add_child(sign)


func _room_light(at: Vector3, energy: float = 1.25, reach: float = 6.2) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = Color("#f7d9b0")
	light.light_energy = energy
	light.omni_range = reach
	add_child(light)


func _model(path: String, at: Vector3, yaw: float = 0.0) -> Node3D:
	var instance := models.instantiate(path)
	instance.position = at
	instance.rotation.y = yaw
	add_child(instance)
	return instance


func _mesh_collision(model: Node3D, solid_parts: Array[String]) -> void:
	var triangles := PackedVector3Array()
	var inverse := global_transform.affine_inverse()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if not part.is_visible_in_tree():
			continue
		for pattern in solid_parts:
			if pattern in String(part.name):
				triangles.append_array((inverse * part.global_transform) * part.mesh.get_faces())
				break
	if triangles.is_empty():
		push_error("Missing Hillview collision mesh parts in " + String(model.name))
		return
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(triangles)
	_add_collider(Vector3.ZERO, shape)


func _solid_box(at: Vector3, size: Vector3, material: Material = null) -> StaticBody3D:
	if material:
		var box := BoxMesh.new()
		box.size = size
		var visible_box := MeshInstance3D.new()
		visible_box.mesh = box
		visible_box.material_override = material
		visible_box.position = at
		add_child(visible_box)
	var shape := BoxShape3D.new()
	shape.size = size
	return _add_collider(at, shape)


func _add_collider(at: Vector3, shape: Shape3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	return body
