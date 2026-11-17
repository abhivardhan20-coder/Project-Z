extends Node3D
# Ordinary editable district scenes, plus supplied HLODs in cullable 512 m cells.
var districts: Dictionary={}
var live: Dictionary={}
var timer := 0.0
var background: Node3D
var protect_playable_city := false
var omitted_background := 0
var requests: Dictionary={}

func _ready() -> void:
	name="KaldranAssetDistricts"
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://Data/asset_placements.json"))
	districts=data.districts
	var scene := load("res://scenes/Districts/Background.tscn") as PackedScene
	background=scene.instantiate();add_child(background)
	if protect_playable_city:_protect_city(data)

func _process(delta: float) -> void:
	timer-=delta
	if timer>0:return
	timer=.3
	var camera := get_viewport().get_camera_3d()
	if not camera:return
	for key: String in districts:
		if key=="Alpine":continue
		var point: Array=districts[key].center
		var distance := Vector2(camera.global_position.x-point[0],camera.global_position.z-point[1]).length()
		if distance<float(districts[key].radius):
			if live.has(key):continue
			var path := "res://scenes/Districts/%s.tscn" % key
			if ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				ResourceLoader.load_threaded_request(path)
				requests[path]=true
			if ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_LOADED:
				var scene := ResourceLoader.load_threaded_get(path) as PackedScene
				requests.erase(path)
				var node := scene.instantiate()
				if protect_playable_city:_filter_district(node)
				add_child(node);live[key]=node
		elif live.has(key):live[key].queue_free();live.erase(key)
		background.get_node("Far_"+key).visible=not live.has(key)

func settled() -> bool:
	var camera := get_viewport().get_camera_3d()
	if not camera:return false
	for key: String in districts:
		if key=="Alpine":continue
		var point: Array=districts[key].center
		if Vector2(camera.global_position.x-point[0],camera.global_position.z-point[1]).length()<float(districts[key].radius) and not live.has(key):return false
	return true

func _exit_tree() -> void:
	# Finish owned loader jobs before the scene and rendering server shut down.
	for path: String in requests:
		if ResourceLoader.load_threaded_get_status(path)!=ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_get(path)
	requests.clear()

func _inside_city(point: Vector3) -> bool:
	return absf(point.x)<600 and absf(point.z)<600

func _filter_district(node: Node3D) -> void:
	for child in node.get_children():
		if child is Node3D and _inside_city(child.position):
			node.remove_child(child);child.free()

func _protect_city(data: Dictionary) -> void:
	# Only the unified map excludes scenery from the existing gameplay blocks.
	# Rebuild affected buffers from source placements, including under headless
	# validation where the dummy renderer cannot read MultiMesh transforms back.
	var cells: Dictionary={}
	var affected: Dictionary={}
	for p: Dictionary in data.background:
		var cell := ("%s_%d_%d" % [p.key,floori(float(p.position[0])/1024),floori(float(p.position[2])/1024)]).replace("-","n")
		if not cells.has(cell):cells[cell]=[]
		if _inside_city(Vector3(p.position[0],p.position[1],p.position[2])):
			affected[cell]=true;omitted_background+=1
		else:cells[cell].append(p)
	for cell: String in affected:
		var view := background.get_node(cell) as MultiMeshInstance3D
		var multi := MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D
		multi.mesh=view.multimesh.mesh;multi.instance_count=cells[cell].size()
		for i in cells[cell].size():
			var p: Dictionary=cells[cell][i]
			multi.set_instance_transform(i,Transform3D(Basis(Vector3.UP,float(p.yaw)).scaled(Vector3.ONE*float(p.scale)),Vector3(p.position[0],p.position[1],p.position[2])))
		view.multimesh=multi
	for key in ["Airport","Railway","Hillside","Capitol"]:_filter_district(background.get_node("Far_"+key))
