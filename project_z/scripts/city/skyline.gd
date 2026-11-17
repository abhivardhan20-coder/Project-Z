extends RefCounted

const GEO := preload("res://scripts/city/geometry.gd")
const PLAN := preload("res://scripts/city/layout.gd")
const RIDGE_SHADER := preload("res://materials/ultra/alpine_ridge.gdshader")
const BUILDING_SHADER := preload("res://materials/ultra/distant_city.gdshader")
const SECTORS := 256
const BANDS := 18
const CAMERA_FAR := 2150.0


static func build(parent: Node3D, layout: PLAN) -> void:
	var ridge := GEO.attach(parent, "AlpineBasin", _ridge(layout), _surface(RIDGE_SHADER), false)
	ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_skyline(parent, layout)
	_foothill_forest(parent, layout)


static func _foothill_forest(parent: Node3D, layout: PLAN) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = PLAN.SEED + 95
	var canopy := CylinderMesh.new()
	canopy.rings = 1
	canopy.radial_segments = 6
	canopy.bottom_radius = 0.56
	canopy.top_radius = 0.12
	var woodland := MultiMesh.new()
	woodland.transform_format = MultiMesh.TRANSFORM_3D
	woodland.use_colors = true
	woodland.mesh = canopy
	woodland.instance_count = 520
	var finish := StandardMaterial3D.new()
	finish.vertex_color_use_as_albedo = true
	finish.roughness = 0.96
	for i in 260:
		var angle := rng.randf_range(-0.97, 0.75) if i < 175 else rng.randf_range(PI - 1.1, PI + 0.97)
		var direction := Vector2.from_angle(angle)
		var edge := direction * float(PLAN.LIMIT) / maxf(absf(direction.x), absf(direction.y))
		var at := edge.lerp(direction * 1610.0, rng.randf_range(0.03, 0.11))
		var ground := layout.height(edge.x, edge.y) + rng.randf_range(-0.6, 1.2)
		var height := rng.randf_range(8.0, 16.5)
		var width := rng.randf_range(3.7, 5.1)
		var color := Color("#35423a").lerp(Color("#666049"), rng.randf() * 0.8)
		woodland.set_instance_transform(2 * i, Transform3D(Basis.from_scale(Vector3(width, height * 0.52, width)),
			Vector3(at.x, ground + height * 0.4, at.y)))
		woodland.set_instance_transform(2 * i + 1, Transform3D(Basis.from_scale(Vector3(width * 0.76, height * 0.53, width * 0.76)),
			Vector3(at.x, ground + height * 0.68, at.y)))
		woodland.set_instance_color(2 * i, color.darkened(0.17))
		woodland.set_instance_color(2 * i + 1, color)
	var view := MultiMeshInstance3D.new()
	view.name = "FoothillConifers"
	view.multimesh = woodland
	view.material_override = finish
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(view)


static func _ridge(layout: PLAN) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = PLAN.SEED + 23
	noise.frequency = 3.45
	noise.fractal_octaves = 5
	var rings := PackedVector3Array()
	for band in BANDS + 1:
		var t := band / float(BANDS)
		for sector in SECTORS:
			var angle := sector * TAU / SECTORS
			var direction := Vector2.from_angle(angle)
			var edge := direction * (PLAN.LIMIT - 0.08) / maxf(absf(direction.x), absf(direction.y))
			var point := edge.lerp(direction * (1510.0 + edge.length() * 0.19), t) - direction * (1.0 - smoothstep(0.0, 0.1, t)) * 14.0
			var elevation := layout.height(edge.x, edge.y) - 0.06
			var main_mass := 142.0 + 168.0 * pow(0.5 + 0.5 * cos(angle + 0.10), 2.2)
			var summit := 0.36 + 0.64 * pow(0.5 + 0.5 * sin(angle * 15.0 - 0.1), 1.5)
			var crest := 0.63 + 0.07 * sin(angle * 9.0 + 0.9)
			var spine := pow(maxf(0.0, 1.0 - absf(t - crest) / 0.56), 1.65)
			var foothill := exp(-pow((t - 0.32) / 0.16, 2.0)) * (46.0 + 24.0 * sin(angle * 19.0))
			var gullies := noise.get_noise_3d(direction.x * 2.2, direction.y * 2.2, t * 3.3)
			var height := (main_mass * summit * spine + foothill + gullies * 85.0) * smoothstep(0.06, 0.32, t)
			rings.append(Vector3(point.x, elevation + height - 7.8 * (1.0 - smoothstep(0.0, 0.15, t)), point.y))
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for band in BANDS:
		for sector in SECTORS:
			var next := (sector + 1) % SECTORS
			var a := band * SECTORS + sector
			var b := band * SECTORS + next
			for index: int in [a, a + SECTORS, b, b, a + SECTORS, b + SECTORS]:
				builder.add_vertex(rings[index])
	builder.index()
	builder.generate_normals()
	return builder.commit()


static func _skyline(parent: Node3D, layout: PLAN) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = PLAN.SEED + 49
	var rows: Array[Vector3] = []
	var masonry := [Color("#787f84"), Color("#98a0a4"), Color("#8e8b81"), Color("#626d76"), Color("#717a80")]
	# Layer the eastern skyline behind the end of the playable road.
	for row in 3:
		for column in 25:
			var x := 524.0 + row * 44.0 + rng.randf_range(-9.0, 9.0)
			var z := -500.0 + column * 28.0 + rng.randf_range(-8.0, 8.0)
			var base := layout.height(500.0, clampf(z, -500.0, 500.0)) - 12.0
			rows.append(Vector3(x, base, z))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = BoxMesh.new()
	multimesh.instance_count = rows.size() * 2
	for i in rows.size():
		var at := rows[i]
		var core := 1.0 - smoothstep(42.0, 260.0, absf(at.z + 236.0))
		var height := rng.randf_range(18.0, 50.0) + (24.0 + 52.0 * rng.randf()) * core * rng.randf()
		var size := Vector3(rng.randf_range(15.0, 24.0), height, rng.randf_range(14.0, 21.0))
		var roof := Vector3(size.x * 0.67, rng.randf_range(2.1, 7.1), size.z * 0.72)
		multimesh.set_instance_transform(i * 2, Transform3D(Basis.from_scale(size), at + Vector3.UP * height * 0.5))
		multimesh.set_instance_transform(i * 2 + 1, Transform3D(Basis.from_scale(roof), at + Vector3.UP * (height + roof.y * 0.5)))
		var tint: Color = masonry[rng.randi_range(0, masonry.size() - 1)]
		multimesh.set_instance_color(i * 2, tint)
		multimesh.set_instance_color(i * 2 + 1, tint.darkened(0.23))
	var skyline := MultiMeshInstance3D.new()
	skyline.name = "EasternSkyline"
	skyline.multimesh = multimesh
	skyline.material_override = _surface(BUILDING_SHADER)
	skyline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(skyline)
	_midrise_bands(parent, layout)


static func _midrise_bands(parent: Node3D, layout: PLAN) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = PLAN.SEED + 175
	var shell := MultiMesh.new()
	shell.transform_format = MultiMesh.TRANSFORM_3D
	shell.use_colors = true
	shell.mesh = BoxMesh.new()
	shell.instance_count = 144
	for i in shell.instance_count:
		var row := floori(i / 36.0)
		var x := 536.0 + row * 37.0 + random.randf_range(-11, 11)
		var z := -571.0 + (i % 36) * 27.4 + random.randf_range(-6, 6)
		var altitude := layout.height(500.0, clampf(z, -500.0, 500.0)) - 5.2
		var h := random.randf_range(8.5, 23.0) + row * 1.7
		var size := Vector3(random.randf_range(10.0, 21.0), h, random.randf_range(11.0, 21.0))
		var color := Color("#555b59").lerp(Color("#a79d90"), random.randf())
		shell.set_instance_transform(i, Transform3D(Basis.from_scale(size), Vector3(x, altitude + h * 0.5, z)))
		shell.set_instance_color(i, color)
	var display := MultiMeshInstance3D.new()
	display.name = "BasinApartmentBands"
	display.multimesh = shell
	display.material_override = _surface(BUILDING_SHADER)
	display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(display)


static func _surface(shader: Shader) -> ShaderMaterial:
	var surface := ShaderMaterial.new()
	surface.shader = shader
	return surface
