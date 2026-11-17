extends SceneTree

const ROOT := "res://"
var manifest: Dictionary
var heights: PackedFloat32Array
var side := 1537

func _initialize() -> void:
	call_deferred("_build")

func _build() -> void:
	manifest = JSON.parse_string(FileAccess.get_file_as_string("res://Data/world.json"))
	heights = FileAccess.get_file_as_bytes("res://Data/capital_height.f32").to_float32_array()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Terrain_Regions/Far"))
	for tile: Dictionary in manifest.tiles:
		for lod in 3:
			var mesh := make_tile(tile, lod)
			var code := ResourceSaver.save(mesh, "res://Terrain_Regions/Far/%s_%d.res" % [tile.id, lod])
			if code != OK:
				push_error("Failed to save distant terrain mesh"); quit(1); return
	print("Baked %d native distant LOD meshes" % (manifest.tiles.size() * 3))
	await _build_near()
	print("NATIVE_BUILD_OK")
	quit(0)

func height_at(x: float, z: float) -> float:
	var u := clampf((x + 24576.0) / 32.0, 0, side - 1)
	var v := clampf((z + 40960.0) / 32.0, 0, side - 1)
	var col := mini(int(u), side-2)
	var row := mini(int(v), side-2)
	return lerpf(lerpf(heights[row*side+col], heights[row*side+col+1],u-col),
		lerpf(heights[(row+1)*side+col],heights[(row+1)*side+col+1],u-col),v-row)

func make_tile(tile: Dictionary, lod: int) -> ArrayMesh:
	var spacing := 64.0 * pow(2.0, lod)
	var cells := roundi(4096.0 / spacing)
	var stride := cells + 1
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var parents := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in stride:
		for col in stride:
			var x := float(tile.west) + col * spacing
			var z := float(tile.north) + row * spacing
			var h := height_at(x,z)
			var normal := Vector3(height_at(x-32,z)-height_at(x+32,z),64,height_at(x,z-32)-height_at(x,z+32)).normalized()
			vertices.append(Vector3(col*spacing,h,row*spacing))
			normals.append(normal)
			var coarse := spacing * 2.0
			var cx := floorf(x/coarse)*coarse
			var cz := floorf(z/coarse)*coarse
			var u := (x-cx)/coarse
			var v := (z-cz)/coarse
			var a := height_at(cx,cz)
			var b := height_at(cx+coarse,cz)
			var c := height_at(cx,cz+coarse)
			var d := height_at(cx+coarse,cz+coarse)
			var parent_height := a+(b-a)*u+(c-a)*v if u+v<=1.0 else d+(c-d)*(1.0-u)+(b-d)*(1.0-v)
			parents.append(Vector2(parent_height,0))
			if row<cells and col<cells:
				var i := row*stride+col
				indices.append_array(PackedInt32Array([i,i+1,i+stride,i+1,i+stride+1,i+stride]))
	# Downward seam skirts hide the sub-pixel T-junction at adjacent LOD boundaries.
	# Samples and normals agree exactly at shared vertices; no independent tile noise.
	var edges: Array[PackedInt32Array] = []
	for edge in 4:
		var line := PackedInt32Array()
		for j in stride:
			line.append([j,j*stride+cells,cells*stride+cells-j,(cells-j)*stride][edge])
		edges.append(line)
	for line in edges:
		for j in cells:
			var a := line[j]
			var b := line[j+1]
			var k := vertices.size()
			vertices.append(vertices[a]-Vector3.UP*180.0)
			vertices.append(vertices[b]-Vector3.UP*180.0)
			normals.append(normals[a]);normals.append(normals[b])
			parents.append(parents[a]-Vector2(180,0));parents.append(parents[b]-Vector2(180,0))
			indices.append_array(PackedInt32Array([a,k,b,b,k,k+1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV2]=parents
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func _build_near() -> void:
	var cfg: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://Data/Sector/sector.json"))
	var terrain := Terrain3D.new()
	terrain.name="CrownApproachEditable"
	terrain.region_size=512
	terrain.vertex_spacing=2.0
	terrain.mesh_size=32
	terrain.mesh_lods=6
	terrain.collision_mode=1
	terrain.collision_radius=96
	terrain.collision_shape_size=32
	terrain.material=Terrain3DMaterial.new()
	terrain.material.world_background=0
	terrain.material.shader_override=load("res://Shaders/native_alpine.gdshader")
	terrain.material.shader_override_enabled=true
	terrain.free_editor_textures=false
	var bake_camera := Camera3D.new()
	root.add_child(bake_camera)
	bake_camera.position=Vector3(cfg.spawn[0],cfg.spawn[1]+2,cfg.spawn[2])
	bake_camera.make_current()
	root.add_child(terrain)
	terrain.set_camera(bake_camera)
	await process_frame
	terrain.data.change_region_size(512)
	terrain.region_size=512
	terrain.free_editor_textures=false
	var size := int(cfg.samples)
	var h := Image.create_from_data(size,size,false,Image.FORMAT_RF,FileAccess.get_file_as_bytes("res://Data/Sector/height.f32"))
	# Native regions are power-of-two with implicit shared adjacent samples.
	h=h.get_region(Rect2i(0,0,size-1,size-1))
	var controls := PackedInt32Array()
	controls.resize((size-1)*(size-1));controls.fill(2)
	var control := Image.create_from_data(size-1,size-1,false,Image.FORMAT_RF,controls.to_byte_array())
	var images: Array[Image]=[h,control,null]
	terrain.data.import_images(images,Vector3(cfg.west,0,cfg.north),0,1)
	if terrain.data.get_region_count()!=9:
		push_error("Native terrain import failed: expected nine populated regions")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Terrain_Regions/CrownApproach"))
	terrain.data.save_directory("res://Terrain_Regions/CrownApproach")
	# Assign the saved directory in the serialized scene. Re-loading live collision
	# during an offline bake triggers a Terrain3D 1.1 headless lifecycle fault.
	var assets := Terrain3DAssets.new()
	var textures: Array[Terrain3DTextureAsset]=[]
	for key: String in ["granite","dark_bedrock","weathered_rock","sedimentary","scree","moss","soil","grass","subalpine","snow","packed_snow","ice","mud","river_gravel","basalt_ash"]:
		var asset := Terrain3DTextureAsset.new()
		asset.name=key;asset.id=textures.size()
		asset.albedo_texture=load("res://materials/Textures/%s_albedo.png" % key)
		asset.normal_texture=load("res://materials/Textures/%s_normal_roughness.png" % key)
		asset.uv_scale=.25
		textures.append(asset)
	assets.texture_list=textures
	terrain.assets=assets
	ResourceSaver.save(assets,"res://materials/terrain_assets.tres")
	terrain.material.show_checkered=false
	terrain.material.show_grey=false
	set_material_textures(terrain.material)
	ResourceSaver.save(terrain.material,"res://materials/native_alpine.tres")
	var scene := PackedScene.new()
	scene.pack(terrain)
	ResourceSaver.save(scene,"res://scenes/editable_sector.tscn")
	var saved := FileAccess.get_file_as_string("res://scenes/editable_sector.tscn")
	FileAccess.open("res://scenes/editable_sector.tscn",FileAccess.WRITE).store_string(saved+"\ndata_directory = \"res://Terrain_Regions/CrownApproach\"\n")
	print("Saved %d native Float32 terrain regions; %.2f m spawn height" % [terrain.data.get_region_count(),terrain.data.get_height(Vector3(cfg.spawn[0],0,cfg.spawn[2]))])
	terrain.queue_free()
	await process_frame

static func set_material_textures(material: Terrain3DMaterial) -> void:
	for item in [["rock_albedo","granite_albedo"],["rock_normal","granite_normal_roughness"],["grass_albedo","grass_albedo"]]:
		material.set_shader_param(item[0],load("res://materials/Textures/%s.png" % item[1]))
	material.set_shader_param("ground_blend",load("res://Data/Sector/blend.png"))
	material.set_shader_param("terrain_aux",load("res://Data/terrain_aux.png"))
