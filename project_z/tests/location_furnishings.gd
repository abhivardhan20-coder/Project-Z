extends SceneTree

const SCENE := preload("res://scenes/world/kaldran_city.tscn")
const PLAN := preload("res://scripts/city/layout.gd")

var city: Node3D
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	city = SCENE.instantiate()
	root.add_child(city)
	if city.get("player") == null:
		quit(1)
		return
	city.player.playable = true
	await _frames(12)
	for id: String in PLAN.PLACES:
		if id in ["safehouse", "corner_shop"]:
			continue
		var entrance: Vector3 = city.city_layout.place(id)
		var outside := entrance + Vector3.FORWARD * 1.72
		outside.y = city.city_layout.height(outside.x, outside.z) + 0.14
		city.player.global_position = outside
		city.player.velocity = Vector3.ZERO
		city.stream.refresh(outside, true)
		await _frames(12)
		var door := _target(id + "_door")
		var cache := _target(id + "_cache")
		_check(door != null and cache != null, id + " room loaded")
		if not door or not cache:
			continue
		_aim(door)
		_check(city.player.find_focus() == door, id + " door is reachable from outside")
		door.activate(city.player)
		await _frames(21)
		var aisle := Vector3(entrance.x, entrance.y, cache.global_position.z - 0.90)
		_check(await _walk(aisle), id + " aisle is walkable from the door to the supply case")
		_aim(cache)
		_check(city.player.find_focus() == cache, id + " case is visible and in reach")
		var note := _target(id + "_note")
		if note:
			var stance := Vector3(entrance.x + 0.93, entrance.y, note.global_position.z - 0.50)
			_check(await _walk(stance), id + " station log has a clear approach")
			_aim(note)
			_check(city.player.find_focus() == note, id + " station log is visible and in reach")
	print("Location furnishing failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _target(id: String) -> Node3D:
	for node in get_nodes_in_group("city_interaction"):
		if node.id == id:
			return node
	return null


func _aim(target: Node3D) -> void:
	var offset: Vector3 = target.focus_point() - city.player.eye.global_position
	city.player.rotation.y = atan2(-offset.x, -offset.z)
	city.player.eye.rotation.x = atan2(offset.y, Vector2(offset.x, offset.z).length())


func _walk(target: Vector3) -> bool:
	var reached := false
	for tick in 220:
		var offset: Vector3 = target - city.player.global_position
		offset.y = 0.0
		if offset.length() <= 0.24:
			reached = true
			break
		city.player.rotation.y = atan2(-offset.x, -offset.z)
		Input.action_press("city_forward")
		await physics_frame
	Input.action_release("city_forward")
	await _frames(4)
	return reached


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _check(ok: bool, label: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1
