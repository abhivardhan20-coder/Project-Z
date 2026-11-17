extends Node3D
## Shared mountain content in the city's existing coordinate system (0 = 320 m ASL).
const STREAMER := preload("res://scripts/streamer.gd")
const ECOLOGY := preload("res://scripts/vegetation.gd")
const DISTRICTS := preload("res://scripts/context_city.gd")
const DATUM := 320.0
var streamer: Node3D
var native: Terrain3D
var ecology: Node3D
var districts: Node3D
var camera: Camera3D
var actor: CharacterBody3D
var cfg: Dictionary
var heights: PackedFloat32Array

func configure(view: Camera3D, body: CharacterBody3D, city_layout: RefCounted) -> void:
	camera=view;actor=body
	cfg=JSON.parse_string(FileAccess.get_file_as_string("res://Data/Sector/sector.json"))
	heights=FileAccess.get_file_as_bytes("res://Data/capital_height.f32").to_float32_array()
	streamer=STREAMER.new();streamer.name="AtlasMountainSpine";streamer.position.y=-DATUM
	streamer.city_cutout=true;streamer.elevation_datum=DATUM;add_child(streamer)
	streamer.configure(camera,JSON.parse_string(FileAccess.get_file_as_string("res://Data/world.json")))
	districts=DISTRICTS.new();districts.position.y=-DATUM;districts.protect_playable_city=true;add_child(districts)
	_transition_collar(city_layout)
	print("UNIFIED_KALDRAN_READY | city, asset districts and mountain trail share one project")

func in_mountains(point: Vector3) -> bool:
	return point.z < -10000 and point.z > -14000 and point.x > -4000 and point.x < 1000

func trail_spawn() -> Vector3:
	return Vector3(cfg.spawn[0],cfg.spawn[1]-DATUM+1.0,cfg.spawn[2])

func ensure_sector() -> void:
	if is_instance_valid(native):return
	native=(load("res://scenes/editable_sector.tscn") as PackedScene).instantiate() as Terrain3D
	# Offset copies in memory, preserving the editable ASL source regions on disk.
	native.data_directory=""
	native.material=native.material.duplicate(true)
	# Use the same regional haze on both sides of the seam. Street fog on just
	# the native sector makes an opaque grey rectangle against the distant mesh.
	var regional_shader := Shader.new()
	regional_shader.code=native.material.shader_override.code.replace("skip_vertex_transform;","skip_vertex_transform,fog_disabled;").replace("// Public uniforms", "uniform vec3 city_haze : source_color = vec3(.65,.72,.78);\nuniform float city_density = .000013;\n// Public uniforms").replace("SPECULAR = .25;", "SPECULAR = .25;\n\tfloat haze = 1.0-exp(-length(v_camera_pos-v_vertex)*city_density);\n\tALBEDO *= 1.0-haze;\n\tEMISSION = city_haze*haze*.55;")
	native.material.shader_override=regional_shader
	add_child(native)
	# An empty Terrain3D starts with 256-sample regions. Region objects alone do
	# not resize its addressing grid; the preserved source regions use 512.
	native.data.change_region_size(512)
	native.set_camera(camera);native.collision_target=actor;native.clipmap_target=actor
	for filename in DirAccess.get_files_at("res://Terrain_Regions/CrownApproach"):
		if not filename.ends_with(".res"):continue
		var region := (load("res://Terrain_Regions/CrownApproach/"+filename) as Terrain3DRegion).duplicate(true) as Terrain3DRegion
		var original := region.height_map
		var values := original.get_data().to_float32_array()
		for i in values.size():values[i]-=DATUM
		region.height_map=Image.create_from_data(original.get_width(),original.get_height(),false,Image.FORMAT_RF,values.to_byte_array())
		region.modified=true
		native.data.add_region(region,false)
	native.data.update_maps()
	native.data.calc_height_range(true)
	native.material.set_shader_param("elevation_datum",DATUM)
	native.material.show_checkered=false
	streamer.sector_active=true;streamer.sync_materials();streamer.refresh(true)
	ecology=ECOLOGY.new();ecology.name="AlpineEcology";ecology.position.y=-DATUM;add_child(ecology)
	ecology.configure(camera,streamer.new_material())

func release_sector() -> void:
	if not is_instance_valid(native):return
	native.queue_free();native=null
	ecology.queue_free();ecology=null
	streamer.sector_active=false;streamer.sync_materials()

func update_weather(wetness: float, haze: Color, density: float, quality: int) -> void:
	if not streamer:return
	camera.far=80000
	streamer.profile=mini(quality,1)
	for material: ShaderMaterial in streamer.materials:
		material.set_shader_parameter("city_haze",haze)
		material.set_shader_parameter("city_density",density)
		material.set_shader_parameter("wetness",wetness)
	if is_instance_valid(native):
		native.material.set_shader_param("wetness",wetness)
		native.material.set_shader_param("city_haze",haze)
		native.material.set_shader_param("city_density",density)
		ecology.profile=mini(quality,1)

func regional_height(x: float,z: float) -> float:
	var u := clampf((x+24576)/32,0,1536)
	var v := clampf((z+40960)/32,0,1536)
	var col := mini(int(u),1535);var row := mini(int(v),1535)
	return lerpf(lerpf(heights[row*1537+col],heights[row*1537+col+1],u-col),lerpf(heights[(row+1)*1537+col],heights[(row+1)*1537+col+1],u-col),v-row)-DATUM

func _transition_collar(city_layout: RefCounted) -> void:
	var builder := SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := PackedVector3Array()
	const SECTIONS := 128
	const BANDS := 16
	for band in BANDS+1:
		var t := band/float(BANDS)
		for section in SECTIONS:
			var direction := Vector2.from_angle(section*TAU/SECTIONS)
			var edge := direction*500/maxf(absf(direction.x),absf(direction.y))
			var at := edge*(1.0+t*1.6)
			var h := lerpf(city_layout.height(edge.x,edge.y)-.04,regional_height(at.x,at.y)-.15,smoothstep(0.0,1.0,t))
			points.append(Vector3(at.x,h,at.y))
	for band in BANDS:
		for section in SECTIONS:
			var next := (section+1)%SECTIONS
			var a := band*SECTIONS+section;var b := band*SECTIONS+next
			for index: int in [a,a+SECTIONS,b,b,a+SECTIONS,b+SECTIONS]:builder.add_vertex(points[index])
	builder.index();builder.generate_normals()
	var material := StandardMaterial3D.new();material.albedo_color=Color("#3d4b38");material.roughness=.95
	var node := MeshInstance3D.new();node.name="CityFoothillTransition";node.mesh=builder.commit();node.material_override=material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
