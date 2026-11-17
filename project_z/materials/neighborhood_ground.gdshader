shader_type spatial;
render_mode diffuse_burley, specular_disabled;

uniform vec3 soil : source_color = vec3(0.25, 0.23, 0.17);
uniform vec3 grass : source_color = vec3(0.31, 0.37, 0.24);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash_cell(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 uv) {
	vec2 cell = floor(uv);
	vec2 t = fract(uv);
	t = t * t * (3.0 - 2.0 * t);
	return mix(
		mix(hash_cell(cell), hash_cell(cell + vec2(1, 0)), t.x),
		mix(hash_cell(cell + vec2(0, 1)), hash_cell(cell + vec2(1, 1)), t.x),
		t.y
	);
}

void fragment() {
	vec2 uv = world_position.xz;
	float patch = value_noise(uv * 0.12) * 0.7 + value_noise(uv * 0.55) * 0.3;
	float grit = value_noise(uv * 24.0) * 0.29 + value_noise(uv * 2.3) * 0.15;
	ALBEDO = mix(soil, grass, smoothstep(0.19, 0.78, patch)) * (0.75 + grit);
	ROUGHNESS = 0.96;
}

