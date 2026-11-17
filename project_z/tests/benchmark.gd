extends SceneTree

const SCENE := preload("res://scenes/world/kaldran_city.tscn")
const PLAN := preload("res://scripts/city/layout.gd")

var city: Node3D
var rows: Array[Dictionary] = []
var root_path: String


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root_path = ProjectSettings.globalize_path("res://.godot/benchmark")
	DirAccess.make_dir_recursive_absolute(root_path)
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	city = SCENE.instantiate()
	root.add_child(city)
	if city.player == null:
		quit(1)
		return
	city.state.base_path = root_path
	city.state.sound = false
	city._new_game()
	var p06_only := OS.get_cmdline_user_args().has("--p06-only")
	for zone: Array in [
		["Hillview P06", Vector2(-309, -251), -1.45, 0.38, 0],
		["Hillview sedan and crossing", Vector2(-346, -253), -1.57, 0.39, 0],
		["Civic arterial", Vector2(128, -139), -1.45, 0.44, 0],
		["Police annex interior", Vector2(48, -135.2), 3.14, 0.42, 0],
		["Utility edge", Vector2(448, 435), 0.50, 0.37, 0],
		["Hillview at night", Vector2(-306, -249), -1.43, 0.84, 0],
		["Market rain", Vector2(-256, 140), -1.47, 0.43, 2],
		["Infected encounter", Vector2(-285, -252), 1.42, 0.54, 0],
		["Chunk crossing", Vector2(-302.7, -249), -1.57, 0.39, 0],
	]:
		if p06_only and not String(zone[0]).begins_with("Hillview"):
			continue
		await _sample(zone)
	var file := FileAccess.open(root_path.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "\t"))
	file.close()
	quit()


func _sample(zone: Array) -> void:
	var xz: Vector2 = zone[1]
	var y: float = city.city_layout.height(xz.x, xz.y)
	city.player.global_position = Vector3(xz.x, y + (0.36 if zone[0] == "Police annex interior" else 0.12), xz.y)
	city.player.velocity = Vector3.ZERO
	city.player.rotation.y = zone[2]
	city.player.eye.rotation.x = -0.08
	city.state.clock = zone[3]
	city.state.weather = zone[4]
	city.sky.update(0.0)
	city.stream.refresh(city.player.global_position, true)
	if zone[0] == "Infected encounter":
		city.state.stage = 1
		city._spawn_enemy("benchmark", Vector2(-292, -252), false)
		if city.actors.has("benchmark"):
			city.actors.benchmark.hear(city.player.global_position, 24.0)
	for frame in 40:
		await process_frame
	if zone[0] in ["Hillview P06", "Hillview sedan and crossing", "Civic arterial", "Market rain"]:
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(root_path.path_join(String(zone[0]).replace(" ", "_") + ".png"))
	if zone[0] == "Chunk crossing":
		Input.action_press("city_forward")
	var samples: Array[float] = []
	var recent_cpu_ms: Array[float] = []
	var draw_calls := 0.0
	var primitives := 0.0
	var max_chunk := 0.0
	var active_agents := 0
	var bodies := 0.0
	var started := Time.get_ticks_usec()
	for frame in 115:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now - started) / 1000.0)
		started = now
		recent_cpu_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		bodies += Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
		max_chunk = maxf(max_chunk, city.stream.last_build_usec / 1000.0)
		active_agents = maxi(active_agents, city.actors.size())
	Input.action_release("city_forward")
	samples.sort()
	recent_cpu_ms.sort()
	var row := {
		"scene": zone[0], "samples": samples.size(), "fps": 1000.0 / (float(samples.reduce(func(a, b): return a + b, 0.0)) / samples.size()),
		"p95_ms": samples[ceili(samples.size() * 0.95) - 1], "p99_ms": samples[ceili(samples.size() * 0.99) - 1],
		"median_process_ms": recent_cpu_ms[recent_cpu_ms.size() / 2], "draws": draw_calls / samples.size(), "primitives": primitives / samples.size(),
		"physics": bodies / samples.size(), "agents": active_agents, "max_recent_chunk_ms": max_chunk,
		"godot_static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"reported_render_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
	}
	rows.append(row)
	print(JSON.stringify(row))
