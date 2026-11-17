extends CharacterBody3D

const WHEELBASE := 2.87
const WHEEL_RADIUS := 0.351
const MAX_SPEED := 17.0
const VEHICLE_LAYER := 8

var shell: Node3D
var camera: Camera3D
var door: Node3D
var entry: Node3D
var seat: Node3D
var exit_marker: Node3D
var steering: Array[Node3D] = []
var wheels: Array[Node3D] = []
var occupied := false
var controls_enabled := false
var speed := 0.0
var steer := 0.0
var start_pose: Transform3D
var door_tween: Tween
var wheel_radius := WHEEL_RADIUS
var wheelbase := WHEELBASE
var max_speed := MAX_SPEED
var chassis_size := Vector3(1.76, 0.91, 4.55)
var chassis_height := 0.455
var door_angle := deg_to_rad(70.0)
var forward_action := &"neighborhood_forward"
var back_action := &"neighborhood_back"
var left_action := &"neighborhood_left"
var right_action := &"neighborhood_right"
var brake_action := &"pilot_brake"


func _ready() -> void:
	collision_layer = VEHICLE_LAYER
	collision_mask = 1 | 2 | 4
	floor_snap_length = 0.57
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(28.0)
	var box := BoxShape3D.new()
	box.size = chassis_size
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position.y = chassis_height
	add_child(shape)
	door = shell.find_child("DriverDoor", true, false) as Node3D
	entry = shell.find_child("DriverEntry", true, false) as Node3D
	seat = shell.find_child("DriverSeat", true, false) as Node3D
	exit_marker = shell.find_child("DriverExit", true, false) as Node3D
	for tag in ["FrontLeft", "FrontRight", "RearLeft", "RearRight"]:
		wheels.append(shell.find_child("Wheel" + tag, true, false) as Node3D)
		if tag.begins_with("Front"):
			steering.append(shell.find_child("Steer" + tag, true, false) as Node3D)
	assert(door and entry and seat and exit_marker and not wheels.has(null) and not steering.has(null))
	camera = Camera3D.new()
	camera.name = "ChaseCamera"
	camera.position = Vector3(0.0, 3.1, -6.8)
	camera.rotation = Vector3(-0.27, PI, 0.0)
	camera.fov = 73.0
	camera.far = 1400.0
	add_child(camera)
	start_pose = global_transform


func entry_focus() -> Vector3:
	return entry.global_position + Vector3.UP * 1.1


func can_board(player: CharacterBody3D, view: Camera3D) -> bool:
	if occupied or absf(speed) > 0.65 or player.global_position.distance_to(entry.global_position) > 2.5:
		return false
	var delta := entry_focus() - view.global_position
	return delta.normalized().dot(-view.global_basis.z) > 0.27 and player.unobstructed(view.global_position, entry_focus(), self)


func board() -> void:
	occupied = true
	controls_enabled = true
	camera.make_current()
	_animate_door()


func leave() -> void:
	occupied = false
	controls_enabled = false
	_animate_door()


func safe_exit(player: CharacterBody3D) -> Variant:
	if absf(speed) > 0.65 or not is_on_floor():
		return null
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.29
	capsule.height = 1.77
	var space := get_world_3d().direct_space_state
	var door_side := signf(to_local(exit_marker.global_position).x)
	for candidate: Vector3 in [exit_marker.global_position,
			to_global(Vector3(-door_side * 1.83, 0.02, 0.33)), to_global(Vector3(door_side * 1.83, 0.02, -1.0))]:
		var ray := PhysicsRayQueryParameters3D.create(candidate + Vector3.UP * 1.4, candidate - Vector3.UP * 1.1, 1, [get_rid(), player.get_rid()])
		var contact := space.intersect_ray(ray)
		if contact.is_empty() or Vector3(contact["normal"]).y < 0.78:
			continue
		var floor_point: Vector3 = contact["position"]
		var test := PhysicsShapeQueryParameters3D.new()
		test.shape = capsule
		test.transform = Transform3D(Basis.IDENTITY, floor_point + Vector3.UP * 0.94)
		test.collision_mask = 1 | 4 | VEHICLE_LAYER
		test.exclude = [player.get_rid()]
		if space.intersect_shape(test, 1).is_empty():
			return floor_point + Vector3.UP * 0.045
	return null


func recover() -> void:
	global_transform = start_pose
	speed = 0.0
	velocity = Vector3.ZERO
	steer = 0.0
	shell.position.y = 0.0
	shell.rotation.x = 0.0


func _physics_process(delta: float) -> void:
	var forward := 0.0
	var steering_input := 0.0
	var brake := not occupied or not controls_enabled
	if not brake:
		forward = Input.get_axis(back_action, forward_action)
		steering_input = Input.get_axis(right_action, left_action)
		brake = Input.is_action_pressed(brake_action)
	var wanted := max_speed if forward > 0 else -4.8
	var pedal := absf(forward)
	if brake:
		speed = move_toward(speed, 0.0, 17.0 * delta)
	elif pedal > 0.01:
		if speed * forward < -0.04:
			speed = move_toward(speed, 0.0, 12.5 * delta)
		else:
			speed = move_toward(speed, wanted * pedal, 4.8 * delta)
	else:
		speed = move_toward(speed, 0.0, 2.3 * delta)
	var angle_limit := lerpf(0.51, 0.23, clampf(absf(speed) / max_speed, 0.0, 1.0))
	steer = move_toward(steer, steering_input * angle_limit, delta * 2.3)
	rotate_y(speed * tan(steer) / wheelbase * delta)
	var heading := global_basis.z.normalized()
	velocity.x = heading.x * speed
	velocity.z = heading.z * speed
	velocity.y = -0.75 if is_on_floor() else velocity.y - delta * 19.0
	move_and_slide()
	if is_on_wall() and absf(speed) > 0.2:
		speed = move_toward(speed, get_real_velocity().dot(heading), delta * 26.0)
	for wheel in wheels:
		wheel.rotation.x = fposmod(wheel.rotation.x + speed * delta / wheel_radius, TAU)
	for swivel in steering:
		swivel.rotation.y = steer
	_update_pose()


func _update_pose() -> void:
	var space := get_world_3d().direct_space_state
	var ends := PackedFloat32Array()
	for axle in [-wheelbase * 0.5, wheelbase * 0.5]:
		var check := to_global(Vector3(0.0, 0.0, axle))
		var ray := PhysicsRayQueryParameters3D.create(check + Vector3.UP * 0.75, check - Vector3.UP * 0.85, 1, [get_rid()])
		var ground := space.intersect_ray(ray)
		if not ground.is_empty() and Vector3(ground["normal"]).y > 0.75:
			ends.append(Vector3(ground["position"]).y - global_position.y)
	if ends.size() == 2:
		shell.position.y = (ends[0] + ends[1]) * 0.5 + 0.015
		shell.rotation.x = -atan2(ends[1] - ends[0], wheelbase)
	if occupied:
		var pivot := global_position + Vector3.UP * 1.6
		var ideal := to_global(Vector3(0.0, 3.0, -6.8))
		var ray := PhysicsRayQueryParameters3D.create(pivot, ideal, 1, [get_rid()])
		var obstruction := space.intersect_ray(ray)
		var camera_at := ideal
		if not obstruction.is_empty():
			camera_at = Vector3(obstruction["position"]).move_toward(pivot, 0.18)
		camera.global_position = camera_at
		camera.look_at(global_position + global_basis.z * 5.0 + Vector3.UP * 1.1)


func _animate_door() -> void:
	if door_tween and door_tween.is_running():
		door_tween.kill()
	door_tween = create_tween().set_trans(Tween.TRANS_SINE)
	door_tween.tween_property(door, "rotation:y", door_angle, 0.23)
	door_tween.tween_interval(0.26)
	door_tween.tween_property(door, "rotation:y", 0.0, 0.27)
