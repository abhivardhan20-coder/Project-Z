extends CharacterBody3D

const MODELS := preload("res://scripts/neighborhood/neighborhood_assets.gd")
const GRAPHICS := preload("res://scripts/graphics/materials.gd")
const AIM_POSE := preload("res://scripts/city/player_aim.gd")
const VEHICLE_LAYER := 8
const SURVIVOR_MODEL := "res://assets/characters/survivor.glb"
const LOOP_CLIPS := [&"Idle", &"Walk", &"Jog", &"Sprint", &"CrouchIdle", &"CrouchWalk", &"Airborne"]
const STANDING := 1.75
const CROUCHED := 1.15
const HEIGHT := 1.62
const SPEED := 4.2
const SPRINT := 6.6
const KEYS := {
	"city_left": KEY_A, "city_right": KEY_D, "city_forward": KEY_W, "city_back": KEY_S,
	"city_jump": KEY_SPACE, "city_sprint": KEY_SHIFT, "city_crouch": KEY_CTRL, "city_use": KEY_E,
	"city_light": KEY_F, "city_reload": KEY_R, "city_pack": KEY_TAB, "city_map": KEY_M,
	"city_pause": KEY_ESCAPE, "city_journal": KEY_J, "city_save": KEY_F5, "city_debug": KEY_F3,
}

signal action_requested(action: String)
signal noise_at(point: Vector3, strength: float)
signal hurt(amount: float)
signal died

var health := 100.0
var stamina := 100.0
var hunger := 100.0
var thirst := 100.0
var exposure := 0.0
var playable := false
var driving := false
var sensitivity := 0.0024
var shoulder := 0.45
var camera_distance := 3.1
var camera: Camera3D
var eye := Node3D.new()
var capsule := CapsuleShape3D.new()
var collider := CollisionShape3D.new()
var body := Node3D.new()
var flashlight := SpotLight3D.new()
var aiming := false
var pistol_equipped := false
var gait := 0.0
var crouched := false
var focused: Node3D
var scan_time := 0.0
var skeleton: Skeleton3D
var animator: AnimationPlayer
var hand_socket: BoneAttachment3D
var active_clip: StringName
var action_time := 0.0
var aim_pose: AIM_POSE
var last_fall_speed := 0.0
var step_phase := 0


static func register_controls() -> void:
	for name: String in KEYS:
		if not InputMap.has_action(name):
			InputMap.add_action(name)
			var key := InputEventKey.new()
			key.physical_keycode = KEYS[name]
			InputMap.action_add_event(name, key)
	for entry: Array in [["city_attack", MOUSE_BUTTON_LEFT], ["city_aim", MOUSE_BUTTON_RIGHT]]:
		if not InputMap.has_action(entry[0]):
			InputMap.add_action(entry[0])
			var button := InputEventMouseButton.new()
			button.button_index = entry[1]
			InputMap.action_add_event(entry[0], button)


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4 | VEHICLE_LAYER
	floor_snap_length = 0.33
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(51.0)
	capsule.radius = 0.28
	capsule.height = STANDING
	collider.shape = capsule
	collider.position.y = STANDING / 2.0
	add_child(collider)
	add_child(body)
	_create_survivor()
	eye.position.y = HEIGHT
	add_child(eye)
	camera = Camera3D.new()
	camera.fov = 72
	camera.far = 1150
	camera.near = 0.055
	eye.add_child(camera)
	camera.current = true
	flashlight.light_color = Color("#fff2d1")
	flashlight.light_energy = 2.7
	flashlight.spot_angle = 35
	flashlight.spot_range = 28
	flashlight.hide()
	eye.add_child(flashlight)


func _unhandled_input(event: InputEvent) -> void:
	if not playable:
		return
	if driving:
		for action in ["city_use", "city_light"]:
			if event.is_action_pressed(action) and not event.is_echo():
				action_requested.emit(action)
				get_viewport().set_input_as_handled()
				return
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * sensitivity
		eye.rotation.x = clampf(eye.rotation.x - event.relative.y * sensitivity, -1.15, 1.09)
	elif event.is_action_pressed("city_light"):
		flashlight.visible = not flashlight.visible
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = maxf(camera_distance - 0.45, 1.15)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = minf(camera_distance + 0.45, 4.6)
	for action in ["city_use", "city_attack", "city_reload"]:
		if event.is_action_pressed(action) and not event.is_echo():
			action_requested.emit(action)


func _physics_process(delta: float) -> void:
	if not playable or driving:
		return
	var pressed := Input.get_vector("city_left", "city_right", "city_forward", "city_back")
	var direction := global_basis * Vector3(pressed.x, 0, pressed.y)
	if Input.is_action_pressed("city_crouch"):
		_resize(CROUCHED)
	elif crouched and _can_stand():
		_resize(STANDING)
	aiming = Input.is_action_pressed("city_aim")
	var sprinting := Input.is_action_pressed("city_sprint") and not crouched and not aiming and stamina > 0.2 and pressed.length_squared() > 0.2
	var speed := 2.0 if crouched else (SPRINT if sprinting else SPEED)
	stamina = clampf(stamina + (-18.0 if sprinting else 12.0) * delta, 0, 100)
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 27.0)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 27.0)
	var landed := is_on_floor()
	if landed:
		var jump := not crouched and stamina >= 10.0 and Input.is_action_just_pressed("city_jump")
		velocity.y = 4.6 if jump else -0.9
		if jump:
			stamina -= 10.0
	else:
		velocity.y -= 16.5 * delta
		last_fall_speed = maxf(last_fall_speed, -velocity.y)
	if landed and velocity.y <= 0.0 and pressed.length_squared() > 0.03:
		_step_up(Vector3(velocity.x, 0, velocity.z) * delta)
	move_and_slide()
	if not landed and is_on_floor():
		if last_fall_speed > 13.5:
			damage((last_fall_speed - 13.5) * 5.5)
		last_fall_speed = 0.0
	_animate(delta, pressed, speed)
	_update_camera(delta)
	scan_time -= delta
	if scan_time <= 0.0:
		scan_time = 0.09
		focused = find_focus()


func _step_up(motion: Vector3) -> void:
	var origin := global_transform
	var contact := KinematicCollision3D.new()
	if not test_move(origin, motion, contact) or contact.get_normal().y > cos(floor_max_angle):
		return
	var rise := Vector3.UP * 0.22
	if test_move(origin, rise):
		return
	var lifted := origin.translated(rise)
	var forward := motion.normalized() * (motion.length() + 0.055)
	if test_move(lifted, forward):
		return
	var landing := lifted.translated(forward)
	if not test_move(landing, Vector3.DOWN * 0.24, contact) or contact.get_normal().y < cos(floor_max_angle):
		return
	var gain := 0.22 + contact.get_travel().y
	if gain > 0.014:
		global_position.y += gain + 0.002


func _resize(height: float) -> void:
	crouched = height < STANDING
	capsule.height = height
	collider.position.y = height * 0.5


func _can_stand() -> bool:
	var upper := SphereShape3D.new()
	upper.radius = capsule.radius * 0.94
	var check := PhysicsShapeQueryParameters3D.new()
	check.shape = upper
	check.transform.origin = global_position + Vector3.UP * (STANDING - capsule.radius)
	check.collision_mask = 1
	check.exclude = [get_rid()]
	check.motion = Vector3.DOWN * (STANDING - CROUCHED)
	var space := get_world_3d().direct_space_state
	return space.intersect_shape(check, 1).is_empty() and space.cast_motion(check)[0] >= 0.99


func _update_camera(delta: float) -> void:
	eye.position.y = lerpf(eye.position.y, HEIGHT - (0.56 if crouched else 0.0), minf(delta * 12.0, 1.0))
	var desired := Vector3(shoulder, 0.14, camera_distance * (0.63 if aiming else 1.0))
	var origin := eye.global_position
	var cast := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.16
	cast.shape = sphere
	cast.transform.origin = origin
	cast.motion = eye.global_basis * desired
	cast.collision_mask = 1
	cast.exclude = [get_rid()]
	var safe := get_world_3d().direct_space_state.cast_motion(cast)[0]
	var result := desired * maxf(0.0, safe - 0.027)
	camera.position = result if result.length_squared() < camera.position.length_squared() else camera.position.lerp(result, minf(delta * 14.0, 1.0))
	body.visible = camera.position.length_squared() > 0.65
	flashlight.position.z = -0.07


func visible_from(from: Vector3, to: Vector3, allowed: CollisionObject3D = null) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == allowed


func find_focus() -> Node3D:
	var best: Node3D
	var best_score := -INF
	for group in ["city_interaction", "neighborhood_interaction"]:
		for node in get_tree().get_nodes_in_group(group):
			var target := node as Node3D
			if not target or target.is_queued_for_deletion() or target.global_position.distance_squared_to(global_position) > 9.0:
				continue
			var point: Vector3 = target.focus_point()
			var offset := point - eye.global_position
			var distance := offset.length()
			var alignment := offset.normalized().dot(-eye.global_basis.z)
			var score := alignment - distance * 0.15
			if distance < 2.85 and alignment > 0.46 and score > best_score and visible_from(eye.global_position, point, target.blocker):
				best = target
				best_score = score
	return best


func announce(message: String) -> void:
	action_requested.emit("notice|" + message)


func set_driving(enabled: bool) -> void:
	driving = enabled
	focused = null
	velocity = Vector3.ZERO
	collision_layer = 0 if enabled else 2
	collision_mask = 0 if enabled else 1 | 4 | VEHICLE_LAYER
	body.visible = not enabled
	if not enabled:
		_resize(STANDING)
		eye.rotation.x = 0.0
		camera.make_current()


func damage(amount: float) -> void:
	if health <= 0.0:
		return
	health = maxf(0.0, health - amount)
	hurt.emit(amount)
	if health == 0.0:
		playable = false
		died.emit()


func _animate(delta: float, movement: Vector2, speed: float) -> void:
	var moving := movement.length_squared() > 0.03
	var visual_speed := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	var facing := body.rotation.y
	if aiming or action_time > 0.0:
		facing = 0.0
	elif moving:
		facing = atan2(-movement.x, -movement.y)
	body.rotation.y = lerp_angle(body.rotation.y, facing, minf(1.0, delta * 10.0))
	if moving and visual_speed > 0.15:
		gait += delta * speed * 2.9
		if is_on_floor() and floori(gait / PI) != step_phase:
			step_phase = floori(gait / PI)
			noise_at.emit(global_position, 3.5 if crouched else speed * 1.7)
	action_time = maxf(0.0, action_time - delta)
	var use_aim := aiming and pistol_equipped and is_on_floor() and action_time == 0.0
	if aim_pose:
		aim_pose.influence = move_toward(aim_pose.influence, 1.0 if use_aim else 0.0, delta * 8.0)
		aim_pose.pitch = clampf(eye.rotation.x, -0.62, 0.62)
	if action_time > 0.0:
		return
	if not is_on_floor() and (velocity.y > 0.0 or last_fall_speed > 2.2):
		_play(&"Airborne")
	elif crouched:
		_play(&"CrouchWalk" if moving and visual_speed > 0.15 else &"CrouchIdle")
	elif visual_speed < 0.15:
		_play(&"Idle")
	elif speed == SPRINT:
		_play(&"Sprint", clampf(visual_speed / 6.2, 0.7, 1.2))
	elif visual_speed < 2.45:
		_play(&"Walk", clampf(visual_speed / 1.55, 0.60, 1.45))
	else:
		_play(&"Jog", clampf(visual_speed / 3.55, 0.75, 1.25))


func _create_survivor() -> void:
	var model := MODELS.new().instantiate(SURVIVOR_MODEL)
	GRAPHICS.adapt_model(model, &"survivor")
	model.rotation.y = PI
	body.add_child(model)
	skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	animator = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	hand_socket = BoneAttachment3D.new()
	hand_socket.name = "CrowbarGrip"
	if not skeleton or not animator:
		push_error("The city survivor requires a skeleton and animation player.")
		body.add_child(hand_socket)
		return
	skeleton.add_child(hand_socket)
	hand_socket.bone_name = &"RightHand"
	for clip_name: StringName in LOOP_CLIPS:
		animator.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
	aim_pose = AIM_POSE.new()
	aim_pose.influence = 0.0
	skeleton.add_child(aim_pose)
	aim_pose.configure(animator.get_animation(&"Aim"))
	_play(&"Idle")
	animator.advance(0.0)


func animate_attack(ranged: bool) -> void:
	action_time = 0.30 if ranged else 0.43
	_play(&"Recoil" if ranged else &"CrowbarSwing", 1.0, true)


func reset_visual() -> void:
	action_time = 0.0
	aiming = false
	if aim_pose:
		aim_pose.influence = 0.0
	body.rotation.y = 0.0
	_play(&"Idle")


func _play(next_clip: StringName, speed: float = 1.0, restart: bool = false) -> void:
	if not animator:
		return
	if active_clip != next_clip or restart:
		active_clip = next_clip
		if restart and animator.current_animation == next_clip:
			animator.stop(true)
		animator.play(next_clip, 0.07 if restart else 0.15)
	animator.speed_scale = speed
