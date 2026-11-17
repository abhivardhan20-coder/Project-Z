shader_type spatial;
render_mode cull_disabled, diffuse_burley;

#include "res://materials/ultra/weather.gdshaderinc"

uniform vec4 deep_color : source_color = vec4(0.14, 0.25, 0.24, 1);
uniform vec4 grazing_color : source_color = vec4(0.40, 0.51, 0.54, 1);
varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1)).xz;
}

void fragment() {
	vec2 p = world_xz;
	float run = sin(p.x * 2.1 - TIME * 1.35 + sin(p.y * 0.8));
	float cross_flow = sin(p.y * 3.4 + p.x * 0.71 + TIME * 1.73);
	vec2 ripple = vec2(run, cross_flow) * 0.045;
	if (pz_quality > 0 && pz_weather.x > 0.04) {
		vec2 cell = fract(p * 2.6) - 0.5;
		float wave = sin(length(cell) * 51.0 - TIME * 15.0 + pz_hash(floor(p * 2.6)) * 6.28);
		ripple += cell * wave * pz_weather.x * 0.18;
	}
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(ripple.x, 0, ripple.y, 0)).xyz);
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);
	ALBEDO = mix(deep_color.rgb * (0.84 + 0.18 * pz_noise(p * 0.27)), grazing_color.rgb, fresnel);
	ROUGHNESS = 0.18 + pz_weather.x * 0.11;
	SPECULAR = 0.62;
}
