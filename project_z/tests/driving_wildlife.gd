extends SceneTree

const CITY := preload("res://scenes/world/kaldran_city.tscn")
const PLAN := preload("res://scripts/city/layout.gd")

var city: Node3D
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	city = CITY.instantiate()
	root.add_child(city)
	var script: Script = get_script()
	var path := script.resource_path.get_base_dir().path_join("../.godot/driving-test").simplify_path()
	city.state.base_path = ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(city.state.base_path)
	city._new_game()
	await frames(22)
	var car: CharacterBody3D = city.car
	var player: CharacterBody3D = city.player
	check(car.is_on_floor() and car.wheels.size() == 4 and not car.wheels.has(null), "Imported Carmine GT rests on four working wheels")
	check(city.wildlife.has(0) and city.wildlife.has(1) and city.wildlife[0].animator.has_animation("run")
		and city.wildlife[1].animator.has_animation("Walk")
		and city.wildlife[1].animator.has_animation("Look around"), "Imported deer and fox are animated and present around Hillview")
	var animal: Node3D = city.wildlife[0]
	var origin: Vector3 = animal.global_position
	animal.alert(origin + Vector3(1.0, 0.0, 0.0), 20.0)
	await frames(42)
	check(animal.global_position.distance_to(origin) > 0.5 and animal.current_clip == 2, "Wildlife moves away from nearby noise")
	var near_block: Node3D = city.stream.loaded[Vector2i(2, 2)].node
	for tag in ["GrassClumps", "FloweringShrubs", "PineSaplings"]:
		var plant := near_block.find_child(tag, false, false) as MultiMeshInstance3D
		check(plant != null and plant.multimesh.instance_count > 0, "%s populates the Hillview block" % tag)

	player.global_position = car.entry.global_position + car.global_basis.x * 0.20 + Vector3.UP * 0.06
	var aim: Vector3 = car.entry_focus() - player.eye.global_position
	player.rotation.y = atan2(-aim.x, -aim.z)
	player.eye.rotation.x = atan2(aim.y, Vector2(aim.x, aim.z).length())
	await frames(12)
	key(KEY_E, true)
	key(KEY_E, false)
	await frames(14)
	check(player.driving and car.occupied and root.get_camera_3d() == car.camera, "Physical E at the driver door boards the car")
	if not player.driving:
		quit(1)
		return
	var start: Vector3 = car.global_position
	key(KEY_W, true)
	await frames(79)
	key(KEY_W, false)
	check(car.global_position.x > start.x + 3.5 and car.wheels[0].rotation.x > 0.05, "Physical W moves the car east and rotates its wheels")
	city._action("city_use")
	check(player.driving, "The exit waits while the car is moving")
	key(KEY_SPACE, true)
	await frames(35)
	key(KEY_SPACE, false)
	check(absf(car.speed) < 0.65, "Space brings the car to a stop")
	var reverse_from: Vector3 = car.global_position
	key(KEY_S, true)
	await frames(53)
	key(KEY_S, false)
	key(KEY_SPACE, true)
	await frames(35)
	key(KEY_SPACE, false)
	check(car.global_position.x < reverse_from.x - 1.3, "Physical S reverses from a stop")
	var junction_x := PLAN.cross_street_x(-250.0, -250.0)
	var z := PLAN.bridge_center(junction_x)
	car.global_position = Vector3(junction_x - 4.4, city.city_layout.height(junction_x - 4.4, z) + 0.08, z)
	car.rotation.y = PI / 2.0
	car.velocity = Vector3.ZERO
	await frames(16)
	key(KEY_W, true)
	key(KEY_D, true)
	await frames(123)
	key(KEY_W, false)
	key(KEY_D, false)
	key(KEY_SPACE, true)
	await frames(45)
	key(KEY_SPACE, false)
	var turn_delta: Vector3 = car.global_position - Vector3(junction_x, 0, z)
	print("Junction displacement ", turn_delta, " heading ", car.rotation.y)
	check(turn_delta.z > 3.0 and absf(turn_delta.x) < 7.0, "The car makes a right turn onto a P06 side road")
	key(KEY_F, true)
	key(KEY_F, false)
	await frames(2)
	check(car.headlights and car.beams[0].visible, "Physical F toggles the headlights")
	var parked: Vector3 = car.global_position
	city._checkpoint(false)
	city._continue_game()
	await frames(20)
	check(player.driving and car.headlights and parked.distance_to(car.global_position) < 0.35, "Checkpoint restores vehicle position, headlights and seat")
	key(KEY_E, true)
	key(KEY_E, false)
	await frames(15)
	check(not player.driving and not car.occupied and root.get_camera_3d() == player.camera and player.is_on_floor(), "Physical E exits safely and restores the on-foot camera")
	var exit_origin: Vector3 = player.global_position
	key(KEY_W, true)
	await frames(25)
	key(KEY_W, false)
	check(exit_origin.distance_to(player.global_position) > 0.40, "Walking controls return after exit")
	var parked_position: Vector3 = car.global_position
	player.global_position = Vector3(390.0, city.city_layout.height(390.0, 390.0) + 0.12, 390.0)
	city.stream.refresh(player.global_position, true)
	await frames(95)
	check(not car.ground_loaded and car.global_position.distance_to(parked_position) < 0.10,
		"The parked car stays put when its terrain streams out")
	city._checkpoint(false)
	var record: Dictionary = city.state.read_save()
	check(record.has("car") and not record.car.driving
		and Vector3(record.car.position).distance_to(parked_position) < 0.10,
		"A parked car outside the loaded area saves correctly")
	print("Driving and wildlife failures: %d" % failed)
	quit(1 if failed else 0)

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func check(condition: bool, note: String) -> void:
	print(("PASS " if condition else "FAIL ") + note)
	if not condition:
		failed += 1


