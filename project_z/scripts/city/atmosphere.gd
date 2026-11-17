extends Node3D

const STATE := preload("res://scripts/city/state.gd")
const SKY_SHADER := preload("res://materials/ultra/sky.gdshader")

var state: STATE
var sun: DirectionalLight3D
var environment: Environment
var rain: GPUParticles3D
var player: CharacterBody3D
var rain_follow: Node3D
var last_sky := -1.0
var last_weather := -1
var last_quality := -1
var wetness := 0.0
var puddles := 0.0
var rain_strength := 0.0
var sheltered := false
var shelter_timer := 0.0
var forward_plus := false
var frozen_time := false
var sky_material: ShaderMaterial
var published_weather := Vector4(-1, -1, -1, -1)
var published_wind := Vector4(-1, -1, -1, -1)


func configure(progress: STATE, character: CharacterBody3D, daylight: DirectionalLight3D, air: Environment) -> void:
	state = progress
	player = character
	rain_follow = character
	sun = daylight
	environment = air
	forward_plus = RenderingServer.get_current_rendering_method() == "forward_plus"
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_height = 12.0
	environment.fog_height_density = 0.0
	sky_material = ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	for asset: Array in [
		["dusk_map", "res://assets/city/qwantani_dusk_2_puresky.hdr"],
		["overcast_map", "res://assets/city/kloofendal_overcast_puresky.hdr"],
	]:
		var photo := load(asset[1]) as Texture2D
		if photo:
			sky_material.set_shader_parameter(asset[0], photo)
	environment.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	environment.sky.radiance_size = Sky.RADIANCE_SIZE_128
	environment.sky.sky_material = sky_material
	rain = GPUParticles3D.new()
	rain.emitting = false
	rain.amount = 250
	rain.lifetime = 0.82
	rain.visibility_aabb = AABB(Vector3(-14, -13, -14), Vector3(28, 30, 28))
	var droplets := ParticleProcessMaterial.new()
	droplets.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	droplets.emission_box_extents = Vector3(12, 1.5, 12)
	droplets.direction = Vector3(0.12, -1, 0.04)
	droplets.spread = 2.0
	droplets.initial_velocity_min = 12.0
	droplets.initial_velocity_max = 17.0
	droplets.gravity = Vector3(0, -5, 0)
	rain.process_material = droplets
	var drop := BoxMesh.new()
	drop.size = Vector3(0.005, 0.23, 0.005)
	var drop_material := StandardMaterial3D.new()
	drop_material.albedo_color = Color(0.65, 0.73, 0.79, 0.20)
	drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = drop_material
	rain.draw_pass_1 = drop
	add_child(rain)


func update(delta: float) -> void:
	if not frozen_time:
		state.clock = fposmod(state.clock + delta / 1440.0, 1.0)
	rain.position = rain_follow.global_position + Vector3.UP * 8.0
	var rain_target := 1.0 if state.weather == 2 else 0.0
	var cloud := [0.19, 0.66, 0.90][state.weather] as float
	var day := maxf(0.0, sin((state.clock - 0.235) * TAU))
	rain_strength = move_toward(rain_strength, rain_target, delta * 0.32)
	wetness = move_toward(wetness, rain_target, delta * (0.12 if rain_target > wetness else lerpf(0.012, 0.035, day)))
	puddles = move_toward(puddles, rain_target, delta * (0.075 if rain_target > puddles else 0.009))
	var weather := Vector4(rain_strength, wetness, cloud, puddles)
	if not weather.is_equal_approx(published_weather):
		published_weather = weather
		RenderingServer.global_shader_parameter_set(&"pz_weather", weather)
	var wind := Vector4(0.80, 0.60, 0.25 + cloud * 0.47, snappedf(day, 0.025))
	if wind != published_wind:
		published_wind = wind
		RenderingServer.global_shader_parameter_set(&"pz_wind", wind)
	shelter_timer -= delta
	if shelter_timer <= 0.0 or state.weather != last_weather:
		shelter_timer = 0.28
		var position := rain_follow.global_position + Vector3.UP * 0.48
		var check := PhysicsRayQueryParameters3D.create(position, position + Vector3.UP * 18.0, 1, [player.get_rid()])
		sheltered = not player.get_world_3d().direct_space_state.intersect_ray(check).is_empty()
	rain.emitting = rain_strength > 0.09 and not sheltered
	rain.amount_ratio = clampf(rain_strength, 0.0, 1.0)
	if absf(state.clock - last_sky) < 0.0008 and state.weather == last_weather and state.quality == last_quality:
		return
	if state.quality != last_quality:
		apply_quality(state.quality)
	last_sky = state.clock
	last_weather = state.weather
	last_quality = state.quality
	var storm := float(state.weather) / 2.0
	var daylight := smoothstep(0.0, 0.33, day)
	var low_sun := (1.0 - smoothstep(0.28, 0.66, day)) * smoothstep(0.02, 0.18, day) * (1.0 - storm * 0.86)
	var arc := clampf((state.clock - 0.235) * 2.0, 0.0, 1.0)
	sun.rotation_degrees = Vector3(-maxf(0.8, 61.0 * day), lerpf(-125.0, 96.0, arc), 0)
	sun.light_color = Color("#fff1dd").lerp(Color("#ff9d53"), low_sun).lerp(Color("#c1d3ef"), storm * 0.53)
	sun.light_energy = (0.73 * day + 0.69 * daylight + 0.51 * low_sun) * (1.0 - storm * 0.85)
	sun.shadow_enabled = state.quality > 0 and day > 0.06
	environment.ambient_light_color = Color("#b2c5e0").lerp(Color("#8ca8c7"), storm)
	environment.ambient_light_energy = lerpf(0.29, 0.56, daylight) * (1.0 - storm * 0.12 - low_sun * 0.18)
	environment.fog_light_color = Color("#263340").lerp(Color("#8ea7ba").lerp(Color("#748ca6"), storm), daylight)
	environment.fog_density = lerpf(0.00022, 0.00088, storm)
	environment.fog_sky_affect = 0.08
	sky_material.set_shader_parameter("zenith", Color("#101e31").lerp(Color("#3d658d").lerp(Color("#283c56"), storm), daylight))
	sky_material.set_shader_parameter("horizon", Color("#354758").lerp(Color("#a6b9c9").lerp(Color("#859bb3"), storm), daylight))
	sky_material.set_shader_parameter("cloud_color", Color("#27384b").lerp(Color("#cdd3d8").lerp(Color("#556d88"), storm), daylight))
	sky_material.set_shader_parameter("storm_weight", storm * daylight)
	sky_material.set_shader_parameter("sunset_weight", low_sun)
	sky_material.set_shader_parameter("dusk_weight", maxf(low_sun, (1.0 - daylight) * 0.48) * (1.0 - storm * 0.41))
	sky_material.set_shader_parameter("cloud_phase", state.clock * 4.4)
	sky_material.set_shader_parameter("cloud_coverage", cloud)


func apply_quality(profile: int) -> void:
	RenderingServer.global_shader_parameter_set(&"pz_quality", profile)
	environment.ssao_enabled = forward_plus and profile == 2
	environment.ssao_radius = 1.18
	environment.ssao_intensity = 1.65
	environment.ssr_enabled = forward_plus and profile == 2
	environment.ssr_max_steps = 24
	environment.volumetric_fog_enabled = forward_plus and profile == 2
	environment.volumetric_fog_density = 0.007
	environment.volumetric_fog_length = 54.0
	environment.glow_enabled = forward_plus and profile == 2
	environment.glow_intensity = 0.21
	environment.glow_bloom = 0.025
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if profile == 2 else DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 120.0 if profile == 2 else 48.0
	sun.directional_shadow_fade_start = 0.78
	get_viewport().positional_shadow_atlas_size = 1024 if profile == 2 else 0
	rain.amount = [75, 230, 390][profile]


func reset_surfaces(weather: int) -> void:
	wetness = 0.66 if weather == 2 else 0.0
	puddles = 0.43 if weather == 2 else 0.0
	rain_strength = 0.8 if weather == 2 else 0.0
