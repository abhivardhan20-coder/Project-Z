extends SceneTree

const SCENE := preload("res://scenes/world/kaldran_city.tscn")
const PLAN := preload("res://scripts/city/layout.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var city := SCENE.instantiate()
	root.add_child(city)
	await _frames(12)
	if city.player == null or city.p06 == null:
		quit(1)
		return
	var player: CharacterBody3D = city.player
	player.playable = true
	var home: Node3D = city.p06.hillview.get_node("HillviewLobbyDoor")
	var shop: Node3D = city.p06.hillview.get_node("HillviewShopDoor")
	var center := Vector3(shop.global_position.x, 16.03, -250)
	player.global_position = center
	await _frames(12)
	_check(player.is_on_floor(), "standing on P06 road")
	await _walk_to(player, Vector3(center.x, 0, -256.65), "north curb ramp")
	await _walk_to(player, center, "north sidewalk to road")
	await _walk_to(player, Vector3(shop.global_position.x, 0, -242.0), "road to south curb and shop sidewalk")
	_check(player.global_position.y > 16.11, "south sidewalk height")
	shop.activate(player)
	await _frames(19)
	await _walk_to(player, shop.global_position + Vector3.BACK * 2.4, "shop threshold to interior")
	await _walk_to(player, shop.global_position + Vector3.FORWARD * 2.7, "shop exit")
	await _walk_to(player, Vector3(home.global_position.x, 0, player.global_position.z), "walk along south pavement")
	home.activate(player)
	await _frames(19)
	await _walk_to(player, home.global_position + Vector3.BACK * 3.0, "apartment threshold to lobby")
	player.global_position = Vector3(-215, PLAN.base_grade(-215, PLAN.bridge_center(-215)) + 0.07, PLAN.bridge_center(-215))
	player.velocity = Vector3.ZERO
	await _frames(12)
	for x: float in [-209.0, -200.0, -191.0, -185.0]:
		await _walk_to(player, Vector3(x, 0, PLAN.bridge_center(x)), "bridge deck at x=%.0f" % x)
	var curb_x := -315.0
	var curb_z := PLAN.bridge_center(curb_x)
	player.global_position = Vector3(curb_x, city.city_layout.height(curb_x, curb_z) + 0.08, curb_z)
	player.velocity = Vector3.ZERO
	await _frames(10)
	await _walk_to(player, Vector3(curb_x, 0, curb_z - 6.1), "step up a regular curb without jumping")
	for axis: float in [-380.0, -250.0, -140.0]:
		for side: float in [-1.0, 1.0]:
			var junction_x := PLAN.cross_street_x(axis, -250.0)
			var center_z := PLAN.bridge_center(junction_x)
			var at := Vector3(junction_x + (7.0 if axis == -140.0 else -7.0), 0, center_z - 0.5)
			at.y = city.city_layout.height(at.x, at.z) + 0.12
			player.global_position = at
			player.velocity = Vector3.ZERO
			city.stream.refresh(at, true)
			await _frames(8)
			await _walk_to(player, Vector3(junction_x, 0, center_z), "P06 junction approach %.0f" % axis)
			for distance: float in [4.0, 10.0]:
				var z := center_z + side * distance
				await _walk_to(player, Vector3(PLAN.cross_street_x(axis, z), 0, z),
					"P06 turn %.0f m %s at %.0f" % [distance, "north" if side < 0 else "south", axis])
	var sedan_count: int = city.p06.parked_sedans.size()
	_check(sedan_count == 3, "three roadworthy sedan placements")
	for sedan: Node3D in city.p06.parked_sedans:
		var wheel := sedan.to_global(Vector3(-0.8, 0.351, 1.44))
		var clearance: float = wheel.y - 0.351 - city.city_layout.height(wheel.x, wheel.z)
		_check(sedan.global_basis.y.dot(Vector3.UP) > 0.96 and absf(clearance) < 0.15, "sedan is upright and tires meet the road")
	print("P06 traversal failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _walk_to(player: CharacterBody3D, destination: Vector3, label: String) -> void:
	var reached := false
	for frame in 260:
		var offset := destination - player.global_position
		offset.y = 0.0
		if offset.length() <= 0.25:
			reached = true
			break
		player.rotation.y = atan2(-offset.x, -offset.z)
		Input.action_press("city_forward")
		await physics_frame
	Input.action_release("city_forward")
	await _frames(4)
	_check(reached, "%s (at %s)" % [label, player.global_position])


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _check(value: bool, label: String) -> void:
	print(("%s " % ("PASS" if value else "FAIL")) + label)
	if not value:
		failures += 1
