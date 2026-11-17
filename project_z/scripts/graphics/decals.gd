extends RefCounted

static var masks: Dictionary = {}


static func pavement(parent: Node3D, at: Vector3, size: Vector2, kind: StringName, yaw: float) -> void:
	if RenderingServer.get_current_rendering_method() != "forward_plus":
		return
	var decal := Decal.new()
	decal.position = at + Vector3.UP * 0.10
	decal.rotation.y = yaw
	decal.texture_albedo = _mask(kind)
	decal.size = Vector3(size.x, 0.68, size.y)
	decal.normal_fade = 0.43
	decal.albedo_mix = 0.72
	decal.distance_fade_enabled = true
	decal.distance_fade_begin = 36.0
	decal.distance_fade_length = 22.0
	parent.add_child(decal)


static func _mask(kind: StringName) -> Texture2D:
	if not masks.has(kind):
		var texture := Image.create_empty(96, 96, false, Image.FORMAT_RGBA8)
		var noise := FastNoiseLite.new()
		noise.seed = 2026
		noise.frequency = 0.09
		var tire := kind == &"tire"
		var color := Color("#24201d") if not tire else Color("#3a3732")
		for y in texture.get_height():
			for x in texture.get_width():
				var p := Vector2(x, y) / 47.5 - Vector2.ONE
				var organic := noise.get_noise_2d(x, y) * 0.30
				var shape := p.length() if not tire else Vector2(absf(absf(p.x) - 0.47) * 9.0, p.y).length()
				color.a = (1.0 - smoothstep(0.42, 0.92, shape + organic)) * (0.50 if tire else 0.65)
				texture.set_pixel(x, y, color)
		texture.generate_mipmaps()
		masks[kind] = ImageTexture.create_from_image(texture)
	return masks[kind]
