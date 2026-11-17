extends Node3D

enum Kind { CACHE, HINGE, SLIDING }

var kind: Kind = Kind.CACHE
var label_text := ""
var has_crowbar := false
var medkits := 0
var opened := false
var marker: Label3D
var blocker: CollisionObject3D
var panels: Array[Node3D] = []
var closed_positions: Array[Vector3] = []
var closed_yaw := 0.0
var hinge_open_angle := 1.52
var busy := false


func _ready() -> void:
	add_to_group("neighborhood_interaction")


func focus_point() -> Vector3:
	return global_position + Vector3.UP * (0.55 if kind == Kind.CACHE else 1.15)


func prompt() -> String:
	if kind == Kind.CACHE:
		return "Empty · " + label_text if opened else "[E] Search " + label_text
	return "[E] %s %s" % ["Close" if opened else "Open", label_text]


func activate(survivor: CharacterBody3D) -> void:
	if kind == Kind.CACHE:
		if opened:
			return
		opened = true
		if marker:
			marker.modulate = Color("#849087")
			marker.text = "SEARCHED"
		survivor.collect_cache(has_crowbar, medkits)
		return

	if busy:
		return
	if opened and survivor.global_position.distance_to(global_position) < 0.85:
		survivor.announce("Step back to close the door.")
		return
	opened = not opened
	busy = true
	blocker.set_deferred("collision_layer", 0 if opened else 1)
	var animation := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if kind == Kind.HINGE:
		animation.tween_property(panels[0], "rotation:y", closed_yaw + (hinge_open_angle if opened else 0.0), 0.26)
	else:
		for index in panels.size():
			var offset := Vector3((-0.86 if index == 0 else 0.86) if opened else 0.0, 0.0, 0.0)
			animation.tween_property(panels[index], "position", closed_positions[index] + offset, 0.26)
	animation.finished.connect(func(): busy = false)

