extends RefCounted

const PLAN := preload("res://scripts/city/layout.gd")
const GEO := preload("res://scripts/city/geometry.gd")
const MODELS := preload("res://scripts/neighborhood/neighborhood_assets.gd")
const TERRAIN := preload("res://scripts/city/terrain.gd")
const PARKING := preload("res://scripts/city/parking.gd")
const FURNITURE := preload("res://scripts/city/interior_assets.gd")
const GRAPHICS := preload("res://scripts/graphics/materials.gd")
const EVACUATION := preload("res://scripts/city/evacuation_dressing.gd")
const TRANSIT := preload("res://scripts/city/transit_landmarks.gd")
const TREE := "res://assets/props/nature/pz_127_temperate_broadleaf_tree/PROJECT_Z_Temperate_Oak_Tree_LOD2.glb"
const BUS := "res://assets/roads/streets/pz_048_bus_stop_shelter/PZ_MorrowTransit_BusShelter_COMPLETE.glb"
const AMBULANCE := "res://assets/vehicles/road/pz_145_ambulance/PZ_Greyhaven_EMS_Ambulance_07.glb"
const TRANSFORMERS := "res://assets/buildings/utility_facilities/pz_084_substation_transformer_yard/PROJECT_Z_Substation_Transformer_Yard.glb"
const BARRIER := "res://assets/city/concrete_road_barrier_02.glb"
const VEGETATION := [
	"res://assets/vegetation/grass_clumps.glb",
	"res://assets/vegetation/flowering_shrub.glb",
	"res://assets/vegetation/pine_saplings.glb",
]

var layout: PLAN
var models: MODELS
var parking: PARKING
var transit: TRANSIT
var trees: Array[Dictionary] = []
var plant_meshes: Dictionary = {}
var box := BoxMesh.new()
var colors: Dictionary = {
	"metal": GEO.material(Color("#676d63")), "stone": GEO.material(Color("#929083")),
	"wood": GEO.material(Color("#746044")), "dark": GEO.material(Color("#3e4845")),
	"trim": GEO.material(Color("#ded4a7")), "red": GEO.material(Color("#7a4841")),
}


func _init(world: PLAN, ground: TERRAIN, library: MODELS) -> void:
	layout = world
	models = library
	parking = PARKING.new(ground, library)
	transit = TRANSIT.new(ground, parking, library)


func populate(root: Node3D, key: Vector2i, detail: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = PLAN.SEED + key.x * 9521 + key.y * 607
	var corner := PLAN.origin(key)
	var poses: Array[Transform3D] = []
	var blocks: Dictionary = {}
	var zone := PLAN.district(corner.x + 50, corner.y + 50)
	parking.populate(root, parking.plan_lot(key), detail)
	transit.populate(root, key, detail)
	if key == PLAN.chunk_for(Vector3(PLAN.OVERLOOK.x, 0, PLAN.OVERLOOK.y)):
		EVACUATION.overlook(root, layout, models)
	for i in (12 if detail else 5):
		var x := corner.x + rng.randf_range(7, 93)
		var z := corner.y + rng.randf_range(7, 93)
		if PLAN.road_distance(x, z) < 6.0 or not _clear(Vector2(x, z), key):
			continue
		var scale := rng.randf_range(0.48, 0.85)
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * scale)
		poses.append(Transform3D(basis, Vector3(x, layout.height(x, z), z)))
		if detail:
			var size := Vector3(0.31, 2.4, 0.31) * scale
			GEO.box(root, Vector3(x, layout.height(x, z) + size.y * 0.5, z), size, null, true)
	if detail:
		for axis: float in PLAN.AXES:
			if axis < corner.y - 8 or axis > corner.y + 108:
				continue
			for along: int in [18, 49, 80]:
				var x := corner.x + along
				if absf(x) > 462 or absf(axis) > 462 or (axis == -250.0 and x >= PLAN.PILOT_WEST - 6 and x <= PLAN.PILOT_EAST + 6):
					continue
				var z := axis + (0.0 if axis == 0 else PLAN.road_z_offset(x, axis)) + (8.2 if axis == 0 else 6.2)
				var site := Vector2(x, z)
				if not _clear(site, key) or PLAN.road_distance(x, z) < 1.4:
					continue
				var at := Vector3(x, layout.height(x, z), z)
				_prop(blocks, "metal", at + Vector3.UP * 2.1, Vector3(0.13, 4.2, 0.13))
				_prop(blocks, "metal", at + Vector3(0, 4.12, -0.44), Vector3(0.14, 0.15, 0.95))
				_prop(blocks, "trim", at + Vector3(0, 4.03, -0.88), Vector3(0.26, 0.11, 0.34))
				_prop(blocks, "dark", at + Vector3(0, 0.015, -1.5), Vector3(0.64, 0.025, 0.42))
				if along == 49:
					_setback(root, key, zone, site + Vector2(2.6, 0.23))
		_landmarks(root, key, blocks)
	for material: String in blocks:
		_instances(root, box, colors[material], blocks[material], false)
	if not poses.is_empty():
		_tree_instances(root, poses, detail)
	_plant_verges(root, key, rng, detail)


func _setback(root: Node3D, key: Vector2i, zone: int, at: Vector2) -> void:
	var materials := ["planter_box_02", "metal_trash_can", "planter_box_02", "metal_trash_can"]
	var site := at + Vector2(0.20, 1.35)
	if _clear(site, key) and PLAN.road_distance(site.x, site.y) > 2.45:
		FURNITURE.furnish(root, materials[zone], Vector3(site.x, layout.height(site.x, site.y), site.y),
			0.06 * (key.x - key.y), 0.83, false)
	if zone == 3:
		var bag := site + Vector2(0.6, 0.04)
		if _clear(bag, key) and PLAN.road_distance(bag.x, bag.y) > 2.45:
			FURNITURE.furnish(root, "trashbag", Vector3(bag.x, layout.height(bag.x, bag.y), bag.y), 0.24, 0.67, false)


func _clear(point: Vector2, key: Vector2i) -> bool:
	if PLAN.RAIL_SITE.has_point(point) or PLAN.AIRPORT_SITE.has_point(point) or PLAN.CIVIC_PLAZA.has_point(point):
		return false
	var lot := parking.plan_lot(key)
	if not lot.is_empty() and lot.bounds.grow(2.3).has_point(point):
		return false
	if point.x > -391 and point.x < -130 and absf(point.y + 250) < 11:
		return false
	for entry: Array in PLAN.PLACES.values():
		var offset := (point - Vector2(entry[1], entry[2] + 4)).abs()
		if offset.x < 12.0 and offset.y < 13.0:
			return false
	for entry: Array in PLAN.LANDMARKS:
		var offset := (point - entry[1]).abs() as Vector2
		var half_size: Vector2 = entry[2] * 0.5 + Vector2.ONE * 3.0
		if offset.x < half_size.x and offset.y < half_size.y:
			return false
	for parcel: Dictionary in PLAN.parcels(key):
		var offset := (point - parcel.center).abs() as Vector2
		if offset.x < parcel.size.x * 0.5 + 2 and offset.y < parcel.size.y * 0.5 + 2:
			return false
	return true


func _plant_verges(root: Node3D, key: Vector2i, rng: RandomNumberGenerator, detail: bool) -> void:
	var corner := PLAN.origin(key)
	var parcels := PLAN.parcels(key)
	var lot := parking.plan_lot(key)
	var paved: Rect2 = lot.bounds.grow(1.75) if not lot.is_empty() else Rect2()
	var placements := [[], [], []]
	for i in (40 if detail else 9):
		var x := corner.x + rng.randf_range(4.0, 96.0)
		var z := corner.y + rng.randf_range(4.0, 96.0)
		var pilot := x > -380.0 and x < -140.0 and absf(z + 250.0) < 61.0
		if pilot and i % 2 == 0:
			z = PLAN.bridge_center(x) - rng.randf_range(11.5, 22.5)
		if z < corner.y + 1.0 or z >= corner.y + 99.0:
			continue
		var at := Vector2(x, z)
		var margin := PLAN.road_distance(x, z)
		if margin < 4.6 or paved.has_point(at) or not _plant_site(at, parcels):
			continue
		if i % 4 == 0 and margin > 8.0:
			placements[2].append(_plant_transform(at, rng, rng.randf_range(0.88, 1.75)))
		elif detail:
			if i % 3 == 0:
				placements[1].append(_plant_transform(at, rng, rng.randf_range(1.5, 2.8)))
			for tuft in 6:
				var patch := at + Vector2(rng.randf_range(-1.6, 1.6), rng.randf_range(-1.6, 1.6))
				if PLAN.road_distance(patch.x, patch.y) > 4.5 and not paved.has_point(patch) and _plant_site(patch, parcels):
					placements[0].append(_plant_transform(patch, rng, rng.randf_range(1.15, 2.3)))
	if key == Vector2i(2, 2) and detail:
		for x: float in [-294.5, -289.3, -286.0, -280.2, -273.2, -264.8]:
			var side := Vector2(x, PLAN.bridge_center(x) - 8.5)
			placements[1].append(_plant_transform(side, rng, rng.randf_range(1.6, 2.5)))
			for i in 11:
				var at := side + Vector2(rng.randf_range(-2.6, 2.6), rng.randf_range(-0.4, 2.6))
				if PLAN.road_distance(at.x, at.y) > 1.45:
					placements[0].append(_plant_transform(at, rng, rng.randf_range(0.8, 1.65)))
	for kind in placements.size():
		if placements[kind].is_empty():
			continue
		var meshes := _vegetation_meshes(VEGETATION[kind])
		if meshes.is_empty():
			continue
		for i in meshes.size():
			var poses: Array[Transform3D] = []
			for j in range(i, placements[kind].size(), meshes.size()):
				poses.append(placements[kind][j])
			if poses.is_empty():
				continue
			var center := Vector3(corner.x + 50.0, 0.0, corner.y + 50.0)
			var display := _instances(root, meshes[i], null, poses, detail and kind == 2, center)
			display.name = ["GrassClumps", "FloweringShrubs", "PineSaplings"][kind]
			display.visibility_range_end = [68.0, 108.0, 245.0][kind]
			display.visibility_range_end_margin = 9.0


func _plant_site(at: Vector2, parcels: Array[Dictionary]) -> bool:
	if PLAN.RAIL_SITE.has_point(at) or PLAN.AIRPORT_SITE.has_point(at) or PLAN.CIVIC_PLAZA.has_point(at):
		return false
	if at.abs().x > 483.0 or at.abs().y > 483.0:
		return false
	if at.x > -218.0 and at.x < -184.0 and absf(at.y + 250.0) < 17.0:
		return false
	for entry: Array in PLAN.PLACES.values():
		if at.distance_squared_to(Vector2(entry[1], entry[2] + 2.0)) < 240.0:
			return false
	for entry: Array in PLAN.LANDMARKS:
		var offset := (at - entry[1]).abs() as Vector2
		var half_size: Vector2 = entry[2] * 0.5 + Vector2.ONE * 1.8
		if offset.x < half_size.x and offset.y < half_size.y:
			return false
	for parcel in parcels:
		var offset := (at - parcel.center).abs() as Vector2
		if offset.x < parcel.size.x * 0.5 + 1.8 and offset.y < parcel.size.y * 0.5 + 1.8:
			return false
	return true


func _plant_transform(at: Vector2, rng: RandomNumberGenerator, scale: float) -> Transform3D:
	var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * scale)
	return Transform3D(basis, Vector3(at.x, layout.height(at.x, at.y) - 0.08, at.y))


func _vegetation_meshes(path: String) -> Array[Mesh]:
	if not plant_meshes.has(path):
		var template := models.instantiate(path)
		var meshes: Array[Mesh] = []
		for part: MeshInstance3D in template.find_children("*", "MeshInstance3D", true, false):
			var mesh := part.mesh.duplicate() as Mesh
			for surface in mesh.get_surface_count():
				var base := part.get_active_material(surface) as BaseMaterial3D
				if base and (path == VEGETATION[0] or base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED):
					mesh.surface_set_material(surface, GRAPHICS.foliage(base))
			meshes.append(mesh)
		template.free()
		plant_meshes[path] = meshes
	return plant_meshes[path]


func _landmarks(root: Node3D, key: Vector2i, blocks: Dictionary) -> void:
	for spec: Array in [
		[BUS, Vector2(114, -133), 0.0],
		[AMBULANCE, Vector2(82, -132.8), 0.0],
		[TRANSFORMERS, Vector2(78, 281), 0.0],
	]:
		var p: Vector2 = spec[1]
		if PLAN.chunk_for(Vector3(p.x, 0, p.y)) != key:
			continue
		var at := Vector3(p.x, layout.height(p.x, p.y), p.y)
		var asset := models.instantiate(spec[0])
		asset.position = at
		asset.rotation.y = spec[2]
		root.add_child(asset)
		if spec[0] == AMBULANCE:
			asset.basis = Basis(Vector3.UP, spec[2]) * Basis(Vector3.RIGHT, -PI / 2)
			GEO.box(root, at + Vector3.UP * 1.1, Vector3(6.4, 2.2, 2.1), null, true)
		if spec[0] == BUS:
			var bin_at := Vector3(p.x + 2.7, layout.height(p.x + 2.7, p.y), p.y)
			FURNITURE.furnish(root, "metal_trash_can", bin_at, 0.14, 0.86)
	if key == Vector2i(6, 3):
		var x := 172.0
		var z := -129.0
		var at := Vector3(x, layout.height(x, z), z)
		GEO.box(root, at + Vector3.UP * 0.18, Vector3(7, 0.36, 7), colors.stone, true)
		GEO.box(root, at + Vector3.UP * 1.75, Vector3(0.94, 3.0, 0.54), colors.dark, true)
		GEO.sign(root, "EVACUATION MEMORIAL", at + Vector3(0, 0.95, 0.3), 0, 0.006)
		EVACUATION.civic(root, layout, models)
	if key == Vector2i(1, 6):
		var at := Vector3(-315, layout.height(-315, 139), 139)
		for i in 5:
			var x := at.x + (i - 2) * 2.25
			var z := at.z + 5.2
			var prop := models.instantiate(BARRIER)
			prop.position = Vector3(x, layout.height(x, z) + 0.025, z)
			root.add_child(prop)
			GEO.box(prop, Vector3(0, 0.36, 0), Vector3(1.57, 0.72, 0.5), null, true)
		GEO.sign(root, "RELIEF DISTRIBUTION CLOSED", at + Vector3(0, 2.0, 2.9), PI, 0.009)


func _prop(groups: Dictionary, key: String, at: Vector3, size: Vector3) -> void:
	if not groups.has(key):
		groups[key] = []
	groups[key].append(Transform3D(Basis.from_scale(size), at))


func _tree_instances(root: Node3D, placements: Array[Transform3D], detail: bool) -> void:
	if trees.is_empty():
		var template := models.instantiate(TREE)
		root.add_child(template)
		for node in template.find_children("*", "MeshInstance3D", true, false):
			var part := node as MeshInstance3D
			var local := template.global_transform.affine_inverse() * part.global_transform
			var mesh := part.mesh.duplicate() as Mesh
			for index in mesh.get_surface_count():
				mesh.surface_set_material(index, part.get_active_material(index))
			trees.append({"mesh": mesh, "offset": local})
		root.remove_child(template)
		template.free()
	for part in trees:
		var poses: Array[Transform3D] = []
		for at in placements:
			poses.append(at * part.offset)
		_instances(root, part.mesh, null, poses, detail)


func _instances(root: Node3D, mesh: Mesh, material: Material, placements: Array, cast_shadow: bool, center := Vector3.ZERO) -> MultiMeshInstance3D:
	var scatter := MultiMesh.new()
	scatter.transform_format = MultiMesh.TRANSFORM_3D
	scatter.mesh = mesh
	scatter.instance_count = placements.size()
	for i in placements.size():
		var pose: Transform3D = placements[i]
		pose.origin -= center
		scatter.set_instance_transform(i, pose)
	var display := MultiMeshInstance3D.new()
	display.position = center
	display.multimesh = scatter
	display.material_override = material
	display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(display)
	return display
