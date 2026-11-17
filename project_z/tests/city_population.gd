extends SceneTree

const CITY := preload("res://scenes/world/kaldran_city.tscn")
const PLAN := preload("res://scripts/city/layout.gd")

var failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var city := CITY.instantiate()
	root.add_child(city)
	var parking = city.stream.dressing.parking
	var buildings := [0, 0, 0, 0]
	var lots := [0, 0, 0, 0]
	var vehicles := 0
	var protected := true
	var grounded := true
	var vehicle_types := {}
	for z in PLAN.COUNT:
		for x in PLAN.COUNT:
			var key := Vector2i(x, z)
			var midpoint := PLAN.origin(key) + Vector2(50, 50)
			var zone := PLAN.district(midpoint.x, midpoint.y)
			var parcels := PLAN.parcels(key)
			for building: Dictionary in parcels:
				if not building.get("infill", false):
					continue
				buildings[zone] += 1
				var footprint := Rect2(building.center - building.size * 0.5, building.size)
				protected = protected and PLAN.roadside_clear(footprint, 3.8)
			var lot: Dictionary = parking.plan_lot(key)
			if lot.is_empty():
				continue
			lots[zone] += 1
			var block := Node3D.new()
			root.add_child(block)
			parking.populate(block, lot, true)
			var group := block.get_node("StreetParking")
			for child in group.get_children():
				if not child.has_meta("vehicle_asset"):
					continue
				vehicles += 1
				vehicle_types[child.get_meta("vehicle_asset")] = true
				var body: StaticBody3D = child.get_child(1)
				var visual: MeshInstance3D = child.get_child(0)
				var box := visual.mesh.get_aabb()
				var half := box.size * Vector3(0.5, 0, 0.5)
				for ux: float in [-1.0, 0.0, 1.0]:
					for uz: float in [-1.0, 0.0, 1.0]:
						var point: Vector3 = child.to_global(Vector3(ux * half.x, 0, uz * half.z))
						protected = protected and PLAN.road_distance(point.x, point.z) >= 1.4
				var at := Vector2(child.position.x, child.position.z)
				grounded = (grounded and child.basis.y.y > 0.95 and body.collision_layer == 1
					and absf(child.position.y - city.terrain.ground_height(at)) < 0.20)
			block.free()
	_check(buildings.min() >= 55, "New buildings in all four districts " + str(buildings))
	_check(lots.min() >= 15, "Roadside parking in all four districts " + str(lots))
	_check(vehicles >= 160, "Detailed blocks populate parked vehicles (%d)" % vehicles)
	_check(vehicle_types.size() == 5, "All five downloaded vehicle bodies are placed")
	_check(protected, "Vehicle and building footprints leave traffic lanes open")
	_check(grounded, "Parked vehicles follow terrain and have physical collision")
	print("Population failures: %d" % failed)
	quit(0 if failed == 0 else 1)


func _check(ok: bool, label: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failed += 1
