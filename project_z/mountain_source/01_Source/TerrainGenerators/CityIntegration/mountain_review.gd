extends "res://scripts/city/city.gd"

const MOUNTAIN_STREAM := preload("res://addons/kaldran_mountains/Scripts/streamer.gd")
var mountain_stream: Node3D

func _ready() -> void:
	super._ready()
	var old_ring := layout.get_node_or_null("AlpineBasin")
	if old_ring:old_ring.queue_free()
	# Existing city height zero is mapped to the capital's 320 m ASL datum.
	mountain_stream=MOUNTAIN_STREAM.new()
	mountain_stream.name="AtlasMountainSpine"
	mountain_stream.position.y=-320
	add_child(mountain_stream)
	player.camera.far=80000
	var world_data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://addons/kaldran_mountains/Data/world.json"))
	mountain_stream.configure(player.camera,world_data)
	_transition_collar()
	print("CITY_MOUNTAINS_READY | atlas-aligned northern range | 320 m capital datum")

func _process(delta: float) -> void:
	super._process(delta)
	if not mountain_stream or not sky.environment:return
	player.camera.far=80000
	for material: ShaderMaterial in mountain_stream.materials:
		material.set_shader_parameter("city_haze",sky.environment.fog_light_color)
		material.set_shader_parameter("city_density",.000013+float(state.weather)*.000005)
		material.set_shader_parameter("wetness",sky.wetness)

func _transition_collar() -> void:
	var builder := SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := PackedVector3Array()
	const SECTIONS := 128
	const BANDS := 12
	for band in BANDS+1:
		var t := band/float(BANDS)
		for section in SECTIONS:
			var direction := Vector2.from_angle(section*TAU/SECTIONS)
			var edge := direction*500/maxf(absf(direction.x),absf(direction.y))
			var at := edge*(1.0+t*1.6)
			var h := lerpf(city_layout.height(edge.x,edge.y)-.04,-6.0,smoothstep(0.0,1.0,t))
			points.append(Vector3(at.x,h,at.y))
	for band in BANDS:
		for section in SECTIONS:
			var next := (section+1)%SECTIONS
			var a := band*SECTIONS+section;var b := band*SECTIONS+next
			for index: int in [a,a+SECTIONS,b,b,a+SECTIONS,b+SECTIONS]:builder.add_vertex(points[index])
	builder.index();builder.generate_normals()
	var m := StandardMaterial3D.new();m.albedo_color=Color("#3d4b38");m.roughness=.95
	var node := MeshInstance3D.new();node.name="CityFoothillTransition";node.mesh=builder.commit();node.material_override=m
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;layout.add_child(node)
