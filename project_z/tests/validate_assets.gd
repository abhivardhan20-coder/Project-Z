extends SceneTree
var failures: Array[String]=[]

func _initialize() -> void:call_deferred("run")
func run() -> void:
	var catalog: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/Baked/catalog.json"))
	var keys: Dictionary={}
	var surfaces := 0
	for record: Dictionary in catalog:
		keys[record.key]=true
		var mesh := load(record.resource) as ArrayMesh
		check(mesh!=null,"Mesh loads "+str(record.resource))
		if not mesh:continue
		check(mesh.get_surface_count()>0,"Nonempty "+str(record.key))
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			check(normals.size()==vertices.size(),"Complete normals "+str(record.resource))
			var material := mesh.surface_get_material(s) as BaseMaterial3D
			if material and material.normal_enabled:
				var tangents: Variant=arrays[Mesh.ARRAY_TANGENT]
				check(tangents!=null and tangents.size()==vertices.size()*4,"Normal map tangents "+str(record.resource))
			surfaces+=1
		if record.key=="RADIO_TOWER":check(mesh.get_aabb().size.y>28 and mesh.get_aabb().size.y<31,"Radio tower is upright at metre scale")
		if record.key=="PINE0":check(mesh.get_aabb().size.y>9 and mesh.get_aabb().size.y<11,"Mature conifer uses authored metre scale")
		if record.key=="SEDAN":check(mesh.get_aabb().size.y>1.3 and mesh.get_aabb().size.y<1.9,"Sedan has corrected up axis")
	var placement: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://Data/asset_placements.json"))
	for record: Dictionary in placement.placements:check(keys.has(record.key),"Placement references selected asset "+str(record.key))
	for name: String in placement.districts:check(ResourceLoader.exists("res://scenes/Districts/%s.tscn" % name),"Editable district exists "+name)
	var distant_count := 0
	var transforms_checked := 0
	if DisplayServer.get_name()!="headless":
		root.size=Vector2i(640,360)
		var background := (load("res://scenes/Districts/Background.tscn") as PackedScene).instantiate()
		root.add_child(background)
		for i in 3:await process_frame
		for child in background.get_children():
			if child is MultiMeshInstance3D:
				distant_count+=child.multimesh.instance_count
				if transforms_checked<8:
					check(child.multimesh.get_instance_transform(0).origin.length()>300,"Saved instance buffer retains world coordinates")
					transforms_checked+=1
		check(distant_count==placement.background.size(),"Background instance count agrees with source")
		background.queue_free();await process_frame
	var result := {"mesh_resources":catalog.size(),"asset_families":keys.size(),"surfaces_checked":surfaces,"placements_checked":placement.placements.size(),"distant_instances_checked":distant_count,"saved_transforms_checked":transforms_checked,"failures":failures}
	FileAccess.open("res://mountain_source/09_Documentation/User_Asset_QA.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("USER_ASSET_QA ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)

func check(passed: bool,label: String) -> void:
	if not passed:failures.append(label);push_error(label)
