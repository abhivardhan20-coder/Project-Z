shader_type spatial;

#include "res://materials/ultra/weather.gdshaderinc"

uniform sampler2D asphalt_track : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D asphalt_track_nor_gl : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D worn_asphalt_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D worn_asphalt_nor_gl : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D worn_asphalt_rough : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leafy_grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D aerial_grass_rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
varying vec3 world_position;
varying vec3 normal_world;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), u.x),
		mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec2 p = world_position.xz;
	float offset_x = 8.0 * sin(p.y * 0.018) * smoothstep(32.0, 120.0, abs(p.y));
	float offset_z = 5.0 * sin(p.x * 0.015) * smoothstep(30.0, 130.0, abs(p.x));
	float across = min(abs(p.x), abs(p.y));
	float margin = across - 5.4;
	float half_width = 5.4;
	float vertical_margin = abs(p.x) - 5.4;
	float horizontal_margin = abs(p.y) - 5.4;
	float along = abs(p.x) < abs(p.y) ? p.y : p.x;
	for (int i = 0; i < 6; i++) {
		float axis = float(i < 3 ? i : i - 3);
		axis = axis < 0.5 ? 140.0 : (axis < 1.5 ? 250.0 : 380.0);
		axis *= i < 3 ? -1.0 : 1.0;
		float z_shift = offset_z;
		if (axis == -250.0 && p.x < 0.0) {
			z_shift = 6.0 * sin((p.x + 300.0) * 0.028) * smoothstep(24.0, 78.0, abs(p.x + 300.0)) * smoothstep(0.0, 65.0, -p.x);
		}
		float width = axis == -250.0 && p.x >= -386.0 && p.x <= -134.0 ? 4.55 : 3.25;
		float vertical = abs(p.x - axis - offset_x);
		float horizontal = abs(p.y - axis - z_shift);
		vertical_margin = min(vertical_margin, vertical - 3.25);
		horizontal_margin = min(horizontal_margin, horizontal - width);
		if (vertical - 3.25 < margin) {
			across = vertical;
			half_width = 3.25;
			margin = vertical - 3.25;
			along = p.y;
		}
		if (horizontal - width < margin) {
			across = horizontal;
			half_width = width;
			margin = horizontal - width;
			along = p.x;
		}
	}
	float distance_to_camera = length(VERTEX);
	float roughness = 0.92;
	float broad = noise2(p * 0.025);
	float local = noise2(p * 0.12 + 3.0);
	vec3 hill_tint = mix(vec3(0.145, 0.176, 0.100), vec3(0.26, 0.28, 0.16), broad);
	vec3 macro_ground = texture(aerial_grass_rock, p * 0.032).rgb;
	vec3 soil = hill_tint * mix(0.76, 1.23, dot(macro_ground, vec3(0.27, 0.60, 0.13)));
	float slope = smoothstep(0.13, 0.58, 1.0 - abs(normalize(normal_world).y));
	soil = mix(soil, macro_ground * vec3(0.69, 0.66, 0.61), slope * 0.62);
	{
		vec3 fine_ground = texture(leafy_grass, p * 0.49).rgb;
		float grass_blend = 0.45 * (1.0 - smoothstep(20.0, 95.0, distance_to_camera));
		soil = mix(soil, fine_ground * vec3(0.82, 0.98, 0.65), grass_blend);
		vec3 road_sample = texture(asphalt_track, p * 0.43).rgb;
		float road_luma = dot(road_sample, vec3(0.26, 0.61, 0.13));
		float patch = smoothstep(0.43, 0.77, noise2(p * 0.31 + broad * 1.2));
		float pavement = 1.0 - smoothstep(-0.16, 0.28, margin);
		vec3 asphalt = vec3(0.096, 0.103, 0.111) * mix(0.69, 1.34, local);
		asphalt *= mix(0.78, 1.29, clamp(road_luma * 3.6, 0.0, 1.0)) * mix(1.0, 0.72, patch);
	float detail_texture = (1.0 - smoothstep(27.0, 72.0, distance_to_camera)) * (0.50 + patch * 0.35);
	vec2 worn_uv = mat2(vec2(0.80, -0.60), vec2(0.60, 0.80)) * p * 0.48;
	if (detail_texture > 0.01) {
		vec3 worn = texture(worn_asphalt_diff, worn_uv).rgb;
		asphalt = mix(asphalt, worn * vec3(0.93, 0.95, 1.02), detail_texture);
	}
		float ravel = 1.0 - smoothstep(15.0, 65.0, distance_to_camera);
		if (ravel > 0.01) {
			vec2 crack_uv = p * vec2(0.69, 0.24);
			crack_uv.x += pz_noise(p * 1.24) * 0.19;
			float fracture = abs(pz_noise(crack_uv) - 0.51);
			float cracks = (1.0 - smoothstep(0.005, 0.019, fracture)) * smoothstep(0.43, 0.72, local);
			asphalt *= 1.0 - cracks * ravel * 0.47;
		}
		float stripe_aa = max(fwidth(across) * 0.65, 0.025);
		float line = 1.0 - smoothstep(0.055 - stripe_aa, 0.055 + stripe_aa, across);
		float dash = abs(fract(along / 9.0) - 0.5);
		line *= 1.0 - smoothstep(0.18, 0.225, dash);
		float edge = 1.0 - smoothstep(0.045 - stripe_aa, 0.045 + stripe_aa, abs(across - half_width + 0.24));
		float junction = smoothstep(0.15, 1.85, max(vertical_margin, horizontal_margin));
		float wear = mix(0.32, 0.90, smoothstep(0.25, 0.75, noise2(p * 9.0))) * mix(0.62, 1.0, broad);
		float paint = max(line, edge * 0.45) * junction * wear;
		asphalt = mix(asphalt, vec3(0.64, 0.53, 0.31), paint);
		vec3 verge = mix(vec3(0.23, 0.218, 0.189) * mix(0.76, 1.15, local), soil, smoothstep(0.28, 3.3, margin));
		soil = mix(verge, asphalt, pavement);
		float detail = pavement * (1.0 - smoothstep(14.0, 52.0, distance_to_camera));
		if (pz_quality > 0 && detail > 0.01) {
		vec2 bump = mix(texture(asphalt_track_nor_gl, p * 0.43).xy,
			texture(worn_asphalt_nor_gl, worn_uv).xy, detail_texture) * 2.0 - 1.0;
			vec3 normal_offset = (VIEW_MATRIX * vec4(bump.x, 0.0, -bump.y, 0.0)).xyz;
			NORMAL = normalize(NORMAL + normal_offset * detail * 0.47);
		}
		roughness = mix(0.92, mix(0.88, 0.79, patch + paint * (1.0 - patch)), pavement);
	if (detail_texture > 0.01) {
		roughness = mix(roughness, texture(worn_asphalt_rough, worn_uv).r, detail_texture * pavement);
	}
		float pond = smoothstep(0.55, 0.78, pz_noise(p * vec2(0.51, 0.29)));
		pond *= (1.0 - smoothstep(0.025, 0.12, 1.0 - normalize(normal_world).y)) * pavement;
		float puddle = pond * pz_weather.w * (1.0 - smoothstep(36.0, 95.0, distance_to_camera));
		float wet = pz_weather.y * mix(0.46, 0.76, pavement);
		soil *= mix(1.0, 0.46, wet + puddle * (1.0 - wet) * 0.60);
		roughness = mix(mix(roughness, 0.34, wet), 0.07, puddle);
		if (pz_quality > 0 && puddle > 0.02 && pz_weather.x > 0.05) {
			vec2 ring = fract(p * 2.2) - 0.5;
			float wave = sin(length(ring) * 48.0 - TIME * 14.0) * (1.0 - smoothstep(0.13, 0.49, length(ring)));
			NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(ring.x, 0, ring.y, 0)).xyz * wave * puddle * 0.12);
		}
	}
	ALBEDO = soil;
	ROUGHNESS = roughness;
	SPECULAR = 0.43;
}
