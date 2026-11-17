shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D ground_blend : filter_linear, repeat_disable;
uniform sampler2DArray ground_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray ground_normal_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
varying vec2 ground_position;

void vertex() {
	ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec4 weights = texture(ground_blend, UV);
	float stone = max(0.0, 1.0 - dot(weights, vec4(1.0)));
	vec3 albedo = vec3(0.0);
	vec4 normal_roughness = vec4(0.0);
	for (int layer = 0; layer < 5; layer++) {
		float weight = layer == 4 ? stone : weights[layer];
		if (weight > 0.004) {
			float scale = layer == 4 ? 3.0 : 2.0;
			vec3 sample_point = vec3(ground_position / scale, float(layer));
			albedo += texture(ground_albedo, sample_point).rgb * weight;
			normal_roughness += texture(ground_normal_roughness, sample_point) * weight;
		}
	}
	float breakup = 0.88 + 0.09 * sin(ground_position.x * 0.11 + sin(ground_position.y * 0.08));
	ALBEDO = albedo * breakup;
	ROUGHNESS = normal_roughness.a;
	NORMAL_MAP = normal_roughness.rgb;
	NORMAL_MAP_DEPTH = 0.66;
}
