extends "res://scripts/neighborhood/neighborhood.gd"

const PLAN := preload("res://scripts/city/layout.gd")
const TERRAIN := preload("res://scripts/city/terrain.gd")
const PILOT := preload("res://scripts/city/p06.gd")
const PLAYER := preload("res://scripts/city/player.gd")
const GEO := preload("res://scripts/city/geometry.gd")
const ARCH := preload("res://scripts/city/architecture.gd")
const STREAM := preload("res://scripts/city/streaming.gd")
const OBJECT := preload("res://scripts/city/interaction.gd")
const FURNITURE := preload("res://scripts/city/interior_assets.gd")
const STATE := preload("res://scripts/city/state.gd")
const MISSION := preload("res://scripts/city/mission.gd")
const UI := preload("res://scripts/city/ui.gd")
const AI := preload("res://scripts/city/infected.gd")
const SKY := preload("res://scripts/city/atmosphere.gd")
const AUDIO := preload("res://scripts/city/audio.gd")
const CAR := preload("res://scripts/city/car.gd")
const WILDLIFE := preload("res://scripts/city/wildlife.gd")
const GRAPHICS := preload("res://scripts/graphics/materials.gd")
const SKYLINE := preload("res://scripts/city/skyline.gd")
const WILDLIFE_REFUGES := [
	Vector2(-287, -288), Vector2(-305, -215), Vector2(-353, -188),
	Vector2(-220, -180), Vector2(-335, 60), Vector2(-186, 88),
	Vector2(74, -200), Vector2(320, -175), Vector2(328, 76), Vector2(106, 406),
	Vector2(-433, 218), Vector2(416, 414),
]
const INFECTED_MODELS := [
	"res://assets/characters/infected_worker.glb",
	"res://assets/characters/infected_civilian.glb",
]
const PISTOL_MODEL := "res://assets/characters/service_pistol.glb"
const SPAWN := PLAN.PILOT + Vector3(10.8, 0.18, 7.1)
const TEST_FLAG := "--city-test"

var city_layout := PLAN.new()
var terrain := TERRAIN.new(city_layout)
var p06: PILOT
var player: PLAYER
var car: CAR
var state := STATE.new()
var architecture := ARCH.new(city_layout, _interact, state.objects)
var stream := STREAM.new()
var mission := MISSION.new(state, city_layout, _stage_changed)
var ui := UI.new()
var sky := SKY.new()
var audio := AUDIO.new()
var home_objects := Node3D.new()
var barrier: Node3D
var generator_lamp: OmniLight3D
var radio_indicator: MeshInstance3D
var starter_case: OBJECT
var barrier_shape: CollisionShape3D
var hill_doors: Dictionary = {}
var actors: Dictionary = {}
var wildlife: Dictionary[int, WILDLIFE] = {}
var weapon_model: Node3D
var pistol_model: Node3D
var spawn_cooldown := 0.0
var diagnostics := false
var playing := false
var test_mode := false
var autosave := 0.0
var reload_delay := 0.0
var attack_delay := 0.0
var hud_timer := 0.0
var nearby_update := 0.0
var first_save := false


func _ready() -> void:
	test_mode = OS.get_cmdline_user_args().has(TEST_FLAG)
	if test_mode:
		state.base_path = ProjectSettings.globalize_path("res://.godot/city-tests")
		DirAccess.make_dir_recursive_absolute(state.base_path)
	PLAYER.register_controls()
	state.load_settings()
	_restore_bindings()
	_set_lighting()
	_build_palette()
	palette.asphalt = GRAPHICS.surface("Asphalt")
	palette.pavement = GRAPHICS.surface("Exposed concrete")
	layout = Node3D.new()
	add_child(layout)
	terrain.horizon(layout)
	stream.configure(city_layout, terrain, architecture, models)
	layout.add_child(stream)
	p06 = PILOT.new()
	add_child(p06)
	p06.build(city_layout, models, palette)
	stream.set_drainage_bridge(p06.drainage_bridge)
	stream.refresh(SPAWN, true)
	hill_doors = {
		"safehouse_door": p06.hillview.get_node("HillviewLobbyDoor"),
		"corner_shop_door": p06.hillview.get_node("HillviewShopDoor"),
	}
	_create_home_objects()
	player = PLAYER.new()
	player.position = SPAWN
	player.add_to_group("city_player")
	add_child(player)
	player.action_requested.connect(_action)
	player.noise_at.connect(_footstep)
	player.hurt.connect(_on_hurt)
	player.died.connect(_death)
	car = CAR.new()
	car.name = "CarmineGT"
	var parking_x := -283.0
	var parking_z := PLAN.bridge_center(parking_x) + 2.90
	car.position = Vector3(parking_x, city_layout.height(parking_x, parking_z) + 0.04, parking_z)
	car.rotation.y = PI / 2.0
	add_child(car)
	stream.refreshed.connect(_update_car_ground)
	weapon_model = models.instantiate(CATALOG.PATHS.crowbar)
	weapon_model.position = Vector3(-0.017, 0.065, 0.018)
	weapon_model.rotation_degrees = Vector3(3.0, -16.0, 4.0)
	player.hand_socket.add_child(weapon_model)
	weapon_model.hide()
	pistol_model = models.instantiate(PISTOL_MODEL)
	pistol_model.rotation_degrees = Vector3(-8.21, 173.27, 74.92)
	var grip_center := Vector3(-0.020, -0.011, 0.0)
	pistol_model.position = Vector3(0.006, 0.071, 0.004) - pistol_model.basis * grip_center
	player.hand_socket.add_child(pistol_model)
	pistol_model.hide()
	add_child(audio)
	add_child(sky)
	var light := get_node("LateSun") as DirectionalLight3D
	for child in get_children():
		if child is WorldEnvironment:
			sky.configure(state, player, light, child.environment)
			break
	ui.progress = state
	add_child(ui)
	ui.command.connect(_command)
	_apply_settings()
	sky.update(0.0)
	_update_hud()
	_open("title")
	if get_parent() == get_tree().root and OS.get_cmdline_user_args().has("--material-lab"):
		_command.call_deferred("shader_lab", null)
		return
	if test_mode:
		_new_game()
		print("Kaldran smoke ready: %d collision-ready chunks, survivor rig %s, First Light stage %d" % [
			stream.loaded.size(), is_instance_valid(player.skeleton), state.stage])


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	if playing and ui.mode == "":
		if player.driving:
			player.global_position = car.seat.global_position
			player.rotation.y = car.rotation.y + PI
		sky.update(delta)
		_tick_survival(delta)
		attack_delay = maxf(0.0, attack_delay - delta)
		reload_delay = maxf(0.0, reload_delay - delta)
		spawn_cooldown -= delta
		mission.evaluate(player)
		nearby_update -= delta
		if nearby_update <= 0.0:
			nearby_update = 0.08
			stream.refresh(player.global_position)
			_discover()
		if spawn_cooldown <= 0.0:
			spawn_cooldown = 0.6
			_manage_infected()
			_manage_wildlife()
		autosave += delta
		if autosave >= 70.0 and not state.flags.has("siege"):
			_checkpoint(false)
	hud_timer -= delta
	if hud_timer <= 0.0:
		hud_timer = 0.12
		_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("city_pause"):
		if ui.mode == "":
			_open("pause")
		elif ui.mode in ["pack", "storage", "map", "journal", "story", "complete", "pause", "settings", "controls"]:
			_open("")
		elif ui.mode in ["settings_title", "controls_title"]:
			_open("title")
	elif playing and ui.mode in ["", "pack", "map", "journal"]:
		if event.is_action_pressed("city_pack"):
			_open("" if ui.mode == "pack" else "pack")
		elif event.is_action_pressed("city_map"):
			_open("" if ui.mode == "map" else "map")
		elif event.is_action_pressed("city_journal"):
			_open("" if ui.mode == "journal" else "journal")
		elif event.is_action_pressed("city_save") and ui.mode == "":
			_checkpoint(true)
		elif event.is_action_pressed("city_debug"):
			diagnostics = not diagnostics


func _open(mode: String, title: String = "", detail: String = "") -> void:
	if mode == "journal":
		title = "First Light · " + MISSION.NAMES[state.stage]
		detail = mission.objective()
	ui.open(mode, (first_save or not state.read_save().is_empty()) if mode in ["title", "death"] else false, title, detail)
	player.playable = playing and mode == ""
	car.controls_enabled = player.playable and player.driving
	for animal: WILDLIFE in wildlife.values():
		animal.active = player.playable
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if player.playable else Input.MOUSE_MODE_VISIBLE
	if mode == "map":
		ui.map.actor = player.global_position
		ui.map.objective = _objective_marker()
		ui.map.discovered = state.discovered
		ui.map.queue_redraw()


func _command(command: String, value: Variant) -> void:
	match command:
		"shader_lab":
			get_tree().change_scene_to_file("res://scenes/graphics/shader_lab.tscn")
		"new":
			_new_game()
		"continue":
			_continue_game()
		"quit":
			get_tree().quit()
		"title":
			playing = false
			_reset_car()
			_open("title")
		"resume":
			_open("")
		"save":
			_checkpoint(true)
			_open("")
		"quality", "weather", "sound", "fov", "sensitivity", "ui_scale":
			state.set(command, value)
			state.save_settings()
			_apply_settings()
			sky.update(0.0)
		"bind":
			_bind(value[0], value[1])
			state.save_settings()
			_open(ui.mode)
		"craft":
			if state.craft(value):
				audio.cue("take", player.global_position)
				ui.announce("Crafted " + state.items[value][0])
			_open("pack")
		"deposit", "withdraw":
			if state.transfer(value, command == "deposit"):
				audio.cue("take", player.global_position)
			_open("storage")
		"item":
			_use_item(value)
			_open("pack")
		_:
			_open(command)


func _new_game() -> void:
	state.reset()
	_reset_car()
	player.position = SPAWN
	player.rotation.y = 2.47
	player.health = 100
	player.stamina = 100
	player.hunger = 100
	player.thirst = 100
	player.exposure = 0
	_begin()


func _continue_game() -> void:
	var data := state.read_save()
	if data.is_empty():
		_open("title")
		return
	_reset_car()
	state.load_record(data, player)
	var parked: Dictionary = data.get("car", {})
	if not parked.is_empty():
		car.global_position = parked.position
		car.rotation.y = parked.yaw
		car.set_headlights(parked.headlights)
		if parked.driving:
			_board_car()
	_begin()


func _begin() -> void:
	sky.reset_surfaces(state.weather)
	for enemy in actors.values():
		if is_instance_valid(enemy):
			enemy.queue_free()
	actors.clear()
	for animal: WILDLIFE in wildlife.values():
		animal.queue_free()
	wildlife.clear()
	for entry in stream.loaded.values():
		stream.remove_child(entry.node)
		entry.node.queue_free()
	stream.loaded.clear()
	stream.refresh(player.global_position, true)
	for id: String in hill_doors:
		var door: Node3D = hill_doors[id]
		door.opened = bool(state.objects.get(id, false))
		door.blocker.set_deferred("collision_layer", 0 if door.opened else 1)
		door.panels[0].rotation.y = door.hinge_open_angle if door.opened else 0.0
	for node in home_objects.get_children():
		if node is OBJECT:
			node.restore(bool(state.objects.get(node.id, false)))
	player.velocity = Vector3.ZERO
	player.eye.rotation.x = 0.0
	player.last_fall_speed = 0.0
	player.focused = null
	player.reset_visual()
	attack_delay = 0.0
	reload_delay = 0.0
	playing = true
	_apply_settings()
	_sync_infrastructure()
	_update_held_weapon()
	_open("")
	_manage_infected()
	_manage_wildlife()
	_checkpoint(false)


func _checkpoint(notify: bool) -> void:
	if not playing or player.health <= 0.0:
		return
	autosave = 0
	var result := state.save(player, {
		"position": car.global_position, "yaw": car.rotation.y,
		"headlights": car.headlights, "driving": player.driving,
	})
	first_save = first_save or result
	if notify or not result:
		ui.announce("Checkpoint saved" if result else "Save unavailable")


func _death() -> void:
	playing = false
	_open("death")


func _on_hurt(_amount: float) -> void:
	if ui.mode == "":
		ui.announce("Injured")


func _action(action: String) -> void:
	if action.begins_with("notice|"):
		ui.announce(action.get_slice("|", 1))
		return
	if player.driving:
		if action == "city_use":
			_exit_car()
		elif action == "city_light":
			car.set_headlights(not car.headlights)
		return
	if action == "city_use":
		var target := player.find_focus()
		if target is OBJECT:
			target.activate(player)
		elif is_instance_valid(target):
			if target.busy:
				return
			var was_open: bool = target.opened
			target.activate(player)
			if target.opened != was_open:
				state.objects[hill_doors.find_key(target)] = target.opened
				audio.cue("door", target.global_position)
				_noise(target.global_position, 6)
		elif car.can_board(player, player.camera):
			_board_car()
			audio.cue("door", car.entry.global_position, -7)
	elif action == "city_reload":
		_reload()
	elif action == "city_attack":
		_attack()


func _board_car() -> void:
	player.set_driving(true)
	player.global_position = car.seat.global_position
	player.rotation.y = car.rotation.y + PI
	# A door interaction can call this while the title or checkpoint is being restored.
	car.board()
	car.controls_enabled = player.playable


func _exit_car() -> void:
	var exit_at: Variant = car.safe_exit(player)
	if exit_at == null:
		ui.announce("Stop and leave room beside the car.")
		return
	car.leave()
	player.global_position = exit_at
	player.rotation.y = car.rotation.y + PI
	player.set_driving(false)
	player.camera.reset_physics_interpolation()
	audio.cue("door", player.global_position, -7)


func _reset_car() -> void:
	player.set_driving(false)
	car.occupied = false
	car.controls_enabled = false
	car.set_headlights(false)
	car.recover()
	if car.door_tween and car.door_tween.is_running():
		car.door_tween.kill()
	car.door.rotation.y = 0.0


func _update_car_ground() -> void:
	var key := PLAN.chunk_for(car.global_position)
	var block: Dictionary = stream.loaded.get(key, {})
	car.ground_loaded = bool(block.get("detail", false))
	if not car.ground_loaded:
		car.velocity = Vector3.ZERO


func _interact(item: OBJECT, _character: CharacterBody3D) -> void:
	match item.kind:
		"door":
			if item.active and player.global_position.distance_to(item.global_position) < 0.81:
				ui.announce("Step clear of the door.")
				return
			item.restore(not item.active, true)
			state.objects[item.id] = item.active
			audio.cue("door", item.global_position)
			_noise(item.global_position, 6.0)
		"loot":
			if item.active:
				return
			if not state.take(item.contents):
				ui.announce("Pack is full.")
				return
			state.objects[item.id] = true
			item.restore(true, true)
			audio.cue("take", item.global_position)
			ui.announce("Supplies collected.")
			mission.evaluate(player)
		"storage":
			_open("storage")
		"bench":
			_open("pack")
		"note":
			if item.id == "police_note":
				_open("story", "Police annex dispatch", "Day 19. The evacuation buses never made the switchback. A relay is still transmitting above the northern ridge. Set your receiver to Channel 6.")
			else:
				_open("story", "Pumping station log", "Flooding tripped the downstream feeder. Reserve filter assemblies are packed for portable tanks.")
		"repair":
			_repair(item.id)
		"bed":
			if state.stage == 5 and not state.flags.has("siege"):
				_checkpoint(false)
				state.flags.siege = true
				state.clock = 0.86
				sky.update(0.0)
				_manage_infected()
				ui.announce("Something is moving on P06.")
			elif state.stage == 5:
				ui.announce("Infected are still nearby.")
			else:
				state.clock = 0.30
				player.stamina = 100
				_checkpoint(true)


func _repair(id: String) -> void:
	var spec: Array = {
		"barrier": [2, {"barricade": 1}, "Entrance reinforced."],
		"power": [2, {"repair": 1, "fuel": 1}, "Generator running. Lights restored."],
		"water": [3, {"filter": 1}, "Clean water available."],
		"radio": [4, {"radio_parts": 1}, "Channel 6 · Anyone in Kaldran, the ridge relay is still live."],
	}[id]
	if state.flags.has(id):
		if id == "water":
			player.thirst = minf(player.thirst + 40, 100)
			ui.announce("Drank clean water.")
		else:
			ui.announce(spec[2])
		return
	if state.stage < int(spec[0]):
		ui.announce("Follow the current field objective.")
		return
	if not state.has_all(state.inventory, spec[1]):
		var missing := PackedStringArray()
		for resource: String in spec[1]:
			if int(state.inventory.get(resource, 0)) < int(spec[1][resource]):
				missing.append(state.items[resource][0])
		ui.announce("Required · " + ", ".join(missing))
		return
	for resource: String in spec[1]:
		state.add(state.inventory, resource, -int(spec[1][resource]))
	state.flags[id] = true
	audio.cue("radio" if id == "radio" else "generator", player.global_position)
	_sync_infrastructure()
	ui.announce(spec[2])
	mission.evaluate(player)


func _create_home_objects() -> void:
	home_objects.name = "SafehouseInterior"
	p06.add_child(home_objects)
	var base := PLAN.PILOT
	var floor_y := PILOT.HILLVIEW.PAVEMENT_Y + 0.028
	starter_case = architecture.crate(home_objects, "starter_cache", "apartment case", base + Vector3(9.18, floor_y, 9.11),
		{"crowbar": 1, "bandage": 2, "cloth": 2}, PI / 2.0)
	architecture.crate(home_objects, "shop_cache", "stock case", base + Vector3(-1.43, floor_y, 9.47),
		{"food": 2, "water": 2, "scrap": 4, "electronics": 2, "fuel": 1, "cloth": 2})
	var trunk := architecture.interact(home_objects, "evac_cache", "sedan trunk", "loot", "Search", p06.trunk_point,
		{"pistol": 1, "ammo": 16, "bandage": 1})
	trunk.blocker = p06.trunk_body
	var cabinet := FURNITURE.furnish(home_objects, "painted_wooden_cabinet_02",
		base + Vector3(12.29, floor_y, 7.55), -PI / 2.0, 0.84)
	_home_interaction(cabinet, "storage", "storage cabinet", "storage", "Open", Vector3(0, 1.11, 0.27))
	var desk := FURNITURE.furnish(home_objects, "metal_office_desk",
		base + Vector3(8.68, floor_y, 10.05), PI / 2.0, 0.92)
	_home_interaction(desk, "bench", "workbench", "bench", "Use", Vector3(0.49, 0.76, 0.27))
	FURNITURE.furnish(home_objects, "metal_toolbox", desk.to_global(Vector3(0.63, 0.724, -0.08)), PI / 2.0, 1.0, false)
	var radio_at := desk.to_global(Vector3(-0.46, 0.725, -0.045))
	var radio := FURNITURE.furnish(home_objects, "vintage_radio_transceiver", radio_at, PI / 2.0, 1.0, false)
	var receiver := _home_interaction(radio, "radio", "radio", "repair", "Use", Vector3(0, 0.17, 0.13))
	receiver.blocker = desk.get_node_or_null("FurnitureCollision") as CollisionObject3D
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("#9cce72")
	var indicator := GEO.box(radio, Vector3(-0.11, 0.111, 0.15), Vector3(0.022, 0.012, 0.009), glow)
	radio_indicator = indicator.get_child(0)
	var generator := FURNITURE.furnish(home_objects, "portable_generator",
		base + Vector3(12.39, floor_y, 9.89), -PI / 2.0, 0.92)
	_home_interaction(generator, "power", "generator", "repair", "Service", Vector3(0, 0.43, 0.22))
	var water := FURNITURE.furnish(home_objects, "Barrel_02", base + Vector3(8.73, floor_y, 11.85))
	_home_interaction(water, "water", "water barrel", "repair", "Use", Vector3(0.18, 0.81, 0))
	var bed := FURNITURE.furnish(home_objects, "vintage_day_bed",
		base + Vector3(12.20, floor_y, 12.85), -PI / 2.0, 0.92, true, 0.54)
	_home_interaction(bed, "bed", "day bed", "bed", "Rest on", Vector3(0.04, 0.53, 0.13))
	FURNITURE.furnish(home_objects, "steel_frame_shelves_02",
		base + Vector3(-2.42, floor_y - 0.027, 10.62), PI / 2.0, 0.9)
	FURNITURE.furnish(home_objects, "plastic_crate_02",
		base + Vector3(-2.44, floor_y - 0.027, 8.67), 0.22, 0.72)
	var mount := base + Vector3(9.58, 0.83, 5.04)
	architecture.interact(home_objects, "barrier", "entrance reinforcement", "repair", "Install", mount)
	barrier = GEO.box(home_objects, base + Vector3(8.78, 0.58, 3.22), Vector3(1.05, 0.9, 0.16), GEO.material(Color("#8b7857")), true)
	barrier_shape = barrier.get_child(0)
	generator_lamp = OmniLight3D.new()
	generator_lamp.position = base + Vector3(10.55, 2.65, 10.25)
	generator_lamp.light_color = Color("#ffe1ad")
	generator_lamp.light_energy = 0.95
	generator_lamp.omni_range = 5.4
	home_objects.add_child(generator_lamp)


func _home_interaction(prop: Node3D, id: String, title: String, kind: String, verb: String, hotspot: Vector3) -> OBJECT:
	var target := architecture.interact(home_objects, id, title, kind, verb, prop.to_global(hotspot))
	target.blocker = prop.get_node_or_null("FurnitureCollision") as CollisionObject3D
	return target


func _sync_infrastructure() -> void:
	var powered := state.flags.has("power")
	p06.set_power(powered)
	generator_lamp.visible = powered
	radio_indicator.visible = state.flags.has("radio")
	barrier.visible = state.flags.has("barrier")
	barrier_shape.set_deferred("disabled", not barrier.visible)


func _stage_changed(stage: int) -> void:
	if stage == 6:
		state.flags.erase("siege")
		_checkpoint(false)
		_open("complete", "SAFEHOUSE ESTABLISHED", mission.objective())
	else:
		ui.announce("First Light · " + MISSION.NAMES[stage])
		_checkpoint(false)


func _discover() -> void:
	for id: String in PLAN.PLACES:
		var at := city_layout.place(id)
		if not state.discovered.has(id) and player.global_position.distance_to(at) < 19.0:
			state.discovered[id] = true


func _tick_survival(delta: float) -> void:
	player.hunger = maxf(0.0, player.hunger - delta * 0.043)
	player.thirst = maxf(0.0, player.thirst - delta * 0.071)
	if player.hunger == 0.0 or player.thirst == 0.0 or player.exposure >= 100.0:
		player.damage(delta * 2.3)
	var point := player.global_position
	if _outside_playable_world(point):
		player.damage(player.health)


func _outside_playable_world(point: Vector3) -> bool:
	return point.y < -20.0 or absf(point.x) >= PLAN.LIMIT or absf(point.z) >= PLAN.LIMIT


func _use_item(id: String) -> void:
	if not state.inventory.has(id):
		return
	match id:
		"crowbar", "pistol":
			if state.weapon != id:
				if state.weapon == "pistol" and state.rounds > 0:
					state.add(state.inventory, "ammo", state.rounds)
					state.rounds = 0
				state.weapon = id
				_update_held_weapon()
			if id == "crowbar":
				state.flags.crowbar_equipped = true
			mission.evaluate(player)
			return
		"bandage":
			if player.health >= 100:
				return
			player.health = minf(player.health + 34, 100)
		"food":
			if player.hunger >= 100:
				return
			player.hunger = minf(player.hunger + 42, 100)
		"water":
			if player.thirst >= 100:
				return
			player.thirst = minf(player.thirst + 43, 100)
		"medication":
			if player.exposure <= 0:
				return
			player.exposure = maxf(player.exposure - 45, 0)
		_:
			return
	state.add(state.inventory, id, -1)
	audio.cue("take", player.global_position)


func _update_held_weapon() -> void:
	weapon_model.visible = state.weapon == "crowbar"
	pistol_model.visible = state.weapon == "pistol"
	player.pistol_equipped = pistol_model.visible


func _reload() -> void:
	if state.weapon != "pistol" or reload_delay > 0.0:
		return
	var loaded := mini(STATE.CLIP - state.rounds, int(state.inventory.get("ammo", 0)))
	if loaded <= 0:
		ui.announce("No spare ammunition." if state.rounds == 0 else "Pistol ready.")
		return
	state.rounds += loaded
	state.add(state.inventory, "ammo", -loaded)
	reload_delay = 0.85
	audio.cue("door", player.global_position, -9)


func _attack() -> void:
	if attack_delay > 0 or reload_delay > 0.0 or state.weapon == "":
		return
	var ranged := state.weapon == "pistol" and player.aiming
	if state.weapon == "pistol" and not ranged:
		ui.announce("Hold aim to fire.")
		return
	if ranged and state.rounds <= 0:
		ui.announce("Reload the pistol.")
		return
	var start := player.eye.global_position
	var direction := -player.eye.global_basis.z
	if ranged:
		state.rounds -= 1
		attack_delay = 0.31
		player.animate_attack(true)
		audio.cue("shot", start)
		_noise(start, 46.0)
		var ray := PhysicsRayQueryParameters3D.create(start, start + direction * 62.0, 1 | 4, [player.get_rid()])
		var result := get_world_3d().direct_space_state.intersect_ray(ray)
		var victim: Variant = result.get("collider")
		if victim is AI:
			victim.take_hit(54)
		return
	attack_delay = 0.54
	audio.cue("hit", start, -8)
	_noise(start, 12.0)
	player.animate_attack(false)
	var closest: AI
	var distance := 2.24
	for enemy: AI in get_tree().get_nodes_in_group("city_infected"):
		var point := enemy.global_position + Vector3.UP * 1.24
		var offset := point - start
		if offset.length() < distance and offset.normalized().dot(direction) > 0.62 and player.visible_from(start, point):
			closest = enemy
			distance = offset.length()
	if closest:
		closest.take_hit(43)
		audio.cue("infected", closest.global_position, -4)


func _footstep(at: Vector3, strength: float) -> void:
	audio.cue("asphalt" if PLAN.road_distance(at.x, at.z) < 0.0 else "soil", at, -15.0)
	_noise(at, strength)


func _noise(at: Vector3, strength: float) -> void:
	for enemy: AI in get_tree().get_nodes_in_group("city_infected"):
		enemy.hear(at, strength)
	for animal: WILDLIFE in wildlife.values():
		animal.alert(at, strength)


func _manage_wildlife() -> void:
	var point := player.global_position
	for i: int in wildlife.keys():
		if wildlife[i].global_position.distance_squared_to(point) > 150.0 * 150.0:
			wildlife[i].queue_free()
			wildlife.erase(i)
	var limit: int = [2, 4, 6][state.quality]
	for i in WILDLIFE_REFUGES.size():
		if wildlife.size() >= limit:
			break
		var refuge: Vector2 = WILDLIFE_REFUGES[i]
		var distance := refuge.distance_squared_to(Vector2(point.x, point.z))
		if wildlife.has(i) or distance < 19.0 * 19.0 or distance > 105.0 * 105.0 or not WILDLIFE.valid_site(refuge):
			continue
		var animal := WILDLIFE.new()
		animal.species = i % WILDLIFE.SPECIES.size()
		animal.terrain = city_layout
		animal.observer = player
		animal.refuge = refuge
		animal.active = player.playable
		animal.position = Vector3(refuge.x, city_layout.height(refuge.x, refuge.y) + 0.025, refuge.y)
		add_child(animal)
		wildlife[i] = animal


func _manage_infected() -> void:
	var capacity: int = [6, 10, 14][state.quality]
	var point := player.global_position
	for id: String in actors.keys():
		var enemy: AI = actors[id]
		if not is_instance_valid(enemy) or enemy.global_position.distance_to(point) > 123.0:
			if is_instance_valid(enemy):
				enemy.queue_free()
			actors.erase(id)
	if state.flags.has("siege") and state.stage == 5:
		for i in 3:
			var id := "night_%d" % (i + 1)
			var x := -293.0 + i * 3.0
			_spawn_enemy(id, Vector2(x, -250.5 - i * 0.7), i == 2)
			if actors.has(id):
				actors[id].hear(PLAN.PILOT + Vector3(11, 0.4, 2.7), 72.0)
	if state.stage >= 1:
		_spawn_enemy("p06_patrol", Vector2(-278.0, -252.4), false)
	var key := PLAN.chunk_for(point)
	for row in range(maxi(0, key.y - 1), mini(PLAN.COUNT, key.y + 2)):
		for column in range(maxi(0, key.x - 1), mini(PLAN.COUNT, key.x + 2)):
			if actors.size() >= capacity:
				return
			var tile := PLAN.origin(Vector2i(column, row))
			var at := tile + Vector2(54.0, 48.0)
			if at.distance_to(Vector2(SPAWN.x, SPAWN.z)) < 72.0:
				continue
			_spawn_enemy("street_%d_%d" % [column, row], at, (column + row) % 3 == 0)


func _spawn_enemy(id: String, position: Vector2, fast: bool) -> void:
	if actors.has(id) or state.defeated.has(id):
		return
	var at := Vector3(position.x, city_layout.height(position.x, position.y) + 0.15, position.y)
	if at.distance_to(player.global_position) > 96.0:
		return
	var enemy := AI.new()
	enemy.id = id
	enemy.target = player
	enemy.position = at
	enemy.pace = 3.35 if fast else 2.05
	enemy.health = 85 if fast else 115
	var appearance := 1 if fast else int(id.hash() % INFECTED_MODELS.size())
	enemy.model = models.instantiate(INFECTED_MODELS[appearance])
	enemy.killed.connect(_killed)
	add_child(enemy)
	actors[id] = enemy


func _killed(id: String) -> void:
	state.defeated[id] = true
	actors.erase(id)
	mission.evaluate(player)


func _apply_settings() -> void:
	player.sensitivity = state.sensitivity
	player.camera.fov = state.fov
	player.camera.far = SKYLINE.CAMERA_FAR
	car.camera.far = player.camera.far
	car.sound_enabled = state.sound
	stream.view_radius = [2, 3, 4][state.quality]
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		get_viewport().scaling_3d_scale = [0.65, 0.80, 1.0][state.quality]
		get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	else:
		get_viewport().scaling_3d_scale = [0.83, 1.0, 1.0][state.quality]
	audio.atmosphere(state.weather, state.sound)
	stream.refresh(player.global_position, true)


func _restore_bindings() -> void:
	for action: String in state.bindings:
		if PLAYER.KEYS.has(action) and state.bindings[action] is int:
			_bind(action, state.bindings[action])


func _bind(action: String, keycode: int) -> void:
	if not PLAYER.KEYS.has(action) or keycode <= 0:
		return
	InputMap.action_erase_events(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)
	state.bindings[action] = keycode


func _objective_marker() -> Vector3:
	if state.stage == 0 and not state.objects.has("starter_cache"):
		return starter_case.global_position
	if state.stage == 0:
		return hill_doors.safehouse_door.global_position
	return mission.marker()


func _update_hud() -> void:
	var point := player.global_position
	var zone: String = PLAN.DISTRICTS[PLAN.district(point.x, point.z)]
	var marker := _objective_marker()
	var hint: String = player.focused.prompt() if is_instance_valid(player.focused) and player.playable else ""
	if player.playable and player.driving:
		hint = "%d km/h    [%s] Brake    [%s] Exit    [%s] Lights" % [
			roundi(absf(car.speed) * 3.6), _key_label("city_jump"), _key_label("city_use"), _key_label("city_light")]
	elif player.playable and hint.is_empty() and car.can_board(player, player.camera):
		hint = "[%s] Drive Carmine GT" % _key_label("city_use")
	var minutes := int(state.clock * 1440.0)
	var hour := "%02d:%02d" % [floori(minutes / 60.0), minutes % 60]
	var debug := ""
	if diagnostics:
		debug = "FPS %d  ·  %d chunks  ·  %d infected  ·  %d draws  ·  chunk peak %.1f ms" % [
			Engine.get_frames_per_second(), stream.loaded.size(), actors.size(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), stream.peak_build_usec / 1000.0]
	ui.update_hud(player, zone, mission.objective(), roundi(Vector2(point.x - marker.x, point.z - marker.z).length()), hour, hint, debug)


func _key_label(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	return OS.get_keycode_string(events[0].physical_keycode) if not events.is_empty() else "Unbound"

