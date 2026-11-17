shader_type spatial;
render_mode cull_disabled, diffuse_burley;

varying vec2 stream;

void vertex() {
	stream = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float flow = sin(stream.y * 2.6 - TIME * 1.9 + sin(stream.x * 0.85) * 1.6);
	float ripple = sin(stream.x * 3.2 + stream.y * 0.52 + TIME * 1.25);
	float glint = pow(max(0.0, flow * ripple), 9.0);
	float fresnel = pow(1.0 - max(0.0, dot(normalize(NORMAL), normalize(VIEW))), 3.0);
	ALBEDO = mix(vec3(0.062, 0.17, 0.17), vec3(0.27, 0.42, 0.43), fresnel);
	ALBEDO += vec3(0.12, 0.14, 0.12) * glint;
	ROUGHNESS = 0.24 + ripple * 0.08;
	SPECULAR = 0.57;
	NORMAL_MAP = vec3(0.5 + ripple * 0.06, 0.5 + flow * 0.07, 1.0);
}
