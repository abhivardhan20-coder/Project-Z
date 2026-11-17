shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

#include "res://materials/ultra/weather.gdshaderinc"

uniform vec4 tint : source_color = vec4(0.44, 0.57, 0.62, 1);
uniform float exposure : hint_range(0.0, 1.0) = 1.0;
varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1)).xyz;
}

void fragment() {
	float grazing = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 4.0);
	float streak = 0.0;
	if (pz_quality > 0 && pz_weather.y > 0.05) {
		vec2 coords = vec2(world.x + world.z, world.y);
		streak = smoothstep(0.71, 0.88, pz_noise(coords * vec2(42.0, 2.6) + vec2(0, TIME * pz_weather.x * 0.3)));
		streak *= pz_weather.y * exposure;
	}
	ALBEDO = tint.rgb * mix(0.50, 0.85, streak);
	SPECULAR = 0.62;
	ROUGHNESS = 0.18 + streak * 0.18;
	ALPHA = clamp(0.15 + grazing * 0.46 + streak * 0.12, 0, 0.72);
}
