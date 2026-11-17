global uniform vec4 pz_weather;
global uniform vec4 pz_wind;
global uniform int pz_quality;

float pz_hash(vec2 p) {
	vec3 mixed = fract(vec3(p.xyx) * 0.1031);
	mixed += dot(mixed, mixed.yzx + 33.33);
	return fract((mixed.x + mixed.y) * mixed.z);
}

float pz_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(pz_hash(cell), pz_hash(cell + vec2(1, 0)), f.x),
		mix(pz_hash(cell + vec2(0, 1)), pz_hash(cell + vec2(1)), f.x), f.y);
}

vec3 pz_rnm(vec3 base, vec3 detail) {
	vec3 t = base + vec3(0, 0, 1);
	vec3 u = detail * vec3(-1, -1, 1);
	return normalize(t * dot(t, u) / max(0.001, t.z) - u);
}

vec3 pz_view_normal(vec3 n, vec3 position_view, vec2 uv, vec3 sample_n) {
	vec3 dp1 = dFdx(position_view);
	vec3 dp2 = dFdy(position_view);
	vec2 duv1 = dFdx(uv);
	vec2 duv2 = dFdy(uv);
	vec3 tangent = cross(dp2, n) * duv1.x + cross(n, dp1) * duv2.x;
	vec3 bitangent = cross(dp2, n) * duv1.y + cross(n, dp1) * duv2.y;
	float scale = inversesqrt(max(max(dot(tangent, tangent), dot(bitangent, bitangent)), 1e-15));
	return normalize(tangent * (scale * sample_n.x) + bitangent * (scale * sample_n.y) + n * sample_n.z);
}
