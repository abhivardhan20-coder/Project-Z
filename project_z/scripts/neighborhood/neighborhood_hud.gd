extends CanvasLayer

const INK := Color("#0f1a20")
const LINE := Color("#344b53")
const WHITE := Color("#edf2ed")
const DIM := Color("#a1b5b7")
const AMBER := Color("#f2bc6b")
const RED := Color("#f07865")

var screen: Control
var health_label: Label
var med_label: Label
var objectives: Label
var status: Label
var hint: Label
var prompt_label: Label
var prompt_card: PanelContainer
var bar: ProgressBar
var overlay: ColorRect
var overlay_title: Label
var overlay_body: Label
var flash: ColorRect
var reticle: Control
var status_time := 0.0
var hit_time := 0.0
var font := SystemFont.new()
var district := "KALDRAN  /  NORTHLINE BLOCK 01"
var dialog_district := "NORTHLINE  /  BLOCK 01"
var movement_keys := "WASD  MOVE    SHIFT  SPRINT    SPACE  JUMP"
var action_keys := "E  USE    LMB  SWING    H  HEAL    ESC  PAUSE    R  RESET"


func _ready() -> void:
	font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI"])
	screen = Control.new()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var title := card(Vector2.ZERO, Vector2(26, 24), Vector2(238, 74))
	title.add_child(text("P R O J E C T   Z", 23, WHITE))
	title.add_child(text(district, 12, AMBER))

	var right := card(Vector2(1, 0), Vector2(-310, 24), Vector2(284, 140))
	right.add_child(text("FIELD OBJECTIVE", 13, AMBER))
	objectives = text("", 19, WHITE)
	right.add_child(objectives)
	hint = text("", 14, DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(hint)

	var life := card(Vector2(0, 1), Vector2(26, -116), Vector2(252, 92))
	health_label = text("", 18, WHITE)
	life.add_child(health_label)
	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 7
	bar.add_theme_stylebox_override("background", flat(Color("#293d45"), Color.TRANSPARENT, 0, 2))
	bar.add_theme_stylebox_override("fill", flat(Color("#9db885"), Color.TRANSPARENT, 0, 2))
	life.add_child(bar)
	med_label = text("", 13, DIM)
	life.add_child(med_label)

	var keys := card(Vector2(1, 1), Vector2(-385, -87), Vector2(359, 63))
	keys.add_child(text(movement_keys, 13, DIM))
	keys.add_child(text(action_keys, 13, DIM))

	reticle = Control.new()
	screen.add_child(reticle)
	anchor(reticle, Vector2(0.5, 0.5), Vector2.ZERO, Vector2.ZERO)
	for pair in [Vector4(-9, -1, 5, 2), Vector4(4, -1, 5, 2), Vector4(-1, -9, 2, 5), Vector4(-1, 4, 2, 5)]:
		var part := ColorRect.new()
		part.color = Color(0.93, 0.96, 0.91, 0.84)
		part.position = Vector2(pair.x, pair.y)
		part.size = Vector2(pair.z, pair.w)
		part.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reticle.add_child(part)

	var interaction := card(Vector2(0.5, 0.5), Vector2(-180, 42), Vector2(360, 46))
	prompt_card = interaction.get_parent().get_parent() as PanelContainer
	prompt_label = text("", 18, AMBER)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction.add_child(prompt_label)
	prompt_card.hide()

	status = text("", 16, WHITE)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(status)
	anchor(status, Vector2(0.5, 1), Vector2(-275, -135), Vector2(550, 35))
	status.hide()

	flash = ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(0.72, 0.14, 0.09, 0.0)

	overlay = ColorRect.new()
	overlay.color = Color(0.032, 0.059, 0.073, 0.83)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dialog := card(Vector2(0.5, 0.5), Vector2(-222, -102), Vector2(444, 204), overlay)
	dialog.add_child(text(dialog_district, 14, AMBER))
	overlay_title = text("", 37, WHITE)
	dialog.add_child(overlay_title)
	overlay_body = text("", 17, DIM)
	overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog.add_child(overlay_body)
	overlay.hide()


func refresh(health: int, medkits: int, searched: int, infected_left: int, armed: bool) -> void:
	health_label.text = "HEALTH   %03d / 100" % health
	health_label.modulate = RED if health <= 32 else WHITE
	med_label.text = "FIELD DRESSINGS   %02d" % medkits
	bar.value = health
	bar.add_theme_stylebox_override("fill", flat(RED if health <= 32 else Color("#9db885"), Color.TRANSPARENT, 0, 2))
	objectives.text = "%02d INFECTED LEFT\n%d OF 5 CACHES SEARCHED" % [infected_left, searched]
	hint.text = "Clear the block. Search supply caches for field dressings." if armed else "Search the marked roadside cache for a crowbar."


func show_prompt(value: String) -> void:
	prompt_card.visible = not value.is_empty() and not overlay.visible
	prompt_label.text = value


func announce(value: String) -> void:
	status.text = value
	status_time = 3.1
	status.show()


func harm() -> void:
	flash.color.a = 0.27


func hit() -> void:
	hit_time = 0.13
	reticle.modulate = Color("#ffbf70")


func show_overlay(title: String, body: String) -> void:
	overlay_title.text = title
	overlay_body.text = body
	overlay.show()
	prompt_card.hide()
	reticle.hide()


func hide_overlay() -> void:
	overlay.hide()
	reticle.show()


func _process(delta: float) -> void:
	if flash:
		flash.color.a = move_toward(flash.color.a, 0.0, delta * 0.73)
	if status_time > 0:
		status_time -= delta
		if status_time <= 0:
			status.hide()
	if hit_time > 0:
		hit_time -= delta
		if hit_time <= 0:
			reticle.modulate = Color.WHITE


func card(point: Vector2, offset: Vector2, dimensions: Vector2, parent: Control = null) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", flat(Color(INK, 0.92), LINE, 1, 5))
	(screen if parent == null else parent).add_child(panel)
	anchor(panel, point, offset, dimensions)
	var padding := MarginContainer.new()
	padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padding.add_theme_constant_override("margin_left", 13)
	padding.add_theme_constant_override("margin_right", 13)
	padding.add_theme_constant_override("margin_top", 9)
	padding.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(padding)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 5)
	padding.add_child(content)
	return content


func text(value: String, size_px: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", tint)
	return label


func anchor(control: Control, point: Vector2, offset: Vector2, dimensions: Vector2) -> void:
	control.anchor_left = point.x
	control.anchor_right = point.x
	control.anchor_top = point.y
	control.anchor_bottom = point.y
	control.offset_left = offset.x
	control.offset_top = offset.y
	control.offset_right = offset.x + dimensions.x
	control.offset_bottom = offset.y + dimensions.y


func flat(color: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style

