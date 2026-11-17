shader_type spatial;
render_mode cull_disabled, diffuse_burley;

#include "res://materials/ultra/weather.gdshaderinc"

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1)).xyz;
	float reach = 1.0 - smoothstep(36.0, 115.0, distance(world, CAMERA_POSITION_WORLD));
	float weight = smoothstep(0.025, 0.60, VERTEX.y);
	float gust = sin(TIME * 1.45 + dot(world.xz, vec2(0.21, 0.16)));
	vec2 push = pz_wind.xy * (0.048 + gust * 0.037) * pz_wind.z * reach * weight;
	VERTEX.xz += push;
}

void fragment() {
	vec4 leaf = texture(leaf_tex, UV) * tint;
	ALBEDO = leaf.rgb * mix(1.0, 0.73, pz_weather.y);
	ROUGHNESS = mix(0.87, 0.56, pz_weather.y);
	BACKLIGHT = leaf.rgb * 0.16;
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = 0.44;
}
