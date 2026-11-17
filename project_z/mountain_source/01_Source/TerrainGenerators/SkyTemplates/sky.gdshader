shader_type sky;

#include "res://materials/ultra/weather.gdshaderinc"

uniform vec4 zenith : source_color = vec4(0.22, 0.39, 0.53, 1.0);
uniform vec4 horizon : source_color = vec4(0.65, 0.73, 0.78, 1.0);
uniform vec4 cloud_color : source_color = vec4(0.73, 0.75, 0.75, 1.0);
uniform float cloud_phase = 0.0;
uniform float cloud_coverage = 0.19;
uniform float storm_weight = 0.0;
uniform float sunset_weight = 0.0;
uniform float dusk_weight = 0.0;
uniform sampler2D dusk_map : filter_linear, repeat_enable;
uniform sampler2D overcast_map : filter_linear, repeat_enable;

void sky() {
	float height = max(EYEDIR.y, 0.0);
	vec3 color = mix(horizon.rgb, zenith.rgb, smoothstep(0.0, 0.68, height));
	if (EYEDIR.y > 0.005) {
		vec2 sky_pos = EYEDIR.xz / (0.32 + height);
		vec2 p = sky_pos * vec2(2.48, 2.9) + vec2(0.8, 0.6) * cloud_phase;
		vec2 warp = vec2(pz_noise(p * 0.67), pz_noise(p * 0.67 + 5.0));
		p += warp * 1.28;
		float density = pz_noise(p) * 0.52 + pz_noise(p * 2.1) * 0.28 + pz_noise(p * 4.37) * 0.14 + pz_noise(p * 8.9) * 0.06;
		float clouds = smoothstep(0.63 - cloud_coverage * 0.33, 0.79 - cloud_coverage * 0.30, density);
		float rim = clouds * (1.0 - smoothstep(0.49, 0.82, clouds));
		vec3 deck = cloud_color.rgb * mix(0.53, 1.12, 1.0 - clouds * storm_weight);
		if (LIGHT0_ENABLED) {
			float sun = max(0.0, dot(EYEDIR, LIGHT0_DIRECTION));
			float warm_start = pow(sun, 3.0) * exp(-height * 2.0) * sunset_weight;
			color = mix(color, vec3(1.11, 0.48, 0.22), warm_start * 0.90);
			deck = mix(deck, deck * vec3(1.07, 0.75, 0.58), warm_start * 0.76);
			deck += LIGHT0_COLOR * rim * (0.13 + 0.72 * warm_start);
			color += LIGHT0_COLOR * LIGHT0_ENERGY * (pow(sun, 85.0) * 0.35 + smoothstep(0.99980, 0.99992, sun) * 3.1);
		}
		color = mix(color, deck, clouds * smoothstep(0.006, 0.11, height) * 0.97);
		float photo_mask = smoothstep(0.005, 0.12, height);
		vec2 dusk_uv = vec2(fract(SKY_COORDS.x + 0.30), SKY_COORDS.y);
		vec3 dusk = texture(dusk_map, dusk_uv).rgb * 1.8;
		vec3 overcast = texture(overcast_map, vec2(fract(SKY_COORDS.x + 0.57), SKY_COORDS.y)).rgb;
		dusk = dusk / (1.0 + dusk * 0.40);
		overcast = overcast / (1.0 + overcast * 0.46);
		color = mix(color, dusk * vec3(1.07, 0.96, 0.92), dusk_weight * photo_mask * 0.73);
		vec3 storm_photo = pow(max(overcast, vec3(0.0)), vec3(1.55)) * vec3(0.44, 0.56, 0.73);
		storm_photo *= mix(1.16, 0.42, clouds);
		color = mix(color, storm_photo, storm_weight * photo_mask * 0.51);
	}
	COLOR = color;
}
