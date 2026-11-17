// Original Kaldran surface model. Shared by native terrain and distant meshes.
uniform float season : hint_range(0.0, 3.0) = 1.0;
uniform float snow_line = 2050.0;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform bool clay = false;
uniform bool silhouette = false;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_blend : filter_linear, repeat_disable;
uniform sampler2D terrain_aux : filter_linear, repeat_disable;
uniform vec4 sector_rect = vec4(-3072.0, -13312.0, 3072.0, 3072.0);

float pz_hash(vec2 p) {return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);}
float pz_noise(vec2 p) {
    vec2 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
    return mix(mix(pz_hash(i),pz_hash(i+vec2(1,0)),f.x),mix(pz_hash(i+vec2(0,1)),pz_hash(i+vec2(1,1)),f.x),f.y);
}
vec4 pz_triplanar(sampler2D tex, vec3 p, vec3 n, float scale) {
    vec3 w = pow(abs(n),vec3(4.0)); w /= max(w.x+w.y+w.z,0.001);
    return texture(tex,p.zy*scale)*w.x + texture(tex,p.xz*scale)*w.y + texture(tex,p.xy*scale)*w.z;
}
vec3 pz_detail_normal(vec3 p,vec3 n,float dist) {
    if(dist>650.0 || clay || silhouette) {return n;}
    vec3 weights=pow(abs(n),vec3(4.0));weights/=max(dot(weights,vec3(1)),.001);
    vec3 tx=texture(rock_normal,p.zy*.25).xyz*2.0-1.0;
    vec3 ty=texture(rock_normal,p.xz*.25).xyz*2.0-1.0;
    vec3 tz=texture(rock_normal,p.xy*.25).xyz*2.0-1.0;
    vec3 detail=vec3(tx.z*sign(n.x),tx.y,tx.x)*weights.x+vec3(ty.x,ty.z*sign(n.y),ty.y)*weights.y+vec3(tz.x,tz.y,tz.z*sign(n.z))*weights.z;
    return normalize(mix(n,detail,(1.0-smoothstep(100.0,650.0,dist))*.28));
}
// Returns RGB reflectance and perceptual roughness. Snow retention uses elevation,
// slope, north aspect, curvature shelter, wind exposure and seasonal snow line.
vec4 pz_surface(vec3 p, vec3 n, float dist) {
    vec2 atlas_uv=(p.xz-vec2(-24576.0,-40960.0))/49152.0;
    vec3 aux=texture(terrain_aux,atlas_uv).rgb;
    float macro=pz_noise(p.xz*.0018)*.62+pz_noise(p.xz*.0063)*.38;
    float rockness=1.0-smoothstep(.48,.82,n.y);
    float alpine=smoothstep(1460.0,2150.0,p.y);
    vec3 bedrock=mix(vec3(.22,.25,.27),vec3(.39,.39,.36),macro);
    float strata=sin(p.y*.045+p.x*.007+p.z*.003)*.5+.5;
    bedrock*=mix(.89,1.07,strata);
    vec3 forest=mix(vec3(.095,.15,.12),vec3(.20,.25,.15),macro);
    vec3 meadow=mix(vec3(.25,.28,.17),vec3(.41,.39,.26),macro);
    vec3 ground=mix(forest,meadow,smoothstep(1150.0,1860.0,p.y));
    vec3 base=pow(mix(ground,bedrock,max(rockness,alpine)),vec3(2.2));
    if(dist<1800.0) {
        vec3 detail=pz_triplanar(rock_albedo,p,n,.25).rgb;
        vec3 grass=texture(grass_albedo,p.xz*.25).rgb;
        float close=1.0-smoothstep(350.0,1800.0,dist);
        base=mix(base,mix(grass,detail,max(rockness,alpine)),close*.72);
        vec2 suv=(p.xz-sector_rect.xy)/sector_rect.zw;
        float inside=step(0.0,suv.x)*step(0.0,suv.y)*step(suv.x,1.0)*step(suv.y,1.0);
        float path=texture(ground_blend,suv).r*inside;
        base=mix(base,vec3(.057,.045,.025)*(0.85+0.3*macro),path*.9);
    }
    float aspect=clamp(-n.z,0.0,1.0);
    float shelter=clamp((aux.r-.38)*2.8,0.0,1.0);
    float wind=clamp(dot(n,normalize(vec3(.7,.15,-.5))),0.0,1.0);
    float thermal=p.y-snow_line+aspect*280.0+shelter*200.0-wind*160.0+(macro-.5)*340.0;
    float snow=smoothstep(-180.0,260.0,thermal)*smoothstep(.38,.84,n.y);
    float ledge=smoothstep(.54,.80,n.y)*smoothstep(.65,.9,aux.r)*smoothstep(-350.0,80.0,thermal);
    snow=max(snow,ledge*.72);
    vec3 snow_color=mix(vec3(.72,.81,.87),vec3(.91,.94,.95),macro);
    base=mix(base,pow(snow_color,vec3(2.2)),snow);
    float rough=mix(.93,.74,snow);
    if(dist<650.0) {rough=mix(rough,pz_triplanar(rock_normal,p,n,.25).a,(1.0-smoothstep(100.0,650.0,dist))*(1.0-snow)*.7);}
    base*=1.0-wetness*(1.0-snow)*.24;
    rough=mix(rough,.39,wetness*(1.0-snow));
    if(clay) {base=vec3(.32);rough=.96;}
    if(silhouette) {base=vec3(.025);rough=1.0;}
    return vec4(base,rough);
}
