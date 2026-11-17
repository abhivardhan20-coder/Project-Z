extends CharacterBody3D

signal state_changed
signal message(text: String)
signal cache_searched
signal hit_enemy
signal harmed
signal died

const INTERACTION := preload("res://scripts/neighborhood/neighborhood_interaction.gd")
const WALK_SPEED := 4.0
const SPRINT_SPEED := 6.7
const JUMP_SPEED := 5.35
const MAX_HEALTH := 100

var health := MAX_HEALTH
var medkits := 0
var has_weapon := false
var active := true
var finished := false
var camera: Camera3D
var crowbar: Node3D
var cooldown := 0.0
var bob_time := 0.0
var swing: Tween
var focused: INTERACTION
var focus_time := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.22
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.75
	var shape := CollisionShape3D.new()
	shape.position.y = 0.875
	shape.shape = capsule
	add_child(shape)

	camera = Camera3D.new()
	camera.name = "SurvivorView"
	camera.position.y = 1.58
	camera.fov = 76.0
	camera.near = 0.055
	add_child(camera)
	camera.make_current()


func equip_view_model(model: Node3D) -> void:
	crowbar = Node3D.new()
	crowbar.position = Vector3(0.32, -0.36, -0.64)
	crowbar.rotation_degrees = Vector3(67, -14, -14)
	camera.add_child(crowbar)
	model.scale = Vector3.ONE * 0.76
	crowbar.add_child(model)
	crowbar.hide()


func _unhandled_input(event: InputEvent) -> void:
	if finished:
		return
	if event.is_action_pressed("neighborhood_pause") and not event.is_echo():
		active = not active
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if active else Input.MOUSE_MODE_VISIBLE
		state_changed.emit()
		get_viewport().set_input_as_handled()
		return
	if not active:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			active = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			state_changed.emit()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x * 0.0022
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.0022, -1.46, 1.46)
	elif event.is_action_pressed("neighborhood_interact") and not event.is_echo():
		var target := find_interaction()
		if target:
			target.activate(self)
	elif event.is_action_pressed("neighborhood_heal") and not event.is_echo():
		heal()
	elif event.is_action_pressed("neighborhood_swing"):
		attack()


func _physics_process(delta: float) -> void:
	if not active or finished:
		return
	cooldown = maxf(0.0, cooldown - delta)
	var input := Input.get_vector("neighborhood_left", "neighborhood_right", "neighborhood_forward", "neighborhood_back")
	var direction := global_basis * Vector3(input.x, 0, input.y)
	var speed := SPRINT_SPEED if Input.is_action_pressed("neighborhood_sprint") else WALK_SPEED
	velocity.x = move_toward(velocity.x, direction.x * speed, 30.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 30.0 * delta)
	if is_on_floor():
		velocity.y = JUMP_SPEED if Input.is_action_just_pressed("neighborhood_jump") else -0.75
	else:
		velocity.y -= 17.0 * delta
	move_and_slide()
	if input.length_squared() > 0.04 and is_on_floor():
		bob_time += delta * (13.0 if speed == SPRINT_SPEED else 9.5)
		camera.position.y = lerpf(camera.position.y, 1.58 + sin(bob_time) * 0.028, 10.0 * delta)
	else:
		camera.position.y = lerpf(camera.position.y, 1.58, 10.0 * delta)

	focus_time -= delta
	if focus_time <= 0.0:
		focus_time = 0.07
		focused = find_interaction()


func find_interaction() -> INTERACTION:
	var best: INTERACTION
	var score := 0.0
	var forward := -camera.global_basis.z
	for node in get_tree().get_nodes_in_group("neighborhood_interaction"):
		var target := node as INTERACTION
		var difference := target.focus_point() - camera.global_position
		var distance := difference.length()
		if distance < 0.01 or distance > 2.7:
			continue
		var alignment := forward.dot(difference / distance)
		var candidate := alignment - distance * 0.10
		if alignment > 0.60 and candidate > score and unobstructed(camera.global_position, target.focus_point(), target.blocker):
			best = target
			score = candidate
	return best


func unobstructed(from: Vector3, to: Vector3, allowed: CollisionObject3D = null) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return result.is_empty() or result.get("collider") == allowed


func collect_cache(crowbar_found: bool, medical: int) -> void:
	if crowbar_found:
		has_weapon = true
		crowbar.show()
	medkits += medical
	cache_searched.emit()
	state_changed.emit()
	if crowbar_found:
		announce("Crowbar equipped. Left click to swing.")
	elif medical > 0:
		announce("+%d field dressing%s" % [medical, "s" if medical != 1 else ""])
	else:
		announce("Cache checked. Supplies taken.")


func announce(text: String) -> void:
	message.emit(text)


func attack() -> void:
	if not active or finished or cooldown > 0.0:
		return
	if not has_weapon:
		announce("Search the roadside supply crate for a crowbar.")
		return
	cooldown = 0.48
	if swing and swing.is_running():
		swing.kill()
	crowbar.rotation_degrees = Vector3(67, -14, -14)
	swing = create_tween().set_trans(Tween.TRANS_QUAD)
	swing.tween_property(crowbar, "rotation_degrees", Vector3(18, 33, 22), 0.12)
	swing.tween_property(crowbar, "rotation_degrees", Vector3(67, -14, -14), 0.30)

	var victim: CharacterBody3D
	var nearest := 2.55
	for node in get_tree().get_nodes_in_group("neighborhood_infected"):
		var target := node as CharacterBody3D
		var point := target.global_position + Vector3.UP * 1.25
		var difference := point - camera.global_position
		var distance := difference.length()
		if distance < nearest and (-camera.global_basis.z).dot(difference.normalized()) > 0.72 and unobstructed(camera.global_position, point):
			victim = target
			nearest = distance
	if victim:
		victim.take_hit(34)
		hit_enemy.emit()


func heal() -> void:
	if not active or finished:
		return
	if health >= MAX_HEALTH:
		announce("Health is full.")
	elif medkits == 0:
		announce("No field dressings left.")
	else:
		medkits -= 1
		health = mini(MAX_HEALTH, health + 38)
		state_changed.emit()
		announce("Field dressing applied.")


func take_damage(amount: int) -> void:
	if not active or finished:
		return
	health = maxi(0, health - amount)
	harmed.emit()
	state_changed.emit()
	if health == 0:
		stop()
		died.emit()


func stop() -> void:
	finished = true
	active = false
	velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

