extends Node3D

const CITY := preload("res://scenes/world/kaldran_city.tscn")
const MATERIALS := preload("res://scripts/graphics/materials.gd")
const WATER := preload("res://materials/ultra/water.gdshader")
const GEO := preload("res://scripts/city/geometry.gd")
const SKYLINE := preload("res://scripts/city/skyline.gd")
const PLAN := preload("res://scripts/city/layout.gd")
const PRESETS := ["Asphalt", "Exposed concrete", "Brick", "Interior plaster", "Interior tile", "Interior wood",
	"Painted steel", "Automotive paint"]

var city: Node3D
var camera := Camera3D.new()
var gallery := Node3D.new()
var stats := Label.new()
var inspect_streets := false
var stream_timer := 0.0
var weather_options: OptionButton
var clock_slider: HSlider


func _ready() -> void:
	city = CITY.instantiate()
	add_child(city)
	city.ui.hide()
	city.player.hide()
	city.sky.frozen_time = true
	city.state.clock = 0.42
	city.state.weather = 0
	city.state.quality = 1
	city._apply_settings()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	add_child(gallery)
	gallery.position = Vector3(-310, 17.0, -256.5)
	add_child(camera)
	camera.fov = 60.0
	camera.far = SKYLINE.CAMERA_FAR
	camera.make_current()
	_build_samples()
	_set_view(0)
	_controls()
	print("Kaldran Material Lab ready")


func _process(delta: float) -> void:
	if not city or not city.sky:
		return
	city.sky.update(delta)
	if inspect_streets:
		stream_timer -= delta
		if stream_timer <= 0.0:
			stream_timer = 0.08
			city.stream.refresh(camera.global_position)
	stats.text = "%s  ·  %d FPS  ·  Wetness %d%%" % [RenderingServer.get_current_rendering_method(),
		Engine.get_frames_per_second(), roundi(city.sky.wetness * 100.0)]


func _build_samples() -> void:
	for i in PRESETS.size():
		var name: String = PRESETS[i]
		var row := floorf(i / 4.0)
		var at := Vector3((i % 4 - 1.5) * 2.0, 0.64, row * -2.6)
		GEO.box(gallery, at - Vector3.UP * 0.29, Vector3(1.69, 0.40, 1.60), MATERIALS.surface(name))
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.48
		sphere.height = 0.96
		mesh.mesh = sphere
		mesh.material_override = MATERIALS.surface(name)
		mesh.position = at + Vector3.UP * 0.41
		gallery.add_child(mesh)
		var label := GEO.sign(gallery, name, at + Vector3(0, -0.31, 0.83), 0.0, 0.004)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var glass := GEO.box(gallery, Vector3(5.1, 0.96, -0.40), Vector3(1.13, 1.28, 0.12), MATERIALS.glass())
	glass.rotation.y = 0.39
	GEO.sign(gallery, "Exterior glass", Vector3(5.1, 0.28, -0.30), 0.0, 0.004)
	var wavemat := ShaderMaterial.new()
	wavemat.shader = WATER
	GEO.box(gallery, Vector3(-5.25, 0.34, -0.38), Vector3(1.55, 0.08, 1.55), wavemat)
	GEO.sign(gallery, "Standing water", Vector3(-5.25, 0.31, 0.48), 0.0, 0.004)


func _controls() -> void:
	var overlay := CanvasLayer.new()
	add_child(overlay)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 22)
	overlay.add_child(panel)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 8)
	panel.add_child(menu)
	var title := Label.new()
	title.text = "KALDRAN CITY  /  MATERIAL LAB"
	title.add_theme_font_size_override("font_size", 22)
	menu.add_child(title)
	_options(menu, ["Material gallery", "P06 Hillview", "Civic lockdown", "Central Station",
		"Airport evacuation highway", "Kaldran basin"], 0, _set_view)
	weather_options = _options(menu, ["Clear", "Overcast", "Rain"], 0, _set_weather)
	_options(menu, ["Low", "Medium", "High"], 1, _set_quality)
	var step := HSlider.new()
	clock_slider = step
	step.min_value = 0
	step.max_value = 1
	step.step = 0.005
	step.value = city.state.clock
	step.value_changed.connect(func(value: float): city.state.clock = value)
	menu.add_child(step)
	var evening := Button.new()
	evening.text = "Golden hour"
	evening.pressed.connect(func(): step.value = 0.695)
	menu.add_child(evening)
	menu.add_child(stats)
	var to_game := Button.new()
	to_game.text = "Return to main menu"
	to_game.pressed.connect(func(): get_tree().change_scene_to_packed(CITY))
	menu.add_child(to_game)


func _options(menu: VBoxContainer, names: Array, choice: int, action: Callable) -> OptionButton:
	var input := OptionButton.new()
	for name: String in names:
		input.add_item(name)
	input.select(choice)
	input.item_selected.connect(action)
	menu.add_child(input)
	return input


func _set_view(index: int) -> void:
	inspect_streets = index != 0
	gallery.visible = not inspect_streets
	match index:
		0:
			camera.global_position = gallery.global_position + Vector3(0, 4.1, 8.1)
			camera.look_at(gallery.global_position + Vector3(0, 0.50, -1.3))
		1:
			camera.global_position = Vector3(-272.4, 18.15, -243.20)
			camera.look_at(Vector3(-306, 18.53, -250.1))
			_shot_weather(0, 0.695)
		2:
			camera.global_position = Vector3(189, 8.86, -110.7)
			camera.look_at(Vector3(189, 14.7, -151))
			_shot_weather(2, 0.47)
		3:
			camera.global_position = Vector3(291, 20.0, -291)
			camera.look_at(Vector3(325, 19.5, -337))
			_shot_weather(1, 0.66)
			city.sky.wetness = 0.75
			city.sky.puddles = 0.65
		4:
			camera.global_position = Vector3(419, 3.65, 108.5)
			camera.look_at(Vector3(438, 7.3, 63))
			_shot_weather(2, 0.712)
		5:
			var ridge := PLAN.OVERLOOK
			camera.global_position = Vector3(ridge.x, city.city_layout.height(ridge.x, ridge.y) + 2.3, ridge.y)
			camera.look_at(Vector3(208, 14, -111))
			_shot_weather(1, 0.35)
	if inspect_streets:
		city.stream.refresh(camera.global_position, true)
	city.sky.rain_follow = camera


func _shot_weather(weather: int, clock: float) -> void:
	city.state.clock = clock
	if clock_slider:
		clock_slider.set_value_no_signal(clock)
	if weather_options:
		weather_options.select(weather)
	_set_weather(weather)


func _set_weather(index: int) -> void:
	city.state.weather = index
	city.sky.reset_surfaces(index)
	city.sky.update(0.0)


func _set_quality(index: int) -> void:
	city.state.quality = index
	city._apply_settings()
