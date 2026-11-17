extends SceneTree

const LAB := preload("res://scenes/graphics/shader_lab.tscn")
const PLAN := preload("res://scripts/city/layout.gd")
const MATERIALS := preload("res://scripts/graphics/materials.gd")

var failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var lab := LAB.instantiate()
	root.add_child(lab)
	if lab.city.player == null:
		quit(1)
		return
	var city: Node3D = lab.city
	var weather: Node3D = city.sky
	weather.rain_follow = city.player
	var clock: float = city.state.clock
	lab._set_weather(2)
	await physics_frame
	weather.update(5.0)
	_check(weather.wetness > 0.9 and weather.puddles > 0.7, "Rain wets exposed surfaces and fills puddles")
	_check(weather.sheltered and not weather.rain.emitting, "Hillview lobby blocks local rain")
	_check(is_equal_approx(city.state.clock, clock), "Lab clock stays where selected")
	var outside := PLAN.PILOT + Vector3(5.0, 0.1, -2.5)
	city.player.global_position = outside
	await physics_frame
	weather.update(1.0)
	_check(not weather.sheltered and weather.rain.emitting, "Exposed pavement receives rain")
	var floor := MATERIALS.indoor_floor("wood_floor", Color.WHITE, 2.0)
	_check(floor.get_shader_parameter("wet_exposure") == 0.0, "Interior flooring stays dry")
	city.state.weather = 0
	weather.update(20.0)
	_check(weather.wetness < 0.64 and weather.puddles > weather.wetness, "Open surfaces dry faster than puddles")
	lab._set_weather(0)
	lab._set_quality(0)
	weather.update(0.0)
	_check(not weather.environment.ssr_enabled and not weather.environment.volumetric_fog_enabled, "Low avoids costly effects")
	lab._set_quality(2)
	weather.update(0.0)
	_check(weather.environment.ssr_enabled == weather.forward_plus and weather.rain.amount == 390, "High makes renderer-aware workload changes")
	if DisplayServer.get_name() != "headless":
		var directory := ProjectSettings.globalize_path("res://.godot/ultra/" + RenderingServer.get_current_rendering_method())
		DirAccess.make_dir_recursive_absolute(directory)
		lab._set_quality(1)
		for shot in [[0, 0, "material-lab"], [1, 0, "hillview-clear"], [1, 2, "hillview-rain"]]:
			lab._set_view(shot[0])
			lab._set_weather(shot[1])
			await _capture(directory.path_join(shot[2] + ".png"))
		for profile in [0, 1, 2]:
			lab._set_quality(profile)
			await _sample_profile(profile)
	print("Ultra graphics failures: %d" % failed)
	quit(0 if failed == 0 else 1)


func _capture(path: String) -> void:
	for frame in 28:
		await process_frame
	RenderingServer.force_draw(false)
	_check(root.get_texture().get_image().save_png(path) == OK, "Saved in-engine capture " + path.get_file())


func _sample_profile(profile: int) -> void:
	for frame in 16:
		await process_frame
	var measurements: Array[float] = []
	var previous := Time.get_ticks_usec()
	for frame in 45:
		await process_frame
		var now := Time.get_ticks_usec()
		measurements.append((now - previous) / 1000.0)
		previous = now
	measurements.sort()
	print("PROFILE %d  median %.2f ms  p95 %.2f ms  GPU memory estimate %.0f MiB" % [
		profile, measurements[22], measurements[42],
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])


func _check(ok: bool, description: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failed += 1
