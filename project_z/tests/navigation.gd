extends SceneTree

const CITY := preload("res://scenes/world/kaldran_city.tscn")
const PLAN := preload("res://scripts/city/layout.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var city := CITY.instantiate()
	root.add_child(city)
	var map := root.world_3d.navigation_map
	for route: Array in [
		["Hillview road", Vector2(-300, -250), false],
		["Hillview drainage bridge", Vector2(-200, PLAN.bridge_center(-200)), true],
		["Civic road", Vector2(0, -140), false],
		["Freight approach", Vector2(200, 145), false],
		["Market approach", Vector2(-200, 150), false],
	]:
		var midpoint: Vector2 = route[1]
		var from := _sample(city, midpoint - Vector2(7, 0), route[2])
		var to := _sample(city, midpoint + Vector2(7, 0), route[2])
		city.stream.refresh(to, true)
		if route[2]:
			# Recreate the bridge blocks even if their first bake is still pending.
			city.stream.refresh(Vector3(440, 0, 440), true)
			city.stream.refresh(to, true)
		var path := await _wait_for_route(map, from, to)
		var ok := not path.is_empty()
		if ok and route[2]:
			var deck := PLAN.base_grade(midpoint.x, midpoint.y)
			for point in path:
				ok = ok and absf(point.y - deck) < 0.65
		print("%s %s connects across the block boundary" % ["PASS" if ok else "FAIL", route[0]])
		if not ok:
			failures += 1
	print("Navigation failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _sample(city: Node3D, position: Vector2, bridge: bool) -> Vector3:
	var surface := PLAN.base_grade(position.x, position.y) if bridge else float(city.terrain.ground_height(position))
	return Vector3(position.x, surface + 0.15, position.y)


func _wait_for_route(map: RID, from: Vector3, to: Vector3) -> PackedVector3Array:
	var deadline := Time.get_ticks_msec() + 25000
	while Time.get_ticks_msec() < deadline:
		await create_timer(0.05, true, false, true).timeout
		var path := NavigationServer3D.map_get_path(map, from, to, true)
		if path.size() >= 2 and path[0].distance_to(from) < 0.65 and path[-1].distance_to(to) < 0.65:
			return path
	return PackedVector3Array()
