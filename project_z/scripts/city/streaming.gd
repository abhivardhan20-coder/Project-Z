extends Node3D

signal refreshed

const PLAN := preload("res://scripts/city/layout.gd")
const TERRAIN := preload("res://scripts/city/terrain.gd")
const ARCH := preload("res://scripts/city/architecture.gd")
const GEO := preload("res://scripts/city/geometry.gd")
const DRESS := preload("res://scripts/city/street_dressing.gd")
const MODELS := preload("res://scripts/neighborhood/neighborhood_assets.gd")
const BAKE_BORDER := TERRAIN.DETAIL_STEP

var plan: PLAN
var terrain: TERRAIN
var architecture: ARCH
var loaded: Dictionary = {}
var wanted: Array[Vector2i] = []
var center := Vector2i(-9, -9)
var view_radius := 3
var detail_radius := 1
var last_build_usec := 0
var peak_build_usec := 0
var navigation_cache: Dictionary = {}
var navigation_bakes: Dictionary = {}
var dressing: DRESS
var drainage_bridge := PackedVector3Array()
var bridge_bounds := Rect2()


func configure(world: PLAN, ground: TERRAIN, buildings: ARCH, models: MODELS) -> void:
	plan = world
	terrain = ground
	architecture = buildings
	dressing = DRESS.new(plan, terrain, models)


func set_drainage_bridge(faces: PackedVector3Array) -> void:
	drainage_bridge = faces
	if faces.is_empty():
		bridge_bounds = Rect2()
		return
	bridge_bounds = Rect2(Vector2(faces[0].x, faces[0].z), Vector2.ZERO)
	for vertex in faces:
		bridge_bounds = bridge_bounds.expand(Vector2(vertex.x, vertex.z))


func refresh(at: Vector3, immediate: bool = false) -> void:
	var next := PLAN.chunk_for(at)
	if center != next or immediate:
		center = next
		_rebuild_queue()
	if immediate:
		while not wanted.is_empty() and _distance(wanted[0]) <= detail_radius:
			_load_next()
	elif not wanted.is_empty():
		_load_next()
	refreshed.emit()


func _distance(key: Vector2i) -> int:
	var delta := (center - key).abs()
	return maxi(delta.x, delta.y)


func _rebuild_queue() -> void:
	wanted.clear()
	for key: Vector2i in loaded.keys():
		if _distance(key) > view_radius + 1:
			remove_child(loaded[key].node)
			loaded[key].node.queue_free()
			loaded.erase(key)
	for row in range(maxi(center.y - view_radius, 0), mini(center.y + view_radius + 1, PLAN.COUNT)):
		for column in range(maxi(center.x - view_radius, 0), mini(center.x + view_radius + 1, PLAN.COUNT)):
			var key := Vector2i(column, row)
			var distance := _distance(key)
			if not loaded.has(key) or (not loaded[key].detail and distance <= detail_radius) or (loaded[key].detail and distance > detail_radius + 1):
				wanted.append(key)
	wanted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _distance(a) < _distance(b))


func _load_next() -> void:
	var start := Time.get_ticks_usec()
	var key: Vector2i = wanted.pop_front()
	var detail: bool = _distance(key) <= detail_radius or (loaded.has(key) and loaded[key].detail and _distance(key) <= detail_radius + 1)
	if loaded.has(key):
		remove_child(loaded[key].node)
		loaded[key].node.queue_free()
	var root := Node3D.new()
	root.name = "Block_%02d_%02d" % [key.x, key.y]
	add_child(root, true)
	terrain.tile(root, key, detail)
	for parcel: Dictionary in PLAN.parcels(key):
		architecture.shell(root, parcel, detail)
	for entry: Array in PLAN.LANDMARKS:
		var location: Vector2 = entry[1]
		if PLAN.chunk_for(Vector3(location.x, 0, location.y)) == key:
			architecture.shell(root, {"center": location, "size": entry[2], "levels": entry[3],
				"zone": PLAN.district(location.x, location.y), "finish": 0}, detail, entry[0])
	if detail:
		for id: String in PLAN.PLACES:
			if id in ["safehouse", "corner_shop"]:
				continue
			if PLAN.chunk_for(plan.place(id)) == key:
				architecture.interior(root, id)
		_edges(root, key)
	dressing.populate(root, key, detail)
	if detail:
		_navigation(root, key)
	loaded[key] = {"node": root, "detail": detail}
	last_build_usec = Time.get_ticks_usec() - start
	peak_build_usec = maxi(peak_build_usec, last_build_usec)


func _navigation(root: Node3D, key: Vector2i) -> void:
	var region := NavigationRegion3D.new()
	region.name = "Walkable"
	root.add_child(region)
	if navigation_cache.has(key):
		region.navigation_mesh = navigation_cache[key]
		return
	if navigation_bakes.has(key):
		return
	var mesh := NavigationMesh.new()
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.agent_radius = 0.25
	mesh.agent_height = 1.75
	mesh.agent_max_climb = 0.25
	mesh.agent_max_slope = 43.0
	mesh.filter_ledge_spans = true
	mesh.edge_max_length = 6.0
	mesh.detail_sample_max_error = 3.0
	mesh.edge_max_error = 0.5
	mesh.border_size = BAKE_BORDER
	var start := PLAN.origin(key)
	var span := PLAN.CHUNK_SIZE + BAKE_BORDER * 2.0
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, root)
	terrain.add_navigation_border(source, key)
	# The bridge belongs to the always-present Hillview scene and spans two city blocks.
	var footprint := Rect2(start - Vector2.ONE * BAKE_BORDER, Vector2.ONE * span)
	if not drainage_bridge.is_empty() and footprint.intersects(bridge_bounds):
		source.add_faces(drainage_bridge, Transform3D.IDENTITY)
	var bounds := source.get_bounds()
	var bottom := floorf(bounds.position.y) - 1.0
	var height := ceilf(bounds.end.y) - bottom + 1.0
	mesh.filter_baking_aabb = AABB(Vector3(footprint.position.x, bottom, footprint.position.y),
		Vector3(span, height, span))
	navigation_bakes[key] = true
	NavigationServer3D.bake_from_source_geometry_data_async(mesh, source, _finish_navigation.bind(key, mesh))


func _finish_navigation(key: Vector2i, mesh: NavigationMesh) -> void:
	navigation_bakes.erase(key)
	navigation_cache[key] = mesh
	if loaded.has(key) and loaded[key].detail:
		var region := loaded[key].node.get_node("Walkable") as NavigationRegion3D
		region.navigation_mesh = mesh


func _edges(parent: Node3D, key: Vector2i) -> void:
	var corner := PLAN.origin(key)
	var gray := GEO.material(Color("#78736a"))
	var stone := GEO.material(Color("#615b50"))
	for side in 4:
		var boundary := key.x == 0 if side == 0 else (key.x == 9 if side == 1 else (key.y == 0 if side == 2 else key.y == 9))
		if not boundary:
			continue
		var x_fixed := side < 2
		var line := -495.0 if side % 2 == 0 else 495.0
		for i in 20:
			var along := (corner.y if x_fixed else corner.x) + 2.5 + 5.0 * i
			var p := Vector2(line, along) if x_fixed else Vector2(along, line)
			var y := plan.height(p.x, p.y)
			var size := Vector3(1.7, 3.6, 5.4) if x_fixed else Vector3(5.4, 3.6, 1.7)
			GEO.box(parent, Vector3(p.x, y + 0.62, p.y), size, gray if PLAN.road_distance(p.x, p.y) < 2 else stone, true)
