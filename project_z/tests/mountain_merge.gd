extends SceneTree

var failures: Array[String]=[]
var captures := "res://mountain_source/08_Reference_Validation/Merged"

func _initialize() -> void:call_deferred("run")

func check(condition: bool,label: String) -> void:
	print(("PASS " if condition else "FAIL ")+label)
	if not condition:failures.append(label)

func frames(count: int) -> void:
	for i in count:await process_frame

func capture(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(captures.path_join(name+".png"))
	return image

func run() -> void:
	if not OS.get_cmdline_user_args().has("--city-test"):
		push_error("Run with -- --city-test to isolate save files");quit(2);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(captures))
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(1280,720)
	var world := (load("res://scenes/mountain_prototype.tscn") as PackedScene).instantiate()
	root.add_child(world);world.ui.hide();world.set_weather(0)
	world.walker.active=false;world.set_process(false)
	world.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;world.camera.size=3600
	world.camera.position=Vector3(-1536,8002,-11776)
	world.camera.look_at(Vector3(-1536,1000,-11776),Vector3.FORWARD)
	world._ensure_sector();world.set_silhouette(true)
	world.streamer.refresh(true)
	await frames(100)
	for profile in 2:
		world.set_quality(profile)
		await frames(50)
		var image := await capture("Seam_Top_Down_Profile_%d" % profile)
		var bright := 0
		# The whole image footprint lies inside valid far terrain. A bright pixel
		# here exposes sky through a mesh gap, independent of texture or lighting.
		for y in range(20,image.get_height()-20,2):
			for x in range(20,image.get_width()-20,2):
				var c := image.get_pixel(x,y)
				if minf(c.r,minf(c.g,c.b))>.8:bright+=1
		check(bright==0,"No exposed sky in native/far seam, profile %d (%d bright pixels)" % [profile,bright])
	# Include an off-centre coarse clipmap boundary, not just the trail spawn.
	world.camera.position.x+=2500
	world.camera.look_at(world.camera.position-Vector3.UP*5000,Vector3.FORWARD)
	await frames(50)
	var offcenter := await capture("Seam_Off_Centre")
	var leaks := 0
	for y in range(20,offcenter.get_height()-20,3):
		for x in range(20,offcenter.get_width()-20,3):
			var c := offcenter.get_pixel(x,y)
			if minf(c.r,minf(c.g,c.b))>.8:leaks+=1
	check(leaks==0,"Moving clipmap retains far fallback (%d bright pixels)" % leaks)
	world.set_silhouette(false);world.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	world.camera.position=Vector3(-1536,8002,-9500)
	world.camera.look_at(Vector3(-1536,1300,-12000))
	world.walker.active=true;world.walker.fly=true;world.walker.set_process(false);world.walker.set_physics_process(false)
	world._process(.1)
	check(not is_instance_valid(world.terrain) and not world.streamer.sector_active,"8002 m free flight restores complete distant surface")
	await frames(60)
	await capture("Fixed_Aerial_8002m")
	world.queue_free();await frames(10)
	var city := (load("res://scenes/world/kaldran_city.tscn") as PackedScene).instantiate()
	root.add_child(city)
	city.sky.frozen_time=true;city.state.clock=.42;city.state.weather=0;city.sky.update(0)
	await frames(70)
	check(city.playing and city.mountains.streamer.live.size()>0,"Default city loads shared mountain world")
	check(city.layout.get_node_or_null("AlpineBasin")==null,"Old horizon removed")
	check(city.mountains.districts.background.get_child_count()>0,"Supplied asset districts loaded")
	city.ui.hide();await capture("Unified_City")
	var origin: Vector3=city.player.global_position
	var stage: int=city.state.stage
	var inventory: Dictionary=city.state.inventory.duplicate(true)
	await city.travel_to_trail()
	for i in 100:await physics_frame
	check(city.mountains.native.data.get_region_count()==9,"Nine native terrain regions in city datum")
	var h: float=city.mountains.native.data.get_height(city.player.global_position)
	print("MOUNTAIN_FLOOR player=",city.player.global_position," ground=",h," region_size=",city.mountains.native.region_size)
	check(is_finite(h) and absf(city.player.global_position.y-h)<2,"City player stands on mountain collision")
	check(city.player.is_on_floor(),"City player on native floor")
	check(city.state.stage==stage and city.state.inventory==inventory,"Story and inventory preserved during travel")
	city._checkpoint(false)
	var record: Dictionary=city.state.read_save()
	check(not record.is_empty() and record.position.z < -10000,"Mountain checkpoint passes save validation")
	await capture("Unified_Mountain_Trail")
	city._continue_game()
	for i in 35:await physics_frame
	check(city.player.is_on_floor() and city.player.position.z < -10000,"Continue restores mountain collision and player")
	city.return_to_city()
	for i in 45:await physics_frame
	check(Vector2(city.player.position.x,city.player.position.z).distance_to(Vector2(origin.x,origin.z))<1,"Return restores original city position")
	check(city.state.stage==stage and city.state.inventory==inventory,"Return preserves gameplay state")
	check(not city.state.read_save().is_empty(),"City save remains readable")
	var report := {"failures":failures,"captures":captures,"checks":"seam profiles, off-centre coverage, aerial unloading, default map, travel, collision, save/continue/return"}
	FileAccess.open("res://mountain_source/09_Documentation/Merge_QA.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("MOUNTAIN_MERGE_QA failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
