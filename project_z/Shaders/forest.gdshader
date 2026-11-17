shader_type spatial;
render_mode cull_disabled, diffuse_burley;
varying vec3 world_position;
void vertex() {
    world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    VERTEX.x+=sin(TIME*1.1+world_position.x*.08+world_position.z*.06)*.035*max(VERTEX.y,0.0);
}
void fragment() {
    ALBEDO=pow(COLOR.rgb,vec3(2.2));
    ROUGHNESS=.94;
    SPECULAR=.14;
}
