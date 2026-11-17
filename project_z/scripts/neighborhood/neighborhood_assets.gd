extends RefCounted

static var scenes: Dictionary = {}
static var pieces: Dictionary = {}


func instantiate(path: String) -> Node3D:
	if not scenes.has(path):
		scenes[path] = _load_model(path)
	var scene: PackedScene = scenes[path]
	if scene == null:
		return Node3D.new()
	return scene.instantiate() as Node3D


func piece(path: String, node_name: String) -> Node3D:
	var key := path + ":" + node_name
	if not pieces.has(key):
		var model := instantiate(path)
		var part := model.find_child(node_name, true, false) as Node3D
		if part == null:
			push_error("Missing model piece: " + key)
			model.free()
			return Node3D.new()
		var transform := part.transform
		var ancestor := part.get_parent_node_3d()
		while ancestor:
			transform = ancestor.transform * transform
			ancestor = ancestor.get_parent_node_3d()
		var basis := transform.basis
		var wrapper := Node3D.new()
		_clear_owner(part)
		part.get_parent().remove_child(part)
		wrapper.add_child(part)
		part.transform = Transform3D(basis, Vector3.ZERO)
		_set_owner(part, wrapper)
		var packed := PackedScene.new()
		packed.pack(wrapper)
		pieces[key] = packed
		wrapper.free()
		model.free()
	return (pieces[key] as PackedScene).instantiate() as Node3D


func _load_model(path: String) -> PackedScene:
	if ResourceLoader.exists(path, "PackedScene"):
		var imported := load(path) as PackedScene
		if imported:
			var model := imported.instantiate()
			_prepare_materials(model)
			var packed := PackedScene.new()
			for child in model.get_children():
				_set_owner(child, model)
			var result := packed.pack(model)
			model.free()
			return packed if result == OK else imported
	# The standalone play launcher can use raw GLBs before the editor builds its import cache.
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	state.handle_binary_image = GLTFState.HANDLE_BINARY_IMAGE_MODE_EMBED_AS_UNCOMPRESSED
	var result: Error
	if FileAccess.file_exists(path + ".runtime"):
		result = document.append_from_buffer(FileAccess.get_file_as_bytes(path + ".runtime"), path.get_base_dir(), state,
			GLTFDocument.IMPORT_FLAG_GENERATE_TANGENT_ARRAYS)
	else:
		result = document.append_from_file(path, state, GLTFDocument.IMPORT_FLAG_GENERATE_TANGENT_ARRAYS)
	if result != OK:
		push_error("Unable to open neighborhood asset: " + path)
		return null
	var model := document.generate_scene(state)
	if model == null:
		push_error("Unable to instantiate neighborhood asset: " + path)
		return null
	_prepare_materials(model)
	for child in model.get_children():
		_set_owner(child, model)
	var packed := PackedScene.new()
	result = packed.pack(model)
	model.free()
	if result != OK:
		push_error("Unable to pack neighborhood asset: " + path)
		return null
	return packed


func _set_owner(node: Node, root: Node) -> void:
	node.owner = root
	for child in node.get_children():
		_set_owner(child, root)


func _clear_owner(node: Node) -> void:
	node.owner = null
	for child in node.get_children():
		_clear_owner(child)

func _prepare_materials(model: Node) -> void:
	# Some source meshes lack vertex normals, so the glTF importer cannot
	# produce tangents for their normal maps. Keep their other PBR maps.
	var fallbacks: Dictionary = {}
	var instances := model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		instances.append(model)
	for node in instances:
		var instance := node as MeshInstance3D
		var mesh := instance.mesh as ArrayMesh
		if mesh == null:
			continue
		for index in mesh.get_surface_count():
			if mesh.surface_get_format(index) & Mesh.ARRAY_FORMAT_TANGENT:
				continue
			var material := instance.get_active_material(index) as BaseMaterial3D
			if material == null or not material.normal_enabled:
				continue
			if not fallbacks.has(material):
				var fallback := material.duplicate() as BaseMaterial3D
				fallback.normal_enabled = false
				fallbacks[material] = fallback
			instance.set_surface_override_material(index, fallbacks[material])
