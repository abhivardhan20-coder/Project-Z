extends SceneTree
var catalog: Dictionary={}
var meshes: Dictionary={}
var collisions: Dictionary={}
var report: Dictionary={}

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var records: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/Baked/catalog.json"))
	for item: Dictionary in records:
		if not catalog.has(item.key):catalog[item.key]=[]
		catalog[item.key].append(item)
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://Data/asset_placements.json"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/Districts"))
	for key: String in data.districts:
		var district := Node3D.new();district.name=key
		var count := 0
		for p: Dictionary in data.placements:
			if p.group!=key:continue
			var parent := Node3D.new();parent.name=p.id
			parent.position=Vector3(p.position[0],p.position[1],p.position[2]);parent.rotation.y=p.yaw;parent.scale=Vector3.ONE*float(p.scale)
			parent.rotation.z=float(p.get("roll",0))
			if p.has("scale_xyz"):parent.scale=Vector3(p.scale_xyz[0],p.scale_xyz[1],p.scale_xyz[2])
			parent.set_meta("source_asset",p.key);district.add_child(parent);parent.owner=district
			var variants: Array=catalog[p.key]
			var size: Array=variants[0].bounds_size
			var extent: float=maxf(size[0],maxf(size[1],size[2]))
			var near_limit := maxf(220,extent*1.8)
			var far_limit := maxf(900,extent*6.0)
			if variants.size()==2:near_limit=maxf(450,extent*4.0)
			for i in variants.size():
				var row: Dictionary=variants[i]
				var view := MeshInstance3D.new();view.mesh=asset(row.resource);view.name=row.variant
				view.lod_bias=.65
				if variants.size()>1:
					view.visibility_range_begin=0 if i==0 else near_limit if i==1 else far_limit
					view.visibility_range_end=near_limit if i==0 else far_limit if i<variants.size()-1 else 0
					view.visibility_range_begin_margin=12;view.visibility_range_end_margin=12
				parent.add_child(view);view.owner=district
				if i==0 and p.collision:
					if not collisions.has(p.key):collisions[p.key]=view.mesh.create_trimesh_shape()
					var body := StaticBody3D.new();var c := CollisionShape3D.new();c.shape=collisions[p.key]
					parent.add_child(body);body.owner=district;body.add_child(c);c.owner=district
			count+=1
		for p: Dictionary in data.surfaces:
			if p.group!=key:continue
			var view := MeshInstance3D.new();view.name=p.name
			var mesh := BoxMesh.new();mesh.size=Vector3(p.size[0],p.size[1],p.size[2]);view.mesh=mesh
			var mat := StandardMaterial3D.new();mat.albedo_color=Color("#696d68") if p.material=="stone" else Color("#303535");mat.roughness=.88
			view.material_override=mat;view.position=Vector3(p.position[0],p.position[1],p.position[2]);view.rotation.y=p.yaw
			district.add_child(view);view.owner=district
			if key=="Alpine":
				view.create_trimesh_collision()
				for child in view.get_children():
					child.owner=district
					for shape in child.get_children():shape.owner=district
		pack(district,key);report[key]={"asset_placements":count,"scene":"res://scenes/Districts/%s.tscn" % key}
		district.free();await process_frame
	var background := Node3D.new();background.name="KaldranBackgroundArchitecture"
	var groups: Dictionary={}
	for p: Dictionary in data.background:
		var cell := "%s_%d_%d" % [p.key,floori(float(p.position[0])/1024),floori(float(p.position[2])/1024)]
		cell=cell.replace("-","n")
		if not groups.has(cell):groups[cell]={"key":p.key,"points":[]}
		groups[cell].points.append(p)
	for cell: String in groups:
		var group: Dictionary=groups[cell]
		var choices: Array=catalog[group.key]
		var mesh := asset(choices[-1].resource)
		var multi := MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=mesh;multi.instance_count=group.points.size()
		for i in group.points.size():
			var p: Dictionary=group.points[i]
			multi.set_instance_transform(i,Transform3D(Basis(Vector3.UP,float(p.yaw)).scaled(Vector3.ONE*float(p.scale)),Vector3(p.position[0],p.position[1],p.position[2])))
		var view := MultiMeshInstance3D.new();view.name=cell;view.multimesh=multi;view.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		background.add_child(view);view.owner=background
	# The headless dummy renderer cannot read back MultiMesh transforms. Persist
	# the buffer explicitly so saved instances retain their placement on load.
	write_background(groups,data.placements);background.free()
	report.background={"instances":data.background.size(),"instanced_cells":groups.size()}
	FileAccess.open("res://mountain_source/09_Documentation/District_Scene_Bake.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("DISTRICT_BAKE_COMPLETE ",JSON.stringify(report));quit(0)

func asset(path: String) -> Mesh:
	if not meshes.has(path):meshes[path]=load(path)
	return meshes[path]

func write_background(groups: Dictionary,placements: Array) -> void:
	var lines := PackedStringArray(["[gd_scene format=3]",""])
	var keys: Dictionary={}
	for group: Dictionary in groups.values():keys[group.key]=true
	var landmarks: Array=[]
	for p: Dictionary in placements:
		if p.key in ["AIR01","AIR02","AIR03","AIR04","AIR08","CIV01","CIV03","RAIL01","RAIL02","RAIL03","RAIL09","HIL01","HIL02","HIL04","HIL07","MIDRISE"]:
			keys[p.key]=true;landmarks.append(p)
	for key: String in keys:
		var choices: Array=catalog[key]
		lines.append('[ext_resource type="ArrayMesh" path="%s" id="%s"]' % [choices[-1].resource,key])
	for cell: String in groups:
		var group: Dictionary=groups[cell]
		var values := PackedStringArray()
		for p: Dictionary in group.points:
			var c: float=cos(float(p.yaw))*float(p.scale)
			var s: float=sin(float(p.yaw))*float(p.scale)
			for v: float in [c,0.0,s,float(p.position[0]),0.0,float(p.scale),0.0,float(p.position[1]),-s,0.0,c,float(p.position[2])]:values.append(str(v))
		lines.append('\n[sub_resource type="MultiMesh" id="%s"]\ntransform_format = 1\ninstance_count = %d\nmesh = ExtResource("%s")\nbuffer = PackedFloat32Array(%s)' % [cell,group.points.size(),group.key,", ".join(values)])
	lines.append('\n[node name="KaldranBackgroundArchitecture" type="Node3D"]')
	for cell: String in groups:
		lines.append('\n[node name="%s" type="MultiMeshInstance3D" parent="."]\ncast_shadow = 0\nmultimesh = SubResource("%s")' % [cell,cell])
	for district in ["Airport","Railway","Hillside","Capitol"]:
		lines.append('\n[node name="Far_%s" type="Node3D" parent="."]' % district)
	for p: Dictionary in landmarks:
		var c: float=cos(float(p.yaw))*float(p.scale);var s: float=sin(float(p.yaw))*float(p.scale)
		lines.append('\n[node name="%s" type="MeshInstance3D" parent="Far_%s"]\ntransform = Transform3D(%s, 0, %s, 0, %s, 0, %s, 0, %s, %s, %s, %s)\nmesh = ExtResource("%s")\ncast_shadow = 0\nlod_bias = 0.4' % [p.id,p.group,c,-s,p.scale,s,c,p.position[0],p.position[1],p.position[2],p.key])
	FileAccess.open("res://scenes/Districts/Background.tscn",FileAccess.WRITE).store_string("\n".join(lines)+"\n")

func pack(node: Node3D,key: String) -> void:
	var packed := PackedScene.new()
	if packed.pack(node)!=OK:push_error("Pack failed "+key);quit(1);return
	if ResourceSaver.save(packed,"res://scenes/Districts/%s.tscn" % key)!=OK:push_error("Save failed "+key);quit(1)
