extends Control

const PLAN := preload("res://scripts/city/layout.gd")

var actor := Vector3.ZERO
var objective := Vector3.ZERO
var discovered: Dictionary = {}


func _draw() -> void:
	var side := minf(size.x, size.y) - 38.0
	var start := (size - Vector2.ONE * side) * 0.5
	var paper := Rect2(start, Vector2.ONE * side)
	draw_rect(paper, Color("#222d2d"))
	var font := ThemeDB.fallback_font
	var names := ["HILLVIEW", "CIVIC", "OLD MARKET", "UTILITY"]
	for district in 4:
		var offset := Vector2(district % 2, district / 2) * side * 0.5
		var zone := Rect2(start + offset, Vector2.ONE * side * 0.5)
		draw_rect(zone, [Color("#353d33"), Color("#394044"), Color("#403832"), Color("#353d40")][district])
		draw_string(font, zone.position + Vector2(11, 25), names[district], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#b9beb0"))
	for axis: float in PLAN.AXES:
		var x := PackedVector2Array()
		var z := PackedVector2Array()
		for along in range(-495, 496, 9):
			x.append(_project(Vector2(axis + (PLAN.road_x_offset(along) if axis != 0 else 0.0), along), paper))
			z.append(_project(Vector2(along, axis + (PLAN.road_z_offset(along, axis) if axis != 0 else 0.0)), paper))
		var ink := Color("#acac94") if axis == 0 else Color("#727869")
		draw_polyline(x, ink, 3.0 if axis == 0 else 1.55, true)
		draw_polyline(z, ink, 3.0 if axis == 0 else 1.55, true)
	for id: String in PLAN.PLACES:
		if not discovered.has(id) and id != "safehouse":
			continue
		var entry: Array = PLAN.PLACES[id]
		var dot := _project(Vector2(entry[1], entry[2]), paper)
		draw_circle(dot, 3.0, Color("#b5d2a3"))
		draw_string(font, dot + Vector2(5, 11), entry[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#d9ded0"))
	var destination := _project(Vector2(objective.x, objective.z), paper)
	draw_arc(destination, 8.5, 0, TAU, 18, Color("#e7bc74"), 2, true)
	draw_circle(_project(Vector2(actor.x, actor.z), paper), 4.5, Color("#e8f3e9"))
	draw_rect(paper, Color("#63706a"), false, 1.2)


func _project(p: Vector2, bounds: Rect2) -> Vector2:
	return bounds.position + (p + Vector2.ONE * PLAN.LIMIT) / (2.0 * PLAN.LIMIT) * bounds.size
