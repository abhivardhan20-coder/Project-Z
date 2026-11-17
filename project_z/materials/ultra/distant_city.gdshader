shader_type spatial;
render_mode specular_disabled;

#include "res://materials/ultra/weather.gdshaderinc"

uniform vec4 default_stone : source_color = vec4(1.0);
varying vec3 facade_normal;
varying vec3 facade_position;

void vertex() {
	facade_normal = NORMAL;
	facade_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 stone = COLOR.rgb * default_stone.rgb;
	float direction = abs(facade_normal.z) > 0.5 ? facade_position.x : facade_position.z;
	vec2 grid = vec2(direction / 2.65, facade_position.y / 3.45);
	vec2 cell = floor(grid);
	vec2 opening = abs(fract(grid) - vec2(0.5, 0.54));
	float pane = (1.0 - smoothstep(0.30, 0.40, opening.x)) * (1.0 - smoothstep(0.27, 0.42, opening.y));
	pane *= 1.0 - step(0.5, abs(facade_normal.y));
	float lit = step(0.92, pz_hash(cell + floor(facade_position.xz * 0.07))) * pane;
	vec3 glass = mix(vec3(0.042, 0.070, 0.095), vec3(0.102, 0.149, 0.183), pz_hash(cell));
	ALBEDO = mix(stone, glass, pane) * (0.84 + 0.16 * step(0.08, fract(grid.y)));
	EMISSION = vec3(0.60, 0.25, 0.067) * lit * (1.0 - pz_wind.w * 0.79) * (0.65 + pz_weather.z * 0.35);
	ROUGHNESS = 0.88;
}
