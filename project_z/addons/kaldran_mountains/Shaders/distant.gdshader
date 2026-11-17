shader_type spatial;
render_mode cull_back, diffuse_burley, fog_disabled;
uniform vec4 city_haze : source_color = vec4(.46,.57,.68,1);
uniform float city_density = .000018;
#include "res://addons/kaldran_mountains/Shaders/alpine_surface.gdshaderinc"
uniform float morph = 0.0;
uniform bool sector_active = false;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
    VERTEX.y = mix(VERTEX.y,UV2.x,morph);
    world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
    if(max(abs(world_position.x),abs(world_position.z))<620.0) {discard;}
    vec2 q=(world_position.xz-sector_rect.xy)/sector_rect.zw;
    // The native clipmap replaces a true hole, not a second z-fighting surface.
    if(sector_active && q.x>0.002 && q.y>0.002 && q.x<.998 && q.y<.998) {discard;}
    vec4 s=pz_surface(world_position+vec3(0,320,0),normalize(world_normal),length(CAMERA_POSITION_WORLD-world_position));
    float air=1.0-exp(-length(CAMERA_POSITION_WORLD-world_position)*city_density);
    ALBEDO=s.rgb*(1.0-air);EMISSION=city_haze.rgb*air;ROUGHNESS=s.a;SPECULAR=.25;
    NORMAL=normalize(mat3(VIEW_MATRIX)*pz_detail_normal(world_position,normalize(world_normal),length(CAMERA_POSITION_WORLD-world_position)));
    if(silhouette) {ALBEDO=vec3(0);EMISSION=vec3(.018);}
}
