extends RefCounted

const LAYOUT := preload("res://scripts/city/layout.gd")
const GEO := preload("res://scripts/city/geometry.gd")
const GROUND := preload("res://materials/city_ground.gdshader")
const SKYLINE := preload("res://scripts/city/skyline.gd")
const DETAIL_STEP := 2.5
const DISTANT_STEP := 10.0

var layout: LAYOUT
var surface := ShaderMaterial.new()


func _init(world_layout: LAYOUT) -> void:
	layout = world_layout
	surface.shader = GROUND
	for texture: String in ["asphalt_track", "asphalt_track_nor_gl", "leafy_grass", "aerial_grass_rock",
			"worn_asphalt_diff", "worn_asphalt_nor_gl", "worn_asphalt_rough"]:
		var path := "res://assets/city/%s.jpg" % texture
		var imported: Texture2D
		if ResourceLoader.exists(path, "Texture2D"):
			imported = load(path) as Texture2D
		if not imported:
			var image := Image.new()
			var filename := path + ".runtime" if FileAccess.file_exists(path + ".runtime") else path
			if image.load_jpg_from_buffer(FileAccess.get_file_as_bytes(filename)) == OK:
				image.generate_mipmaps()
				imported = ImageTexture.create_from_image(image)
		if imported:
			surface.set_shader_parameter(texture, imported)


func horizon(parent: Node3D) -> void:
	SKYLINE.build(parent, layout)
	# Keep the ground under far scenery visible while detailed blocks stream in.
	var ground := SurfaceTool.new()
	ground.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stride := 53
	var points := PackedVector3Array()
	for z in stride:
		for x in stride:
			var at := Vector2(x, z) * 20.0 - Vector2.ONE * (LAYOUT.LIMIT + 20)
			var edge := at.clamp(Vector2.ONE * -LAYOUT.LIMIT, Vector2.ONE * LAYOUT.LIMIT)
			points.append(Vector3(at.x, layout.height(edge.x, edge.y) - 6.0, at.y))
	for z in stride - 1:
		for x in stride - 1:
			var a := z * stride + x
			for index: int in [a, a + 1, a + stride, a + 1, a + stride + 1, a + stride]:
				ground.add_vertex(points[index])
	ground.index()
	ground.generate_normals()
	var soil := ShaderMaterial.new()
	soil.shader = SKYLINE.RIDGE_SHADER
	var display := GEO.attach(parent, "BasinUnderlay", ground.commit(), soil, false)
	display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func tile(parent: Node3D, key: Vector2i, detail: bool) -> MeshInstance3D:
	# Shared samples on every edge. Far tiles have no physics bodies.
	var step := DETAIL_STEP if detail else DISTANT_STEP
	var divisions := roundi(LAYOUT.CHUNK_SIZE / step)
	var stride := divisions + 1
	var start := LAYOUT.origin(key)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var triangles := PackedInt32Array()
	for row in stride:
		for column in stride:
			var p := start + Vector2(column * step, row * step)
			# Match the 10 m far mesh at near/far boundaries.
			var height := _tile_height(p)
			vertices.append(Vector3(p.x, height, p.y))
			var dx := layout.height(p.x + 0.4, p.y) - layout.height(p.x - 0.4, p.y)
			var dz := layout.height(p.x, p.y + 0.4) - layout.height(p.x, p.y - 0.4)
			normals.append(Vector3(-dx, 0.8, -dz).normalized())
			var i := row * stride + column
			if row < divisions and column < divisions:
				triangles.append_array(PackedInt32Array([i, i + 1, i + stride, i + 1, i + stride + 1, i + stride]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = triangles
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return GEO.attach(parent, "Terrain", mesh, surface, detail)


func add_navigation_border(source: NavigationMeshSourceGeometryData3D, key: Vector2i) -> void:
	var start := LAYOUT.origin(key)
	var faces := PackedVector3Array()
	# Add one ring of neighboring terrain samples to the navigation bake only.
	# The bake clips this ring so the agent clearance does not shrink block seams.
	const DIVISIONS := int(LAYOUT.CHUNK_SIZE / DETAIL_STEP)
	for step_z in range(-1 if key.y > 0 else 0, DIVISIONS + (1 if key.y < LAYOUT.COUNT - 1 else 0)):
		for step_x in range(-1 if key.x > 0 else 0, DIVISIONS + (1 if key.x < LAYOUT.COUNT - 1 else 0)):
			if step_x >= 0 and step_x < DIVISIONS and step_z >= 0 and step_z < DIVISIONS:
				continue
			var a := start + Vector2(step_x, step_z) * DETAIL_STEP
			var b := a + Vector2.RIGHT * DETAIL_STEP
			var c := a + Vector2.DOWN * DETAIL_STEP
			var d := c + Vector2.RIGHT * DETAIL_STEP
			var va := Vector3(a.x, _tile_height(a), a.y)
			var vb := Vector3(b.x, _tile_height(b), b.y)
			var vc := Vector3(c.x, _tile_height(c), c.y)
			var vd := Vector3(d.x, _tile_height(d), d.y)
			faces.append_array(PackedVector3Array([va, vb, vc, vb, vd, vc]))
	source.add_faces(faces, Transform3D.IDENTITY)


func ground_height(point: Vector2, detail: bool = true) -> float:
	var step := DETAIL_STEP if detail else DISTANT_STEP
	var start := (point / step).floor() * step
	var uv := (point - start) / step
	var right := _tile_height(start + Vector2.RIGHT * step)
	var down := _tile_height(start + Vector2.DOWN * step)
	if uv.x + uv.y <= 1.0:
		return _tile_height(start) * (1.0 - uv.x - uv.y) + right * uv.x + down * uv.y
	var end := _tile_height(start + Vector2.ONE * step)
	return end * (uv.x + uv.y - 1.0) + right * (1.0 - uv.y) + down * (1.0 - uv.x)


func _tile_height(point: Vector2) -> float:
	if fposmod(point.y, LAYOUT.CHUNK_SIZE) == 0.0:
		var low_x := floorf(point.x / DISTANT_STEP) * DISTANT_STEP
		return lerpf(layout.height(low_x, point.y), layout.height(low_x + DISTANT_STEP, point.y),
			(point.x - low_x) / DISTANT_STEP)
	if fposmod(point.x, LAYOUT.CHUNK_SIZE) == 0.0:
		var low_z := floorf(point.y / DISTANT_STEP) * DISTANT_STEP
		return lerpf(layout.height(point.x, low_z), layout.height(point.x, low_z + DISTANT_STEP),
			(point.y - low_z) / DISTANT_STEP)
	return layout.height(point.x, point.y)
