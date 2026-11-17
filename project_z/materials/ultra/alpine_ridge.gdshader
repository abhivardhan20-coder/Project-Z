shader_type spatial;
render_mode cull_disabled, specular_disabled;

#include "res://materials/ultra/weather.gdshaderinc"

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 position = world_position;
	vec2 ground = position.xz;
	float altitude = position.y;
	float slope = abs(normalize(world_normal).y);
	float stone = pz_noise(ground * 0.051 + altitude * 0.017);
	float strata = pz_noise(ground * vec2(0.075, 0.024) + vec2(altitude * 0.072, 0.0));
	float seams = pz_noise(ground * vec2(0.17, 0.045) + vec2(altitude * 0.048, 0.0));
	float tree_line = 88.0 + pz_noise(ground * 0.022) * 42.0;
	vec3 forest = mix(vec3(0.039, 0.060, 0.051), vec3(0.096, 0.113, 0.081), stone);
	vec3 rock = mix(vec3(0.062, 0.088, 0.121), vec3(0.235, 0.247, 0.253), strata * 0.61 + stone * 0.26 + seams * 0.13);
	vec3 land = mix(forest, rock, max(smoothstep(tree_line - 24.0, tree_line + 40.0, altitude), (1.0 - slope) * 0.48));
	float snow_line = 112.0 + strata * 61.0 + (1.0 - slope) * 96.0 + seams * 26.0;
	float snow = smoothstep(snow_line - 8.0, snow_line + 17.0, altitude);
	vec3 snow_color = mix(vec3(0.35, 0.43, 0.54), vec3(0.82, 0.87, 0.93), strata * 0.69 + stone * 0.31);
	ALBEDO = mix(land, snow_color, snow);
	ROUGHNESS = 0.98;
}
