extends RefCounted

const GEO := preload("res://scripts/city/geometry.gd")
const MODELS := preload("res://scripts/neighborhood/neighborhood_assets.gd")
const FOLDER := "res://assets/reference_dressing/"

static var library := MODELS.new()
static var meshes: Dictionary = {}


static func place(parent: Node3D, name: String, at: Vector3, yaw: float = 0.0,
		size := Vector3.ZERO, solid := false) -> MeshInstance3D:
	if not meshes.has(name):
		meshes[name] = _prepare(parent, name)
	var mesh: ArrayMesh = meshes[name]
	var bounds := mesh.get_aabb()
	var scale := Vector3.ONE
	if size != Vector3.ZERO and bounds.has_volume():
		scale = size / bounds.size
	var mount := Node3D.new()
	mount.name = name.to_pascal_case()
	mount.position = at
	mount.rotation.y = yaw
	parent.add_child(mount, true)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.scale = scale
	var center := bounds.get_center()
	visual.position = -Vector3(center.x, bounds.position.y, center.z) * scale
	mount.add_child(visual)
	visual.visibility_range_end = 420.0 if maxf(bounds.size.x, bounds.size.y) > 5.0 else 90.0
	visual.visibility_range_end_margin = 8.0
	if solid and bounds.has_volume():
		var footprint := bounds.size * scale
		GEO.box(mount, Vector3.UP * footprint.y * 0.49, footprint * Vector3(0.91, 0.98, 0.94), null, true)
	return visual


static func _prepare(parent: Node3D, name: String) -> ArrayMesh:
	var source := library.instantiate(FOLDER + name + ".glb")
	parent.add_child(source)
	var inverse := source.global_transform.affine_inverse()
	var orientation := Transform3D.IDENTITY
	if name in ["airport_entry", "baggage_trolley", "jersey_barrier", "litter", "stretcher"]:
		orientation = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)
	var batches := {}
	for part: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		if not part.mesh or not part.is_visible_in_tree():
			continue
		var local := (String(part.name)).to_lower()
		if local.begins_with("ucx") or local.contains("collision") or local.begins_with("proxy"):
			continue
		var transform := orientation * inverse * part.global_transform
		for i in part.mesh.get_surface_count():
			var surface := part.get_active_material(i)
			if not batches.has(surface):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				tool.set_material(surface)
				batches[surface] = tool
			var batch: SurfaceTool = batches[surface]
			batch.append_from(part.mesh, i, transform)
	var result := ArrayMesh.new()
	for batch: SurfaceTool in batches.values():
		batch.commit(result)
	source.free()
	return result
