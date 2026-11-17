extends RefCounted

static var boxes: Dictionary = {}
static var finishes: Dictionary = {}


static func material(tint: Color) -> StandardMaterial3D:
	if not finishes.has(tint):
		var value := StandardMaterial3D.new()
		value.albedo_color = tint
		value.roughness = 0.87
		finishes[tint] = value
	return finishes[tint]


static func box(parent: Node3D, center: Vector3, size: Vector3, surface: Material, solid: bool = false) -> Node3D:
	var root: Node3D
	if solid:
		var body := StaticBody3D.new()
		body.collision_mask = 0
		var shape := BoxShape3D.new()
		shape.size = size
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		root = body
	else:
		root = Node3D.new()
	root.position = center
	parent.add_child(root)
	if surface:
		var visual := MeshInstance3D.new()
		if not boxes.has(size):
			var mesh := BoxMesh.new()
			mesh.size = size
			boxes[size] = mesh
		visual.mesh = boxes[size]
		visual.material_override = surface
		root.add_child(visual)
	return root


static func strip(parent: Node3D, title: String, left: PackedVector3Array, right: PackedVector3Array, surface: Material, solid: bool) -> MeshInstance3D:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(left.size() - 1):
		for point: Vector3 in [left[i], right[i], left[i + 1], right[i], right[i + 1], left[i + 1]]:
			builder.set_uv(Vector2(point.x, point.z) * 0.22)
			builder.add_vertex(point)
	builder.generate_normals()
	return attach(parent, title, builder.commit(), surface, solid)


static func attach(parent: Node3D, title: String, mesh: ArrayMesh, surface: Material, solid: bool) -> MeshInstance3D:
	var display := MeshInstance3D.new()
	display.name = title
	display.mesh = mesh
	display.material_override = surface
	parent.add_child(display)
	if solid:
		var body := StaticBody3D.new()
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var mesh_shape := mesh.create_trimesh_shape()
		mesh_shape.backface_collision = true
		shape.shape = mesh_shape
		body.add_child(shape)
		display.add_child(body)
	return display


static func sign(parent: Node3D, text: String, at: Vector3, yaw: float, size: float = 0.012) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.outline_size = 6
	label.pixel_size = size
	label.modulate = Color("#e0d6b9")
	label.position = at
	label.rotation.y = yaw
	parent.add_child(label)
	return label
