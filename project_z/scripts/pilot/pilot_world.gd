extends "res://scripts/neighborhood/neighborhood.gd"

const LANDSCAPE := preload("res://scripts/pilot/pilot_landscape.gd")
const PILOT_SURVIVOR := preload("res://scripts/pilot/pilot_survivor.gd")
const PILOT_INFECTED := preload("res://scripts/pilot/pilot_infected.gd")
const SEDAN := preload("res://scripts/pilot/pilot_driver.gd")
const HILLVIEW := preload("res://scripts/pilot/pilot_hillview.gd")
const BRIDGE_KIT := "res://assets/roads/streets/pz_044_urban_bridge_road_kit/"
const INFECTED_MODEL := LANDSCAPE.DATA + "PZ-188_Common_Infected_Animated_v01.glb"
const VEHICLE_MODEL := LANDSCAPE.DATA + "PZ-196_PZ141_Driving_Sedan_v01.glb"
const WAREHOUSE_MODEL := "res://assets/buildings/points_of_interest/pz_029_warehouse_building/ProjectZ_Warehouse_Building.glb"

var landscape: LANDSCAPE
var pilot_player: PILOT_SURVIVOR
var sedan: SEDAN
var spawn_point: Vector3
var arrival: Vector3
var last_safe: Vector3
var foot_west := false
var vehicle_west := false
var foot_crossed := false
var vehicle_crossed := false
var yard_on_foot := false
var yard_in_car := false


func _ready() -> void:
	_register_controls()
	if not InputMap.has_action("pilot_brake"):
		InputMap.add_action("pilot_brake")
		var brake := InputEventKey.new()
		brake.physical_keycode = KEY_SPACE
		InputMap.action_add_event("pilot_brake", brake)
	seeded.seed = 1790805
	_set_lighting()
	for child in get_children():
		if child is WorldEnvironment:
			child.environment.fog_density = 0.00155
			child.environment.fog_light_color = Color("#91a09d")
			child.environment.ambient_light_energy = 0.53
		elif child is DirectionalLight3D:
			child.directional_shadow_max_distance = 150.0
	landscape = LANDSCAPE.new()
	landscape.name = "PilotLandscape"
	add_child(landscape)
	if not landscape.build():
		get_tree().quit(1)
		return
	layout = Node3D.new()
	layout.name = "KaldranPilotObjects"
	add_child(layout)
	navigation.region = Rect2i(-515, -24, 178, 151)
	navigation.cell_size = Vector2(CELL, CELL)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	_build_palette()
	_build_pilot_roads()
	_build_northline()
	_build_hillview()
	_build_works()
	_build_vegetation()
	_build_sedan()
	_build_player()
	infected_left = 3
	_spawn_pilot_infected(4002.0, 5.7, 2.25)
	_spawn_pilot_infected(4225.0, -5.6, 2.38)
	_spawn_pilot_infected(4437.0, 5.4, 2.23)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_window().focus_exited.connect(_release_mouse)
	_refresh_hud()


func _build_player() -> void:
	hud = HUD.new()
	hud.district = "KALDRAN  /  NORTHLINE PILOT"
	hud.dialog_district = "KALDRAN  /  PILOT ROUTE"
	hud.movement_keys = "WASD  MOVE / DRIVE    SHIFT  SPRINT    E  USE"
	hud.action_keys = "SPACE  JUMP / BRAKE    LMB  SWING    H  HEAL    R  RESET"
	add_child(hud)
	pilot_player = PILOT_SURVIVOR.new()
	pilot_player.name = "PilotSurvivor"
	pilot_player.sedan = sedan
	spawn_point = _point(3915.0, 4760.2, 143.94)
	last_safe = spawn_point
	pilot_player.position = spawn_point
	pilot_player.rotation.y = -PI / 2.0
	survivor = pilot_player
	add_child(pilot_player)
	var crowbar := models.instantiate(CATALOG.PATHS["crowbar"])
	_restore_texture_tint(crowbar)
	pilot_player.equip_view_model(crowbar)
	pilot_player.state_changed.connect(_refresh_hud)
	pilot_player.message.connect(hud.announce)
	pilot_player.harmed.connect(hud.harm)
	pilot_player.hit_enemy.connect(hud.hit)
	pilot_player.cache_searched.connect(func(): searched += 1)
	pilot_player.died.connect(_defeated)


func _build_pilot_roads() -> void:
	var stations := landscape.road
	for index in range(stations.size() - 1):
		var start := stations[index]
		var finish := stations[index + 1]
		if start.x >= landscape.yard_start:
			break
		if start.x >= landscape.bridge_min and finish.x <= landscape.bridge_max:
			_place_file(BRIDGE_KIT + "PZ_Bridge_Span_12m_Weathered.glb", start + Vector3.UP * 0.026, -PI / 2.0)
			continue
		var model := _place("road", start + Vector3.UP * 0.015)
		var length := finish.distance_to(start)
		var forward := (finish - start) / length
		var across := forward.cross(Vector3.UP).normalized()
		model.basis = Basis(forward * (length / 10.0), across.cross(forward), across)
	var bridge_start := Vector3(landscape.bridge_min, landscape.bridge_height, landscape.bridge_center_z)
	var bridge_finish := Vector3(landscape.bridge_max, landscape.bridge_height, landscape.bridge_center_z)
	_place_file(BRIDGE_KIT + "PZ_Abutment_Near.glb", bridge_start, -PI / 2.0)
	_place_file(BRIDGE_KIT + "PZ_Abutment_Far.glb", bridge_finish, -PI / 2.0)
	for side in [-1.0, 1.0]:
		_block(bridge_start.lerp(bridge_finish, 0.5) + Vector3(0.0, 0.66, side * 5.47),
			Vector3(72.0, 1.3, 0.29), 0.0, false)
	_sign("KALDRAN RIVER BRIDGE", landscape.road_point(landscape.bridge_min - 8.0) + Vector3(0, 0, 6.0))
	_sign("NORTHLINE  /  WEST", landscape.road_point(landscape.bridge_max + 9.0) + Vector3(0, 0, -6.0))
	for e in [3972.0, 4060.0, 4160.0, 4260.0, 4380.0, 4434.0]:
		var center := landscape.road_point(e - landscape.origin.x)
		var at := center + Vector3(0.0, -0.16, 5.8)
		_place("lamp", at, PI)


func _build_northline() -> void:
	var house_a := _point(3919.0, 4785.0, 143.93)
	var house_b := _point(3947.0, 4784.0, 143.93)
	_house(house_a, false, "12  /  NORTHLINE", landscape.terrain_height(house_a.x - 2.0, house_a.z + 8.4))
	_house(house_b, true, "17  /  NORTHLINE", landscape.terrain_height(house_b.x - 2.0, house_b.z + 8.4))
	_place("sofa", house_a + Vector3(2.1, 0.0, -2.8))
	_block(house_a + Vector3(2.1, 0.4, -2.8), Vector3(2.18, 0.8, 0.9))
	_place("bed", house_b + Vector3(2.0, 0.0, -2.3))
	_block(house_b + Vector3(2.0, 0.37, -2.3), Vector3(1.75, 0.74, 2.17))
	_cache("roadside cache", _point(3917.0, 4760.2, 143.94), true, 1)
	_cache("Northline house cache", house_b + Vector3(-2.15, 0.02, -2.4), false, 1)
	_sign("NORTHLINE  /  KALDRAN PILOT", _point(3920.0, 4770.2, 143.82))
	_sign("INDUSTRIAL WORKS  /  EAST", _point(3954.0, 4769.8, 143.87))


func _build_hillview() -> void:
	var corner := HILLVIEW.new()
	corner.name = "HillviewSteps"
	corner.position = landscape.road_point(3921.0 - landscape.origin.x) + Vector3(0.0, 0.015, 4.55)
	layout.add_child(corner)
	corner.build(models, palette)
	var paving := corner.position + Vector3.UP * HILLVIEW.PAVEMENT_Y
	for side in [-1.0, 1.0]:
		var edge := paving + Vector3(HILLVIEW.SIDEWALK_LEFT if side < 0.0 else HILLVIEW.SIDEWALK_RIGHT, 0.0, HILLVIEW.CURB_DEPTH)
		landscape.grade_paved_edge(edge, edge + Vector3.BACK * (HILLVIEW.FACADE_Z - HILLVIEW.CURB_DEPTH),
			Vector3.RIGHT * side, palette["pavement"])


func _build_works() -> void:
	var base := landscape.to_scene(landscape.layout_data["industrial_origin"])
	for module: Dictionary in landscape.layout_data["industrial_modules"]:
		var offset: Array = module["offset"]
		var at := base + Vector3(offset[0], offset[1], offset[2])
		_place_file(LANDSCAPE.DATA + "industrial/" + module["name"] + ".glb", at)
		for proxy: Dictionary in module["collision"]:
			var low: Array = proxy["min"]
			var high: Array = proxy["max"]
			var a := Vector3(low[0], low[1], low[2])
			var b := Vector3(high[0], high[1], high[2])
			_block(at + (a + b) * 0.5, b - a, 0.0, false)
	# The yard pavement and workshop apron share one 46 by 15 metre surface.
	var yard_east := base + Vector3.RIGHT * 46.0
	var yard_south := base + Vector3.BACK * 15.0
	var far_corner := yard_east + Vector3.BACK * 15.0
	landscape.grade_paved_edge(base, yard_east, Vector3.FORWARD, palette["asphalt"])
	landscape.grade_paved_edge(yard_south, far_corner, Vector3.BACK, palette["asphalt"])
	landscape.grade_paved_edge(base, yard_south, Vector3.LEFT, palette["asphalt"])
	landscape.grade_paved_edge(yard_east, far_corner, Vector3.RIGHT, palette["asphalt"])
	var warehouse := landscape.to_scene(landscape.layout_data["warehouse_origin"])
	_place_file(WAREHOUSE_MODEL, warehouse)
	_block(warehouse + Vector3(17.5, 3.5, -12.5), Vector3(34.9, 7.0, 24.9), 0.0, false)
	arrival = _point(4447.0, 4805.0, 130.42)
	_cache("works supply cache", _point(4438.0, 4801.2, 130.44), false, 2)
	_sign("KALDRAN INDUSTRIAL WORKS", _point(4424.0, 4800.0, 130.42))
	_sign("YARD CHECKPOINT", _point(4449.0, 4800.0, 130.42))


func _build_sedan() -> void:
	sedan = SEDAN.new()
	sedan.name = "PilotSedan"
	sedan.shell = models.instantiate(VEHICLE_MODEL)
	sedan.add_child(sedan.shell)
	sedan.position = _point(3938.0, 4761.0, 143.97)
	sedan.rotation.y = PI / 2.0
	layout.add_child(sedan)
	sedan.door.rotation.y = deg_to_rad(26.0)
	_world_label("DRIVABLE SEDAN", sedan.position + Vector3.UP * 1.82, true, 34)


func _spawn_pilot_infected(east: float, lateral: float, pace: float) -> void:
	var enemy := PILOT_INFECTED.new()
	enemy.name = "PilotInfected_%d" % int(east)
	var at := landscape.road_point(east - landscape.origin.x)
	at.z += lateral
	at.y = maxf(at.y, landscape.terrain_height(at.x, at.z)) + 0.03
	enemy.position = at
	enemy.speed = pace
	enemy.target = pilot_player
	enemy.route = _pilot_route
	enemy.visual = models.instantiate(INFECTED_MODEL)
	enemy.add_child(enemy.visual)
	enemy.killed.connect(_infected_killed)
	add_child(enemy)


func _pilot_route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var nearby := _route(from, to)
	if not nearby.is_empty():
		return nearby
	var result := PackedVector3Array()
	var sign_x := signf(to.x - from.x)
	var first := landscape.road_point(from.x)
	if absf(from.z - first.z) > 1.4:
		result.append(first)
	for distance in [4.0, 12.0, 22.0]:
		if distance < absf(to.x - from.x):
			result.append(landscape.road_point(from.x + sign_x * distance))
	result.append(to)
	return result


func _process(_delta: float) -> void:
	if pilot_player == null or ended:
		return
	var at := sedan.global_position if pilot_player.driving else pilot_player.global_position
	if at.y < -12.0 or landscape.outside(at) or landscape.submerged(at):
		if pilot_player.driving:
			sedan.recover()
		else:
			pilot_player.global_position = last_safe
			pilot_player.velocity = Vector3.ZERO
		hud.announce("River or pilot boundary reached. Returned to dry ground.")
		return
	var station := landscape.road_point(at.x)
	if not pilot_player.driving and pilot_player.is_on_floor() and not landscape.is_wet(at.x, at.z):
		last_safe = at + Vector3.UP * 0.03
	if absf(at.z - station.z) < 8.0:
		if at.x < landscape.bridge_min - 5.0:
			if pilot_player.driving:
				vehicle_west = true
			else:
				foot_west = true
		elif at.x > landscape.bridge_max + 5.0:
			if pilot_player.driving:
				vehicle_crossed = vehicle_west
			else:
				foot_crossed = foot_west
		if at.distance_to(arrival) < 12.0:
			if pilot_player.driving and vehicle_crossed and not yard_in_car:
				yard_in_car = true
				hud.announce("Industrial yard reached by sedan.")
			elif not pilot_player.driving and foot_crossed and not yard_on_foot:
				yard_on_foot = true
				hud.announce("Industrial yard reached on foot.")
	_update_objective(at)
	if not pilot_player.active:
		return
	var prompt := ""
	if pilot_player.driving:
		prompt = "[E] Exit sedan" if absf(sedan.speed) < 0.65 else ""
	elif sedan.can_board(pilot_player, pilot_player.camera):
		prompt = "[E] Enter sedan"
	elif is_instance_valid(pilot_player.focused):
		prompt = pilot_player.focused.prompt()
	hud.show_prompt(prompt)


func _update_objective(at: Vector3) -> void:
	var distance := int(round(at.distance_to(arrival)))
	hud.objectives.text = "%02d INFECTED LEFT\nINDUSTRIAL YARD  %03d m" % [infected_left, distance]
	if yard_on_foot or yard_in_car:
		hud.hint.text = "Yard reached %s." % ("on foot and by sedan" if yard_on_foot and yard_in_car else ("on foot" if yard_on_foot else "by sedan"))
	elif pilot_player.driving:
		hud.hint.text = "%d km/h   Follow the road east. Space to brake." % int(absf(sedan.speed) * 3.6)
	else:
		hud.hint.text = "Follow the road east across the bridge." if pilot_player.has_weapon else "Search the roadside crate for a crowbar."


func _refresh_hud() -> void:
	if not pilot_player or not hud:
		return
	hud.refresh(pilot_player.health, pilot_player.medkits, searched, infected_left, pilot_player.has_weapon)
	_update_objective(pilot_player.global_position)
	if not ended:
		if pilot_player.active:
			hud.hide_overlay()
		else:
			hud.show_overlay("Pilot paused", "Click to resume. Press R to restart at Northline.")


func _infected_killed() -> void:
	infected_left -= 1
	_refresh_hud()
	hud.announce("Infected down. %d remaining." % infected_left)


func _defeated() -> void:
	ended = true
	hud.show_overlay("Survivor down", "Press R to restart the Northline pilot.")


func _build_vegetation() -> void:
	var oak: Array[Transform3D] = []
	var pine: Array[Transform3D] = []
	for index in 650:
		var x := seeded.randf_range(-640.0, 340.0)
		var z := seeded.randf_range(-685.0, 285.0)
		if index < 180:
			x = seeded.randf_range(-260.0, 330.0)
			z = landscape.road_point(x).z + seeded.randf_range(-51.0, 50.0)
		var at := Vector3(x, landscape.terrain_height(x, z), z)
		if landscape.is_wet(x, z) or not _tree_site_clear(at):
			continue
		var size := seeded.randf_range(0.7, 1.24)
		var pose := Transform3D(Basis(Vector3.UP, seeded.randf_range(0.0, TAU)).scaled(Vector3.ONE * size), at)
		(pine if at.y > 38.0 or index % 5 < 2 else oak).append(pose)
		if index < 180:
			_block(at + Vector3.UP * 0.8, Vector3(0.56, 1.6, 0.56) * size, 0, false)
	_instance_trees("oak", oak)
	_instance_trees("pine", pine)


func _tree_site_clear(at: Vector3) -> bool:
	var lane := landscape.road_point(at.x)
	if Vector2(at.x - lane.x, at.z - lane.z).length() < 11.0:
		return false
	for site: Dictionary in landscape.layout_data["sites"]:
		var b: Array = site["bounds_m"]
		var east := at.x + landscape.origin.x
		var north := landscape.origin.z - at.z
		if east > b[0] - 5.0 and east < b[1] + 5.0 and north > b[2] - 5.0 and north < b[3] + 5.0:
			return false
	return true


func _instance_trees(key: String, poses: Array[Transform3D]) -> void:
	if poses.is_empty():
		return
	var template := models.instantiate(CATALOG.PATHS[key])
	layout.add_child(template)
	for child in template.find_children("*", "MeshInstance3D", true, false):
		var piece := child as MeshInstance3D
		var scatter := MultiMesh.new()
		scatter.transform_format = MultiMesh.TRANSFORM_3D
		var geometry := piece.mesh.duplicate() as Mesh
		for surface in geometry.get_surface_count():
			geometry.surface_set_material(surface, piece.get_active_material(surface))
		scatter.mesh = geometry
		scatter.instance_count = poses.size()
		var local := template.global_transform.affine_inverse() * piece.global_transform
		for i in poses.size():
			scatter.set_instance_transform(i, poses[i] * local)
		var cluster := MultiMeshInstance3D.new()
		cluster.multimesh = scatter
		layout.add_child(cluster)
	template.free()


func _sign(title: String, at: Vector3) -> void:
	_box(at + Vector3.UP * 0.65, Vector3(0.13, 1.3, 0.13), "trim")
	var text := _world_label(title, at + Vector3.UP * 1.55, true, 39)
	text.pixel_size = 0.0064


func _point(east: float, north: float, height: float) -> Vector3:
	return landscape.to_scene([east, north, height])


func _place_file(path: String, at: Vector3, yaw: float = 0.0) -> Node3D:
	var model := models.instantiate(path)
	model.position = at
	model.rotation.y = yaw
	layout.add_child(model)
	return model
