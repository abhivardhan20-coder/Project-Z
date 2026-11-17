extends RefCounted

const PLAN := preload("res://scripts/city/layout.gd")
const GEO := preload("res://scripts/city/geometry.gd")
const TERRAIN := preload("res://scripts/city/terrain.gd")
const MODELS := preload("res://scripts/neighborhood/neighborhood_assets.gd")
const FURNITURE := preload("res://scripts/city/interior_assets.gd")
const VAN := "res://assets/vehicles/road/delivery_van.glb"
const MINIVAN := "res://assets/vehicles/road/minivan.glb"
const BUS := "res://assets/vehicles/road/city_bus.glb"
const HATCHBACK := "res://assets/vehicles/road/1990s_hatchback.glb"
const SEDAN := "res://assets/vehicles/road/1990s_sedan.glb"
const ASPHALT := Color("#545650")
const PAINT := Color("#c2bca2")

var terrain: TERRAIN
var models: MODELS
var lot_cache: Dictionary = {}
var car_meshes: Dictionary = {}


func _init(ground: TERRAIN, library: MODELS) -> void:
	terrain = ground
	models = library


func plan_lot(key: Vector2i) -> Dictionary:
	if not lot_cache.has(key):
		lot_cache[key] = _choose_lot(key)
	return lot_cache[key]


func _choose_lot(key: Vector2i) -> Dictionary:
	var corner := PLAN.origin(key)
	var zone := PLAN.district(corner.x + 50, corner.y + 50)
	var rng := RandomNumberGenerator.new()
	rng.seed = PLAN.SEED + key.x * 1979 + key.y * 2539
	if key == Vector2i(2, 2):
		# The lot east of Hillview Steps sits behind the existing sidewalk.
		var hillview := Vector2(-262.0, PLAN.bridge_center(-262.0) + 11.65)
		return {"at": hillview, "bounds": Rect2(hillview - Vector2(8.5, 4.0), Vector2(17, 8)),
			"horizontal": true, "side": 1.0, "zone": 0, "seed": 4}
	if zone == 0 and rng.randf() > 0.66:
		return {}
	var parcels := PLAN.parcels(key)
	var candidates: Array[Dictionary] = []
	for axis: float in PLAN.AXES:
		for horizontal: bool in [true, false]:
			var across := corner.y if horizontal else corner.x
			if axis < across - 18.0 or axis > across + 118.0:
				continue
			for along: float in [17.0, 34.0, 53.0, 69.0, 83.0]:
				var lane := (corner.x if horizontal else corner.y) + along
				var street := axis + (0.0 if axis == 0.0 else (
					PLAN.road_z_offset(lane, axis) if horizontal else PLAN.road_x_offset(lane)))
				for side: float in [-1.0, 1.0]:
					var drive := street + side * (11.7 if axis == 0 else 9.4)
					var at := Vector2(lane, drive) if horizontal else Vector2(drive, lane)
					var size := Vector2(17.0, 8.0) if horizontal else Vector2(8.0, 17.0)
					var bounds := Rect2(at - size * 0.5, size)
					if not Rect2(corner + Vector2.ONE * 1.0, Vector2.ONE * 98.0).encloses(bounds):
						continue
					if not PLAN.roadside_clear(bounds, 1.2) or not PLAN.available(bounds, parcels, 1.65):
						continue
					if not _flat(bounds):
						continue
					candidates.append({"at": at, "bounds": bounds, "horizontal": horizontal, "side": side, "zone": zone})
	if candidates.is_empty():
		return {}
	var lot: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
	lot["seed"] = rng.randi()
	return lot


func _flat(bounds: Rect2) -> bool:
	var low := INF
	var high := -INF
	for u: float in [0.0, 0.5, 1.0]:
		for v: float in [0.0, 0.5, 1.0]:
			var y := terrain.ground_height(bounds.position + bounds.size * Vector2(u, v))
			low = minf(low, y)
			high = maxf(high, y)
	return high - low < 1.37


func populate(parent: Node3D, lot: Dictionary, detail: bool) -> void:
	if lot.is_empty():
		return
	var group := Node3D.new()
	group.name = "StreetParking"
	parent.add_child(group)
	var at: Vector2 = lot.at
	var across := Vector2.DOWN if lot.horizontal else Vector2.RIGHT
	var along := Vector2.RIGHT if lot.horizontal else Vector2.DOWN
	var side: float = lot.side
	var rng := RandomNumberGenerator.new()
	rng.seed = lot.seed
	_paving(group, lot.bounds, detail, 0.086, GEO.material(ASPHALT), "ParkingApron")
	var entrance := at - across * side * 5.3 + along * 5.9
	var throat := Vector2(4.65, 3.15) if lot.horizontal else Vector2(3.15, 4.65)
	_paving(group, Rect2(entrance - throat * 0.5, throat), detail, 0.076, GEO.material(ASPHALT), "Driveway")
	if detail:
		for x: float in [-7.6, -4.2, -0.8, 2.6]:
			var line_center := at + along * x + across * side * 0.75
			var size := Vector2(0.085, 5.38) if lot.horizontal else Vector2(5.38, 0.085)
			_paving(group, Rect2(line_center - size * 0.5, size), true, 0.102, GEO.material(PAINT), "BayMarking")
	var zone: int = lot.zone
	if rng.randf() < 0.19 and zone in [1, 3]:
		place_car(group, BUS, at + across * side * 1.6 - along * 0.85,
			PI / 2.0 if lot.horizontal else 0.0, detail)
	else:
		var options: Array = [[HATCHBACK, SEDAN, MINIVAN], [SEDAN, HATCHBACK, VAN],
			[HATCHBACK, VAN, MINIVAN], [VAN, VAN, SEDAN]][zone]
		for i in (1 if not detail else 3):
			var slot := i - 1
			if i > 0 and rng.randf() > 0.78:
				continue
			var car_at := at + along * (-2.5 + slot * 3.4) + across * side * 0.74
			var facing := across * side
			var yaw := atan2(facing.x, facing.y) + rng.randf_range(-0.045, 0.045)
			place_car(group, options[(i + lot.seed) % options.size()], car_at, yaw, detail)
	if detail:
		var end := at - along * 8.0 + across * side * 3.18
		var floor_y := terrain.ground_height(end)
		var prop := "industrial_pastic_container" if zone == 3 else ("planter_box_02" if zone != 1 else "metal_trash_can")
		FURNITURE.furnish(group, prop, Vector3(end.x, floor_y + 0.095, end.y), 0.17, 0.77, false)
		_lot_details(group, at, across * side, along, zone)


func _lot_details(group: Node3D, at: Vector2, across: Vector2, along: Vector2, zone: int) -> void:
	var marker := at + along * 8.02 - across * 2.66
	var base := Vector3(marker.x, terrain.ground_height(marker) + 0.086, marker.y)
	var yaw := atan2(-across.x, -across.y)
	var metal := GEO.material(Color("#727970"))
	GEO.box(group, base + Vector3.UP * 0.76, Vector3(0.073, 1.52, 0.073), metal)
	var board := GEO.box(group, base + Vector3.UP * 1.49, Vector3(0.67, 0.39, 0.065), GEO.material(Color("#44545a")))
	board.rotation.y = yaw
	var title := "LOADING" if zone == 3 else "PARKING"
	GEO.sign(board, title, Vector3(0, 0, 0.040), 0, 0.0022)
	if zone != 3:
		return
	var freight := at - along * 6.75 + across * 3.2
	var y := terrain.ground_height(freight) + 0.086
	for i in 2:
		var position := Vector3(freight.x + along.x * 0.61 * i, y, freight.y + along.y * 0.61 * i)
		FURNITURE.furnish(group, "cardboard_box_01", position, yaw + 0.15 * i, 0.98, false)


func place_car(parent: Node3D, path: String, at: Vector2, yaw: float, detail: bool, lift: float = 0.12) -> void:
	if not car_meshes.has(path):
		_prepare_car(parent, path)
	var model: Dictionary = car_meshes[path]
	if model.is_empty():
		return
	var bounds: AABB = model.bounds
	var forward := Vector2(sin(yaw), cos(yaw))
	var right := Vector2(forward.y, -forward.x)
	var dz := (terrain.ground_height(at + forward, detail) - terrain.ground_height(at - forward, detail)) * 0.5
	var dx := (terrain.ground_height(at + right, detail) - terrain.ground_height(at - right, detail)) * 0.5
	var facing := Vector3(forward.x, dz, forward.y).normalized()
	var up := facing.cross(Vector3(right.x, dx, right.y).normalized()).normalized()
	var vehicle := Node3D.new()
	vehicle.name = "Parked" + path.get_file().get_basename().to_pascal_case()
	vehicle.set_meta("vehicle_asset", path)
	vehicle.position = Vector3(at.x, terrain.ground_height(at, detail) + lift, at.y)
	vehicle.basis = Basis(up.cross(facing).normalized(), up, facing)
	parent.add_child(vehicle, true)
	var visual := MeshInstance3D.new()
	visual.mesh = model.mesh
	visual.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if detail else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.visibility_range_end = 175.0
	visual.visibility_range_end_margin = 12.0
	vehicle.add_child(visual)
	if detail:
		GEO.box(vehicle, Vector3.UP * bounds.size.y * 0.52,
			Vector3(bounds.size.x * 0.88, bounds.size.y * 0.93, bounds.size.z * 0.99), null, true)


func _prepare_car(parent: Node3D, path: String) -> void:
	var source := models.instantiate(path)
	parent.add_child(source)
	var batches := {}
	for part: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		if not part.mesh:
			continue
		var pose := source.global_transform.affine_inverse() * part.global_transform
		for i in part.mesh.get_surface_count():
			var material := part.get_active_material(i)
			if not batches.has(material):
				var surface := SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				surface.set_material(material)
				batches[material] = surface
			batches[material].append_from(part.mesh, i, pose)
	var mesh := ArrayMesh.new()
	for surface: SurfaceTool in batches.values():
		surface.commit(mesh)
	source.free()
	car_meshes[path] = {"mesh": mesh, "bounds": mesh.get_aabb()} if mesh.get_surface_count() > 0 else {}


func _paving(parent: Node3D, rect: Rect2, detail: bool, lift: float, surface: Material, name: String) -> void:
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	var slices := maxi(1, ceili(rect.size.y / 2.0))
	var columns := maxi(1, ceili(rect.size.x / 2.0))
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for column in columns:
		left.clear()
		right.clear()
		for slice in range(slices + 1):
			for i in 2:
				var point := rect.position + rect.size * Vector2(float(column + i) / columns, float(slice) / slices)
				var y := terrain.ground_height(point, detail)
				if i == 0:
					left.append(Vector3(point.x, y + lift, point.y))
				else:
					right.append(Vector3(point.x, y + lift, point.y))
		for i in slices:
			for point: Vector3 in [left[i], right[i], left[i + 1], right[i], right[i + 1], left[i + 1]]:
				builder.add_vertex(point)
	builder.generate_normals()
	GEO.attach(parent, name, builder.commit(), surface, false).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
