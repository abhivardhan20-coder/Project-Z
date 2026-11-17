shader_type spatial;
render_mode cull_back, diffuse_burley;
#include "res://Shaders/alpine_surface.gdshaderinc"
uniform float morph = 0.0;
uniform bool sector_active = false;
uniform bool city_cutout = false;
uniform vec3 city_haze : source_color = vec3(.65,.72,.78);
uniform float city_density = 0.0;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
    VERTEX.y = mix(VERTEX.y,UV2.x,morph) - (sector_active ? 0.08 : 0.0);
    world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
    vec2 q=(world_position.xz-sector_rect.xy)/sector_rect.zw;
    // 384 m inset clears missing neighbours at the outer native clipmap edge.
    // Native terrain begins at 320 m, leaving a continuous 64 m overlap.
    vec2 focus = abs(world_position.xz-CAMERA_POSITION_WORLD.xz);
    if(sector_active && q.x>.125 && q.y>.125 && q.x<.875 && q.y<.875 && max(focus.x,focus.y)<1800.0) {discard;}
    if(city_cutout && max(abs(world_position.x),abs(world_position.z))<620.0) {discard;}
    vec4 s=pz_surface(world_position,normalize(world_normal),length(CAMERA_POSITION_WORLD-world_position));
    ALBEDO=s.rgb;ROUGHNESS=s.a;SPECULAR=.25;
    NORMAL=normalize(mat3(VIEW_MATRIX)*pz_detail_normal(world_position,normalize(world_normal),length(CAMERA_POSITION_WORLD-world_position)));
    if(city_cutout) {
        float haze = 1.0-exp(-length(CAMERA_POSITION_WORLD-world_position)*city_density);
        ALBEDO *= 1.0-haze;
        EMISSION = city_haze*haze*.55;
    }
    if(silhouette) {ALBEDO=vec3(0);EMISSION=vec3(.018);}
}
