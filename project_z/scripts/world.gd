extends Node3D

@export var initial_camera := 4
const STREAMER := preload("res://scripts/streamer.gd")
const WALKER := preload("res://scripts/walker.gd")
const ECOLOGY := preload("res://scripts/vegetation.gd")
const CITY := preload("res://scripts/context_city.gd")

var manifest: Dictionary
var sector_cfg: Dictionary
var camera: Camera3D
var walker: CharacterBody3D
var terrain: Terrain3D
var streamer: Node3D
var ecology: Node3D
var city: Node3D
var environment: Environment
var sun: DirectionalLight3D
var sky_material: ShaderMaterial
var cloud_material: ShaderMaterial
var clouds: Node3D
var ui: CanvasLayer
var status: Label
var weather: Array
var weather_index := 2
var camera_index := 4
var quality := 0
var season_value := 1.0
var is_clay := false
var is_silhouette := false
var seconds := 0.0
var near_scene: PackedScene
var snow_particles: GPUParticles3D
var startup_complete := false

func _ready() -> void:
	manifest=JSON.parse_string(FileAccess.get_file_as_string("res://Data/world.json"))
	sector_cfg=JSON.parse_string(FileAccess.get_file_as_string("res://Data/Sector/sector.json"))
	weather=JSON.parse_string(FileAccess.get_file_as_string("res://Lighting/presets.json"))
	camera=Camera3D.new();camera.name="ReferenceCamera";camera.near=.2;camera.far=80000;add_child(camera);camera.make_current()
	walker=WALKER.new();walker.name="MountainWalker";walker.camera=camera;add_child(walker)
	_lighting()
	city=CITY.new();add_child(city)
	streamer=STREAMER.new();streamer.name="RegionalMountainStreamer";add_child(streamer)
	select_camera(initial_camera,false)
	streamer.configure(camera,manifest)
	near_scene=load("res://scenes/editable_sector.tscn")
	_make_ui()
	set_weather(weather_index)
	set_quality(0)
	startup_complete=true
	print("KALDRAN_MOUNTAINS_READY | Godot %s | %s" % [Engine.get_version_info().string,RenderingServer.get_video_adapter_name()])

func _lighting() -> void:
	sun=DirectionalLight3D.new();sun.name="AlpineSun";sun.shadow_enabled=true;sun.directional_shadow_max_distance=180
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS;add_child(sun)
	environment=Environment.new();environment.background_mode=Environment.BG_SKY
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.reflected_light_source=2
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure=1.1
	environment.fog_enabled=true;environment.fog_sky_affect=.03;environment.fog_aerial_perspective=.06
	environment.sky=Sky.new();environment.sky.radiance_size=Sky.RADIANCE_SIZE_128
	environment.sky.process_mode=Sky.PROCESS_MODE_INCREMENTAL
	sky_material=ShaderMaterial.new();sky_material.shader=preload("res://Shaders/sky.gdshader")
	sky_material.set_shader_parameter("dusk_map",load("res://Lighting/qwantani_dusk_2_puresky.hdr"))
	sky_material.set_shader_parameter("overcast_map",load("res://Lighting/kloofendal_overcast_puresky.hdr"))
	environment.sky.sky_material=sky_material
	var world_environment := WorldEnvironment.new();world_environment.environment=environment;add_child(world_environment)
	clouds=Node3D.new();clouds.name="OrographicCloudBanks";add_child(clouds)
	cloud_material=ShaderMaterial.new();cloud_material.shader=preload("res://Shaders/cloud_bank.gdshader")
	for i in 5:
		var plane := QuadMesh.new();plane.size=Vector2(8500,800)
		var bank := MeshInstance3D.new();bank.mesh=plane;bank.material_override=cloud_material;bank.position=Vector3((i-2)*7200,1200+(i%3)*240,-16000-(i%2)*5400)
		bank.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;clouds.add_child(bank)
	snow_particles=GPUParticles3D.new();snow_particles.amount=800;snow_particles.lifetime=4;snow_particles.visibility_aabb=AABB(Vector3(-20,-20,-20),Vector3(40,40,40))
	var snow := ParticleProcessMaterial.new();snow.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX;snow.emission_box_extents=Vector3(15,8,15)
	snow.direction=Vector3(.2,-1,.1);snow.spread=12;snow.initial_velocity_min=1;snow.initial_velocity_max=2.6;snow.gravity=Vector3(.2,-.3,0)
	snow_particles.process_material=snow
	var flake := QuadMesh.new();flake.size=Vector2(.026,.026)
	var ice := StandardMaterial3D.new();ice.albedo_color=Color(.83,.90,.96);ice.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;flake.material=ice
	snow_particles.draw_pass_1=flake;snow_particles.emitting=false;add_child(snow_particles)

func select_camera(index: int,update_streamer := true) -> void:
	camera_index=clampi(index,0,4)
	walker.active=false;walker.velocity=Vector3.ZERO;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var cfg: Dictionary=manifest.cameras[camera_index]
	camera.global_position=Vector3(cfg.position[0],cfg.position[1],cfg.position[2])
	# Estimates from visible architecture; no EXIF or camera survey was supplied.
	camera.look_at(Vector3(cfg.target[0],cfg.target[1],cfg.target[2]),Vector3.UP)
	camera.fov=float(cfg.fov)
	set_weather(int(cfg.weather))
	if update_streamer and streamer.camera:streamer.refresh()

func enter_sector() -> void:
	_ensure_sector()
	camera_index=5
	walker.active=true;walker.fly=false
	walker.global_position=Vector3(sector_cfg.spawn[0],sector_cfg.spawn[1]+1,sector_cfg.spawn[2])
	walker.velocity=Vector3.ZERO;walker.yaw=float(sector_cfg.get("spawn_yaw",0));walker.pitch=-.05
	camera.global_position=walker.global_position+Vector3.UP*1.65;camera.rotation=Vector3(walker.pitch,walker.yaw,0);camera.fov=65
	terrain.set_camera(camera);terrain.collision_target=walker;terrain.clipmap_target=walker
	set_weather(0);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func _ensure_sector() -> void:
	if is_instance_valid(terrain):return
	terrain=near_scene.instantiate() as Terrain3D
	add_child(terrain)
	terrain.set_camera(camera);terrain.collision_target=walker;terrain.clipmap_target=camera
	terrain.material.show_checkered=false
	terrain.material.set_shader_param("snow_line",_snow_line())
	terrain.material.set_shader_param("wetness",weather[weather_index].wet)
	terrain.material.set_shader_param("clay",is_clay)
	terrain.material.set_shader_param("silhouette",is_silhouette)
	streamer.sector_active=true;streamer.sync_materials();streamer.refresh()
	ecology=ECOLOGY.new();ecology.name="StreamedAlpineEcology";add_child(ecology)
	ecology.configure(camera,streamer.new_material());ecology.profile=quality
	ecology.winter=season_value>1.65 and season_value<2.45
	var cliff := (load("res://Meshes/jointed_cliff.glb") as PackedScene).instantiate()
	cliff.name="CrownApproachJointedCliff";cliff.position=Vector3(-1770,terrain.data.get_height(Vector3(-1770,0,-11830)),-11830);cliff.rotation.y=.4
	ecology.add_child(cliff)
	for mesh: MeshInstance3D in cliff.find_children("*","MeshInstance3D",true,false):
		mesh.material_override=streamer.new_material();mesh.create_trimesh_collision()

func _release_sector() -> void:
	if not is_instance_valid(terrain):return
	terrain.queue_free();terrain=null
	ecology.queue_free();ecology=null
	streamer.sector_active=false;streamer.sync_materials()

func _process(delta: float) -> void:
	seconds+=delta
	if not startup_complete:return
	snow_particles.position=camera.global_position+Vector3.UP*5
	var distance := Vector2(camera.global_position.x+1536,camera.global_position.z+11776).length()
	# High-altitude review must retain the complete distant terrain surface.
	# Hysteresis avoids repeatedly rebuilding collision during free flight.
	var height_above := camera.global_position.y - _regional_height(camera.global_position)
	if distance<3000 and height_above<650 and not is_instance_valid(terrain):_ensure_sector()
	elif (distance>3600 or height_above>900) and is_instance_valid(terrain) and (not walker.active or walker.fly):_release_sector()
	if status and int(seconds*2)!=int((seconds-delta)*2):
		var name := str(manifest.cameras[camera_index].id) if camera_index<5 else "Crown Approach • walking" if not walker.fly else "Free flight"
		status.text="%s   /   %s   /   %s\nElevation %.0f m   •   %d terrain regions   •   %d FPS" % [name,weather[weather_index].name,"Development" if quality==0 else "Cinematic",camera.global_position.y,streamer.live.size(),Engine.get_frames_per_second()]

var regional_heights := PackedFloat32Array()
func _regional_height(point: Vector3) -> float:
	if regional_heights.is_empty():regional_heights=FileAccess.get_file_as_bytes("res://Data/capital_height.f32").to_float32_array()
	var col := clampi(roundi((point.x+24576)/32),0,1536)
	var row := clampi(roundi((point.z+40960)/32),0,1536)
	return regional_heights[row*1537+col]

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	if event.keycode>=KEY_1 and event.keycode<=KEY_5:select_camera(event.keycode-KEY_1)
	elif event.keycode==KEY_6:enter_sector()
	elif event.keycode==KEY_F:
		walker.active=true;walker.fly=true;walker.global_position=camera.global_position-Vector3.UP*1.65
		walker.yaw=camera.rotation.y;walker.pitch=camera.rotation.x;camera_index=6
		if is_instance_valid(terrain):terrain.clipmap_target=camera
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	elif event.keycode==KEY_C:set_clay(not is_clay)
	elif event.keycode==KEY_H:ui.visible=not ui.visible
	elif event.keycode==KEY_R:set_weather((weather_index+1)%weather.size())
	elif event.keycode==KEY_P:set_quality(1-quality)

func _snow_line() -> float:
	# Circular linear blend is continuous across spring -> summer as well.
	var lines := [2440.0,2050.0,760.0,1650.0,2440.0]
	var s := clampf(season_value,0,3.999)
	return lerpf(lines[int(s)],lines[int(s)+1],fmod(s,1.0))

func set_season(value: float) -> void:
	season_value=value
	if is_instance_valid(ecology):ecology.winter=value>1.65 and value<2.45
	if streamer:streamer.snow_line=_snow_line();streamer.sync_materials()
	if is_instance_valid(terrain):terrain.material.set_shader_param("snow_line",_snow_line())

func set_weather(index: int) -> void:
	weather_index=index
	if not sun:return
	var p: Dictionary=weather[index]
	sun.rotation_degrees=Vector3(p.sun[0],p.sun[1],p.sun[2]);sun.light_color=Color(p.sun_color);sun.light_energy=p.energy
	environment.ambient_light_color=Color(p.ambient);environment.ambient_light_energy=p.ambient_energy
	environment.fog_light_color=Color(p.fog);environment.fog_density=float(p.density)*.55 if not is_silhouette else 0.0
	sky_material.set_shader_parameter("zenith",Color("#355879").lerp(Color("#152639"),float(p.storm)*.6))
	sky_material.set_shader_parameter("horizon",Color(p.fog))
	sky_material.set_shader_parameter("cloud_color",Color("#d3d6d4").lerp(Color("#52667a"),p.storm))
	sky_material.set_shader_parameter("cloud_coverage",p.cloud)
	sky_material.set_shader_parameter("storm_weight",p.storm)
	sky_material.set_shader_parameter("sunset_weight",p.sunset)
	sky_material.set_shader_parameter("dusk_weight",p.sunset)
	if index==4:
		sky_material.set_shader_parameter("zenith",Color("#070e19"));sky_material.set_shader_parameter("cloud_color",Color("#202c3f"));sky_material.set_shader_parameter("cloud_coverage",.2)
	cloud_material.set_shader_parameter("cloud_color",Color(p.fog).lightened(.08))
	cloud_material.set_shader_parameter("strength",.08+float(p.cloud)*.16)
	snow_particles.emitting=index==6 and walker.active
	if streamer:streamer.wetness=p.wet;streamer.sync_materials()
	if is_instance_valid(terrain):terrain.material.set_shader_param("wetness",p.wet)

func set_quality(value: int) -> void:
	quality=value
	streamer.profile=value;streamer.refresh()
	environment.ssao_enabled=value==1;environment.ssao_radius=1.8;environment.ssao_intensity=.65
	environment.volumetric_fog_enabled=value==1
	environment.volumetric_fog_density=.00008;environment.volumetric_fog_length=2000
	environment.glow_enabled=false;environment.ssr_enabled=false
	sun.directional_shadow_max_distance=300 if value==1 else 160
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if value==1 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	get_viewport().msaa_3d=Viewport.MSAA_4X if value==1 else Viewport.MSAA_2X
	if is_instance_valid(terrain):terrain.mesh_size=48 if value==1 else 32
	if is_instance_valid(ecology):ecology.profile=value

func set_clay(value: bool) -> void:
	is_clay=value;streamer.clay=value;streamer.sync_materials()
	if is_instance_valid(terrain):terrain.material.set_shader_param("clay",value)

func set_silhouette(value: bool) -> void:
	is_silhouette=value
	streamer.silhouette=value;streamer.sync_materials()
	city.visible=not value;clouds.visible=not value
	environment.fog_enabled=not value
	environment.background_mode=Environment.BG_COLOR if value else Environment.BG_SKY
	environment.background_color=Color.WHITE
	if is_instance_valid(terrain):terrain.material.set_shader_param("silhouette",value)

func _make_ui() -> void:
	ui=CanvasLayer.new();ui.name="MountainReview";add_child(ui)
	var panel := PanelContainer.new();panel.position=Vector2(28,24);ui.add_child(panel)
	var style := StyleBoxFlat.new();style.bg_color=Color(.035,.06,.08,.89);style.corner_radius_top_left=8;style.corner_radius_top_right=8;style.corner_radius_bottom_left=8;style.corner_radius_bottom_right=8
	style.content_margin_left=20;style.content_margin_right=20;style.content_margin_top=15;style.content_margin_bottom=15;panel.add_theme_stylebox_override("panel",style)
	var box := VBoxContainer.new();box.add_theme_constant_override("separation",10);panel.add_child(box)
	var title := Label.new();title.text="PROJECT Z  /  KALDRAN MOUNTAIN SPINE";title.add_theme_color_override("font_color",Color("#e4bd7e"));title.add_theme_font_size_override("font_size",22);box.add_child(title)
	var sub := Label.new();sub.text="Geographic & playable prototype   •   One shared mountain system";sub.add_theme_font_size_override("font_size",15);box.add_child(sub)
	var row := HBoxContainer.new();box.add_child(row)
	for i in 5:
		var b := Button.new();b.text="%d  %s" % [i+1,manifest.cameras[i].id];b.pressed.connect(select_camera.bind(i));row.add_child(b)
	var walk := Button.new();walk.text="6  Walk the mountain trail";walk.pressed.connect(enter_sector);box.add_child(walk)
	var options := HBoxContainer.new();box.add_child(options)
	var weather_choice := OptionButton.new()
	for p: Dictionary in weather:weather_choice.add_item(p.name)
	weather_choice.select(weather_index);weather_choice.item_selected.connect(set_weather);options.add_child(weather_choice)
	var profile_choice := OptionButton.new();profile_choice.add_item("Development profile");profile_choice.add_item("Cinematic profile");profile_choice.item_selected.connect(set_quality);options.add_child(profile_choice)
	var grey := CheckButton.new();grey.text="Untextured terrain";grey.toggled.connect(set_clay);options.add_child(grey)
	var season_label := Label.new();season_label.text="Season: summer → autumn → winter → spring → summer";box.add_child(season_label)
	var slider := HSlider.new();slider.min_value=0;slider.max_value=3.999;slider.step=.01;slider.value=1;slider.value_changed.connect(set_season);box.add_child(slider)
	status=Label.new();status.add_theme_font_size_override("font_size",15);box.add_child(status)
	var help := Label.new();help.text="WASD move  ·  Mouse look  ·  Shift faster  ·  Space jump\nF free flight (Q/E down/up)  ·  Esc release mouse  ·  H hide panel\nKaldran districts and alpine trail · supplied asset pass";help.add_theme_font_size_override("font_size",14);help.modulate=Color("#9eb5bf");box.add_child(help)
