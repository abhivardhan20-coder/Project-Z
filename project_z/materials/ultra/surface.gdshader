shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://materials/ultra/weather.gdshaderinc"

group_uniforms Textures;
uniform sampler2D base_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D orm : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool has_normal = false;
uniform bool has_orm = false;
uniform bool has_detail = false;
group_uniforms Finish;
uniform vec4 tint : source_color = vec4(1.0);
uniform float roughness : hint_range(0.08, 1.0) = 0.79;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float metres : hint_range(0.1, 12.0) = 2.4;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.55;
uniform float macro_strength : hint_range(0.0, 0.6) = 0.15;
uniform float wet_exposure : hint_range(0.0, 1.0) = 0.0;
uniform float coat : hint_range(0.0, 1.0) = 0.0;
uniform bool world_mapping = true;
group_uniforms;

varying vec3 position_world;
varying vec3 normal_world;
varying vec3 position_view;

void vertex() {
	position_world = (MODEL_MATRIX * vec4(VERTEX, 1)).xyz;
	normal_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	position_view = (MODELVIEW_MATRIX * vec4(VERTEX, 1)).xyz;
}

void fragment() {
	vec3 axis = abs(normalize(normal_world));
	vec2 projected = axis.y > max(axis.x, axis.z) ? position_world.xz :
		(axis.x > axis.z ? position_world.zy : position_world.xy);
	vec2 uv = world_mapping ? projected / metres : UV;
	float distance_fade = 1.0 - smoothstep(13.0, 58.0, length(position_view));
	vec3 color = texture(base_color, uv).rgb * tint.rgb;
	float macro = pz_noise(projected * 0.17);
	color *= 1.0 + (macro - 0.5) * macro_strength;
	vec3 channels = has_orm ? texture(orm, uv).rgb : vec3(1.0, 1.0, 0.0);
	float wet = pz_weather.y * wet_exposure * mix(0.57, 1.0, macro);
	if (has_normal && distance_fade > 0.01 && pz_quality > 0) {
		vec3 base_n = texture(normal_map, uv).xyz * 2.0 - 1.0;
		base_n = normalize(vec3(base_n.xy * normal_strength * distance_fade, base_n.z));
		if (has_detail && pz_quality == 2) {
			vec3 detail_n = texture(detail_normal, uv * 6.0).xyz * 2.0 - 1.0;
			base_n = pz_rnm(base_n, normalize(vec3(detail_n.xy * distance_fade * 0.30, detail_n.z)));
		}
		NORMAL = pz_view_normal(normalize(NORMAL), position_view, uv, base_n);
	}
	ALBEDO = color * mix(1.0, 0.57, wet);
	AO = channels.r;
	ROUGHNESS = mix(max(0.085, roughness * channels.g), 0.24, wet);
	METALLIC = max(metallic, channels.b);
	SPECULAR = mix(0.37, 0.49, wet);
	CLEARCOAT = coat * float(pz_quality > 0);
	CLEARCOAT_ROUGHNESS = mix(0.32, 0.14, wet);
}
