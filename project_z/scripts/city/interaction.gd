extends Node3D

const GEO := preload("res://scripts/city/geometry.gd")

var id := ""
var title := ""
var verb := "Use"
var kind := ""
var contents: Dictionary = {}
var active := false
var blocker: CollisionObject3D
var handler: Callable
var hinge: Node3D
var angle := -PI / 2
var swing: Tween
var container_lid: Node3D
var lid_closed := 0.0


func _ready() -> void:
	add_to_group("city_interaction")


func focus_point() -> Vector3:
	return global_position + Vector3.UP * (1.05 if kind == "door" else 0.04)


func prompt() -> String:
	if kind == "door":
		return "[E] %s %s" % ["Close" if active else "Open", title]
	if kind == "loot" and active:
		return title + " · searched"
	return "[E] %s %s" % [verb, title]


func activate(player: CharacterBody3D) -> void:
	if handler.is_valid():
		handler.call(self, player)


func create_door(width: float, height: float, surface: Material) -> void:
	hinge = Node3D.new()
	hinge.position.x = -width * 0.5
	add_child(hinge)
	GEO.box(hinge, Vector3(width * 0.5, height * 0.5, 0), Vector3(width - 0.03, height - 0.025, 0.07), surface)
	GEO.box(hinge, Vector3(width - 0.13, 1.02, -0.063), Vector3(0.12, 0.034, 0.07), GEO.material(Color("#bbb4a1")))
	blocker = GEO.box(self, Vector3(0, height * 0.5, 0), Vector3(width, height, 0.1), null, true) as CollisionObject3D


func restore(on: bool, animate: bool = false) -> void:
	active = on
	if hinge:
		blocker.set_deferred("collision_layer", 0 if on else 1)
		if swing and swing.is_running():
			swing.kill()
		var yaw := angle if on else 0.0
		if animate:
			swing = create_tween().set_trans(Tween.TRANS_SINE)
			swing.tween_property(hinge, "rotation:y", yaw, 0.23)
		else:
			hinge.rotation.y = yaw
	if container_lid:
		var pitch := lid_closed - (1.16 if active else 0.0)
		if animate:
			if swing and swing.is_running():
				swing.kill()
			swing = create_tween().set_trans(Tween.TRANS_SINE)
			swing.tween_property(container_lid, "rotation:x", pitch, 0.28)
		else:
			container_lid.rotation.x = pitch
