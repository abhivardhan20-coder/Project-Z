shader_type spatial;

#include "res://materials/ultra/weather.gdshaderinc"

uniform vec4 tint : source_color = vec4(0.63, 0.59, 0.51, 1.0);
uniform bool masonry = false;
uniform bool siding = false;
uniform sampler2D brick_surface : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plaster_surface : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D brick_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D plaster_normal : hint_normal, filter_linear_mipmap, repeat_enable;

varying vec3 position_world;
varying vec3 normal_world;
varying vec3 position_view;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(17.13, 95.43))) * 43758.5453);
}

void vertex() {
	position_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	position_view = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = abs(normal_world);
	vec2 wall = vec2(n.x > n.z ? position_world.z : position_world.x, position_world.y);
	float drip = hash21(vec2(floor(wall.x * 4.2), 3.0));
	float fade = 1.0 - smoothstep(0.012, 0.039, max(length(dFdx(wall)), length(dFdy(wall))));
	float wear = mix(0.5, hash21(floor(wall * 31.0)), fade);
	float stain = mix(0.94, 1.02, sin(wall.y * 0.46 + 1.7 * drip) * 0.5 + 0.5);
	float texture_mask = 0.96 + 0.055 * wear;
	if (n.y < 0.6 && masonry) {
		vec3 brick = texture(brick_surface, wall / 2.0).rgb;
		texture_mask *= mix(0.69, 1.17, dot(brick, vec3(0.2126, 0.7152, 0.0722)));
	} else if (n.y < 0.6) {
		vec3 plaster = texture(plaster_surface, wall / 2.15).rgb;
		texture_mask *= mix(0.72, 1.03, dot(plaster, vec3(0.2126, 0.7152, 0.0722)));
	}
	if (n.y < 0.6 && siding) {
		texture_mask *= 0.83 + 0.17 * smoothstep(0.04, 0.15, fract(wall.x * 4.0));
	}
	float wet = pz_weather.y * mix(0.10, 0.57, max(0.0, normal_world.y) + 0.29 * pz_noise(wall * vec2(2.2, 0.19)));
	float close = (1.0 - smoothstep(12.0, 56.0, length(position_view))) * (1.0 - step(0.6, n.y));
	if (close > 0.01 && pz_quality > 0) {
		vec3 mapped = (masonry ? texture(brick_normal, wall / 2.0).xyz :
			texture(plaster_normal, wall / 2.15).xyz) * 2.0 - 1.0;
		NORMAL = pz_view_normal(normalize(NORMAL), position_view, wall, normalize(vec3(mapped.xy * close * 0.63, mapped.z)));
	}
	ALBEDO = tint.rgb * texture_mask * stain * mix(1.0, 0.60, wet);
	ROUGHNESS = mix(siding ? 0.67 : 0.87, 0.46, wet);
}
