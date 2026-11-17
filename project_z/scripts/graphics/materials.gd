extends RefCounted

const SURFACE := preload("res://materials/ultra/surface.gdshader")
const GLASS := preload("res://materials/ultra/glass.gdshader")
const FOLIAGE := preload("res://materials/ultra/foliage.gdshader")
const FURNITURE := preload("res://scripts/city/interior_assets.gd")
static var cache: Dictionary = {}


static func surface(preset: String) -> ShaderMaterial:
	if not cache.has(preset):
		var material := ShaderMaterial.new()
		material.resource_name = preset
		material.shader = SURFACE
		var id := "concrete_floor_02"
		var tint := Color("#a6a099")
		var rough := 0.82
		var exposure := 0.0
		match preset:
			"Asphalt":
				id = "asphalt_track"
				tint = Color("#8b8a86")
				exposure = 0.94
			"Exposed concrete":
				exposure = 0.56
			"Brick":
				id = "brick_wall_001"
				exposure = 0.40
			"Interior plaster":
				id = "white_plaster_02"
				tint = Color("#c4bdb0")
			"Interior tile":
				id = "tiled_floor_001"
				rough = 0.67
			"Interior wood":
				id = "wood_floor"
				tint = Color("#aa947a")
			"Painted steel":
				id = ""
				tint = Color("#6d7778")
				rough = 0.59
				exposure = 0.49
				material.set_shader_parameter("metallic", 0.48)
			"Automotive paint":
				id = ""
				tint = Color("#573632")
				rough = 0.32
				exposure = 0.83
				material.set_shader_parameter("metallic", 0.21)
				material.set_shader_parameter("coat", 0.74)
		if preset == "Asphalt":
			material.set_shader_parameter("metres", 2.4)
		if id != "":
			var base := load_jpg("res://assets/city/asphalt_track.jpg") if id == "asphalt_track" else FURNITURE.texture(id, "Diffuse")
			var normal := load_jpg("res://assets/city/asphalt_track_nor_gl.jpg") if id == "asphalt_track" else FURNITURE.texture(id, "nor_gl")
			material.set_shader_parameter("base_color", base)
			material.set_shader_parameter("normal_map", normal)
			material.set_shader_parameter("has_normal", normal != null)
			if normal:
				material.set_shader_parameter("has_detail", true)
				material.set_shader_parameter("detail_normal", normal)
		material.set_shader_parameter("roughness", rough)
		material.set_shader_parameter("tint", tint)
		material.set_shader_parameter("wet_exposure", exposure)
		cache[preset] = material
	return cache[preset]


static func indoor_floor(id: String, tint: Color, metres: float) -> ShaderMaterial:
	var key := [id, tint, metres]
	if not cache.has(key):
		var reference := "Exposed concrete"
		match id:
			"wood_floor": reference = "Interior wood"
			"tiled_floor_001": reference = "Interior tile"
		var material := surface(reference).duplicate() as ShaderMaterial
		material.set_shader_parameter("tint", tint)
		material.set_shader_parameter("metres", metres)
		material.set_shader_parameter("wet_exposure", 0.0)
		cache[key] = material
	return cache[key]


static func glass() -> ShaderMaterial:
	if not cache.has("glass"):
		var material := ShaderMaterial.new()
		material.shader = GLASS
		cache["glass"] = material
	return cache["glass"]


static func foliage(source: Material) -> Material:
	var base := source as BaseMaterial3D
	if not base or not base.albedo_texture:
		return source
	if not cache.has(source):
		var material := ShaderMaterial.new()
		material.shader = FOLIAGE
		material.set_shader_parameter("leaf_tex", base.albedo_texture)
		material.set_shader_parameter("tint", base.albedo_color)
		cache[source] = material
	return cache[source]


static func adapt_model(model: Node3D, category: StringName) -> void:
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if not part.mesh:
			continue
		for index in part.mesh.get_surface_count():
			var source := part.get_active_material(index) as StandardMaterial3D
			if not source:
				continue
			if category == &"car" and source.resource_name.begins_with("Paint"):
				part.set_surface_override_material(index, _car_paint(source))
			elif category in [&"survivor", &"infected"] and source.resource_name == "_Body":
				var key := [category, source]
				if not cache.has(key):
					var skin := source.duplicate() as StandardMaterial3D
					skin.roughness = maxf(skin.roughness, 0.65)
					skin.metallic = 0.0
					skin.metallic_specular = 0.31 if category == &"survivor" else 0.24
					cache[key] = skin
				part.set_surface_override_material(index, cache[key])


static func _car_paint(base: StandardMaterial3D) -> ShaderMaterial:
	if not cache.has(base):
		var material := surface("Automotive paint").duplicate() as ShaderMaterial
		material.set_shader_parameter("tint", base.albedo_color)
		material.set_shader_parameter("world_mapping", false)
		material.set_shader_parameter("macro_strength", 0.035)
		if base.albedo_texture:
			material.set_shader_parameter("base_color", base.albedo_texture)
		if base.normal_texture:
			material.set_shader_parameter("normal_map", base.normal_texture)
			material.set_shader_parameter("has_normal", true)
		cache[base] = material
	return cache[base]


static func load_jpg(path: String) -> Texture2D:
	if ResourceLoader.exists(path, "Texture2D"):
		return load(path) as Texture2D
	var file := path + ".runtime" if FileAccess.file_exists(path + ".runtime") else path
	var image := Image.new()
	if image.load_jpg_from_buffer(FileAccess.get_file_as_bytes(file)) != OK:
		return null
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
