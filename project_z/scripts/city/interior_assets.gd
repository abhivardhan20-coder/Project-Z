extends RefCounted

const GEO := preload("res://scripts/city/geometry.gd")
const MODELS := preload("res://scripts/neighborhood/neighborhood_assets.gd")
const FOLDER := "res://assets/interiors/"

static var library := MODELS.new()
static var bounds_cache: Dictionary = {}
static var finishes: Dictionary = {}
static var textures: Dictionary = {}


static func furnish(parent: Node3D, asset: String, at: Vector3, yaw: float = 0.0,
		uniform_scale: float = 1.0, solid: bool = true, collision_height: float = 0.0) -> Node3D:
	var path := FOLDER + asset + ".glb"
	var prop := Node3D.new()
	prop.name = asset
	prop.position = at
	prop.rotation.y = yaw
	parent.add_child(prop, true)
	var model := library.instantiate(path)
	prop.add_child(model)
	var bounds: AABB = bounds_cache.get(asset, AABB())
	if not bounds.has_volume():
		bounds = _bounds(model)
		bounds_cache[asset] = bounds
	if not bounds.has_volume():
		push_error("Interior model has no visible geometry: " + path)
		return prop
	var center := bounds.get_center()
	model.scale = Vector3.ONE * uniform_scale
	model.position = -Vector3(center.x, bounds.position.y, center.z) * uniform_scale
	if solid:
		var size := bounds.size * uniform_scale
		if collision_height > 0:
			size.y = minf(size.y, collision_height)
		var blocker := GEO.box(prop, Vector3.UP * size.y * 0.5, size, null, true)
		blocker.name = "FurnitureCollision"
	return prop


static func finish(id: String, tint: Color, metres: float, roughness: float) -> StandardMaterial3D:
	var key := [id, tint, metres, roughness]
	if not finishes.has(key):
		var surface := StandardMaterial3D.new()
		surface.albedo_color = tint
		surface.albedo_texture = texture(id, "Diffuse")
		surface.normal_texture = texture(id, "nor_gl")
		surface.normal_enabled = surface.normal_texture != null
		surface.normal_scale = 0.45
		surface.roughness = roughness
		surface.uv1_triplanar = true
		surface.uv1_world_triplanar = true
		surface.uv1_scale = Vector3.ONE / metres
		finishes[key] = surface
	return finishes[key]


static func texture(id: String, channel: String) -> Texture2D:
	var path := FOLDER + id + "-" + channel + ".jpg"
	if not textures.has(path):
		textures[path] = _texture(path)
	return textures[path]


static func _bounds(model: Node3D) -> AABB:
	var bounds := AABB()
	var world_to_model := model.global_transform.affine_inverse()
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		meshes.append(model)
	for part: MeshInstance3D in meshes:
		if part.mesh:
			var box := (world_to_model * part.global_transform) * part.get_aabb()
			bounds = bounds.merge(box) if bounds.has_volume() else box
	return bounds


static func _texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path, "Texture2D"):
		return load(path) as Texture2D
	var filename := path + ".runtime" if FileAccess.file_exists(path + ".runtime") else path
	if not FileAccess.file_exists(filename):
		return null
	var image := Image.new()
	if image.load_jpg_from_buffer(FileAccess.get_file_as_bytes(filename)) != OK:
		return null
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
