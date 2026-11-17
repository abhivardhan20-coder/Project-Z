"""Adapt the verified copy to its single-project layout and repair the seam."""
from pathlib import Path
import json
import re
import numpy as np

GAME = Path(__file__).resolve().parents[1] / 'project_z'
SOURCE = GAME / 'mountain_source'
SCRIPTS = SOURCE / '01_Source/GenerationScripts'

def edit(path, old, new):
    text = path.read_text(encoding='utf-8')
    if old not in text:
        raise ValueError(f'Missing edit anchor in {path}: {old[:70]}')
    path.write_text(text.replace(old,new),encoding='utf-8')

# Source stays next to the runtime; it is excluded from Godot asset importing.
(SOURCE/'.gdignore').write_text('')
for path in SCRIPTS.glob('*.py'):
    text = path.read_text(encoding='utf-8')
    text = re.sub(r"ROOT/(['\"])07_Godot/([^'\"]+)\1", lambda m: "ROOT.parent/"+m[1]+m[2]+m[1],text)
    text = text.replace("ROOT/'07_Godot'", 'ROOT.parent').replace("ROOT.parent/'project_z'", 'ROOT.parent')
    for folder in ('Assets','Materials','Scripts','Scenes','Tests'):
        text = text.replace('res://'+folder+'/', 'res://'+folder.lower()+'/')
        # Only runtime directory names, never the numbered source directories.
        text = re.sub(r"(['\"])"+folder+r"(?=/|['\"])",r'\1'+folder.lower(),text)
    path.write_text(text,encoding='utf-8')
for directory in ('scripts','tests'):
    for path in (GAME/directory).glob('*.gd'):
        text=path.read_text(encoding='utf-8').replace('res://../08_Reference_Validation','res://mountain_source/08_Reference_Validation').replace('res://../09_Documentation','res://mountain_source/09_Documentation')
        path.write_text(text,encoding='utf-8')

surface=GAME/'Shaders/alpine_surface.gdshaderinc'
edit(surface,'uniform float season', 'uniform float elevation_datum = 0.0;\nuniform float season')
edit(surface,'vec4 pz_surface(vec3 p, vec3 n, float dist) {','vec4 pz_surface(vec3 p, vec3 n, float dist) {\n    p.y += elevation_datum;')
edit(surface,'vec3 pz_detail_normal(vec3 p,vec3 n,float dist) {','vec3 pz_detail_normal(vec3 p,vec3 n,float dist) {\n    p.y += elevation_datum;')

far=GAME/'Shaders/distant.gdshader'
edit(far,'uniform bool sector_active = false;','''uniform bool sector_active = false;
uniform bool city_cutout = false;
uniform vec3 city_haze : source_color = vec3(.65,.72,.78);
uniform float city_density = 0.0;''')
edit(far,'VERTEX.y = mix(VERTEX.y,UV2.x,morph);','VERTEX.y = mix(VERTEX.y,UV2.x,morph) - (sector_active ? 0.08 : 0.0);')
edit(far,'    // The native clipmap replaces a true hole, not a second z-fighting surface.\n    if(sector_active && q.x>0.002 && q.y>0.002 && q.x<.998 && q.y<.998) {discard;}', '''    // 384 m inset clears missing neighbours at the outer native clipmap edge.
    // Native terrain begins at 320 m, leaving a continuous 64 m overlap.
    if(sector_active && q.x>.125 && q.y>.125 && q.x<.875 && q.y<.875) {discard;}
    if(city_cutout && max(abs(world_position.x),abs(world_position.z))<620.0) {discard;}''')
edit(far,'    if(silhouette)', '''    if(city_cutout) {
        float haze = 1.0-exp(-length(CAMERA_POSITION_WORLD-world_position)*city_density);
        ALBEDO *= 1.0-haze;
        EMISSION = city_haze*haze*.55;
    }
    if(silhouette)''')

# Generate the native shader using the same source path as future rebuilds.
prep=SCRIPTS/'prepare_engine.py'
edit(prep,"(P/'Shaders/native_alpine.gdshader').write_text(source,encoding='utf-8')",'''source=source.replace('void fragment() {', 'void fragment() {\\n\\tvec2 border = min(v_vertex.xz-sector_rect.xy,sector_rect.xy+sector_rect.zw-v_vertex.xz);\\n\\tif(min(border.x,border.y)<320.0) {discard;}')
(P/'Shaders/native_alpine.gdshader').write_text(source,encoding='utf-8')''')
native=GAME/'Shaders/native_alpine.gdshader'
edit(native,'void fragment() {','void fragment() {\n\tvec2 border = min(v_vertex.xz-sector_rect.xy,sector_rect.xy+sector_rect.zw-v_vertex.xz);\n\tif(min(border.x,border.y)<320.0) {discard;}')

stream=GAME/'scripts/streamer.gd'
edit(stream,'var sector_active := false','var sector_active := false\nvar city_cutout := false\nvar elevation_datum := 0.0')
edit(stream,'m.set_shader_parameter("sector_active",sector_active)','m.set_shader_parameter("sector_active",sector_active)\n\tm.set_shader_parameter("city_cutout",city_cutout)\n\tm.set_shader_parameter("elevation_datum",elevation_datum)')
edit(stream,'var center := Vector3(float(tile.west)+2048,(float(tile.min)+float(tile.max))*.5,float(tile.north)+2048)','var center := to_global(Vector3(float(tile.west)+2048,(float(tile.min)+float(tile.max))*.5,float(tile.north)+2048))')
edit(stream,'# Preserve the collision-to-distant boundary with a fixed 64 m collar.','# Fix the shared boundary to the 64 m source triangle grid.')

world=GAME/'scripts/world.gd'
edit(world,'if distance<3500 and not is_instance_valid(terrain):_ensure_sector()\n\telif distance>4800 and is_instance_valid(terrain) and not walker.active:_release_sector()', '''# High-altitude review must retain the complete distant terrain surface.
    # Hysteresis avoids repeatedly rebuilding collision during free flight.
\tvar height_above := camera.global_position.y - _regional_height(camera.global_position)
\tif distance<3000 and height_above<650 and not is_instance_valid(terrain):_ensure_sector()
\telif (distance>3600 or height_above>900) and is_instance_valid(terrain) and (not walker.active or walker.fly):_release_sector()''')
# Mixed indentation in comment-only lines is harmless, use tabs consistently.
edit(world,'func _unhandled_input(event:', '''var regional_heights := PackedFloat32Array()
func _regional_height(point: Vector3) -> float:
\tif regional_heights.is_empty():regional_heights=FileAccess.get_file_as_bytes("res://Data/capital_height.f32").to_float32_array()
\tvar col := clampi(roundi((point.x+24576)/32),0,1536)
\tvar row := clampi(roundi((point.z+40960)/32),0,1536)
\treturn regional_heights[row*1537+col]

func _unhandled_input(event:''')
edit(GAME/'scripts/build_native.gd','terrain.mesh_lods=7','terrain.mesh_lods=6')
scene=GAME/'scenes/editable_sector.tscn'
text=scene.read_text().replace('mesh_lods = 7','mesh_lods = 6')
if 'mesh_lods =' not in text:text=text.replace('vertex_spacing = 2.0','vertex_spacing = 2.0\nmesh_lods = 6')
scene.write_text(text)

# Align the outer collar to the actual coarse triangular surface, not bilinear
# 32 m samples. The entire trail/core (inset >=1024 m) remains bit-identical.
collar='''def align_collar(h, H, domain, X, Z, distance):
    spacing=64.0
    cx=np.floor(X/spacing)*spacing;cz=np.floor(Z/spacing)*spacing
    u=(X-cx)/spacing;v=(Z-cz)/spacing
    a=sample(H,cx,cz,domain['west'],domain['north'],domain['spacing'])
    b=sample(H,cx+spacing,cz,domain['west'],domain['north'],domain['spacing'])
    c=sample(H,cx,cz+spacing,domain['west'],domain['north'],domain['spacing'])
    d=sample(H,cx+spacing,cz+spacing,domain['west'],domain['north'],domain['spacing'])
    coarse=np.where(u+v<=1,a+(b-a)*u+(c-a)*v,d+(c-d)*(1-u)+(b-d)*(1-v))
    t=smooth(448,768,distance)
    return coarse*(1-t)+h*t

'''
generator=SCRIPTS/'generate.py'
edit(generator,'def make_sector(H,domain):',collar+'def make_sector(H,domain):')
edit(generator,'    # Real runoff graph is exported;', '    h=align_collar(h,H,domain,X,Z,distance)\n    # Real runoff graph is exported;')

import sys
sys.path.insert(0,str(SCRIPTS))
from generate import align_collar, sample
cfg=json.loads((GAME/'Data/Sector/sector.json').read_text())
domain=json.loads((GAME/'Data/world.json').read_text())['domain']
H=np.fromfile(GAME/'Data/capital_height.f32',dtype='<f4').reshape(1537,1537)
h=np.fromfile(GAME/'Data/Sector/height.f32',dtype='<f4').reshape(cfg['samples'],cfg['samples'])
X,Z=np.meshgrid(np.arange(cfg['samples'])*2+cfg['west'],np.arange(cfg['samples'])*2+cfg['north'])
distance=np.minimum.reduce([X-cfg['west'],cfg['west']+cfg['size']-X,Z-cfg['north'],cfg['north']+cfg['size']-Z])
new=align_collar(h,H,domain,X,Z,distance).astype('<f4')
assert np.array_equal(new[distance>=768],h[distance>=768])
for path in (GAME/'Data/Sector/height.f32',SOURCE/'03_Heightmaps/Streamed_Regions/crown_approach_2m.f32'):new.tofile(path)
data_path=GAME/'Data/Sector/instances.json'
instances=json.loads(data_path.read_text())
for p in instances['trees']:
    p[1]=round(float(sample(new,p[0],p[2],cfg['west'],cfg['north'],2)),3)
data_path.write_text(json.dumps(instances,indent=2))

# Enable the editor plugin without replacing the city input/render/save settings.
config=GAME/'project.godot'
with config.open('a',encoding='utf-8') as f:f.write('\n[editor_plugins]\n\nenabled=PackedStringArray("res://addons/terrain_3d/plugin.cfg")\n')
print('MERGE_LAYOUT_AND_SEAM_UPDATED; trail core unchanged; collar max correction',float(np.max(np.abs(new-h))))
