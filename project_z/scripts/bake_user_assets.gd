extends SceneTree

var groups: Dictionary
var input_nodes := 0
var source_surfaces := 0
var report: Array = []
var family_offsets: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var catalog: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/User/catalog.json"))
	var arguments := OS.get_cmdline_user_args()
	var only := PackedStringArray()
	if arguments.size()>0:
		only=arguments[0].split(",")
		var previous: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/Baked/catalog.json"))
		for entry: Dictionary in previous:
			if not entry.key in only:report.append(entry)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/Baked"))
	for item: Dictionary in catalog:
		if not only.is_empty() and not item.key in only:continue
		groups={};input_nodes=0;source_surfaces=0
		var packed := ResourceLoader.load(item.path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		if not packed:push_error("Could not import "+str(item.path));quit(1);return
		var source := packed.instantiate() as Node3D
		# HIL10 was supplied in Z-up coordinates; its pavilion is 4.3 m tall.
		var root_pose := Transform3D(Basis(Vector3.RIGHT,-PI/2),Vector3.ZERO) if item.key in ["HIL10","FIR","FIR_LOW","JUNIPER","GRASS","LICHEN","RADIO_TOWER","RADIO_HUT","SEDAN","POLICE","BUS"] else Transform3D.IDENTITY
		collect(source,root_pose)
		var bounds := AABB()
		var have_bounds := false
		for group: Dictionary in groups.values():
			for part: Dictionary in group.parts:
				var box: AABB=part.transform*part.mesh.get_aabb()
				bounds=box if not have_bounds else bounds.merge(box);have_bounds=true
		if not family_offsets.has(item.key):family_offsets[item.key]=Vector3(-bounds.get_center().x,-bounds.position.y,-bounds.get_center().z)
		var offset: Vector3=family_offsets[item.key]
		var importer := ImporterMesh.new()
		for group: Dictionary in groups.values():
			var builder := SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			for part: Dictionary in group.parts:
				var pose: Transform3D=part.transform;pose.origin+=offset
				builder.append_from(part.mesh,part.surface,pose)
			builder.index()
			var arrays := builder.commit_to_arrays()
			var normals: Variant=arrays[Mesh.ARRAY_NORMAL]
			if normals==null or normals.size()==0:
				builder.generate_normals();arrays=builder.commit_to_arrays()
			var material: Material=group.material
			var uv: Variant=arrays[Mesh.ARRAY_TEX_UV]
			if uv!=null and uv.size()>0:
				builder.generate_tangents();arrays=builder.commit_to_arrays()
			elif material is BaseMaterial3D and material.normal_enabled:
				material=material.duplicate();material.normal_enabled=false
			# This alpine kit authored atlas V in bottom-up convention. Its leaf
			# cards otherwise sample the opaque stone tiles in the atlas's bottom.
			if item.key in ["FIR","FIR_LOW","JUNIPER","GRASS","LICHEN"] and uv!=null:
				var corrected: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
				for v in corrected.size():corrected[v].y=1.0-corrected[v].y
				arrays[Mesh.ARRAY_TEX_UV]=corrected
				var tangents: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
				for t in range(3,tangents.size(),4):tangents[t]=-tangents[t]
				arrays[Mesh.ARRAY_TANGENT]=tangents
			# Source custom vertex channels are unused by the imported standard PBR
			# materials. Discard them rather than mis-declare their packed formats.
			for channel in [Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2,Mesh.ARRAY_CUSTOM3]:arrays[channel]=null
			importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},material)
		importer.generate_lods(45.0,60.0,[])
		var mesh := importer.get_mesh()
		if not mesh or mesh.get_surface_count()==0:push_error("Empty asset "+str(item.key));quit(1);return
		var name := "%s_%s" % [item.key,item.variant]
		var path := "res://assets/Baked/%s.res" % name
		if ResourceSaver.save(mesh,path)!=OK:push_error("Could not save "+path);quit(1);return
		var box := mesh.get_aabb()
		var lods := 0
		for s in importer.get_surface_count():lods+=importer.get_surface_lod_count(s)
		report.append({"key":item.key,"variant":item.variant,"resource":path,"source":item.path,
			"source_mesh_nodes":input_nodes,"source_surfaces":source_surfaces,"batched_surfaces":mesh.get_surface_count(),
			"mesh_lod_index_sets":lods,"bounds_min":[box.position.x,box.position.y,box.position.z],
			"bounds_size":[box.size.x,box.size.y,box.size.z],"normalization_offset":[offset.x,offset.y,offset.z]})
		print("BAKED ",name," nodes=",input_nodes," surfaces=",mesh.get_surface_count()," bounds=",box.size)
		source.free()
		await process_frame
	FileAccess.open("res://assets/Baked/catalog.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	FileAccess.open("res://mountain_source/09_Documentation/User_Asset_Bake.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("USER_ASSET_BAKE_COMPLETE ",report.size())
	quit(0)

func collect(node: Node, parent: Transform3D) -> void:
	var label := String(node.name).to_lower()
	if ("collision" in label and not "nocollision" in label) or "collider" in label or label.begins_with("col_"):return
	var pose := parent
	if node is Node3D:pose=parent*node.transform
	if node is MeshInstance3D:
		var view := node as MeshInstance3D
		if view.mesh and view.visible:
			input_nodes+=1
			for s in view.mesh.get_surface_count():
				if view.mesh.surface_get_primitive_type(s)!=Mesh.PRIMITIVE_TRIANGLES:continue
				var material := view.get_active_material(s)
				var key := "%s_%s" % [material.get_instance_id() if material else 0,view.mesh.surface_get_format(s)]
				if not groups.has(key):groups[key]={"material":material,"parts":[]}
				groups[key].parts.append({"mesh":view.mesh,"surface":s,"transform":pose});source_surfaces+=1
	for child in node.get_children():collect(child,pose)
