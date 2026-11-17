extends Node3D

const LAYOUT := preload("res://scripts/city/layout.gd")
const GEO := preload("res://scripts/city/geometry.gd")
const HILLVIEW := preload("res://scripts/pilot/pilot_hillview.gd")
const MODELS := preload("res://scripts/neighborhood/neighborhood_assets.gd")
const CATALOG := preload("res://scripts/neighborhood/neighborhood_catalog.gd")
const SEDAN := "res://assets/pilot/PZ-196_PZ141_Driving_Sedan_v01.glb"
const HYDRANT := "res://assets/city/fire_hydrant.glb"
const WATER := preload("res://materials/ultra/water.gdshader")
const DECALS := preload("res://scripts/graphics/decals.gd")
const EVACUATION := preload("res://scripts/city/evacuation_dressing.gd")

var hillview: HILLVIEW
var powered_lights: Array[OmniLight3D] = []
var safehouse_tubes: Array[StandardMaterial3D] = []
var parked_sedans: Array[Node3D] = []
var trunk_point := Vector3.ZERO
var trunk_body: StaticBody3D
var sedan_mesh: ArrayMesh
var drainage_bridge := PackedVector3Array()


func build(layout: LAYOUT, models: MODELS, palette: Dictionary) -> void:
	hillview = HILLVIEW.new()
	hillview.name = "HillviewSteps"
	hillview.position = LAYOUT.PILOT
	add_child(hillview)
	hillview.build(models, palette, true)
	safehouse_tubes = hillview.safehouse_tubes
	_limit_building_details()
	for node in hillview.find_children("*", "OmniLight3D", true, false):
		var lamp := node as OmniLight3D
		if String(lamp.name).ends_with("WindowBounce"):
			continue
		lamp.set_meta("powered_energy", lamp.light_energy)
		lamp.light_energy *= 0.22
		powered_lights.append(lamp)
	var concrete: Material = palette.pavement
	var asphalt: Material = palette.asphalt
	var rail: Material = palette.trim
	for side: float in [-1.0, 1.0]:
		_sidewalk(layout, side, concrete)
		var a := PackedVector3Array()
		var b := PackedVector3Array()
		for x in range(-215, -184):
			var z := LAYOUT.bridge_center(x) + side * 6.9
			var y := LAYOUT.base_grade(x, z) + 0.72
			a.append(Vector3(x, y, z - 0.09))
			b.append(Vector3(x, y, z + 0.09))
			if x % 3 == 0:
				GEO.box(self, Vector3(x, y - 0.28, z), Vector3(0.16, 0.92, 0.19), rail, true)
		for i in range(0, a.size() - 1, 3):
			var start := a[i]
			var end := a[mini(i + 3, a.size() - 1)]
			var beam := GEO.box(self, (start + end) * 0.5, Vector3(start.distance_to(end), 0.18, 0.2), rail, true)
			beam.rotation.y = atan2(start.z - end.z, end.x - start.x)
	for i in 6:
		var x := -365.0 + i * 6
		var z := LAYOUT.bridge_center(x) - 10.4
		GEO.box(self, Vector3(x, layout.height(x, z) + 0.57, z), Vector3(6.0, 1.4, 0.45), concrete, true)
	var west := PackedVector3Array()
	var east := PackedVector3Array()
	for x in range(-214, -185):
		var z := LAYOUT.bridge_center(x)
		var y := LAYOUT.base_grade(x, z) + 0.04
		west.append(Vector3(x, y, z + 6.9))
		east.append(Vector3(x, y, z - 6.9))
	GEO.strip(self, "HillviewDrainageBridge", west, east, asphalt, true)
	for i in range(west.size() - 1):
		drainage_bridge.append_array(PackedVector3Array([west[i], east[i], west[i + 1],
			east[i], east[i + 1], west[i + 1]]))
	for x in [-215.0, -185.0]:
		var z := LAYOUT.bridge_center(x)
		GEO.box(self, Vector3(x, layout.height(x, z) - 0.66, z), Vector3(1.7, 1.35, 13.5), concrete, true)
	_drainage_water(layout)

	for x in range(-372, -144, 23):
		var z := LAYOUT.bridge_center(x) - 8.4
		if LAYOUT.road_distance(x, z) < 1.0:
			continue
		var pole := models.instantiate(CATALOG.PATHS.lamp)
		pole.position = Vector3(x, layout.height(x, z), z)
		pole.rotation.y = PI
		add_child(pole)
	var cable := ImmediateMesh.new()
	cable.surface_begin(Mesh.PRIMITIVE_LINES, palette.dark)
	for pole_x in range(-372, -165, 23):
		if LAYOUT.road_distance(pole_x, LAYOUT.bridge_center(pole_x) - 8.4) < 1.0 or LAYOUT.road_distance(pole_x + 23, LAYOUT.bridge_center(pole_x + 23) - 8.4) < 1.0:
			continue
		for segment in 7:
			for endpoint in 2:
				var f := (segment + endpoint) / 7.0
				var x := pole_x + f * 23.0
				var z := LAYOUT.bridge_center(x) - 8.4
				var y := layout.height(x, z) + 7.2 - 0.53 * sin(f * PI)
				cable.surface_add_vertex(Vector3(x, y, z))
	cable.surface_end()
	var cable_run := MeshInstance3D.new()
	cable_run.mesh = cable
	cable_run.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cable_run)
	for x: float in [-340.0, -237.0, -171.0]:
		_park_sedan(layout, models, x)
	for x: float in [-326.0, -271.0, -224.0, -157.0]:
		var z := LAYOUT.bridge_center(x) - 7.7
		var asset := models.instantiate(HYDRANT)
		var new_hydrant := asset.find_child("fire_hydrant", true, false) as Node3D
		if new_hydrant:
			new_hydrant.hide()
		var aged := asset.find_child("fire_hydrant_aged", true, false) as Node3D
		if aged:
			asset.position = Vector3(x, layout.height(x, z) + 0.02, z) - aged.position
			add_child(asset)
		else:
			asset.free()
	for x in [-353.0, -248.0, -171.0]:
		var z := LAYOUT.bridge_center(x) + 8.4
		if LAYOUT.road_distance(x, z) < 1.0:
			continue
		var at := Vector3(x, layout.height(x, z), z)
		GEO.box(self, at + Vector3.UP * 0.7, Vector3(0.11, 1.4, 0.11), rail, true)
		GEO.box(self, at + Vector3.UP * 1.5, Vector3(2.7, 0.37, 0.09), palette.dark)
		GEO.sign(self, "P06  /  HILLVIEW", at + Vector3(0, 1.5, -0.06), PI, 0.005)
	var crossing := LAYOUT.PILOT.x + HILLVIEW.SHOP_X
	for i in 8:
		GEO.box(self, Vector3(crossing, 16.023, -253.62 + i * 0.99), Vector3(2.0, 0.006, 0.34), palette.marking)
	for x: float in [-337.0, -299.0, -282.0, -270.0, -237.0, -174.0]:
		var z := LAYOUT.bridge_center(x) + 2.61
		var at := Vector3(x, layout.height(x, z), z)
		DECALS.pavement(self, at, Vector2(1.65, 2.15), &"oil", x * 0.12)
		DECALS.pavement(self, at + Vector3(-4.2, 0, -1.35), Vector2(2.28, 4.7), &"tire", PI * 0.5)
	EVACUATION.hillview(self, layout, models)


func set_power(on: bool) -> void:
	for lamp in powered_lights:
		lamp.light_energy = float(lamp.get_meta("powered_energy", 0.83)) if on else 0.18
	for tube in safehouse_tubes:
		tube.emission_enabled = on


func _drainage_water(layout: LAYOUT) -> void:
	var upstream := PackedVector3Array()
	var downstream := PackedVector3Array()
	for z in range(-266, -229, 2):
		var at := Vector3(-200.0, layout.height(-200.0, z) + 0.20, z)
		var width := 0.5 + 1.35 * (1.0 - smoothstep(8.0, 19.0, absf(z + 248.0)))
		upstream.append(at - Vector3.RIGHT * width)
		downstream.append(at + Vector3.RIGHT * width)
	var surface := ShaderMaterial.new()
	surface.shader = WATER
	GEO.strip(self, "DrainageWater", upstream, downstream, surface, false)


func _park_sedan(layout: LAYOUT, models: MODELS, x: float) -> void:
	var z := LAYOUT.bridge_center(x) + 3.35
	var center := Vector3(x, layout.height(x, z), z)
	var tangent := Vector3(1.0, 0.0, (LAYOUT.bridge_center(x + 1.0) - LAYOUT.bridge_center(x - 1.0)) * 0.5).normalized()
	tangent.y = (layout.height(x + tangent.x, z + tangent.z) - layout.height(x - tangent.x, z - tangent.z)) * 0.5
	tangent = tangent.normalized()
	var right := Vector3.UP.cross(tangent).normalized()
	var across := (layout.height(x + right.x, z + right.z) - layout.height(x - right.x, z - right.z)) * 0.5
	right = (right + Vector3.UP * across).normalized()
	var up := tangent.cross(right).normalized()
	var parked := Node3D.new()
	parked.name = "ParkedSedan%d" % int(absf(x))
	parked.position = center + up * 0.025
	parked.basis = Basis(up.cross(tangent).normalized(), up, tangent)
	add_child(parked)
	if not sedan_mesh:
		var source := models.instantiate(SEDAN)
		parked.add_child(source)
		sedan_mesh = _batch_vehicle(source)
		source.free()
	var visual := MeshInstance3D.new()
	visual.mesh = sedan_mesh
	parked.add_child(visual)
	parked_sedans.append(parked)
	var collider := GEO.box(parked, Vector3(0, 0.72, 0.01), Vector3(1.84, 1.38, 4.76), null, true) as StaticBody3D
	if parked_sedans.size() == 1:
		trunk_body = collider
		trunk_point = parked.to_global(Vector3(0, 0.88, -2.39))


func _batch_vehicle(source: Node3D) -> ArrayMesh:
	var world_to_model := source.global_transform.affine_inverse()
	var batches := {}
	for node in source.find_children("*", "MeshInstance3D", true, false):
		var piece := node as MeshInstance3D
		if not piece.is_visible_in_tree() or not piece.mesh:
			continue
		var pose := world_to_model * piece.global_transform
		for index in piece.mesh.get_surface_count():
			var material := piece.get_active_material(index)
			if not batches.has(material):
				var surface := SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				surface.set_material(material)
				batches[material] = surface
			batches[material].append_from(piece.mesh, index, pose)
	var result := ArrayMesh.new()
	for surface: SurfaceTool in batches.values():
		surface.commit(result)
	return result


func _limit_building_details() -> void:
	# A single opaque apartment volume preserves the silhouette at distance.
	var proxy := GEO.box(self, LAYOUT.PILOT + Vector3(18, 4.89, 12.75),
		Vector3(20.0, 9.48, 16.0), GEO.material(Color("#9c9382")))
	var proxy_mesh := proxy.get_child(0) as MeshInstance3D
	proxy_mesh.visibility_range_begin = 95.0
	proxy_mesh.visibility_range_begin_margin = 8.0
	for node in hillview.find_children("*", "MeshInstance3D", true, false):
		var visual := node as MeshInstance3D
		if visual.global_position.y > LAYOUT.PILOT.y + 2.0:
			visual.visibility_range_end = 106.0
			visual.visibility_range_end_margin = 8.0


func _sidewalk(layout: LAYOUT, side: float, material: Material) -> void:
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	var curb_top := PackedVector3Array()
	var curb_bottom := PackedVector3Array()
	for x in range(int(LAYOUT.PILOT_WEST), int(LAYOUT.PILOT_EAST) + 1):
		var inside_hero := side > 0.0 and x >= LAYOUT.PILOT.x + HILLVIEW.SIDEWALK_LEFT and x <= LAYOUT.PILOT.x + HILLVIEW.SIDEWALK_RIGHT
		if inside_hero or (x >= LAYOUT.BRIDGE.x - 4.0 and x <= LAYOUT.BRIDGE.y + 4.0):
			if left.size() >= 2:
				GEO.strip(self, "RaisedPaving", left, right, material, true)
				_curb(curb_top, curb_bottom, material, side)
			left.clear()
			right.clear()
			curb_top.clear()
			curb_bottom.clear()
			continue
		var z := LAYOUT.bridge_center(x)
		var inner_z := z + side * 4.55
		var outer_z := z + side * 6.95
		var inner_rise := _sidewalk_height(x, inner_z, side)
		var outer_rise := _sidewalk_height(x, outer_z, side)
		if inner_rise < 0.009 and outer_rise < 0.009:
			if left.size() >= 2:
				GEO.strip(self, "RaisedPaving", left, right, material, true)
				_curb(curb_top, curb_bottom, material, side)
			left.clear()
			right.clear()
			curb_top.clear()
			curb_bottom.clear()
			continue
		var inner := Vector3(x, layout.height(x, inner_z) + inner_rise, inner_z)
		var outer := Vector3(x, layout.height(x, outer_z) + outer_rise, outer_z)
		left.append(outer if side > 0.0 else inner)
		right.append(inner if side > 0.0 else outer)
		curb_top.append(inner)
		curb_bottom.append(inner - Vector3.UP * (inner_rise + 0.04))
	if left.size() >= 2:
		GEO.strip(self, "RaisedPaving", left, right, material, true)
		_curb(curb_top, curb_bottom, material, side)


func _curb(top: PackedVector3Array, bottom: PackedVector3Array, material: Material, side: float) -> void:
	if side < 0.0:
		GEO.strip(self, "CurbFace", bottom, top, material, true)
	else:
		GEO.strip(self, "CurbFace", top, bottom, material, true)


func _sidewalk_height(x: float, z: float, side: float) -> float:
	var rise := 0.15
	for axis: float in [-380.0, -250.0, -140.0]:
		var across := absf(x - LAYOUT.cross_street_x(axis, z))
		rise = minf(rise, lerpf(0.008, 0.15, smoothstep(3.45, 5.5, across)))
	if side < 0.0 and absf(z - LAYOUT.bridge_center(x)) < 5.0:
		var crossing := absf(x - (LAYOUT.PILOT.x + HILLVIEW.SHOP_X))
		rise = minf(rise, lerpf(0.018, 0.15, smoothstep(1.0, 2.35, crossing)))
	return rise
