extends SceneTree
var seen: Dictionary={}
var missing: Array[String]=[]
var links := 0

func _initialize() -> void:
	for folder in ["assets/Baked","scenes/Districts","Terrain_Regions","materials/Textures","Meshes","Lighting"]:
		walk("res://"+folder)
	for path in ["res://scenes/mountain_prototype.tscn","res://scenes/editable_sector.tscn","res://scenes/world/kaldran_city.tscn"]:audit(path)
	var report := {"resources":seen.size(),"dependency_links":links,"missing":missing}
	FileAccess.open("res://mountain_source/09_Documentation/Merged_Dependencies.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("MERGED_DEPENDENCIES ",JSON.stringify(report))
	quit(0 if missing.is_empty() else 1)

func walk(folder: String) -> void:
	for name in DirAccess.get_files_at(folder):
		if name.get_extension() in ["res","tres","tscn"]:audit(folder.path_join(name))
	for name in DirAccess.get_directories_at(folder):walk(folder.path_join(name))

func audit(path: String) -> void:
	if seen.has(path):return
	seen[path]=true
	for dependency in ResourceLoader.get_dependencies(path):
		var linked: String=dependency.get_slice("::",dependency.get_slice_count("::")-1)
		links+=1
		if not linked.begins_with("res://") or linked.contains("../") or linked.contains("addons/kaldran_mountains") or not ResourceLoader.exists(linked):
			missing.append(path+" -> "+linked)
		elif linked.get_extension() in ["res","tres","tscn"]:audit(linked)
