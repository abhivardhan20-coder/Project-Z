extends Node3D

const DATA := "res://assets/pilot/"
const GROUND_SHADER := preload("res://materials/pilot_ground.gdshader")
const WATER_SHADER := preload("res://materials/pilot_water.gdshader")
const MATERIALS := ["grass", "compacted_dirt", "wet_mud", "gravel", "exposed_rock"]
const TILE_QUADS := 250
const SHOULDER_BLEND_WIDTH := 1.6

var layout_data: Dictionary
var heights: PackedFloat32Array
var water_mask: Image
var origin: Vector3
var samples: int
var spacing: float
var west: float
var north: float
var road := PackedVector3Array()
var road_angles := PackedFloat32Array()
var bridge_min: float
var bridge_max: float
var bridge_center_z: float
var bridge_height: float
var yard_start: float
var ground_start: Vector2
var ground_end: Vector2


func build() -> bool:
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA + "pilot_layout.json"))
	if not decoded is Dictionary:
		push_error("Kaldran pilot layout could not be opened.")
		return false
	layout_data = decoded
	var grid: Dictionary = layout_data["grid"]
	origin = Vector3(grid["origin_m"][0], grid["origin_m"][2], grid["origin_m"][1])
	west = grid["west"]
	north = grid["north"]
	samples = grid["samples"]
	spacing = grid["spacing"]
	heights = FileAccess.get_file_as_bytes(DATA + "height_f32.bin").to_float32_array()
	if heights.size() != samples * samples:
		push_error("Kaldran pilot elevation data has the wrong size.")
		return false
	water_mask = _load_image(DATA + "water_mask.png")
	if water_mask == null or water_mask.is_empty():
		push_error("Kaldran pilot water mask could not be opened.")
		return false
	var ground := _ground_material()
	if ground == null:
		return false
	ground_start = Vector2(west - origin.x, origin.z - north)
	ground_end = ground_start + Vector2.ONE * spacing * (samples - 1)
	for row in range(0, samples - 1, TILE_QUADS):
		for column in range(0, samples - 1, TILE_QUADS):
			_terrain_tile(column, row, ground)
	for point: Array in layout_data["road_m"]:
		road.append(to_scene(point))
	for index in road.size():
		var chord := road[mini(index + 1, road.size() - 1)] - road[maxi(index - 1, 0)]
		road_angles.append(atan2(chord.x, chord.z))
	var bridge: Dictionary = layout_data["bridge"]
	bridge_min = bridge["east_start"] - origin.x
	bridge_max = bridge["east_end"] - origin.x
	bridge_center_z = origin.z - bridge["north"]
	bridge_height = bridge["surface_m"] - origin.y
	yard_start = to_scene(layout_data["industrial_origin"]).x
	_build_water()
	_build_road()
	return true


func to_scene(point: Array) -> Vector3:
	return Vector3(point[0] - origin.x, point[2] - origin.y, origin.z - point[1])


func terrain_height(x: float, z: float) -> float:
	var c := clampf((x - ground_start.x) / spacing, 0, samples - 1)
	var r := clampf((z - ground_start.y) / spacing, 0, samples - 1)
	var i := mini(floori(c), samples - 2)
	var j := mini(floori(r), samples - 2)
	var u := c - i
	var v := r - j
	var a := heights[j * samples + i]
	var b := heights[j * samples + i + 1]
	var d := heights[(j + 1) * samples + i]
	var e := heights[(j + 1) * samples + i + 1]
	if u + v <= 1.0:
		return a + (b - a) * u + (d - a) * v
	return e + (d - e) * (1.0 - u) + (b - e) * (1.0 - v)


func road_point(x: float) -> Vector3:
	var bound := clampf(x, road[0].x, road[-1].x)
	for index in range(1, road.size()):
		if bound <= road[index].x:
			var first := road[index - 1]
			return first.lerp(road[index], (bound - first.x) / (road[index].x - first.x))
	return road[-1]


func outside(point: Vector3) -> bool:
	return point.x < ground_start.x or point.x > ground_end.x or point.z < ground_start.y or point.z > ground_end.y


func submerged(point: Vector3) -> bool:
	if outside(point):
		return false
	var c := clampi(roundi((point.x - ground_start.x) / spacing), 0, samples - 1)
	var r := clampi(roundi((point.z - ground_start.y) / spacing), 0, samples - 1)
	# The bridge deck and its approach are above the channel's southern water level.
	if point.x >= bridge_min and point.x <= bridge_max and absf(point.z - bridge_center_z) < 6.0:
		return point.y < bridge_height - 2.0 and water_mask.get_pixel(c, r).r > 0.5
	return water_mask.get_pixel(c, r).r > 0.5 and point.y < terrain_height(point.x, point.z) + 2.2


func is_wet(x: float, z: float) -> bool:
	var col := clampi(roundi((x - ground_start.x) / spacing), 0, samples - 1)
	var row := clampi(roundi((z - ground_start.y) / spacing), 0, samples - 1)
	return water_mask.get_pixel(col, row).r > 0.5


func _ground_material() -> ShaderMaterial:
	var albedos: Array[Image] = []
	var normals: Array[Image] = []
	for key: String in MATERIALS:
		for kind in ["albedo", "normal_roughness"]:
			var image := _load_image(DATA + "materials/%s_%s.png" % [key, kind])
			if image == null or image.is_empty():
				push_error("Kaldran pilot ground material missing: " + key)
				return null
			image.convert(Image.FORMAT_RGBA8)
			image.generate_mipmaps()
			(albedos if kind == "albedo" else normals).append(image)
	var layers := Texture2DArray.new()
	var detail := Texture2DArray.new()
	if layers.create_from_images(albedos) != OK or detail.create_from_images(normals) != OK:
		push_error("Kaldran pilot ground textures could not be assembled.")
		return null
	var blend := _load_image(DATA + "ground_blend.png")
	if blend == null or blend.is_empty():
		return null
	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	material.set_shader_parameter("ground_blend", ImageTexture.create_from_image(blend))
	material.set_shader_parameter("ground_albedo", layers)
	material.set_shader_parameter("ground_normal_roughness", detail)
	return material


func _load_image(path: String) -> Image:
	if ResourceLoader.exists(path, "Texture2D"):
		var texture := load(path) as Texture2D
		if texture:
			return texture.get_image()
	if FileAccess.file_exists(path + ".runtime"):
		var image := Image.new()
		if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path + ".runtime")) == OK:
			return image
	return Image.load_from_file(path)


func _terrain_tile(col: int, row: int, material: Material) -> void:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var index := PackedInt32Array()
	var stride := TILE_QUADS + 1
	var count := stride * stride
	points.resize(count)
	normals.resize(count)
	tangents.resize(count * 4)
	uvs.resize(count)
	index.resize(TILE_QUADS * TILE_QUADS * 6)
	var face := 0
	for r in stride:
		for c in stride:
			var i := r * stride + c
			var x := col + c
			var z := row + r
			var sample := z * samples + x
			var lo_x := maxi(0, x - 1)
			var hi_x := mini(samples - 1, x + 1)
			var lo_z := maxi(0, z - 1)
			var hi_z := mini(samples - 1, z + 1)
			var dx := (heights[z * samples + hi_x] - heights[z * samples + lo_x]) / ((hi_x - lo_x) * spacing)
			var dz := (heights[hi_z * samples + x] - heights[lo_z * samples + x]) / ((hi_z - lo_z) * spacing)
			var tangent := Vector3(1.0, dx, 0.0).normalized()
			points[i] = Vector3(ground_start.x + x * spacing, heights[sample], ground_start.y + z * spacing)
			normals[i] = Vector3(-dx, 1.0, -dz).normalized()
			tangents[i * 4] = tangent.x
			tangents[i * 4 + 1] = tangent.y
			tangents[i * 4 + 2] = tangent.z
			tangents[i * 4 + 3] = -1.0
			uvs[i] = Vector2(x, z) / float(samples - 1)
			if r < TILE_QUADS and c < TILE_QUADS:
				index[face] = i
				index[face + 1] = i + 1
				index[face + 2] = i + stride
				index[face + 3] = i + 1
				index[face + 4] = i + stride + 1
				index[face + 5] = i + stride
				face += 6
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_attach_mesh("PilotTile_%d_%d" % [col, row], mesh, material, true)


func _build_water() -> void:
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	for stream: Dictionary in layout_data["water_strips"]:
		var a := PackedVector3Array()
		var b := PackedVector3Array()
		for index in stream["left"].size():
			a.append(to_scene(stream["left"][index]))
			b.append(to_scene(stream["right"][index]))
		_attach_mesh(stream["id"], _strip(a, b), material, false)


func _build_road() -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("#373a39")
	dark.roughness = 0.91
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("#c5ae62")
	paint.roughness = 0.88
	var a := PackedVector3Array()
	var b := PackedVector3Array()
	for index in road.size():
		var side := Vector3(cos(road_angles[index]), 0.0, -sin(road_angles[index]))
		var width := 5.69 if road[index].x >= bridge_min and road[index].x <= bridge_max else 4.55
		a.append(road[index] + side * width)
		b.append(road[index] - side * width)
	# The continuous surface seals every join between the visible road and bridge modules.
	_attach_mesh("ContinuousRoadSupport", _strip(a, b), null, true, false)
	var paving_stop := 1
	while paving_stop < road.size() and road[paving_stop].x <= yard_start:
		paving_stop += 1
	_attach_mesh("ContinuousRoadbed", _strip(a.slice(0, paving_stop), b.slice(0, paving_stop)), dark, false)
	_build_road_shoulders(a, b, paving_stop)
	var dash_start := road[0].x + 3.0
	while dash_start < yard_start - 3.0:
		var p := road_point(dash_start) + Vector3.UP * 0.026
		var q := road_point(dash_start + 2.8) + Vector3.UP * 0.026
		var offset := (q - p).cross(Vector3.UP).normalized() * 0.047
		_attach_mesh("CenterMark", _strip(PackedVector3Array([p - offset, q - offset]),
			PackedVector3Array([p + offset, q + offset])), paint, false)
		dash_start += 7.0


func _build_road_shoulders(a: PackedVector3Array, b: PackedVector3Array, paving_stop: int) -> void:
	var gravel := StandardMaterial3D.new()
	gravel.albedo_color = Color("#6d6457")
	gravel.roughness = 0.98
	var west_count := 0
	var east_start := 0
	while west_count < paving_stop and road[west_count].x <= bridge_min:
		west_count += 1
	east_start = west_count
	while east_start < paving_stop and road[east_start].x < bridge_max:
		east_start += 1
	for edge in [a, b]:
		_road_shoulder(edge, 0, west_count, gravel)
		_road_shoulder(edge, east_start, paving_stop, gravel)
	# Both ends have the same gradual join as the shoulders.
	var last := road.size() - 1
	for station in [0, last]:
		var direction := (road[0] - road[1]) if station == 0 else (road[last] - road[last - 1])
		direction.y = 0.0
		direction = direction.normalized()
		var left := a[station]
		var right := b[station]
		_attach_mesh("RoadEndBlend", _strip(
			PackedVector3Array([left, _shoulder_to_ground(left, direction)]),
			PackedVector3Array([right, _shoulder_to_ground(right, direction)])), gravel, true)


func _road_shoulder(edge: PackedVector3Array, first: int, end: int, material: Material) -> void:
	var inside := PackedVector3Array()
	var outside_edge := PackedVector3Array()
	for index in range(first, end):
		var direction := (edge[index] - road[index]).normalized()
		inside.append(edge[index] - direction * 0.06 - Vector3.UP * 0.004)
		outside_edge.append(_shoulder_to_ground(edge[index], direction))
	_attach_mesh("RoadShoulderBlend", _strip(inside, outside_edge), material, true)


func grade_paved_edge(start: Vector3, finish: Vector3, outward: Vector3, material: Material) -> void:
	var segments := maxi(1, ceili(start.distance_to(finish) / spacing))
	var pavement := PackedVector3Array()
	var ground := PackedVector3Array()
	for segment in range(segments + 1):
		var edge := start.lerp(finish, float(segment) / segments)
		pavement.append(edge)
		ground.append(_shoulder_to_ground(edge, outward))
	_attach_mesh("PavedEdgeBlend", _strip(pavement, ground), material, true)


func _shoulder_to_ground(edge: Vector3, direction: Vector3) -> Vector3:
	var base := edge + direction * SHOULDER_BLEND_WIDTH
	base.y = terrain_height(base.x, base.z) - 0.025
	return base


func _strip(a: PackedVector3Array, b: PackedVector3Array) -> ArrayMesh:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in a.size():
		points.append(a[i])
		points.append(b[i])
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		if i + 1 < a.size():
			var k := i * 2
			if (a[i + 1] - a[i]).cross(b[i] - a[i]).y < 0:
				indices.append_array(PackedInt32Array([k, k + 2, k + 1, k + 2, k + 3, k + 1]))
			else:
				indices.append_array(PackedInt32Array([k, k + 1, k + 2, k + 2, k + 1, k + 3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _attach_mesh(title: String, mesh: ArrayMesh, material: Material, solid: bool, draw: bool = true) -> void:
	var piece := MeshInstance3D.new()
	piece.name = title
	piece.mesh = mesh
	piece.material_override = material
	piece.visible = draw
	add_child(piece)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var collider := CollisionShape3D.new()
		collider.shape = mesh.create_trimesh_shape()
		body.add_child(collider)
		piece.add_child(body)
