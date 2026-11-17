extends SceneTree

const SCENE := preload("res://scenes/world/kaldran_city.tscn")
const PLAN := preload("res://scripts/city/layout.gd")
const OBJECT := preload("res://scripts/city/interaction.gd")

var city: Node3D
var failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	city = SCENE.instantiate()
	root.add_child(city)
	if city.player == null or city.p06 == null:
		quit(1)
		return
	city.state.base_path = ProjectSettings.globalize_path("res://.godot/integration")
	DirAccess.make_dir_recursive_absolute(city.state.base_path)
	city._new_game()
	await _frames(20)
	_check(city.player.is_on_floor(), "Third-person spawn on the apartment floor")
	_check(city.player.skeleton != null and city.player.animator.has_animation("CrouchWalk")
		and city.player.animator.has_animation("CrowbarSwing"), "Survivor uses a skinned character with gameplay animations")
	_check(city.player.hand_socket.bone_name == "RightHand" and city.weapon_model.get_parent() == city.player.hand_socket
		and city.pistol_model.get_parent() == city.player.hand_socket, "Held props follow the survivor's hand bone")
	var chunks := {}
	var parcels := 0
	for z in PLAN.COUNT:
		for x in PLAN.COUNT:
			var key := Vector2i(x, z)
			chunks[PLAN.origin(key)] = true
			parcels += PLAN.parcels(key).size()
	_check(chunks.size() == 100 and chunks.has(Vector2(-500, -500)) and chunks.has(Vector2(400, 400)), "100 unique 100 m blocks cover 1 km²")
	print("Generated parcels: %d, landmark shells: %d, interiors: %d" % [parcels, PLAN.LANDMARKS.size(), PLAN.PLACES.size()])
	await _travel(city.SPAWN)
	_use("starter_cache")
	_check(city.state.inventory.get("crowbar", 0) == 1 and city.state.stage == 0, "Starter case grants equipment and preserves stage order")
	city._command("item", "crowbar")
	city._open("")
	var door: Node3D = city.hill_doors.safehouse_door
	await _travel(door.global_position + Vector3.BACK * 1.2)
	city.player.rotation.y = 0.0
	await _frames(2)
	_check(city.player.find_focus() == door, "Player can focus the real apartment entrance")
	city._action("city_use")
	await _frames(20)
	_check(door.opened and city.state.objects.safehouse_door, "Apartment door changes collision and persistent state")
	await _walk(door.global_position + Vector3.FORWARD * 2.6)
	await _frames(4)
	_check(city.state.stage == 1, "Wake up completes through movement and equipment")
	_use("shop_cache")
	_check(city.state.stage == 2 and city.state.inventory.get("fuel", 0) == 1, "Shop supplies advance Scavenge")
	_use("shop_cache")
	_check(city.state.inventory.get("fuel", 0) == 1, "Searched case cannot duplicate loot")
	_check(city.state.craft("barricade") and city.state.craft("repair") and city.state.craft("bandage"), "Three recipes consume real ingredients")
	_use("barrier")
	_use("power")
	_check(city.state.stage == 3 and city.generator_lamp.visible and city.barrier.visible, "Repairs change the safehouse and advance the mission")
	_use("storage")
	city._command("deposit", "food")
	city._command("withdraw", "food")
	_check(not city.state.storage.has("food"), "Storage transfer round-trips")
	city._open("")

	var pump: Vector3 = city.city_layout.place("pump")
	await _travel(pump + Vector3.FORWARD * 2.8)
	var far_edge := Vector3(390, city.city_layout.height(390, 390), 390)
	await _travel(far_edge)
	_check(city.stream.center == PLAN.chunk_for(far_edge) and not city.stream.loaded.has(PLAN.chunk_for(city.SPAWN)), "Travel beyond the retention band unloads the starting block")
	await _travel(pump + Vector3.FORWARD * 2.8)
	_check(_locate("pump_door") != null, "Utility interior streams in with its door")
	_use("pump_door")
	await _frames(18)
	await _walk(pump + Vector3.BACK * 3.1)
	_check(city.player.global_position.z > pump.z + 2.5, "Player capsule traverses pumping-station entrance")
	_use("pump_cache")
	_check(city.state.craft("filter"), "Pumping-station assembly crafts the fourth recipe")
	await _travel(city.SPAWN)
	_use("water")
	_check(city.state.stage == 4, "Restoring water activates The Signal")
	var civic: Vector3 = city.city_layout.place("police")
	await _travel(civic + Vector3.FORWARD * 2.8)
	_use("police_door")
	await _frames(16)
	await _walk(civic + Vector3.BACK * 2.8)
	_check(city.player.global_position.z > civic.z + 2.2, "Player capsule traverses civic entrance")
	_use("police_cache")
	await _travel(city.SPAWN)
	_use("radio")
	_check(city.state.stage == 5, "Civic receiver activates the safehouse radio")
	_check(city.state.read_save().get("stage") == 5, "Mission progress is saved through the checkpoint path")
	_use("bed")
	_check(city.state.flags.has("siege") and city.actors.has("night_3"), "Rest starts a three-infected encounter")
	var appearances := {}
	for id in ["night_1", "night_2", "night_3"]:
		var actor: CharacterBody3D = city.actors.get(id)
		if is_instance_valid(actor) and actor.animator and actor.animator.has_animation("LungeAttack"):
			var mesh := actor.model.find_child("H_DDS_HighRes", true, false) as MeshInstance3D
			if mesh and mesh.skin:
				appearances[mesh.mesh] = true
	_check(appearances.size() >= 2, "Siege loads both skinned infected appearances with attack motion")
	var enemy: CharacterBody3D = city.actors.get("night_1")
	if is_instance_valid(enemy):
		await _travel(enemy.global_position + Vector3.BACK * 1.65)
		city.player.rotation.y = 0.0
		city._action("city_attack")
		_check(enemy.health < 115 and city.player.active_clip == "CrowbarSwing",
			"Crowbar input triggers damage and the matching character animation")
	else:
		_check(false, "Crowbar test has a live infected")
	var previous_health: float = city.player.health
	var attacker: CharacterBody3D = city.actors.get("night_3")
	if is_instance_valid(attacker):
		await _travel(attacker.global_position + Vector3.BACK * 1.1)
		await _frames(105)
	_check(city.player.health < previous_health, "A live infected detects and damages the survivor")
	await _travel(city.SPAWN)
	for id in ["night_1", "night_2", "night_3"]:
		if city.actors.has(id):
			city.actors[id].take_hit(120)
	_check(city.state.stage == 6 and city.ui.mode == "complete", "All infected deaths trigger mission completion")
	var record: Dictionary = city.state.read_save()
	_check(record.get("stage") == 6 and record.defeated.has("night_3") and record.objects.has("pump_cache"), "Completion, defeated entities and loot survive saving")
	city._continue_game()
	await _frames(18)
	_check(city.state.stage == 6 and city.hill_doors.safehouse_door.opened and city.generator_lamp.visible, "Continue restores door, mission and generator state")
	_check(not city.actors.has("night_3"), "Defeated infected never respawn on reload")
	city.player.damage(city.player.health)
	_check(city.ui.mode == "death", "Lethal damage opens the checkpoint screen")
	city._continue_game()
	await _frames(12)
	_check(city.player.health > 0 and city.state.stage == 6, "Death recovery restores a living checkpoint")
	city._checkpoint(false)
	var primary: String = city.state.base_path.path_join("kaldran.save")
	var file := FileAccess.open(primary, FileAccess.WRITE)
	file.store_string("damaged")
	file.close()
	_check(city.state.read_save().get("stage") == 6, "Corrupt primary falls back to a valid backup")
	city._new_game()
	await _frames(10)
	_check(city.state.stage == 0 and not city.state.objects.has("shop_cache") and not city.generator_lamp.visible,
		"New game resets mission, loot and infrastructure")
	print("Integration failures: %d" % failed)
	quit(0 if failed == 0 else 1)


func _travel(at: Vector3) -> void:
	city.player.global_position = at + Vector3.UP * 0.12
	city.player.velocity = Vector3.ZERO
	city.stream.refresh(at, true)
	await _frames(9)


func _walk(destination: Vector3) -> void:
	for tick in 150:
		var offset: Vector3 = destination - city.player.global_position
		offset.y = 0.0
		if offset.length() < 0.25:
			break
		city.player.rotation.y = atan2(-offset.x, -offset.z)
		Input.action_press("city_forward")
		await physics_frame
	Input.action_release("city_forward")
	await _frames(3)


func _locate(id: String) -> Node3D:
	for node in get_nodes_in_group("city_interaction"):
		if node.id == id:
			return node
	return null


func _use(id: String) -> void:
	var item := _locate(id)
	_check(item != null, "%s object exists" % id)
	if item:
		item.activate(city.player)


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _check(ok: bool, message: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		failed += 1
