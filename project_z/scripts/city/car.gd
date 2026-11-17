extends "res://scripts/pilot/pilot_driver.gd"

const MODELS := preload("res://scripts/neighborhood/neighborhood_assets.gd")
const GRAPHICS := preload("res://scripts/graphics/materials.gd")
const MODEL := "res://assets/vehicles/road/carmine_gt.glb"

var headlights := false
var beams: Array[SpotLight3D] = []
var engine_audio := AudioStreamPlayer3D.new()
var sound_enabled := true
var ground_loaded := true


func _ready() -> void:
	shell = MODELS.new().instantiate(MODEL)
	GRAPHICS.adapt_model(shell, &"car")
	add_child(shell)
	wheel_radius = 0.384
	wheelbase = 2.80
	max_speed = 24.0
	chassis_size = Vector3(2.03, 1.11, 4.35)
	chassis_height = chassis_size.y * 0.5
	door_angle = deg_to_rad(-58.0)
	forward_action = &"city_forward"
	back_action = &"city_back"
	left_action = &"city_left"
	right_action = &"city_right"
	brake_action = &"city_jump"
	super._ready()
	camera.fov = 70.0
	camera.near = 0.11
	for side: float in [-0.72, 0.72]:
		var lamp := SpotLight3D.new()
		lamp.position = Vector3(side, 0.68, 2.28)
		lamp.rotation_degrees = Vector3(5.0, 180.0, 0.0)
		lamp.light_color = Color("#f1f5ff")
		lamp.light_energy = 2.5
		lamp.spot_range = 34.0
		lamp.spot_angle = 28.0
		lamp.hide()
		shell.add_child(lamp)
		beams.append(lamp)
	engine_audio.stream = _engine_loop()
	engine_audio.unit_size = 3.0
	engine_audio.max_distance = 32.0
	engine_audio.volume_db = -20.0
	add_child(engine_audio)


func can_board(player: CharacterBody3D, view: Camera3D) -> bool:
	if occupied or not is_on_floor() or absf(speed) > 0.65:
		return false
	if player.global_position.distance_squared_to(entry.global_position) > 5.4:
		return false
	var direction := entry_focus() - view.global_position
	return direction.normalized().dot(-view.global_basis.z) > 0.16 and player.visible_from(view.global_position, entry_focus(), self)


func set_headlights(enabled: bool) -> void:
	headlights = enabled
	for beam in beams:
		beam.visible = enabled


func _physics_process(delta: float) -> void:
	if not ground_loaded:
		return
	super._physics_process(delta)
	var running := occupied and controls_enabled and sound_enabled
	if running and not engine_audio.playing:
		engine_audio.play()
	elif not running and engine_audio.playing:
		engine_audio.stop()
	if running:
		var throttle := absf(Input.get_axis(back_action, forward_action))
		var rpm := 0.72 + 0.70 * absf(speed) / max_speed + 0.20 * throttle
		engine_audio.pitch_scale = lerpf(engine_audio.pitch_scale, rpm, minf(delta * 4.0, 1.0))
		engine_audio.volume_db = -23.0 + throttle * 6.0


func _engine_loop() -> AudioStreamWAV:
	var pcm := PackedByteArray()
	var rate := 22050
	pcm.resize(rate * 2)
	for i in rate:
		var t := TAU * float(i) / rate
		var pulse := 0.56 + 0.44 * sin(t * 24.0)
		var wave := sin(t * 48.0) * 0.52 + sin(t * 72.0) * 0.25 + sin(t * 121.0) * 0.12
		pcm.encode_s16(i * 2, int(wave * pulse * 15800.0))
	var sample := AudioStreamWAV.new()
	sample.data = pcm
	sample.format = AudioStreamWAV.FORMAT_16_BITS
	sample.mix_rate = rate
	sample.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sample.loop_end = rate
	return sample
