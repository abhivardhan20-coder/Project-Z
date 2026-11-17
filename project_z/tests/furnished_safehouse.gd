extends SceneTree

const SCENE := preload("res://scenes/world/kaldran_city.tscn")
const PLAN := preload("res://scripts/city/layout.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var city := SCENE.instantiate()
	root.add_child(city)
	if city.get("player") == null:
		quit(1)
		return
	var test_script: Script = get_script()
	var test_path := test_script.resource_path.get_base_dir().path_join("../.godot/interior-review").simplify_path()
	city.state.base_path = ProjectSettings.globalize_path(test_path)
	DirAccess.make_dir_recursive_absolute(city.state.base_path)
	city._new_game()
	for tick in 12:
		await physics_frame
	var player: CharacterBody3D = city.player
	var origin := player.global_position
	_check(player.is_on_floor(), "Survivor spawns on the furnished lobby floor")
	var starter := _fixture("starter_cache")
	if not starter:
		quit(1)
		return
	_check(player.find_focus() == starter, "The starter case can be searched from spawn")
	if DisplayServer.get_name() != "headless":
		_capture(city.state.base_path, "safehouse-before-power")
	city._action("city_use")
	for tick in 24:
		await physics_frame
	_check(starter.active and city.state.inventory.get("crowbar", 0) == 1, "Searching the modeled crate grants the starter supplies")
	_check(starter.container_lid != null and starter.container_lid.rotation.x < starter.lid_closed - 0.95, "The looted crate opens")
	starter.restore(false)
	starter.restore(city.state.objects.get("starter_cache", false))
	_check(starter.active and starter.container_lid.rotation.x < starter.lid_closed - 0.95, "Restoring saved loot reopens the lid")
	for id: String in ["storage", "bench", "power", "water", "radio", "bed"]:
		var target := _fixture(id)
		_check(is_instance_valid(target) and is_instance_valid(target.blocker), id + " has a modeled fixture and collision")
	var storage := _fixture("storage")
	storage.activate(player)
	_check(city.ui.mode == "storage", "The storage cabinet opens the storage panel")
	city._open("")
	await _walk(player, PLAN.PILOT + Vector3(10.72, 0.18, 13.65))
	_check(player.position.z > origin.z + 6.0, "The aisle is walkable past the furnished props")
	city.state.flags.power = true
	city.state.flags.radio = true
	city._sync_infrastructure()
	_check(city.generator_lamp.visible and city.radio_indicator.visible, "Infrastructure changes the actual room lighting and radio indicator")
	_check(city.p06.safehouse_tubes.size() == 3, "Three modeled lights have controlled tube materials")
	if DisplayServer.get_name() != "headless":
		player.rotation.y = 0.0
		for frame in 14:
			await process_frame
		_capture(city.state.base_path, "safehouse-restored")
	for id: String in ["storage", "bench", "power", "water", "radio", "bed"]:
		var target := _fixture(id)
		if not target:
			continue
		player.global_position = Vector3(PLAN.PILOT.x + 10.65, origin.y, target.global_position.z)
		player.velocity = Vector3.ZERO
		await physics_frame
		var aim: Vector3 = target.focus_point() - player.eye.global_position
		player.rotation.y = atan2(-aim.x, -aim.z)
		player.eye.rotation.x = atan2(aim.y, Vector2(aim.x, aim.z).length())
		_check(player.find_focus() == target, id + " can be targeted from the lobby aisle")
	print("Furnished safehouse failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _fixture(id: String) -> Node3D:
	for node in get_nodes_in_group("city_interaction"):
		if node.id == id:
			return node
	return null


func _walk(player: CharacterBody3D, to: Vector3) -> void:
	for tick in 145:
		var offset := to - player.global_position
		offset.y = 0.0
		if offset.length() < 0.15:
			break
		player.rotation.y = atan2(-offset.x, -offset.z)
		Input.action_press("city_forward")
		await physics_frame
	Input.action_release("city_forward")


func _capture(path: String, name: String) -> void:
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(path.path_join(name + ".png"))


func _check(ok: bool, label: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1
