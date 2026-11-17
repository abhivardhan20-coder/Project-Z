extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var camera := Camera3D.new();root.add_child(camera)
	camera.position=Vector3(-1650,725,-11319);camera.make_current()
	var actor := CharacterBody3D.new();root.add_child(actor);actor.position=camera.position
	var native := (load("res://scenes/editable_sector.tscn") as PackedScene).instantiate() as Terrain3D
	native.data_directory="";native.material=native.material.duplicate(true);root.add_child(native)
	native.data.change_region_size(512)
	native.set_camera(camera);native.collision_target=actor;native.clipmap_target=actor
	print("BEFORE region_size=",native.region_size," vertex=",native.vertex_spacing," regions=",native.data.get_region_count()," collision=",native.collision_mode)
	for filename in DirAccess.get_files_at("res://Terrain_Regions/CrownApproach"):
		if not filename.ends_with(".res"):continue
		var region := (load("res://Terrain_Regions/CrownApproach/"+filename) as Terrain3DRegion).duplicate(true) as Terrain3DRegion
		var original := region.height_map
		var values := original.get_data().to_float32_array()
		print(filename," at=",region.location," size=",region.region_size," image=",original.get_size()," before=",values[0])
		for i in values.size():values[i]-=320
		region.height_map=Image.create_from_data(original.get_width(),original.get_height(),false,Image.FORMAT_RF,values.to_byte_array())
		region.modified=true
		print(" add=",native.data.add_region(region,false)," after=",region.height_map.get_pixel(0,0).r)
	native.data.update_maps();native.data.calc_height_range(true)
	for i in 8:await physics_frame
	print("AFTER region_size=",native.region_size," regions=",native.data.get_region_count()," locations=",native.data.get_region_locations()," height=",native.data.get_height(actor.position)," range=",native.data.get_height_range())
	var ray := PhysicsRayQueryParameters3D.create(actor.position+Vector3.UP*1000,actor.position-Vector3.UP*1000,1)
	print("RAY ",root.world_3d.direct_space_state.intersect_ray(ray))
	quit()
