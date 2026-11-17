extends Node3D

const PLAN := preload("res://scripts/city/layout.gd")
const MODELS := preload("res://scripts/neighborhood/neighborhood_assets.gd")
const SPECIES := [
	["res://assets/wildlife/deer.glb", 1.0, 0.0, ["idle", "walk", "run"], 1.45, 4.4, 13.0],
	["res://assets/wildlife/fox.glb", 1.0, PI, ["Look around", "Walk", "Walk"], 0.80, 2.35, 10.0],
]

var terrain: PLAN
var observer: CharacterBody3D
var refuge := Vector2.ZERO
var destination := Vector2.ZERO
var species := 0
var model: Node3D
var animator: AnimationPlayer
var roaming := RandomNumberGenerator.new()
var next_choice := 0.0
var alarm := 0.0
var retreat_from := Vector2.ZERO
var current_clip := -1
var active := false
var speed := 0.0


func _ready() -> void:
	var animal: Array = SPECIES[species]
	model = MODELS.new().instantiate(animal[0])
	model.scale = Vector3.ONE * float(animal[1])
	model.rotation.y = float(animal[2])
	add_child(model)
	animator = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animator:
		for clip: String in animal[3]:
			if animator.has_animation(clip):
				animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		_play(0)
	destination = refuge
	roaming.seed = int(refuge.x * 19.0 + refuge.y * 101.0)


func alert(at: Vector3, radius: float) -> void:
	if global_position.distance_squared_to(at) < radius * radius:
		retreat_from = Vector2(at.x, at.z)
		alarm = 3.4
		next_choice = 0.0


func _physics_process(delta: float) -> void:
	if not active:
		return
	var player_distance := observer.global_position.distance_squared_to(global_position)
	if player_distance > 130.0 * 130.0:
		return
	var animal: Array = SPECIES[species]
	var here := Vector2(global_position.x, global_position.z)
	var player_near := player_distance < pow(float(animal[6]), 2.0)
	alarm = maxf(0.0, alarm - delta)
	if player_near:
		retreat_from = Vector2(observer.global_position.x, observer.global_position.z)
		alarm = maxf(alarm, 1.1)
	next_choice -= delta
	if next_choice <= 0.0:
		_choose_destination(here)
	var direction := destination - here
	var moving := direction.length_squared() > 0.25
	var requested_speed := float(animal[5] if alarm > 0.0 else animal[4]) if moving else 0.0
	speed = move_toward(speed, requested_speed, delta * 5.5)
	if moving:
		direction = direction.normalized()
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.y), minf(delta * 5.2, 1.0))
		var ahead := here + direction * speed * delta
		if valid_site(ahead) and _path_clear(here, ahead + direction * 0.7):
			global_position = Vector3(ahead.x, terrain.height(ahead.x, ahead.y) + 0.025, ahead.y)
		else:
			destination = here
			next_choice = 0.0
			speed = 0.0
	_play(0 if speed < 0.30 else (2 if alarm > 0.0 else 1))


func _choose_destination(here: Vector2) -> void:
	next_choice = roaming.randf_range(2.5, 5.0)
	destination = here
	if alarm == 0.0 and roaming.randf() < 0.25:
		return
	var away := (here - retreat_from).normalized()
	var safe := 0.0
	for attempt in 10:
		var point := refuge + Vector2.from_angle(roaming.randf_range(0.0, TAU)) * roaming.randf_range(3.0, 24.0)
		if not valid_site(point) or not _path_clear(here, point):
			continue
		var distance := here.distance_to(point)
		var gain := (point - here).dot(away) if alarm > 0.0 else distance
		if gain > safe:
			destination = point
			safe = gain
	if alarm > 0.0:
		next_choice = 0.85


func _path_clear(from: Vector2, to: Vector2) -> bool:
	var start := Vector3(from.x, terrain.height(from.x, from.y) + 0.78, from.y)
	var finish := Vector3(to.x, terrain.height(to.x, to.y) + 0.78, to.y)
	var ray := PhysicsRayQueryParameters3D.create(start, finish, 1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


static func valid_site(at: Vector2) -> bool:
	return at.abs().x < 480.0 and at.abs().y < 480.0 and PLAN.road_distance(at.x, at.y) > 8.0


func _play(index: int) -> void:
	if animator and index != current_clip:
		current_clip = index
		animator.play(SPECIES[species][3][index], 0.16)
		animator.speed_scale = [1.0, 1.8, 3.6][index] if species == 1 else 1.0
