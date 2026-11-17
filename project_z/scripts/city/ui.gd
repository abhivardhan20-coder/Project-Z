extends CanvasLayer

const MAP := preload("res://scripts/city/map.gd")
const STATE := preload("res://scripts/city/state.gd")
const PLAYER := preload("res://scripts/city/player.gd")
const PALE := Color("#e9e6d9")
const DIM := Color("#a8b1a7")
const ACCENT := Color("#e2bc80")
const EDGE := Color("#3c4a47")

signal command(action: String, value: Variant)

var screen := Control.new()
var field := Control.new()
var modal := ColorRect.new()
var field_label: Label
var district_label: Label
var objective_label: Label
var range_label: Label
var prompt_label: Label
var survival_label: Label
var notice_label: Label
var debug_label: Label
var health := ProgressBar.new()
var stamina := ProgressBar.new()
var sheet: VBoxContainer
var mode := ""
var notice_time := 0.0
var progress: STATE
var map: MAP
var rebind_action := ""
var mountain_travel_available := false
var at_mountain_trail := false


func _ready() -> void:
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI"])
	theme.default_font = font
	theme.default_font_size = 17
	theme.set_color("font_color", "Label", PALE)
	theme.set_color("font_color", "Button", PALE)
	theme.set_color("font_hover_color", "Button", ACCENT)
	theme.set_stylebox("normal", "Button", _style(Color("#29322e"), EDGE))
	theme.set_stylebox("hover", "Button", _style(Color("#39443d"), Color("#8b795b")))
	theme.set_stylebox("pressed", "Button", _style(Color("#4b4939"), ACCENT))
	screen.theme = theme
	screen.add_child(field)
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top_left := _card(field, Vector2.ZERO, Vector2(24, 22), Vector2(280, 110))
	field_label = _label(top_left, "KALDRAN CITY", 24)
	district_label = _label(top_left, "", 15, ACCENT)
	range_label = _label(top_left, "", 14, DIM)
	var top_right := _card(field, Vector2(1, 0), Vector2(-354, 22), Vector2(330, 160))
	_label(top_right, "FIRST LIGHT", 13, ACCENT)
	objective_label = _label(top_right, "", 16)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var lower := _card(field, Vector2(0, 1), Vector2(24, -139), Vector2(300, 118))
	_bar(lower, health, Color("#b57e65"))
	_bar(lower, stamina, Color("#acbc8c"))
	survival_label = _label(lower, "", 14, DIM)
	prompt_label = _center_label(field, Vector2(0.5, 0.54), "", 19, ACCENT)
	notice_label = _center_label(field, Vector2(0.5, 0.86), "", 17, PALE)
	var reticle := _center_label(field, Vector2(0.5, 0.5), "·", 26, PALE)
	reticle.modulate.a = 0.72
	debug_label = _center_label(field, Vector2(0.5, 0.11), "", 14, DIM)
	field.hide()
	screen.add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.color = Color(0.047, 0.065, 0.059, 0.89)


func update_hud(player: PLAYER, district: String, mission: String, distance: int, hour: String, hint: String, diagnostic: String) -> void:
	health.value = player.health
	stamina.value = player.stamina
	district_label.text = district
	range_label.text = "%s     ·     %d m to objective" % [hour, distance]
	objective_label.text = mission
	prompt_label.text = hint
	var weapon := "Unarmed"
	if progress.weapon == "crowbar":
		weapon = "Crowbar"
	elif progress.weapon == "pistol":
		weapon = "Pistol %d / %d" % [progress.rounds, int(progress.inventory.get("ammo", 0))]
	survival_label.text = "Health %d   Stamina %d\nFood %d   Water %d   Exposure %d\n%s" % [player.health, player.stamina, player.hunger, player.thirst, player.exposure, weapon]
	debug_label.text = diagnostic


func announce(message: String) -> void:
	notice_label.text = message
	notice_time = 4.5


func _process(delta: float) -> void:
	if notice_time > 0.0:
		notice_time = maxf(0.0, notice_time - delta)
		notice_label.modulate.a = minf(1.0, notice_time * 2.0)


func _input(event: InputEvent) -> void:
	if rebind_action == "" or not event is InputEventKey or not event.pressed or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	var action := rebind_action
	rebind_action = ""
	if event.physical_keycode != KEY_ESCAPE:
		command.emit("bind", [action, event.physical_keycode])
	else:
		command.emit("settings", null)


func open(next: String, can_continue: bool = false, title: String = "", detail: String = "") -> void:
	mode = next
	modal.visible = mode != ""
	field.visible = mode != "title" and mode != "settings_title" and mode != "controls_title"
	rebind_action = ""
	if mode == "":
		return
	for child in modal.get_children():
		modal.remove_child(child)
		child.queue_free()
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _style(Color("#141d1b"), EDGE, 19.0))
	center.add_child(box)
	sheet = VBoxContainer.new()
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet.add_theme_constant_override("separation", 8)
	var width := 670.0 if mode in ["map", "pack", "storage"] else 520.0
	if mode in ["map", "pack", "storage", "controls", "controls_title"]:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		var height := 665.0 if mode == "map" else 585.0
		scroll.custom_minimum_size = Vector2(width * progress.ui_scale, height)
		box.add_child(scroll)
		scroll.add_child(sheet)
	else:
		# Scroll containers can collapse to zero height when only the width is set.
		sheet.custom_minimum_size.x = width * progress.ui_scale
		box.add_child(sheet)
	var primary: Button
	match mode:
		"title":
			_label(sheet, "DAY 21   /   THE KALDRAN OUTBREAK", 15, ACCENT)
			_label(sheet, "PROJECT Z", 62)
			_label(sheet, "KALDRAN CITY", 24, DIM)
			var new_game := _button(sheet, "New Game", "new")
			var load_game := _button(sheet, "Continue", "continue")
			load_game.disabled = not can_continue
			primary = load_game if can_continue else new_game
			_button(sheet, "Settings", "settings_title")
			_button(sheet, "Material Lab", "shader_lab")
			_button(sheet, "Exit to Desktop", "quit")
		"pause":
			_label(sheet, "Paused", 34)
			primary = _button(sheet, "Resume", "resume")
			if mountain_travel_available:
				_button(sheet, "Return to Kaldran City" if at_mountain_trail else "Travel to Mountain Trail", "city_travel" if at_mountain_trail else "mountain_travel")
			_button(sheet, "Save Game", "save")
			_button(sheet, "Objective Journal", "journal")
			_button(sheet, "Settings", "settings")
			_button(sheet, "Return to Title", "title")
		"pack", "storage":
			_pack(mode == "storage")
		"settings", "settings_title":
			_settings()
		"controls", "controls_title":
			_controls()
		"map":
			_label(sheet, "Kaldran City", 33)
			_label(sheet, "White  Player      Amber  Objective      Green  Discovered", 14, DIM)
			map = MAP.new()
			map.custom_minimum_size = Vector2(0, 535)
			sheet.add_child(map)
			_button(sheet, "Close Map", "resume")
		"journal", "story", "complete":
			_label(sheet, title, 34)
			var body := _label(sheet, detail, 17, DIM)
			body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			primary = _button(sheet, "Return to Game", "resume")
		"death":
			_label(sheet, "Survivor down", 36)
			_label(sheet, "Load your last safe checkpoint to try again.", 16, DIM)
			var reload_checkpoint := _button(sheet, "Reload Checkpoint", "continue")
			reload_checkpoint.disabled = not can_continue
			var return_to_title := _button(sheet, "Return to Title", "title")
			primary = reload_checkpoint if can_continue else return_to_title
	if primary:
		primary.grab_focus.call_deferred()


func _pack(storing: bool) -> void:
	_label(sheet, "Safehouse storage" if storing else "Field pack", 34)
	_label(sheet, "%.1f / %.0f kg" % [progress.weight(progress.inventory), STATE.CAPACITY], 15, ACCENT)
	var names := progress.inventory.keys()
	names.sort()
	for id: String in names:
		var item: Array = progress.items[id]
		var row := HBoxContainer.new()
		sheet.add_child(row)
		var caption := _label(row, "%d × %s%s" % [progress.inventory[id], item[0], " · equipped" if progress.weapon == id else ""], 16)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.tooltip_text = item[2]
		caption.mouse_filter = Control.MOUSE_FILTER_STOP
		if storing:
			_button(row, "Store", "deposit", id).disabled = progress.weapon == id
		elif id in ["food", "water", "bandage", "medication", "crowbar", "pistol"]:
			_button(row, "Equip" if id in ["crowbar", "pistol"] else "Use", "item", id)
	if storing:
		_label(sheet, "Cabinet", 22)
		var stored := progress.storage.keys()
		stored.sort()
		for id: String in stored:
			_button(sheet, "Take %s (%d stored)" % [progress.items[id][0], progress.storage[id]], "withdraw", id)
	else:
		_label(sheet, "Crafting", 22)
		for id: String in progress.recipes:
			var needs: PackedStringArray = []
			for ingredient: String in progress.recipes[id]:
				needs.append("%d %s" % [progress.recipes[id][ingredient], progress.items[ingredient][0]])
			var recipe := _button(sheet, "%s  ·  %s" % [progress.items[id][0], ", ".join(needs)], "craft", id)
			recipe.disabled = not progress.has_all(progress.inventory, progress.recipes[id])
	_button(sheet, "Close", "resume")


func _settings() -> void:
	_label(sheet, "Settings", 34)
	var qualities := OptionButton.new()
	for title in ["Low  ·  900p target", "Medium  ·  1080p target", "High"]:
		qualities.add_item(title)
	qualities.select(progress.quality)
	qualities.item_selected.connect(func(value: int): command.emit("quality", value))
	sheet.add_child(qualities)
	var skies := OptionButton.new()
	for title in ["Clear", "Overcast", "Rain"]:
		skies.add_item(title)
	skies.select(progress.weather)
	skies.item_selected.connect(func(value: int): command.emit("weather", value))
	sheet.add_child(skies)
	_slider("Field of view", "fov", progress.fov, 58, 93, 1)
	_slider("Mouse sensitivity", "sensitivity", progress.sensitivity, 0.0008, 0.007, 0.0001)
	_slider("Interface scale", "ui_scale", progress.ui_scale, 0.8, 1.3, 0.05)
	var audio := CheckButton.new()
	audio.text = "Sound"
	audio.button_pressed = progress.sound
	audio.toggled.connect(func(value: bool): command.emit("sound", value))
	sheet.add_child(audio)
	_button(sheet, "Remap Keyboard", "controls_title" if mode == "settings_title" else "controls")
	_button(sheet, "Back", "title" if mode == "settings_title" else "pause")


func _controls() -> void:
	_label(sheet, "Keyboard controls", 34)
	_label(sheet, "Select an action and press a new key.", 15, DIM)
	for action: String in PLAYER.KEYS:
		var events := InputMap.action_get_events(action)
		var label := action.trim_prefix("city_").capitalize()
		var binding := OS.get_keycode_string(events[0].physical_keycode) if not events.is_empty() else "Unbound"
		var button := Button.new()
		button.text = "%s   ·   %s" % [label, binding]
		button.pressed.connect(func(): rebind_action = action; button.text = "Press a key for %s" % label)
		sheet.add_child(button)
	_button(sheet, "Back", "settings_title" if mode == "controls_title" else "settings")


func _slider(title: String, name: String, value: float, minimum: float, maximum: float, step: float) -> void:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.value_changed.connect(func(next: float): command.emit(name, next))
	_label(sheet, title, 15, DIM)
	sheet.add_child(slider)


func _button(parent: Control, title: String, action: String, value: Variant = null) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 36
	button.pressed.connect(func(): command.emit(action, value))
	parent.add_child(button)
	return button


func _label(parent: Control, content: String, font_size: int, tint: Color = PALE) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_font_size_override("font_size", roundi(font_size * progress.ui_scale))
	label.add_theme_color_override("font_color", tint)
	parent.add_child(label)
	return label


func _center_label(parent: Control, anchor: Vector2, content: String, font_size: int, tint: Color) -> Label:
	var label := _label(parent, content, font_size, tint)
	_anchor(label, anchor, Vector2(-310, -17), Vector2(620, 34))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_shadow_color", Color("#15211c"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _bar(parent: Control, bar: ProgressBar, tint: Color) -> void:
	bar.show_percentage = false
	bar.custom_minimum_size.y = 6
	bar.add_theme_stylebox_override("background", _style(Color("#34423c"), Color.TRANSPARENT, 0))
	bar.add_theme_stylebox_override("fill", _style(tint, Color.TRANSPARENT, 0))
	parent.add_child(bar)


func _card(parent: Control, anchor: Vector2, offset: Vector2, dimensions: Vector2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.07, 0.105, 0.09, 0.88), EDGE))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	_anchor(panel, anchor, offset, dimensions)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	return column


func _style(background: Color, border: Color, padding: float = 9.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0 else 0)
	style.set_corner_radius_all(3)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_content_margin(side, padding)
	return style


func _anchor(control: Control, anchor: Vector2, offset: Vector2, dimensions: Vector2) -> void:
	control.anchor_left = anchor.x
	control.anchor_right = anchor.x
	control.anchor_top = anchor.y
	control.anchor_bottom = anchor.y
	control.offset_left = offset.x
	control.offset_right = offset.x + dimensions.x
	control.offset_top = offset.y
	control.offset_bottom = offset.y + dimensions.y
