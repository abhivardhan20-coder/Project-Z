shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 cloud_color : source_color = vec4(.62,.69,.74,1);
uniform float strength = .25;
float hash(vec2 p) {return fract(sin(dot(p,vec2(12.78,91.31)))*43758.5453);}
float noise(vec2 p) {vec2 f=fract(p),i=floor(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void fragment() {
    vec2 p=UV*vec2(6.,2.4)+vec2(TIME*.001,0.0);
    float cloud=noise(p)*.55+noise(p*2.13)*.3+noise(p*4.27)*.15;
    vec2 edge_uv=UV*2.0-1.0;
    float edge=1.0-smoothstep(.2,1.0,length(edge_uv));
    ALBEDO=cloud_color.rgb;
    ALPHA=smoothstep(.43,.69,cloud)*edge*strength;
}
