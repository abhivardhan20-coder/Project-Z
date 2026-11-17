extends Node

var effects: Dictionary = {}
var ambient := AudioStreamPlayer.new()
var voices: Array[AudioStreamPlayer3D] = []
var cursor := 0
var enabled := true
var weather := -1


func _ready() -> void:
	add_child(ambient)
	ambient.volume_db = -25.0
	for i in 8:
		var voice := AudioStreamPlayer3D.new()
		voice.max_distance = 33.0
		voice.unit_size = 5.0
		add_child(voice)
		voices.append(voice)


func cue(kind: String, position: Vector3, gain: float = 0.0) -> void:
	if not enabled:
		return
	if not effects.has(kind):
		effects[kind] = _make(kind)
	var voice := voices[cursor]
	cursor = (cursor + 1) % voices.size()
	voice.stop()
	voice.global_position = position
	voice.stream = effects[kind]
	voice.volume_db = gain
	voice.pitch_scale = randf_range(0.92, 1.08)
	voice.play()


func atmosphere(mode: int, sound: bool) -> void:
	enabled = sound
	if not enabled:
		ambient.stop()
		for voice in voices:
			voice.stop()
		return
	if mode != weather or not ambient.playing:
		weather = mode
		var key := "rain" if mode == 2 else "wind"
		if not effects.has(key):
			effects[key] = _make(key)
		ambient.stream = effects[key]
		ambient.play()


func _make(kind: String) -> AudioStreamWAV:
	var spec: Array = {
		"asphalt": [0.16, 81.0, 0.62], "soil": [0.19, 61.0, 0.78], "door": [0.24, 111.0, 0.67],
		"take": [0.24, 420.0, 0.25], "hit": [0.25, 53.0, 0.78], "shot": [0.31, 40.0, 1.0],
		"generator": [1.30, 54.0, 0.33], "infected": [0.49, 66.0, 0.56], "radio": [0.72, 360.0, 0.60],
		"wind": [3.4, 34.0, 0.49], "rain": [3.4, 77.0, 0.80],
	}.get(kind, [0.14, 280.0, 0.30])
	var loop := kind in ["wind", "rain"]
	var rng := RandomNumberGenerator.new()
	rng.seed = kind.hash()
	var samples := int(22050 * spec[0])
	var data := PackedByteArray()
	data.resize(samples * 2)
	var low := 0.0
	for index in samples:
		var t := float(index) / 22050
		var noise := rng.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.08 if kind != "rain" else 0.22)
		var decay := 0.55 if loop else sin(minf(1.0, t * 65.0) * PI * 0.5) * pow(1.0 - float(index) / samples, 2.4)
		var wave := sin(t * spec[1] * TAU * (1.0 - t * 0.12)) * 0.55
		var rough := noise if kind == "shot" else low
		data.encode_s16(index * 2, int(clampf((wave * (1.0 - spec[2]) + rough * spec[2]) * decay, -1.0, 1.0) * 28000))
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = 22050
	audio.data = data
	if loop:
		audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
		audio.loop_end = samples
	return audio
