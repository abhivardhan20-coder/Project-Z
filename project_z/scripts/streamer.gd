extends Node3D

const SHADER := preload("res://Shaders/distant.gdshader")
var active_shader: Shader = SHADER
var camera: Camera3D
var tiles: Array = []
var live: Dictionary = {}
var pending: Dictionary = {}
var materials: Array[ShaderMaterial] = []
var profile := 0
var timer := 0.0
var sector_active := false
var city_cutout := false
var elevation_datum := 0.0
var snow_line := 2050.0
var wetness := 0.0
var clay := false
var silhouette := false
var loaded_count := 0
var unload_count := 0
var transitions := 0
var rock: Texture2D
var rock_normal: Texture2D
var grass: Texture2D
var blend: Texture2D
var aux: Texture2D

func configure(view: Camera3D, manifest: Dictionary) -> void:
	camera=view
	if city_cutout:
		# Street fog is too dense for the 49 km skyline; use distance haze here.
		active_shader=Shader.new()
		active_shader.code=SHADER.code.replace("render_mode cull_back, diffuse_burley;","render_mode cull_back, diffuse_burley, fog_disabled;")
	tiles=manifest.tiles
	rock=load("res://materials/Textures/granite_albedo.png")
	rock_normal=load("res://materials/Textures/granite_normal_roughness.png")
	grass=load("res://materials/Textures/grass_albedo.png")
	blend=load("res://Data/Sector/blend.png")
	aux=load("res://Data/terrain_aux.png")
	refresh(true)

func new_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader=active_shader
	m.set_shader_parameter("rock_albedo",rock)
	m.set_shader_parameter("rock_normal",rock_normal)
	m.set_shader_parameter("grass_albedo",grass)
	m.set_shader_parameter("ground_blend",blend)
	m.set_shader_parameter("terrain_aux",aux)
	apply(m)
	materials.append(m)
	return m

func apply(m: ShaderMaterial) -> void:
	m.set_shader_parameter("snow_line",snow_line)
	m.set_shader_parameter("wetness",wetness)
	m.set_shader_parameter("clay",clay)
	m.set_shader_parameter("silhouette",silhouette)
	m.set_shader_parameter("sector_active",sector_active)
	m.set_shader_parameter("city_cutout",city_cutout)
	m.set_shader_parameter("elevation_datum",elevation_datum)

func sync_materials() -> void:
	for material in materials:apply(material)

func _process(delta: float) -> void:
	if not camera:return
	timer-=delta
	if timer<=0:
		timer=.45
		refresh()
	var completed := 0
	for id: String in pending.keys():
		var job: Dictionary=pending[id]
		if ResourceLoader.load_threaded_get_status(job.path)==ResourceLoader.THREAD_LOAD_LOADED:
			var resource := ResourceLoader.load_threaded_get(job.path) as ArrayMesh
			pending.erase(id)
			if live.has(id):_swap(id,resource,job.lod)
			completed+=1
			if completed>=2:break
		elif ResourceLoader.load_threaded_get_status(job.path)==ResourceLoader.THREAD_LOAD_FAILED:
			push_error("Terrain streaming failed: "+str(job.path));pending.erase(id)
	for id: String in live:
		var item: Dictionary=live[id]
		if item.morphing:
			item.elapsed+=delta
			var t := minf(item.elapsed/.45,1.0)
			item.material.set_shader_parameter("morph",t if item.to_coarser else 1.0-t)
			if t>=1.0:
				if item.to_coarser:
					item.node.mesh=item.next_mesh
					item.lod=item.next_lod
				item.material.set_shader_parameter("morph",0.0)
				item.morphing=false
				item.next_mesh=null

func refresh(immediate := false) -> void:
	var eye := camera.global_position
	var forward := -camera.global_basis.z
	var px := get_viewport().get_visible_rect().size.y / (2.0*tan(deg_to_rad(camera.fov*.5)))
	var wanted: Dictionary={}
	for tile: Dictionary in tiles:
		var center := to_global(Vector3(float(tile.west)+2048,(float(tile.min)+float(tile.max))*.5,float(tile.north)+2048))
		var distance := maxf(1,eye.distance_to(center)-3500)
		if distance>59000:continue
		if not immediate and distance>9000 and forward.dot((center-eye).normalized()) < -.18:continue
		var lod := 2
		var tolerance := 4.0 if profile==0 else 1.6
		while lod>0 and float(tile.errors_m[lod])*px/distance>tolerance:lod-=1
		# Fix the shared boundary to the 64 m source triangle grid.
		if sector_active and tile.west<0 and tile.west+4096>-3072 and tile.north<-10240 and tile.north+4096>-13312:lod=0
		wanted[tile.id]=true
		if live.has(tile.id):
			var item: Dictionary=live[tile.id]
			if item.lod==lod or item.morphing or pending.has(tile.id):continue
			# Only transition one level at a time so geomorph targets always agree.
			lod=clampi(lod,item.lod-1,item.lod+1)
			if lod>item.lod and float(tile.errors_m[lod])*px/distance>tolerance*.78:continue
		else:
			var node := MeshInstance3D.new()
			node.name="Region_"+str(tile.id)
			node.position=Vector3(tile.west,0,tile.north)
			node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var material := new_material()
			node.material_override=material
			add_child(node)
			live[tile.id]={"node":node,"material":material,"lod":-1,"morphing":false,"next_mesh":null,"elapsed":0.0,"to_coarser":false,"next_lod":lod}
		var path := "res://Terrain_Regions/Far/%s_%d.res" % [tile.id,lod]
		if immediate:
			_swap(tile.id,load(path) as ArrayMesh,lod)
		else:
			ResourceLoader.load_threaded_request(path,"ArrayMesh",true,ResourceLoader.CACHE_MODE_IGNORE)
			pending[tile.id]={"path":path,"lod":lod}
	for id: String in live.keys():
		if wanted.has(id) or pending.has(id):continue
		materials.erase(live[id].material)
		live[id].node.queue_free();live.erase(id);unload_count+=1

func _swap(id: String,mesh: ArrayMesh,lod: int) -> void:
	var item: Dictionary=live[id]
	if item.lod<0:
		item.node.mesh=mesh;item.lod=lod;loaded_count+=1;return
	if item.lod==lod:return
	item.morphing=true;item.elapsed=0.0;item.to_coarser=lod>int(item.lod)
	item.next_mesh=mesh;item.next_lod=lod
	if not item.to_coarser:
		item.node.mesh=mesh;item.lod=lod
		item.material.set_shader_parameter("morph",1.0)
	transitions+=1

func settled() -> bool:
	if not pending.is_empty():return false
	for item: Dictionary in live.values():
		if item.morphing:return false
	return true

func _exit_tree() -> void:
	for job: Dictionary in pending.values():
		if ResourceLoader.load_threaded_get_status(job.path)!=ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_get(job.path)
	pending.clear()
