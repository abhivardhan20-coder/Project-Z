extends RefCounted

const PLAN := preload("res://scripts/city/layout.gd")
const GEO := preload("res://scripts/city/geometry.gd")
const PARKING := preload("res://scripts/city/parking.gd")
const TERRAIN := preload("res://scripts/city/terrain.gd")
const EVAC := preload("res://scripts/city/evacuation_dressing.gd")
const FINISH := preload("res://scripts/graphics/materials.gd")
const FURNITURE := preload("res://scripts/city/interior_assets.gd")
const MODELS := preload("res://scripts/neighborhood/neighborhood_assets.gd")
const REFERENCE := preload("res://scripts/city/reference_models.gd")

var terrain: TERRAIN
var parking: PARKING
var models: MODELS
var stone: Material = FINISH.surface("Exposed concrete")
var paving: Material = FINISH.surface("Asphalt")
var frame := GEO.material(Color("#495256"))
var metal := GEO.material(Color("#84949d"))
var paint := GEO.material(Color("#c9c1a6"))
var cloth := GEO.material(Color("#555343"))
var glass := FINISH.glass()
var amber := _lamp_material(Color("#ffcc86"), 1.3)


func _init(ground: TERRAIN, cars: PARKING, library: MODELS) -> void:
	terrain = ground
	parking = cars
	models = library


func populate(parent: Node3D, key: Vector2i, detail: bool) -> void:
	if key == PLAN.chunk_for(Vector3(PLAN.RAIL_CENTER.x, 0, PLAN.RAIL_CENTER.y)):
		_station(parent, detail)
	if key == PLAN.chunk_for(Vector3(PLAN.AIRPORT_CENTER.x, 0, PLAN.AIRPORT_CENTER.y)):
		_airport(parent, detail)


func _station(parent: Node3D, detail: bool) -> void:
	var station := _site(parent, "KaldranCentralStation", PLAN.RAIL_CENTER)
	GEO.box(station, Vector3(-3, 0.13, 2), Vector3(61, 0.27, 59), stone)
	GEO.box(station, Vector3(-8, 0.72, -14), Vector3(43, 1.44, 36), stone, detail)
	_hall(station, Vector3(-8, 1.44, -14), 39.0, 32.0, 9.0, 8.4, "KALDRAN CENTRAL", detail)
	for track: float in [18.5, 25.5]:
		for slot in 6:
			REFERENCE.place(station, "track", Vector3(track, 0.13, -34 + slot * 10), PI * 0.5)
		for i in 2:
			REFERENCE.place(station, "metro_train", Vector3(track, 0.61, -18 + i * 23.25 + (track - 18.5) * 0.5),
				PI * 0.5, Vector3.ZERO, detail)
	GEO.box(station, Vector3(22.1, 0.44, -8), Vector3(2.88, 0.88, 54), stone, detail)
	if detail:
		REFERENCE.place(station, "platform_bench", Vector3(22.1, 0.88, 11.7), PI * 0.5)
		REFERENCE.place(station, "station_entry", Vector3(-8, 1.44, 2.35), PI, Vector3(8.0, 4.17, 1.15))
		for index in 8:
			var center := Vector3(-8, 0.28 + index * 0.146, 9.5 - index * 0.68)
			var step := GEO.box(station, center, Vector3(25, 0.29, 0.86), stone)
			step.name = "StationStep"
		# A continuous walkable path goes up the stair flight.
		var ramp := GEO.box(station, Vector3(-8, 0.70, 7.1), Vector3(24.8, 0.14, 5.72), null, true)
		ramp.rotation.x = 0.213
		_plaza(station, Vector3(-12, 0.28, 16.2), true)
		_queue(station, Vector3(1, 0, 24), 3, true)
		_queue(station, Vector3(10, 0, 28), 3, true)
		EVAC.open_sedan(station, models, Vector3(-8, 0.32, 23), 1.12, false)
		var bus_at := station.to_global(Vector3(-21, 0, 19))
		parking.place_car(parent, PARKING.BUS, Vector2(bus_at.x, bus_at.z), -PI * 0.5, true, 0.31)
		_markings(station, Vector3(-16, 0.282, 21.7))
	_batch_structure(station)


func _airport(parent: Node3D, detail: bool) -> void:
	var airport := _site(parent, "AirportEvacuationApproach", PLAN.AIRPORT_CENTER)
	GEO.box(airport, Vector3(3, 0.16, 0), Vector3(55, 0.32, 79), paving)
	var terminal := _hall(airport, Vector3(19.0, 0.35, -7), 51.0, 19.0, 6.0, 5.7, "KALDRAN AIRPORT", detail)
	terminal.rotation.y = -1.07
	REFERENCE.place(airport, "control_tower", Vector3(27.0, 0.32, -28.0), 0.0, Vector3(8.9, 33.0, 8.9), detail)
	REFERENCE.place(airport, "regional_aircraft", Vector3(27.0, 0.22, 27.35), -0.68)
	for z in range(-35, 45, 10):
		var pose := Vector3(-22.2 + 0.0008 * z * z, 6.75, z)
		GEO.box(airport, pose, Vector3(9.2, 1.05, 10.25), stone, detail)
		GEO.box(airport, pose + Vector3(-3.9, 0.68, 0), Vector3(0.32, 0.66, 10.25), stone)
		GEO.box(airport, pose + Vector3(3.9, 0.68, 0), Vector3(0.32, 0.66, 10.25), stone)
		if z % 20 == -15 or z % 20 == 5:
			GEO.box(airport, pose + Vector3(0, -3.54, 0), Vector3(1.03, 6.4, 1.72), stone, detail)
		if detail:
			GEO.box(airport, pose + Vector3(3.05, -0.59, 0), Vector3(0.19, 0.11, 0.48), amber)
	if detail:
		REFERENCE.place(terminal, "airport_entry", Vector3(0, 0.0, 10.24), 0.0, Vector3(9.5, 5.2, 1.23))
		REFERENCE.place(airport, "baggage_trolley", Vector3(-20.0, 0.32, 27.4), -0.87)
		for z in range(-33, 39, 4):
			_railing(airport, Vector3(2.2, 0.31, z), PI * 0.5, 3.92)
		_fence_top(airport)
		for z in range(-25, 39, 5):
			GEO.box(airport, Vector3(-4.0, 0.326, z), Vector3(0.095, 0.01, 2.44), paint)
		_plaza(airport, Vector3(-19, 0.32, 21.5), false)
		_queue(airport, Vector3(-10, 0, 33.0), 7, true)
		_queue(airport, Vector3(-0.2, 0, 29.0), 6, true)
		EVAC.open_sedan(airport, models, Vector3(-6.25, 0.33, 25.8), -0.13, true)
		var bus_at := airport.to_global(Vector3(0.6, 0, -16.5))
		parking.place_car(parent, PARKING.BUS, Vector2(bus_at.x, bus_at.z), -0.12, true, 0.31)
	_batch_structure(airport)


func _site(parent: Node3D, title: String, point: Vector2) -> Node3D:
	var site := Node3D.new()
	site.name = title
	site.position = Vector3(point.x, terrain.layout.height(point.x, point.y), point.y)
	parent.add_child(site)
	return site


func _hall(root: Node3D, at: Vector3, width: float, depth: float, eave: float, rise: float, title: String, detail: bool) -> Node3D:
	var building := Node3D.new()
	building.position = at
	root.add_child(building)
	var fascia := depth * 0.5
	var lhs := -width * 0.5
	var rhs := width * 0.5
	for x: float in [lhs, rhs]:
		GEO.box(building, Vector3(x, eave * 0.5, 0), Vector3(1.1, eave, depth), frame, detail)
		GEO.box(building, Vector3(x, 0.31, 0), Vector3(1.4, 0.62, depth + 0.55), stone)
	for z: float in [-fascia, fascia]:
		var count := roundi(width / 2.15)
		for i in count:
			var x := lhs + (i + 0.5) * width / count
			var height := eave + _arch(x, width, rise)
			var opening := absf(x) < 3.5 and z > 0.0
			var sill := 2.52 if opening else 0.0
			var cell_width := width / count
			var inner_x := absf(x) - cell_width * 0.5
			var outer_x := absf(x) + cell_width * 0.5
			var h1 := eave + _arch(inner_x, width, rise)
			var h2 := eave + _arch(outer_x, width, rise)
			var handed := signf(x)
			if is_zero_approx(handed):
				handed = 1.0
			_skin(building, PackedVector3Array([
				Vector3(x - handed * cell_width * 0.5, sill, z),
				Vector3(x + handed * cell_width * 0.5, sill, z),
				Vector3(x + handed * cell_width * 0.5, h2, z),
				Vector3(x - handed * cell_width * 0.5, h1, z),
			]), glass)
			GEO.box(building, Vector3(x - width / count * 0.5, height * 0.5, z + signf(z) * 0.08),
				Vector3(0.095, height, 0.16), frame)
			if detail and not opening:
				GEO.box(building, Vector3(x, 1.1, z), Vector3(width / count, 2.2, 0.12), null, true)
		for y in range(2, int(eave + rise), 2):
			var cap := sqrt(maxf(0.0, 1.0 - pow(maxf(0.0, y - eave) / rise, 2.0)))
			GEO.box(building, Vector3(0, y, z + signf(z) * 0.06), Vector3(width * cap, 0.08, 0.18), frame)
	var crown := PackedVector3Array()
	for i in 25:
		var x := lerpf(lhs, rhs, i / 24.0)
		crown.append(Vector3(x, eave + _arch(x, width, rise), 0))
	for i in crown.size() - 1:
		var a := crown[i]
		var b := crown[i + 1]
		var center := (a + b) * 0.5
		var rot := atan2(b.y - a.y, b.x - a.x)
		var roof := GEO.box(building, center, Vector3(a.distance_to(b) + 0.054, 0.14, depth + 1.86), metal)
		roof.rotation.z = rot
		for z: float in [-fascia - 0.95, -fascia * 0.5, 0, fascia * 0.5, fascia + 0.95]:
			var rib := GEO.box(building, center + Vector3(0, -0.14, z), Vector3(a.distance_to(b) + 0.04, 0.25, 0.21), frame)
			rib.rotation.z = rot
		if detail and i % 3 == 1:
			for z: float in [-fascia * 0.55, 0, fascia * 0.55]:
				GEO.box(building, center + Vector3(0, -1.1, z), Vector3(1.55, 0.055, 0.26), amber)
	GEO.box(building, Vector3(0, 3.7, fascia + 1.37), Vector3(width * 0.54, 0.47, 2.95), frame)
	for x: float in [-width * 0.32, width * 0.32]:
		GEO.box(building, Vector3(x, 2.6, fascia + 0.49), Vector3(2.25, 5.2, 0.96), stone, detail)
	GEO.sign(building, title, Vector3(0, 4.51, fascia + 0.19), 0.0, 0.012)
	return building


func _arch(x: float, width: float, rise: float) -> float:
	return rise * sqrt(maxf(0.0, 1.0 - pow(x * 2.0 / width, 2.0)))


func _skin(parent: Node3D, points: PackedVector3Array, surface: Material) -> void:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := [0, 1, 2, 0, 2, 3] if surface == glass else [0, 1, 2, 0, 2, 3, 2, 1, 0, 3, 2, 0]
	for index: int in indices:
		builder.add_vertex(points[index])
	builder.generate_normals()
	GEO.attach(parent, "Skin", builder.commit(), surface, false)


func _plaza(root: Node3D, at: Vector3, station: bool) -> void:
	for i in 4:
		var p := at + Vector3((i - 1.5) * 1.76, 0, 0)
		REFERENCE.place(root, "jersey_barrier", p, float(i % 2) * 0.1, Vector3(1.65, 0.70, 0.79))
		GEO.box(root, p + Vector3.UP * 0.34, Vector3(1.52, 0.68, 0.48), null, true)
		_railing(root, p + Vector3(0, 0, 1.85), 0.015 * i, 1.78)
	_tent(root, at + Vector3(-2.0, 0, -3.9), station)
	EVAC._worklight(root, at + Vector3(2.82, 0, -1.83), 0.72)
	for i in 3:
		var p := at + Vector3(-4.2 + float(i % 2) * 0.75, 0, -1.81 - i * 0.71)
		FURNITURE.furnish(root, "wooden_military_crate", p, i * 0.15, 0.86, true)
	EVAC._prop(root, models, EVAC.SUITCASE, at + Vector3(4.1, 0, 1.19), 0.42)
	FURNITURE.furnish(root, "medical_box", at + Vector3(2.2, 0.04, 2.3), -0.57, 0.94, false)
	for i in 4:
		REFERENCE.place(root, "litter", at + Vector3(2.3 + i * 1.07, 0.015, 2.5 + sin(i) * 0.81), float(i))


func _tent(root: Node3D, at: Vector3, marked: bool) -> void:
	var tent := Node3D.new()
	tent.position = at
	root.add_child(tent)
	for side: float in [-1.0, 1.0]:
		GEO.box(tent, Vector3(side * 2.28, 0.96, 0), Vector3(0.05, 1.92, 5.7), cloth, true)
		var roof := GEO.box(tent, Vector3(side * 1.17, 2.55, 0), Vector3(2.66, 0.085, 5.9), cloth)
		roof.rotation.z = -side * 0.46
		for z: float in [-2.75, 2.75]:
			GEO.box(tent, Vector3(side * 2.23, 1.0, z), Vector3(0.075, 2.0, 0.075), frame)
	GEO.box(tent, Vector3(0, 0.96, -2.83), Vector3(4.5, 1.92, 0.05), cloth, true)
	if marked:
		var sign_at := Vector3(1.43, 1.30, 2.858)
		GEO.box(tent, sign_at, Vector3(0.54, 0.49, 0.04), paint)
		GEO.sign(tent, "+", sign_at + Vector3.BACK * 0.025, 0.0, 0.01).modulate = Color("#8f3d36")


func _railing(root: Node3D, at: Vector3, angle: float, width: float) -> void:
	var panel := Node3D.new()
	panel.position = at
	panel.rotation.y = angle
	root.add_child(panel)
	for y: float in [0.31, 1.105]:
		GEO.box(panel, Vector3(0, y, 0), Vector3(width, 0.064, 0.065), metal)
	for i in 8:
		var x := lerpf(-width * 0.47, width * 0.47, i / 7.0)
		GEO.box(panel, Vector3(x, 0.704, 0), Vector3(0.037, 0.81, 0.041), frame)


func _markings(root: Node3D, at: Vector3) -> void:
	for count in 8:
		GEO.box(root, at + Vector3(0, 0.006, count * 0.51), Vector3(4.3, 0.014, 0.31), paint)


func _fence_top(root: Node3D) -> void:
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES, frame)
	for i in 768:
		for endpoint in 2:
			var t := (i + endpoint) / 768.0
			var angle := t * TAU * 96.0
			lines.surface_add_vertex(Vector3(2.2 + cos(angle) * 0.19, 1.59 + sin(angle) * 0.19, -34.0 + 72.0 * t))
	lines.surface_end()
	var mesh := MeshInstance3D.new()
	mesh.mesh = lines
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh)


func _batch_structure(root: Node3D) -> void:
	var groups: Dictionary = {}
	var to_local := root.global_transform.affine_inverse()
	for piece: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if not piece.mesh is BoxMesh or piece.material_override == glass:
			continue
		var material := piece.material_override
		if not groups.has(material):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tool.set_material(material)
			groups[material] = tool
		var batch: SurfaceTool = groups[material]
		batch.append_from(piece.mesh, 0, to_local * piece.global_transform)
		piece.free()
	var mesh := ArrayMesh.new()
	for batch: SurfaceTool in groups.values():
		batch.commit(mesh)
	GEO.attach(root, "StationaryStructure", mesh, null, false)


func _queue(root: Node3D, at: Vector3, count: int, detail: bool) -> void:
	var paths := [PARKING.SEDAN, PARKING.MINIVAN, PARKING.HATCHBACK, PARKING.VAN]
	for i in count:
		var p := root.to_global(at + Vector3(sin(i * 4.6) * 0.39, 0, -i * 5.28))
		parking.place_car(root.get_parent_node_3d(), paths[i % paths.size()], Vector2(p.x, p.z), PI + sin(i) * 0.1, detail, 0.34)


static func _lamp_material(color: Color, intensity: float) -> StandardMaterial3D:
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = color
	lamp.emission_enabled = true
	lamp.emission = color
	lamp.emission_energy_multiplier = intensity
	return lamp
