extends Node3D
# Supplied conifers, granite, moss, undergrowth and deadwood in streamed cells.
var camera: Camera3D
var chunks: Dictionary={}
var live: Dictionary={}
var meshes: Dictionary={}
var shapes: Dictionary={}
var timer := 0.0
var profile := 0
var winter := false

func asset(key: String) -> Mesh:
	if not meshes.has(key):meshes[key]=load("res://assets/Baked/%s_local.res" % key)
	return meshes[key]

func configure(view: Camera3D,_material: ShaderMaterial) -> void:
	camera=view
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://Data/Sector/instances.json"))
	for kind in ["trees","rocks"]:
		for point: Array in data[kind]:
			var key := Vector2i(floori(float(point[0])/64),floori(float(point[2])/64))
			if not chunks.has(key):chunks[key]={"trees":[],"rocks":[],"details":[]}
			chunks[key][kind].append(point)
	var details: Array=JSON.parse_string(FileAccess.get_file_as_string("res://Data/Sector/undergrowth.json"))
	for point: Dictionary in details:
		var key := Vector2i(floori(float(point.position[0])/64),floori(float(point.position[2])/64))
		if not chunks.has(key):chunks[key]={"trees":[],"rocks":[],"details":[]}
		chunks[key].details.append(point)
	var props := load("res://scenes/Districts/Alpine.tscn") as PackedScene
	if props:add_child(props.instantiate())

func _process(delta: float) -> void:
	if not camera:return
	timer-=delta
	if timer>0:return
	timer=.6
	var wanted: Dictionary={}
	var eye := Vector2(camera.global_position.x,camera.global_position.z)
	for key: Vector2i in chunks:
		var center := Vector2(key)*64+Vector2.ONE*32
		var dist := center.distance_to(eye)
		if dist>1550:continue
		var tier := 0 if dist<(115.0 if profile==0 else 180.0) else 1 if dist<450 else 2
		wanted[key]=tier
		if live.has(key) and live[key].tier==tier and live[key].winter==winter:continue
		if live.has(key):live[key].node.queue_free()
		var parent := Node3D.new();parent.name="Ecology_%s_%s" % [key.x,key.y];add_child(parent)
		live[key]={"node":parent,"tier":tier,"winter":winter}
		_build_chunk(parent,chunks[key],tier)
	for key: Vector2i in live.keys():
		if not wanted.has(key):live[key].node.queue_free();live.erase(key)

func _build_chunk(parent: Node3D,data: Dictionary,tier: int) -> void:
	var pine := asset("WINTER_PINE" if winter else "PINE0" if tier==0 else "PINE1")
	var transforms: Array[Transform3D]=[]
	var height := pine.get_aabb().size.y
	for p: Array in data.trees:
		var scale: float=float(p[3])/height
		transforms.append(Transform3D(Basis(Vector3.UP,float(p[4])).scaled(Vector3.ONE*scale),Vector3(p[0],p[1]-.08,p[2])))
		if tier==0:
			var body := StaticBody3D.new();body.position=Vector3(p[0],p[1]+2,p[2]);parent.add_child(body)
			var c := CollisionShape3D.new();var trunk := CylinderShape3D.new();trunk.height=4;trunk.radius=maxf(.12,float(p[3])*.022)
			c.shape=trunk;body.add_child(c)
	_multimesh(parent,pine,transforms,tier==0)
	if tier<2:
		for variant in 4:
			var mesh := asset("ROCK%d" % (variant+1))
			transforms=[]
			for p: Array in data.rocks:
				if int(p[5])%3!=variant%3 or (variant==3 and int(float(p[0]))%4!=0):continue
				if variant==0 and int(float(p[0]))%4==0:continue
				var scale: float=float(p[3])/maxf(mesh.get_aabb().size.x,mesh.get_aabb().size.z)
				var t := Transform3D(Basis(Vector3.UP,float(p[4])).scaled(Vector3.ONE*scale),Vector3(p[0],p[1]-.12*scale,p[2]))
				transforms.append(t)
				if tier==0:_collision(parent,mesh,t,"ROCK%d" % variant)
			_multimesh(parent,mesh,transforms,tier==0)
	if tier==0:
		var grouped: Dictionary={}
		for p: Dictionary in data.details:
			var name: String=p.key
			if not grouped.has(name):grouped[name]=[]
			var t := Transform3D(Basis(Vector3.UP,float(p.yaw)).scaled(Vector3.ONE*float(p.scale)),Vector3(p.position[0],p.position[1],p.position[2]))
			grouped[name].append(t)
			if name in ["LOG","STUMP","ROOTS"]:_collision(parent,asset(name),t,name)
		for key: String in grouped:
			var poses: Array[Transform3D]=[];poses.assign(grouped[key])
			_multimesh(parent,asset(key),poses,key in ["FIR","LOG","STUMP"])

func _collision(parent: Node3D,mesh: Mesh,t: Transform3D,key: String) -> void:
	if not shapes.has(key):shapes[key]=mesh.create_convex_shape(true,false)
	var body := StaticBody3D.new();body.transform=t
	var collision := CollisionShape3D.new();collision.shape=shapes[key];body.add_child(collision);parent.add_child(body)

func _multimesh(parent: Node3D,mesh: Mesh,transforms: Array[Transform3D],shadow: bool) -> void:
	if transforms.is_empty():return
	var mm := MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=transforms.size()
	for i in transforms.size():mm.set_instance_transform(i,transforms[i])
	var node := MultiMeshInstance3D.new();node.multimesh=mm;parent.add_child(node)
	node.lod_bias=.55
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
