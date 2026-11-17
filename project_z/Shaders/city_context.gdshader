shader_type spatial;
varying vec3 wp;
varying vec3 wn;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
    vec2 uv=abs(wn.x)>abs(wn.z)?wp.zy:wp.xy;
    vec2 cell=fract(uv/vec2(4.3,3.5));
    float window=step(.17,cell.x)*step(cell.x,.79)*step(.17,cell.y)*step(cell.y,.77)*(1.-step(.5,wn.y));
    vec3 glass=mix(vec3(.075,.12,.15),vec3(.20,.28,.33),.5+.5*sin(floor(uv.x/4.3)*5.7+floor(uv.y/3.5)*8.3));
    ALBEDO=pow(mix(COLOR.rgb,glass,window*.85),vec3(2.2));ROUGHNESS=mix(.87,.32,window);METALLIC=window*.15;
}
