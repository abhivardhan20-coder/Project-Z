extends SceneTree

const CITY := preload("res://scenes/world/kaldran_city.tscn")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var city := CITY.instantiate()
	root.add_child(city)
	if city.player == null:
		quit(1)
		return
	var test_script: Script = get_script()
	var save_path := test_script.resource_path.get_base_dir().path_join("../.godot/startup-test").simplify_path()
	city.state.base_path = ProjectSettings.globalize_path(save_path)
	DirAccess.make_dir_recursive_absolute(city.state.base_path)
	await _layout()

	var start: Button = _button(city.ui.sheet, "New Game")
	var start_ready := _usable(start)
	_check(start_ready, "Normal launch displays a clickable New Game button")
	if not start_ready:
		quit(1)
		return
	_click(start)
	await _layout()
	_check(city.player.playable and not city.ui.modal.visible, "Clicking New Game enables player input")
	for frame in 10:
		await physics_frame
	var origin: Vector3 = city.player.position
	_key(KEY_W, true)
	for frame in 28:
		await physics_frame
	_key(KEY_W, false)
	var displacement: Vector3 = city.player.position - origin
	_check(Vector2(displacement.x, displacement.z).length() > 0.75, "Physical W input moves the survivor from the default spawn")

	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await _layout()
	var resume: Button = _button(city.ui.sheet, "Resume")
	var resume_ready := _usable(resume)
	_check(resume_ready and not city.player.playable, "Escape opens a usable pause menu")
	if resume_ready:
		_click(resume)
		await _layout()
	_check(city.player.playable and not city.ui.modal.visible, "Clicking Resume restores movement")
	print("Startup failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _layout() -> void:
	for frame in 4:
		await process_frame


func _button(parent: Control, title: String) -> Button:
	for node in parent.find_children("*", "Button", true, false):
		if node.text == title:
			return node
	return null


func _usable(button: Button) -> bool:
	if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled:
		return false
	var rect := button.get_global_rect()
	if not root.get_visible_rect().encloses(rect) or rect.size.y < 25:
		return false
	var parent := button.get_parent() as Control
	while parent:
		if parent.clip_contents and not parent.get_global_rect().encloses(rect):
			return false
		parent = parent.get_parent() as Control
	return true


func _click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = point
		click.global_position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		root.push_input(click, true)


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _check(ok: bool, result: String) -> void:
	print(("%s " % ("PASS" if ok else "FAIL")) + result)
	if not ok:
		failures += 1
