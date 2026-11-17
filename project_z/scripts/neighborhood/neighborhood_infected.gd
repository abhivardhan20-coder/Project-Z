extends CharacterBody3D

signal killed

const SURVIVOR := preload("res://scripts/neighborhood/neighborhood_survivor.gd")

var target: SURVIVOR
var visual: Node3D
var route: Callable
var health := 100
var speed := 2.25
var damage := 14
var awake := false
var attack_timer := 0.0
var path_timer := 0.0
var stagger := 0.0
var step := 0.0
var attack_pose := 0.0
var path := PackedVector3Array()


func _ready() -> void:
	add_to_group("neighborhood_infected")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.30
	capsule.height = 1.75
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.875
	add_child(collision)


func _physics_process(delta: float) -> void:
	if health == 0 or not target.active:
		return
	attack_timer = maxf(0.0, attack_timer - delta)
	stagger = maxf(0.0, stagger - delta)
	attack_pose = move_toward(attack_pose, 0.0, delta * 3.0)
	var separation := target.global_position - global_position
	separation.y = 0.0
	var distance := separation.length()
	var visible := distance < 21.0 and target.unobstructed(global_position + Vector3.UP, target.global_position + Vector3.UP)
	if distance < 6.5 or visible:
		awake = true
	var direction := Vector3.ZERO
	if awake and stagger == 0.0:
		if visible and distance < 1.36:
			if attack_timer == 0.0:
				attack_timer = 0.93
				attack_pose = 1.0
				target.take_damage(damage)
		else:
			direction = _pursuit(separation, visible, delta)

	if direction.length_squared() > 0.01 or distance < 1.4:
		var facing := direction if direction.length_squared() > 0.01 else separation.normalized()
		if facing.length_squared() > 0.01:
			rotation.y = lerp_angle(rotation.y, atan2(-facing.x, -facing.z), minf(1.0, delta * 9.0))
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y = -0.6 if is_on_floor() else velocity.y - 17.0 * delta
	move_and_slide()
	step += delta * (9.3 if direction.length_squared() > 0.01 else 1.8)
	visual.position.y = sin(step) * (0.034 if direction.length_squared() > 0.01 else 0.01)
	visual.rotation.z = sin(step * 0.5) * 0.052
	visual.rotation.x = -0.13 - attack_pose * 0.37 + stagger * 0.55


func _pursuit(separation: Vector3, visible: bool, delta: float) -> Vector3:
	path_timer -= delta
	if visible and path.is_empty():
		# An unobstructed ray is enough to walk directly across a road or yard.
		return separation.normalized()
	if path_timer <= 0.0:
		path_timer = 0.48
		path = route.call(global_position, target.global_position)
	while not path.is_empty():
		var difference := path[0] - global_position
		difference.y = 0.0
		if difference.length() > 0.34:
			return difference.normalized()
		path.remove_at(0)
	return separation.normalized() if visible else Vector3.ZERO


func take_hit(amount: int) -> void:
	health = maxi(0, health - amount)
	awake = true
	stagger = 0.29
	if health > 0:
		return
	remove_from_group("neighborhood_infected")
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	velocity = Vector3.ZERO
	var collapse := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD)
	collapse.tween_property(visual, "rotation:x", -1.56, 0.37)
	collapse.tween_property(visual, "position:y", 0.16, 0.37)
	killed.emit()

