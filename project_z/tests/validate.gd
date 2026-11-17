extends SceneTree

var world: Node3D
var failures: Array[String]=[]
var report: Dictionary={}
var output: String

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	output=ProjectSettings.globalize_path("res://mountain_source/08_Reference_Validation")
	root.content_scale_size=Vector2i(1920,1080)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size=Vector2i(1280,720)
	world=(load("res://scenes/mountain_prototype.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.ui.visible=false
	_check(world.startup_complete,"Mountain scene initialized")
	report.engine=Engine.get_version_info().string
	report.gpu=RenderingServer.get_video_adapter_name()
	report.renderer=RenderingServer.get_current_rendering_method()
	report.viewport=[root.content_scale_size.x,root.content_scale_size.y]
	report.cpu=OS.get_processor_name()
	report.capture_date=Time.get_datetime_string_from_system()
	report.profiles=[]
	var quick := "--quick" in OS.get_cmdline_user_args()
	var headless := DisplayServer.get_name()=="headless"
	for i in ([4] if quick else [0,1,2,3,4]):
		world.select_camera(i)
		await settle()
		if i==0:
			var distant_count := 0
			var tested := 0
			for child in world.city.background.get_children():
				if child is MultiMeshInstance3D:
					distant_count+=child.multimesh.instance_count
					if tested<3:
						_check(child.multimesh.get_instance_transform(0).origin.length()>300,"Saved distant building transforms survive loading")
						tested+=1
			report.distant_buildings=distant_count
			_check(distant_count>3000,"Distant city instances are present")
		if not headless:
			var dir := output.path_join(str(world.manifest.cameras[i].id))
			DirAccess.make_dir_recursive_absolute(dir)
			await capture(dir.path_join("render.png"))
			if not quick and i<4:await measure(0,str(world.manifest.cameras[i].id))
			world.set_clay(true)
			await capture(dir.path_join("clay.png"))
			world.set_clay(false)
			world.set_silhouette(true)
			await capture(dir.path_join("silhouette.png"))
			world.set_silhouette(false)
	if not quick:
		for profile in 2:
			world.select_camera(4);world.set_quality(profile)
			await settle()
			if not headless:await measure(profile,"Panorama")
	world.enter_sector()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await settle()
	for i in 180:await physics_frame
	_check(world.terrain.data.get_region_count()==9,"Nine editable native terrain regions loaded")
	_check(world.walker.is_on_floor(),"Player stands on native terrain collision")
	var spawn_height: float=world.terrain.data.get_height(Vector3(world.sector_cfg.spawn[0],0,world.sector_cfg.spawn[2]))
	_check(absf(world.walker.global_position.y-spawn_height)<.7,"Player floor agrees with elevation source")
	var ray := PhysicsRayQueryParameters3D.create(world.walker.global_position+Vector3.UP*5,world.walker.global_position-Vector3.UP*10,1)
	_check(not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Ground physics ray hits near the spawn")
	if not headless:
		var dir := output.path_join("PlayableSector");DirAccess.make_dir_recursive_absolute(dir)
		await capture(dir.path_join("trail.png"))
		if not quick:
			for profile in 2:
				world.set_quality(profile);await settle();await measure(profile,"PlayableSector")
			world.set_season(2);world.set_weather(6);await capture(dir.path_join("winter.png"))
			world.set_weather(4);await capture(dir.path_join("moonlight.png"))
			world.set_weather(0);world.set_season(0);await capture(dir.path_join("summer.png"))
	if not quick:
		# Move across the 1 km native region boundary and let dynamic collision follow.
		var p := Vector3(-2052,0,-11700)
		p.y=world.terrain.data.get_height(p)+2
		world.walker.global_position=p
		for i in 90:await physics_frame
		_check(world.walker.is_on_floor(),"Native collision follows region-boundary travel")
		p.x=-2044;p.y=world.terrain.data.get_height(p)+2;world.walker.global_position=p
		for i in 90:await physics_frame
		_check(world.walker.is_on_floor(),"Player lands on both sides of native region seam")
		world.select_camera(4);await settle()
		_check(not is_instance_valid(world.terrain),"Near terrain unloads outside its region")
		_check(world.streamer.unload_count>0,"Distant terrain tiles leave the live set")
		world.enter_sector()
		for i in 90:await physics_frame
		var start: Vector3=world.walker.global_position
		var key := InputEventKey.new();key.physical_keycode=KEY_W;key.pressed=true
		Input.parse_input_event(key)
		for i in 120:await physics_frame
		key=InputEventKey.new();key.physical_keycode=KEY_W;key.pressed=false;Input.parse_input_event(key)
		_check(world.walker.global_position.distance_to(start)>3.0,"W input moves the player along the trail")
		for i in 15:await physics_frame
		_check(world.walker.is_on_floor(),"Player remains grounded after walking")
		if not headless:
			world.select_camera(4);await settle()
			var weather_dir := output.path_join("Weather");DirAccess.make_dir_recursive_absolute(weather_dir)
			for index in 8:
				world.set_weather(index)
				await capture(weather_dir.path_join("%02d.png" % index))
		report.weather_presets_rendered=8 if not headless else 0
	report.failures=failures
	report.streaming={"loads":world.streamer.loaded_count,"unloads":world.streamer.unload_count,"lod_transitions":world.streamer.transitions}
	var path := ProjectSettings.globalize_path("res://mountain_source/09_Documentation/Engine_QA_Quick.json" if quick else "res://mountain_source/09_Documentation/Engine_QA.json")
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("MOUNTAIN_QA_COMPLETE failures=%d" % failures.size())
	quit(0 if failures.is_empty() else 1)

func settle() -> void:
	var start := Time.get_ticks_msec()
	for i in 6000:
		await process_frame
		if i>40 and Time.get_ticks_msec()-start>1000 and world.streamer.settled() and world.city.settled():break
		if Time.get_ticks_msec()-start>45000:break
	_check(world.city.settled(),"Nearby authored districts finish streaming")

func capture(path: String) -> void:
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image.get_width()==1920 and image.get_height()==1080,"Capture is 1920 x 1080")
	_check(image.save_png(path)==OK,"Captured "+path.get_file())

func measure(profile: int,view: String) -> void:
	var values: Array[float]=[]
	var previous := Time.get_ticks_usec()
	for i in 120:
		await process_frame
		var now := Time.get_ticks_usec();values.append((now-previous)/1000.0);previous=now
	values.sort()
	var m := {"profile":profile,"view":view,"frames":values.size(),"median_ms":values[60],"p95_ms":values[114],"fps_from_median":1000.0/values[60],
		"video_memory_mib":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
	report.profiles.append(m);print(JSON.stringify(m))

func _check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures.append(label)
