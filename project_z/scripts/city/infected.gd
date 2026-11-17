extends CharacterBody3D

const PLAYER := preload("res://scripts/city/player.gd")
const GRAPHICS := preload("res://scripts/graphics/materials.gd")
enum Behavior { IDLE, WANDER, INVESTIGATE_SOUND, SUSPICIOUS, CHASE, ATTACK, SEARCH, RETURN, DEAD }

signal killed(id: String)

var id := ""
var target: PLAYER
var model: Node3D
var anchor := Vector3.ZERO
var clue := Vector3.ZERO
var pace := 2.0
var health := 100
var behavior := Behavior.IDLE
var awareness := 0.0
var cooldown := 0.0
var windup := 0.0
var attack_recovery := 0.0
var stagger := 0.0
var memory := 0.0
var turn := 1.0
var stuck := 0.0
var animator: AnimationPlayer
var clip := ""
var agent := NavigationAgent3D.new()
var route_requested := false


func _ready() -> void:
	add_to_group("city_infected")
	anchor = global_position
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | PLAYER.VEHICLE_LAYER
	floor_snap_length = 0.34
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.27
	capsule.height = 1.72
	collision.shape = capsule
	collision.position.y = 0.86
	add_child(collision)
	add_child(agent)
	agent.path_desired_distance = 0.9
	agent.target_desired_distance = 1.35
	if model:
		GRAPHICS.adapt_model(model, &"infected")
		model.rotation.y = PI
		add_child(model)
		animator = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if animator:
			for name in ["Idle", "Shamble", "Pursuit"]:
				var animation := animator.get_animation(name)
				if animation:
					animation.loop_mode = Animation.LOOP_LINEAR
	_play("Idle")


func hear(point: Vector3, strength: float) -> void:
	if behavior in [Behavior.DEAD, Behavior.ATTACK, Behavior.CHASE] or point.distance_to(global_position) > strength:
		return
	clue = point
	memory = 4.0
	behavior = Behavior.INVESTIGATE_SOUND


func _physics_process(delta: float) -> void:
	if not target.playable or behavior == Behavior.DEAD:
		return
	var distance := global_position.distance_to(target.global_position)
	cooldown = maxf(0.0, cooldown - delta)
	attack_recovery = maxf(0.0, attack_recovery - delta)
	stagger = maxf(0.0, stagger - delta)
	memory = maxf(0.0, memory - delta)
	var to_player := target.global_position - global_position
	var facing := (-global_basis.z).dot(to_player.normalized())
	var sight_range := 13.0 if target.crouched else 26.0
	var sees := distance < sight_range and (facing > 0.28 or distance < 3.5 or behavior == Behavior.CHASE) and _clear(target.global_position)
	if sees:
		awareness = minf(1.0, awareness + delta * (2.7 if distance < 9 else 1.15))
		clue = target.global_position
		memory = 5.0
	else:
		awareness = maxf(0.0, awareness - delta * 0.36)
	var direction := Vector3.ZERO
	if windup > 0.0:
		windup = maxf(0.0, windup - delta)
		if windup == 0.0:
			if distance < 1.62 and not target.driving and _clear(target.global_position) and stagger == 0.0:
				target.damage(13.0 if pace < 2.6 else 20.0)
				target.exposure = minf(100.0, target.exposure + 7.5)
			behavior = Behavior.CHASE
	elif stagger == 0.0 and attack_recovery == 0.0:
		if (sees and awareness >= 1.0) or (behavior == Behavior.CHASE and memory > 0.0):
			behavior = Behavior.CHASE if sees else Behavior.SEARCH
			if sees and distance < 1.43 and cooldown == 0.0:
				behavior = Behavior.ATTACK
				windup = 0.39
				cooldown = 1.10
				attack_recovery = 0.86
				_play("LungeAttack")
			else:
				direction = _direction(clue, delta)
		elif sees:
			behavior = Behavior.SUSPICIOUS
		elif memory > 0.0 and behavior in [Behavior.INVESTIGATE_SOUND, Behavior.SEARCH]:
			direction = _direction(clue, delta)
		elif global_position.distance_to(anchor) > 6.0:
			behavior = Behavior.RETURN
			direction = _direction(anchor, delta)
		else:
			behavior = Behavior.WANDER
			direction = _direction(anchor + Vector3(sin(float(Time.get_ticks_msec()) * 0.00027) * 3.2, 0, cos(float(Time.get_ticks_msec()) * 0.00024) * 2.9), delta)
	var look := to_player if behavior in [Behavior.CHASE, Behavior.ATTACK, Behavior.SUSPICIOUS] else direction
	if Vector2(look.x, look.z).length_squared() > 0.02:
		rotation.y = lerp_angle(rotation.y, atan2(-look.x, -look.z), minf(delta * 8.0, 1.0))
	var speed := pace if behavior in [Behavior.CHASE, Behavior.SEARCH] else pace * 0.57
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y = -0.8 if is_on_floor() else velocity.y - delta * 16.5
	move_and_slide()
	if windup == 0.0 and stagger == 0.0 and attack_recovery == 0.0:
		var moving := direction.length_squared() > 0.01 and get_real_velocity().length_squared() > 0.03
		var running := behavior == Behavior.CHASE and pace > 2.6
		var next := ("Pursuit" if running else "Shamble") if moving else "Idle"
		var playback := clampf(speed / (3.2 if running else 1.52), 0.68, 1.43) if moving else 1.0
		_play(next, false, playback)


func _direction(destination: Vector3, delta: float) -> Vector3:
	var offset := destination - global_position
	offset.y = 0.0
	if offset.length_squared() < 0.66:
		return Vector3.ZERO
	var direction := offset.normalized()
	if _clear(destination):
		route_requested = false
		stuck = 0.0
		return direction
	if NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) > 0:
		if not route_requested or agent.target_position.distance_squared_to(destination) > 3.0:
			agent.target_position = destination
			route_requested = true
		var next := agent.get_next_path_position()
		if not agent.is_navigation_finished() and agent.is_target_reachable():
			var route := next - global_position
			route.y = 0.0
			if route.length_squared() > 0.05:
				return route.normalized()
	stuck += delta
	if stuck > 1.15:
		turn *= -1.0
		stuck = 0.0
	for angle: float in [0.64, 1.15, 1.58, 2.1]:
		var bypass := direction.rotated(Vector3.UP, angle * turn)
		if _clear(global_position + bypass * 2.0):
			return bypass
	return Vector3.ZERO


func _clear(to: Vector3) -> bool:
	return target.visible_from(global_position + Vector3.UP * 1.15, to + Vector3.UP * 1.12)


func take_hit(damage: int) -> void:
	if behavior == Behavior.DEAD:
		return
	health = maxi(0, health - damage)
	windup = 0.0
	attack_recovery = 0.0
	awareness = 1.0
	if health > 0:
		stagger = 0.33
		_play("HitReaction", true)
		return
	behavior = Behavior.DEAD
	remove_from_group("city_infected")
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	_play("Death")
	killed.emit(id)
	get_tree().create_timer(7.0, false).timeout.connect(queue_free)


func _play(name: String, restart: bool = false, speed: float = 1.0) -> void:
	if not animator:
		return
	if (clip != name or restart) and animator.has_animation(name):
		clip = name
		if restart:
			animator.stop(true)
		animator.play(name, 0.08)
	animator.speed_scale = speed
