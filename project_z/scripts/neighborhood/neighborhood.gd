extends Node3D

const CATALOG := preload("res://scripts/neighborhood/neighborhood_catalog.gd")
const MODELS := preload("res://scripts/neighborhood/neighborhood_assets.gd")
const SURVIVOR := preload("res://scripts/neighborhood/neighborhood_survivor.gd")
const INFECTED := preload("res://scripts/neighborhood/neighborhood_infected.gd")
const INTERACTION := preload("res://scripts/neighborhood/neighborhood_interaction.gd")
const HUD := preload("res://scripts/neighborhood/neighborhood_hud.gd")
const GROUND := preload("res://materials/neighborhood_ground.gdshader")

const CELL := 0.5
const STREET_Y := 0.023
const TERRAIN_Y := -0.016
const FENCE_PANEL_WIDTH := 2.0
const SLAB_Y := 0.042
const HOUSE_HALF_SPAN := 4.0
const HOUSE_WALL_HEIGHT := 3.0
const ROOF_OVERHANG := 0.32
const ROOF_RISE := 1.53
const ROOF_THICKNESS := 0.16

var models := MODELS.new()
var navigation := AStarGrid2D.new()
var survivor: SURVIVOR
var hud: HUD
var layout: Node3D
var searched := 0
var infected_left := 4
var ended := false
var palette: Dictionary
var seeded := RandomNumberGenerator.new()


func _ready() -> void:
	seeded.seed = 4262026
	_register_controls()
	navigation.region = Rect2i(-99, -99, 199, 199)
	navigation.cell_size = Vector2(CELL, CELL)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	layout = Node3D.new()
	layout.name = "NorthlineStreetLayout"
	add_child(layout)
	_set_lighting()
	_build_palette()
	_build_ground_and_streets()
	_build_houses_and_market()
	_build_street_details()

	hud = HUD.new()
	add_child(hud)
	survivor = SURVIVOR.new()
	survivor.name = "Survivor"
	survivor.position = Vector3(-12.0, 0.04, 19.4)
	survivor.rotation.y = -0.46
	add_child(survivor)
	var crowbar := models.instantiate(CATALOG.PATHS["crowbar"])
	_restore_texture_tint(crowbar)
	survivor.equip_view_model(crowbar)
	survivor.state_changed.connect(_refresh_hud)
	survivor.message.connect(hud.announce)
	survivor.harmed.connect(hud.harm)
	survivor.hit_enemy.connect(hud.hit)
	survivor.cache_searched.connect(func(): searched += 1)
	survivor.died.connect(_defeated)

	_spawn_infected("zombie", Vector3(-25.0, 0.02, -9.6), 2.35)
	_spawn_infected("worker", Vector3(24.0, 0.02, -9.5), 2.05)
	_spawn_infected("medic", Vector3(15.0, 0.02, 24.5), 2.55)
	_spawn_infected("zombie", Vector3(-33.0, 0.02, 22.0), 2.30)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_window().focus_exited.connect(_release_mouse)
	_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("neighborhood_restart") and not event.is_echo():
		get_tree().reload_current_scene()


func _process(_delta: float) -> void:
	if survivor and survivor.active:
		hud.show_prompt(survivor.focused.prompt() if is_instance_valid(survivor.focused) else "")


func _refresh_hud() -> void:
	hud.refresh(survivor.health, survivor.medkits, searched, infected_left, survivor.has_weapon)
	if ended or survivor.finished:
		return
	if survivor.active:
		hud.hide_overlay()
	else:
		hud.show_overlay("Paused", "Click to resume the patrol. Press R to restart the block.")


func _release_mouse() -> void:
	if not ended and survivor.active:
		survivor.active = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh_hud()


func _defeated() -> void:
	ended = true
	hud.show_overlay("Survivor down", "Northline is still overrun. Press R to restart the patrol.")


func _infected_killed() -> void:
	infected_left -= 1
	_refresh_hud()
	if infected_left == 0:
		ended = true
		survivor.stop()
		hud.show_overlay("Block secured", "All four infected are down. You searched %d of 5 caches. Press R to replay." % searched)
	else:
		hud.announce("Infected down. %d remaining." % infected_left)


func _register_controls() -> void:
	var keymap := {
		"neighborhood_left": KEY_A, "neighborhood_right": KEY_D,
		"neighborhood_forward": KEY_W, "neighborhood_back": KEY_S,
		"neighborhood_jump": KEY_SPACE,
		"neighborhood_sprint": KEY_SHIFT, "neighborhood_interact": KEY_E,
		"neighborhood_heal": KEY_H, "neighborhood_pause": KEY_ESCAPE, "neighborhood_restart": KEY_R,
	}
	for action in keymap:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var key := InputEventKey.new()
			key.physical_keycode = keymap[action]
			InputMap.action_add_event(action, key)
	if not InputMap.has_action("neighborhood_swing"):
		InputMap.add_action("neighborhood_swing")
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("neighborhood_swing", button)


func _set_lighting() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#344b68")
	sky_material.sky_horizon_color = Color("#b09280")
	sky_material.ground_horizon_color = Color("#80796d")
	sky_material.ground_bottom_color = Color("#26353a")
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#b6ccdf")
	environment.ambient_light_energy = 0.43
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("#777f8d")
	environment.fog_density = 0.0041
	environment.fog_sky_affect = 0.23
	var atmosphere := WorldEnvironment.new()
	atmosphere.environment = environment
	add_child(atmosphere)

	var sun := DirectionalLight3D.new()
	sun.name = "LateSun"
	sun.rotation_degrees = Vector3(-24, -39, 0)
	sun.light_color = Color("#ffcf9d")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 66
	add_child(sun)


func _build_palette() -> void:
	var colors := {
		"pavement": Color("#858078"), "gravel": Color("#6d6858"),
		"marking": Color("#d1b168"), "roof_a": Color("#293b42"),
		"roof_b": Color("#59403a"), "trim": Color("#7f7766"),
		"gable_a": Color("#727b72"), "gable_b": Color("#8a7b62"),
		"asphalt": Color("#34383b"), "barrier": Color("#696c64"),
		"dark": Color("#222a2a"), "plate": Color("#d3ad67"),
	}
	for key in colors:
		var paint := StandardMaterial3D.new()
		paint.albedo_color = colors[key]
		paint.roughness = 0.91
		palette[key] = paint
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.24, 0.40, 0.42, 0.48)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.24
	palette["glass"] = glass
	for key in ["gable_a", "gable_b"]:
		palette[key].cull_mode = BaseMaterial3D.CULL_DISABLED
	var window_sample := models.instantiate(CATALOG.PATHS["window_wall"])
	var core := window_sample.find_child("WALL_MasonryCore_TrueThroughOpening", true, false) as MeshInstance3D
	if core:
		var masonry := core.get_active_material(0).duplicate() as BaseMaterial3D
		# Use the same world-aligned brick courses on solid, window, and doorway modules.
		masonry.uv1_triplanar = true
		masonry.uv1_world_triplanar = true
		masonry.uv1_scale = Vector3.ONE
		palette["house_masonry"] = masonry
	window_sample.free()
	var diffuser := StandardMaterial3D.new()
	diffuser.albedo_color = Color("#ebd6ab")
	diffuser.emission_enabled = true
	diffuser.emission = Color("#ebd6ab")
	diffuser.emission_energy_multiplier = 0.36
	palette["ceiling_light"] = diffuser


func _build_ground_and_streets() -> void:
	var terrain := MeshInstance3D.new()
	terrain.name = "NeighborhoodTerrain"
	var surface := PlaneMesh.new()
	surface.size = Vector2(185, 185)
	terrain.mesh = surface
	terrain.position.y = TERRAIN_Y
	var ground_material := ShaderMaterial.new()
	ground_material.shader = GROUND
	terrain.material_override = ground_material
	layout.add_child(terrain)
	_block(Vector3(0, -0.26, 0), Vector3(100, 0.52, 100), 0, false)
	for side in [-1, 1]:
		_block(Vector3(side * 50.2, 2.0, 0), Vector3(0.4, 4, 100), 0, false)
		_block(Vector3(0, 2.0, side * 50.2), Vector3(100, 4, 0.4), 0, false)

	_place("crossing", Vector3(0, STREET_Y, 0))
	for section in [[-50.0, 8.0], [-42.0, 10.0], [-32.0, 10.0], [-22.0, 10.0],
			[12.0, 10.0], [22.0, 10.0], [32.0, 10.0], [42.0, 8.0]]:
		var start: float = section[0]
		var stretch: float = section[1] / 10.0
		_place("road", Vector3(start, STREET_Y, 0), 0, Vector3(stretch, 1, 1))
		_place("road", Vector3(0, STREET_Y, start), -PI / 2.0, Vector3(stretch, 1, 1))
	for coordinate in [-47, -41, -35, -29, -23, -17, 17, 23, 29, 35, 41, 47]:
		_box(Vector3(coordinate, 0.027, 0), Vector3(2.3, 0.005, 0.09), "marking")
		_box(Vector3(0, 0.027, coordinate), Vector3(0.09, 0.005, 2.3), "marking")
	for side in [-1, 1]:
		for start in [-38, 26]:
			_box(Vector3(start, 0.012, side * 5.8), Vector3(25, 0.04, 1.7), "pavement")
			_box(Vector3(side * 5.8, 0.012, start), Vector3(1.7, 0.04, 25), "pavement")

	for at: Vector3 in [Vector3(-46, 0, 0), Vector3(46, 0, 0), Vector3(0, 0, -46), Vector3(0, 0, 46)]:
		var yaw := PI / 2.0 if absf(at.x) > 0 else 0.0
		for shift in [-2.6, 0.0, 2.6]:
			var barrier_position := at + Basis(Vector3.UP, yaw) * Vector3(shift, 0.42, 0)
			_box(barrier_position, Vector3(2.45, 0.84, 0.68), "barrier", Vector3(0, yaw, 0))
			_box(barrier_position + Vector3.UP * 0.16, Vector3(2.35, 0.12, 0.695), "marking", Vector3(0, yaw, 0))
			_block(barrier_position, Vector3(2.45, 0.84, 0.68), yaw)


func _build_houses_and_market() -> void:
	var a := Vector3(-24, SLAB_Y, -20)
	var b := Vector3(25, SLAB_Y, -21)
	_house(a, false, "12  /  WEST WALK")
	_house(b, true, "17  /  EAST WALK")

	_place("sofa", a + Vector3(2.1, 0.01, -2.8), 0.05)
	_block(a + Vector3(2.1, 0.4, -2.8), Vector3(2.18, 0.8, 0.90))
	_place("bed", b + Vector3(2.05, 0.01, -2.33), 0)
	_block(b + Vector3(2.05, 0.37, -2.33), Vector3(1.75, 0.74, 2.17))
	_cache("west house cache", a + Vector3(-2.1, 0.01, -2.6), false, 1)
	_cache("east house cache", b + Vector3(-2.4, 0.01, -2.7), false, 1)

	var origin := Vector3(28, SLAB_Y, 18)
	var shop := _place("market", origin, PI)
	var sign := shop.find_child("SIGNAGE__NORTHLINE_MARKET_Main_Signage", true, false) as MeshInstance3D
	if sign:
		var face := sign.get_active_material(0) as BaseMaterial3D
		if face:
			# The sign's mesh maps the top of the artwork to the bottom of the panel.
			var upright := face.duplicate() as BaseMaterial3D
			upright.uv1_offset.y += upright.uv1_scale.y
			upright.uv1_scale.y *= -1.0
			sign.set_surface_override_material(0, upright)
	for region in [
		Vector4(0, -7.0, 0.22, 14), Vector4(10, -7.0, 0.22, 14),
		Vector4(2.08, 0, 4.16, 0.22), Vector4(7.92, 0, 4.16, 0.22),
		Vector4(3.50, -14, 7.0, 0.22), Vector4(9.75, -14, 0.50, 0.22),
		Vector4(6.58, -10.65, 1.15, 0.19), Vector4(9.13, -10.65, 1.75, 0.19),
		Vector4(6.12, -12.27, 0.19, 3.14),
	]:
		var local := Vector3(region.x, 1.52, region.y)
		_block(origin + Basis(Vector3.UP, PI) * local, Vector3(region.z, 3.04, region.w), PI)
	_block(Vector3(23, SLAB_Y - 0.11, 25), Vector3(10, 0.22, 14), 0, false)
	_sliding_door(shop, Vector3(23, SLAB_Y, 17.79))
	_box(Vector3(23, 0.006, 13.7), Vector3(11.1, 0.03, 8.45), "pavement")
	for x in [20.2, 23.0, 25.8]:
		for z in [21.8, 25.0]:
			_place("stocked_shelf" if x == 23.0 else "shelf", Vector3(x, SLAB_Y, z), PI / 2.0)
			_block(Vector3(x, 1.08, z), Vector3(2.0, 2.12, 0.76), PI / 2.0)
	_cache("grocery stockroom cache", Vector3(19.55, SLAB_Y, 30.2), false, 2)
	_light(Vector3(23, 3.15, 18.9), Color("#ffc782"), 3.1, 9.0)
	_light(Vector3(23, 3.14, 26), Color("#d6e0c4"), 2.8, 8.5)


func _house(center: Vector3, damaged: bool, street_sign: String, approach_y: float = 0.0) -> void:
	for x in [-2, 2]:
		for z in [-2, 2]:
			_place("floor" if not damaged else "tile", center + Vector3(x, 0, z))
			var ceiling_yaw := (int(x > 0) + 2 * int(z > 0)) * PI / 2.0
			var ceiling := _place("ceiling", center + Vector3(x, HOUSE_WALL_HEIGHT - 0.12, z), ceiling_yaw)
			var tile_trim := ceiling.find_child("Ceiling_Perimeter_J_Trim", true, false) as MeshInstance3D
			if tile_trim:
				tile_trim.hide()
	_block(center - Vector3.UP * 0.09, Vector3(8, 0.18, 8), 0, false)
	_block(center + Vector3.UP * (HOUSE_WALL_HEIGHT - 0.06), Vector3(8, 0.12, 8), 0, false)
	for x in [-2, 2]:
		var front := center + Vector3(x, 0, 4)
		if x == -2:
			var doorway := _place("door_wall", front - Vector3(2, 0, 0))
			_apply_masonry(doorway, "SM_Wall_Doorway_StructuralCore")
			for left in [-1.225, 1.225]:
				_block(front + Vector3(left, 1.5, 0), Vector3(1.55, 3.0, 0.25))
			_hinged_door(front)
		else:
			_wall(front, 0, "window_wall")
		_wall(center + Vector3(x, 0, -4), PI, "window_wall" if x == -2 else ("damage_wall" if damaged else "wall"))
	for z in [-2, 2]:
		_wall(center + Vector3(4, 0, z), PI / 2.0, "window_wall" if z < 0 else "wall")
		_wall(center + Vector3(-4, 0, z), -PI / 2.0, "wall" if z < 0 else "window_wall")

	_house_roof(center, damaged)
	_house_walkway(center + Vector3(-2, 0, 4), approach_y)
	_box(center + Vector3(-2, 2.67, 4.25), Vector3(1.93, 0.34, 0.10), "dark")
	_world_label(street_sign, center + Vector3(-2, 2.68, 4.31), false, 28)
	_light(center + Vector3(-2, 2.28, 4.46), Color("#f9b672"), 1.45, 5.2)
	var fixture := center + Vector3(0, HOUSE_WALL_HEIGHT - 0.145, -0.5)
	_box(fixture, Vector3(0.72, 0.06, 0.37), "dark")
	_box(fixture - Vector3.UP * 0.04, Vector3(0.62, 0.04, 0.30), "ceiling_light")
	_light(fixture - Vector3.UP * 0.22, Color("#f5d3ab"), 2.45, 6.8)


func _house_walkway(door: Vector3, approach_y: float) -> void:
	# Run the porch from grade to the top of the floor collider.
	var threshold := door - Vector3.BACK * 0.045
	var path_start := door + Vector3.BACK * 4.4
	path_start.y = approach_y - 0.012
	var left := Vector3.LEFT * 0.825
	var right := -left
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(palette["pavement"])
	for vertex: Vector3 in [
		threshold + left, threshold + right, path_start + left,
		threshold + right, path_start + right, path_start + left,
	]:
		surface.add_vertex(vertex)
	surface.generate_normals()
	var walkway := MeshInstance3D.new()
	walkway.name = "HouseEntryWalkway"
	walkway.mesh = surface.commit()
	layout.add_child(walkway)
	walkway.create_trimesh_collision()


func _house_roof(center: Vector3, damaged: bool) -> void:
	var roof_key := "roof_b" if damaged else "roof_a"
	var gable_key := "gable_b" if damaged else "gable_a"
	var eave := HOUSE_HALF_SPAN + ROOF_OVERHANG
	var slope := ROOF_RISE / HOUSE_HALF_SPAN
	var pitch := atan(slope)
	var ridge := HOUSE_WALL_HEIGHT - 0.035 + ROOF_RISE
	var ridge_overlap := 0.045
	var panel_midpoint := (eave - ridge_overlap) * 0.5
	var panel_length := (eave + ridge_overlap) / cos(pitch)
	var panel_height := ridge - panel_midpoint * slope + ROOF_THICKNESS * 0.5 / cos(pitch)
	for side: int in [-1, 1]:
		var angles := Vector3(side * pitch, 0, 0)
		_box(center + Vector3(0, panel_height, side * panel_midpoint), Vector3(8.65, ROOF_THICKNESS, panel_length), roof_key, angles)
		_box(center + Vector3(0, ridge - eave * slope + 0.06, side * eave), Vector3(8.67, 0.17, 0.12), "trim")
		_gable(center + Vector3(side * (HOUSE_HALF_SPAN + 0.105), 0, 0), gable_key, side, ridge)
		for x in [-3.2, -1.6, 0.0, 1.6, 3.2]:
			_box(center + Vector3(x, panel_height + 0.094, side * panel_midpoint), Vector3(0.033, 0.045, panel_length - 0.08), roof_key, angles)
	_box(center + Vector3(0, ridge + 0.155, 0), Vector3(8.65, 0.11, 0.23), roof_key)


func _wall(at: Vector3, yaw: float, model: String) -> void:
	var panel := _place(model, at, yaw)
	_block(at + Vector3.UP * HOUSE_WALL_HEIGHT * 0.5, Vector3(4, HOUSE_WALL_HEIGHT, 0.26), yaw)
	if model == "window_wall":
		_apply_masonry(panel, "WALL_MasonryCore_TrueThroughOpening")
		_box(at + Vector3(0, 1.77, 0) + Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.10), Vector3(1.40, 1.42, 0.023), "glass", Vector3(0, yaw, 0))
	else:
		_apply_masonry(panel, "Render_Brick_Masonry_Core")
		var rear := panel.find_child("Render_Rear_Concrete_Finish", true, false) as MeshInstance3D
		if rear:
			rear.hide()
		var plaster := panel.find_child("Render_Front_Concrete_Plaster", true, false) as MeshInstance3D
		if plaster and model == "wall":
			plaster.hide()
		elif plaster:
			_restore_texture_tint(plaster)
			_apply_masonry(panel, "Render_Exposed_Brick_Courses")


func _restore_texture_tint(model: Node3D) -> void:
	# These source exports multiply their embedded textures by 1/255.
	var materials: Dictionary = {}
	var faces := model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		faces.append(model)
	for node in faces:
		var face := node as MeshInstance3D
		for surface in face.mesh.get_surface_count():
			var material := face.get_active_material(surface) as BaseMaterial3D
			if material == null or material.albedo_texture == null:
				continue
			if not materials.has(material):
				var corrected := material.duplicate() as BaseMaterial3D
				corrected.albedo_color = Color.WHITE
				materials[material] = corrected
			face.set_surface_override_material(surface, materials[material])


func _apply_masonry(panel: Node3D, part: String) -> void:
	var face := panel.find_child(part, true, false) as MeshInstance3D
	if face and palette.has("house_masonry"):
		face.material_override = palette["house_masonry"]


func _gable(at: Vector3, key: String, side: int, ridge: float) -> void:
	var triangles := SurfaceTool.new()
	triangles.begin(Mesh.PRIMITIVE_TRIANGLES)
	triangles.set_material(palette[key])
	var base := HOUSE_WALL_HEIGHT - 0.10
	var span := HOUSE_HALF_SPAN + 0.13
	triangles.add_vertex(Vector3(0, base, side * span))
	triangles.add_vertex(Vector3(0, ridge + 0.075, 0))
	triangles.add_vertex(Vector3(0, base, -side * span))
	triangles.generate_normals()
	var shape := MeshInstance3D.new()
	shape.mesh = triangles.commit()
	shape.position = at
	shape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	layout.add_child(shape)


func _hinged_door(at: Vector3) -> void:
	var entry := INTERACTION.new()
	entry.kind = INTERACTION.Kind.HINGE
	entry.label_text = "house door"
	entry.position = at
	layout.add_child(entry)
	var model := models.instantiate(CATALOG.PATHS["door"])
	model.scale = Vector3(0.89, 0.936, 1.0)
	entry.add_child(model)
	var panel := model.find_child("DoorLeaf_HingePivot", true, false) as Node3D
	if panel:
		# The source leaf sits under a Z-up conversion. Give the animation a Y-up pivot.
		var hinge := Node3D.new()
		hinge.name = "UprightHinge"
		entry.add_child(hinge)
		hinge.global_position = panel.global_position
		panel.reparent(hinge, true)
		entry.panels.append(hinge)
		entry.closed_yaw = hinge.rotation.y
	entry.blocker = _block(at + Vector3.UP * 1.03, Vector3(0.89, 2.06, 0.14), 0, false)


func _sliding_door(shop: Node3D, at: Vector3) -> void:
	var entry := INTERACTION.new()
	entry.kind = INTERACTION.Kind.SLIDING
	entry.label_text = "grocery doors"
	entry.position = at
	layout.add_child(entry)
	var doors := shop.find_child("GROUP__MOVING_DOORS", true, false) as Node3D
	for side in ["Left", "Right"]:
		var panel := Node3D.new()
		doors.add_child(panel)
		for piece in doors.get_children():
			if String(piece.name).begins_with("MOVING_DOORS__Sliding_Glass_Leaf_" + side):
				piece.reparent(panel, true)
		panel.position.x = 0.86 if side == "Left" else -0.86
		entry.panels.append(panel)
		entry.closed_positions.append(panel.position)
	entry.blocker = _block(at + Vector3.UP * 1.43, Vector3(1.57, 2.86, 0.14), 0, false)


func _build_street_details() -> void:
	_cache("roadside supply crate", Vector3(-10.55, 0.01, 16.6), true, 1)
	_cache("pickup cargo cache", Vector3(-31.0, 0.01, 16.2), false, 1)
	_park("truck", Vector3(-34.1, TERRAIN_Y, 14.65), 0.24, Vector3(5.99, 1.95, 2.36))
	_park("car", Vector3(9.0, TERRAIN_Y, -15.5), 1.22, Vector3(4.88, 1.48, 2.23))
	_park("car", Vector3(35.2, TERRAIN_Y, 14.2), -0.19, Vector3(4.88, 1.48, 2.23))
	_fence_run(Vector3(-34, 0, -28.4), 10, 0)
	_fence_run(Vector3(16, 0, -29.4), 9, 0)
	_fence_run(Vector3(36.5, 0, 18), 7, -PI / 2.0)
	_fence_run(Vector3(-42, 0, 34.3), 9, 0)
	_place("barricade", Vector3(-8, 0.0, 24), 0.16)
	_block(Vector3(-8, 0.8, 24), Vector3(1.83, 1.6, 0.37), 0.16)
	for spot: Vector2 in [
		Vector2(-41, -36), Vector2(-36, -20), Vector2(-29, -34), Vector2(-15, -32),
		Vector2(-14, -14), Vector2(-41, -9), Vector2(-36, 8), Vector2(-44, 17),
		Vector2(-35, 29), Vector2(-29, 35), Vector2(-17, 32), Vector2(-15, 23),
		Vector2(15, -35), Vector2(24, -34), Vector2(32, -35), Vector2(37, -20),
		Vector2(42, -16), Vector2(35, -9), Vector2(39, 9), Vector2(42, 27),
		Vector2(32, 38), Vector2(19, 37), Vector2(12, 28), Vector2(12, -20),
		Vector2(-52, -22), Vector2(-55, 14), Vector2(53, -20), Vector2(55, 16),
		Vector2(-24, 53), Vector2(22, 54), Vector2(-25, -52), Vector2(21, -53),
	]:
		var scale_ := seeded.randf_range(0.67, 1.12)
		var tree := "pine" if seeded.randf() < 0.34 else "oak"
		_place(tree, Vector3(spot.x, 0, spot.y), seeded.randf_range(-PI, PI), Vector3.ONE * scale_)
		if absf(spot.x) < 49 and absf(spot.y) < 49:
			_block(Vector3(spot.x, 1.5, spot.y), Vector3(0.48, 3.0, 0.48) * scale_)
		for j in 2:
			var bush := spot + Vector2(seeded.randf_range(-2.8, 2.8), seeded.randf_range(-2.8, 2.8))
			_place("shrub", Vector3(bush.x, 0, bush.y), seeded.randf_range(-PI, PI), Vector3.ONE * seeded.randf_range(0.53, 0.89))
	for spot: Vector3 in [Vector3(-14, 0, 10.5), Vector3(11, 0, 14), Vector3(12, 0, -14), Vector3(-12, 0, -13)]:
		_place("lamp", spot, 0 if spot.x < 0 else PI)
		var light_x := spot.x + (2.5 if spot.x < 0 else -2.5)
		_light(Vector3(light_x, 7.25, spot.z), Color("#f3bc78"), 3.35, 13.0)


func _fence_run(start: Vector3, count: int, yaw: float) -> void:
	var orientation := Basis(Vector3.UP, yaw)
	for index in range(count + 1):
		var at := start + orientation * Vector3(index * FENCE_PANEL_WIDTH, 0, 0)
		var post := models.piece(CATALOG.PATHS["fence"], "PART_POST_ReinforcedLine_2p35m")
		post.position = at
		post.rotation.y = yaw
		layout.add_child(post)
		if index < count:
			var panel := models.piece(CATALOG.PATHS["fence"], "PART_CHAINLINK_Standard_2m")
			panel.position = at
			panel.rotation.y = yaw
			layout.add_child(panel)

	# Each panel starts at its left post and extends two metres along local X.
	var span := count * FENCE_PANEL_WIDTH
	var center := start + orientation * Vector3(span * 0.5, 1.185, 0)
	var collision := _block(center, Vector3(span + 0.21, 2.37, 0.21), yaw)
	collision.add_to_group("neighborhood_fences")


func _park(model: String, at: Vector3, yaw: float, size: Vector3) -> void:
	var tire_clearance := 0.001 if model == "car" else 0.015
	var vehicle := _place(model, at - Vector3.UP * tire_clearance, yaw)
	vehicle.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI / 2.0)
	if model == "car":
		_fit_sedan(vehicle)
	_block(at + Vector3.UP * size.y * 0.5, size, yaw)


func _fit_sedan(vehicle: Node3D) -> void:
	# Work in the original sedan's X-forward, Z-up model coordinates.
	var shell := vehicle.find_child("PZ2026_SEDAN_SHELL_ASSET", true, false) as Node3D
	var roof := shell.find_child("Roof_Panel_Body_Upper", true, false) as MeshInstance3D
	var paint := roof.get_active_material(0).duplicate() as BaseMaterial3D
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED

	var engine_bay := shell.find_child("ENGINE_BAY", true, false) as Node3D
	engine_bay.position.z -= 0.18
	var bracing := shell.find_child("Trunk_Interior_Bracing", true, false) as Node3D
	bracing.position.z -= 0.08
	for trunk_hinge in shell.find_children("Boot_Lid_Gooseneck_Hinge_*", "Node3D", true, false):
		trunk_hinge.position.z -= 0.09

	var seatback := shell.find_child("RearBench_Backrest", true, false) as Node3D
	seatback.position.x += 0.06
	for rest in shell.find_children("RearBench_HeadRest_*", "Node3D", true, false):
		rest.position += Vector3(0.10, 0, -0.05)

	for label: String in ["LEFT", "RIGHT"]:
		var side := -1.0 if label == "LEFT" else 1.0
		var short_label := label.left(1)
		var rail := shell.find_child(short_label + "_RoofSide_Stiffener", true, false) as MeshInstance3D
		rail.position += Vector3(0, -side * 0.026, -0.020)
		rail.material_override = paint
		for pillar: String in ["A", "B", "C"]:
			var support := shell.find_child("%s_%s_Pillar_LoadBearing" % [short_label, pillar], true, false) as MeshInstance3D
			support.material_override = paint

		for door: String in ["FRONT", "REAR"]:
			var prefix := "Door_%s_%s_" % [label, door]
			var glass := shell.find_child(prefix + "Moveable_TintedGlass", true, false) as Node3D
			var seal := shell.find_child(prefix + "WindowWeatherStrip", true, false) as Node3D
			var pivot := Node3D.new()
			pivot.name = "WindowFitPivot"
			glass.get_parent().add_child(pivot)
			pivot.global_position = shell.to_global(Vector3(0, side * 0.866, 1.081))
			glass.reparent(pivot, true)
			seal.reparent(pivot, true)
			seal.position.y -= side * 0.026
			pivot.rotation.x = side * 0.34

		_sedan_quad(shell, "RearPillarSkin", paint, [
			Vector3(-1.217, side * 0.75, 1.423), Vector3(-1.012, side * 0.777, 1.355),
			Vector3(-1.09, side * 0.876, 1.077), Vector3(-1.51, side * 0.775, 1.082),
		])
		_sedan_quad(shell, "FrontPillarSkin", paint, [
			Vector3(0.638, side * 0.741, 1.401), Vector3(0.665, side * 0.772, 1.377),
			Vector3(1.039, side * 0.875, 1.079), Vector3(1.145, side * 0.756, 1.051),
		])
		_sedan_quad(shell, "RearDeckEdge", paint, [
			Vector3(-2.304, side * 0.743, 1.050), Vector3(-2.304, side * 0.839, 1.060),
			Vector3(-1.491, side * 0.839, 1.063), Vector3(-1.491, side * 0.748, 1.116),
		])
		_sedan_quad(shell, "HoodEdge", paint, [
			Vector3(1.077, side * 0.753, 1.066), Vector3(1.077, side * 0.841, 1.064),
			Vector3(2.324, side * 0.841, 1.035), Vector3(2.324, side * 0.747, 0.946),
		])
	_sedan_quad(shell, "RearWindowSeal", palette["dark"], [
		Vector3(-1.535, -0.765, 1.101), Vector3(-1.535, 0.765, 1.101),
		Vector3(-1.476, 0.751, 1.100), Vector3(-1.476, -0.751, 1.100),
	])


func _sedan_quad(parent: Node3D, part_name: String, material: Material, corners: Array[Vector3]) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for index in [0, 1, 2, 0, 2, 3]:
		surface.set_uv(uv[index])
		surface.add_vertex(corners[index])
	surface.generate_normals()
	surface.generate_tangents()
	var panel := MeshInstance3D.new()
	panel.name = part_name
	panel.mesh = surface.commit()
	parent.add_child(panel)


func _cache(title: String, at: Vector3, weapon: bool, medicine: int) -> void:
	var item := INTERACTION.new()
	item.label_text = title
	item.has_crowbar = weapon
	item.medkits = medicine
	item.position = at
	layout.add_child(item)
	var crate := models.instantiate(CATALOG.PATHS["crate"])
	crate.rotation.x = -PI / 2.0
	item.add_child(crate)
	item.marker = _world_label("CROWBAR / SUPPLIES" if weapon else "SUPPLY CACHE", at + Vector3.UP * 0.81, true, 39)
	item.blocker = _block(at + Vector3.UP * 0.23, Vector3(0.64, 0.46, 0.49))
	if weapon:
		_box(at + Vector3(0, 0.475, 0), Vector3(0.56, 0.012, 0.15), "plate")


func _world_label(value: String, at: Vector3, billboard: bool, size_px: int) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.font_size = size_px
	label.outline_size = 6 if billboard else 2
	label.pixel_size = 0.0036 if billboard else 0.0028
	label.modulate = Color("#ffcf82")
	label.position = at
	if billboard:
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	layout.add_child(label)
	return label


func _light(at: Vector3, tint: Color, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = tint
	light.light_energy = energy
	light.omni_range = reach
	layout.add_child(light)


func _place(key: String, at: Vector3, yaw: float = 0.0, factor: Vector3 = Vector3.ONE) -> Node3D:
	var model := models.instantiate(CATALOG.PATHS[key])
	model.position = at
	model.rotation.y = yaw
	model.scale = factor
	layout.add_child(model)
	return model


func _box(at: Vector3, size: Vector3, color_key: String, angles: Vector3 = Vector3.ZERO) -> void:
	var shape := BoxMesh.new()
	shape.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.material_override = palette[color_key]
	mesh.position = at
	mesh.rotation = angles
	layout.add_child(mesh)


func _block(at: Vector3, size: Vector3, yaw: float = 0.0, blocks_route: bool = true) -> StaticBody3D:
	var block := StaticBody3D.new()
	block.position = at
	block.rotation.y = yaw
	block.collision_layer = 1
	block.collision_mask = 0
	var box := BoxShape3D.new()
	box.size = size
	var shape := CollisionShape3D.new()
	shape.shape = box
	block.add_child(shape)
	layout.add_child(block)
	if blocks_route:
		_mark_obstacle(at, size, yaw)
	return block


func _mark_obstacle(at: Vector3, size: Vector3, yaw: float) -> void:
	var extent := Vector2(
		(absf(cos(yaw)) * size.x + absf(sin(yaw)) * size.z) * 0.5 + 0.25,
		(absf(sin(yaw)) * size.x + absf(cos(yaw)) * size.z) * 0.5 + 0.25
	)
	var middle := Vector2(at.x, at.z)
	var minimum := (middle - extent) / CELL
	var maximum := (middle + extent) / CELL
	for x in range(ceili(minimum.x), floori(maximum.x) + 1):
		for z in range(ceili(minimum.y), floori(maximum.y) + 1):
			if navigation.is_in_bounds(x, z):
				navigation.set_point_solid(Vector2i(x, z))


func _nearest_open(at: Vector3) -> Vector2i:
	var grid := Vector2i(roundi(at.x / CELL), roundi(at.z / CELL))
	for radius in range(0, 5):
		var best := Vector2i(999, 999)
		var distance := INF
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var cell := grid + Vector2i(x, z)
				if navigation.is_in_boundsv(cell) and not navigation.is_point_solid(cell):
					var candidate := Vector2(at.x, at.z).distance_squared_to(Vector2(cell) * CELL)
					if candidate < distance:
						best = cell
						distance = candidate
		if is_finite(distance):
			return best
	return Vector2i(999, 999)


func _route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()
	var start := _nearest_open(from)
	var end := _nearest_open(to)
	if navigation.is_in_boundsv(start) and navigation.is_in_boundsv(end):
		var points := navigation.get_point_path(start, end, true)
		for index in range(1, points.size()):
			result.append(Vector3(points[index].x, 0, points[index].y))
	return result


func _spawn_infected(key: String, at: Vector3, speed: float) -> void:
	var infected := INFECTED.new()
	infected.name = "Infected_" + key
	infected.position = at
	infected.rotation.y = seeded.randf_range(-PI, PI)
	infected.target = survivor
	infected.speed = speed
	infected.route = _route
	infected.step = seeded.randf_range(0, 6.0)
	var visual := Node3D.new()
	var model := models.instantiate(CATALOG.PATHS[key])
	if key == "zombie":
		model.basis = Basis(Vector3.UP, PI / 2.0) * Basis(Vector3.RIGHT, -PI / 2.0)
	else:
		model.rotation.y = PI
	visual.add_child(model)
	infected.add_child(visual)
	infected.visual = visual
	infected.killed.connect(_infected_killed)
	add_child(infected)

