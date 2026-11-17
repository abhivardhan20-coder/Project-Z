extends SceneTree
var city: Node3D
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1920,1080)
	city=(load("res://scenes/world/kaldran_mountain_review.tscn") as PackedScene).instantiate()
	root.add_child(city)
	city.ui.hide();city.playing=false
	city.player.playable=false
	city.state.clock=.42;city.state.weather=0;city.sky.frozen_time=true;city.sky.update(0)
	var camera := Camera3D.new();camera.far=80000;camera.fov=58
	city.add_child(camera);camera.position=Vector3(4,city.city_layout.height(4,90)+1.8,90);camera.look_at(Vector3(60,1800,-22000));camera.make_current()
	city.player.position=camera.position-Vector3.UP*1.8
	city.stream.refresh(city.player.position,true)
	city.mountain_stream.camera=camera;city.mountain_stream.refresh(true)
	for i in 100:await process_frame
	var deadline := Time.get_ticks_msec()+45000
	while (not city.mountains.districts.settled() or not city.mountain_stream.settled()) and Time.get_ticks_msec()<deadline:
		await process_frame
	var passed: bool = city.mountain_stream.live.size()>0 and city.layout.get_node_or_null("AlpineBasin")==null
	passed=passed and city.mountains.districts.omitted_background>0
	passed=passed and city.mountains.districts.settled() and city.mountain_stream.settled()
	for cell in city.mountains.districts.background.get_children():
		if not cell is MultiMeshInstance3D:continue
		for i in cell.multimesh.instance_count:
			var point: Vector3=cell.multimesh.get_instance_transform(i).origin
			if absf(point.x)<600 and absf(point.z)<600:passed=false
	print("CITY_MOUNTAIN_INTEGRATION ","PASS" if passed else "FAIL")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var path := ProjectSettings.globalize_path("res://mountain_source/08_Reference_Validation/Existing_City_Integration.png")
		root.get_texture().get_image().save_png(path)
	quit(0 if passed else 1)
