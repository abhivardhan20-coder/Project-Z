"""Prepare original shaders, clearly licensed local assets, and camera scene wrappers."""
from pathlib import Path
import shutil, json
from PIL import Image
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
P=ROOT.parent
source=(P/'addons/terrain_3d/extras/shaders/minimum.gdshader').read_text(encoding='utf-8')
source=source.replace('// Public uniforms','#include "res://Shaders/alpine_surface.gdshaderinc"\n\n// Public uniforms')
source=source.replace('ALBEDO = vec3(.2);\n\tROUGHNESS = .7;',
'''vec4 surface = pz_surface(v_vertex, normalize(w_normal), length(v_camera_pos-v_vertex));
	ALBEDO = surface.rgb;
	ROUGHNESS = surface.a;
	NORMAL = normalize(mat3(VIEW_MATRIX) * pz_detail_normal(v_vertex, normalize(w_normal), length(v_camera_pos-v_vertex)));
	SPECULAR = .25;''')
source=source.replace('void fragment() {', 'void fragment() {\n\tvec2 border = min(v_vertex.xz-sector_rect.xy,sector_rect.xy+sector_rect.zw-v_vertex.xz);\n\tif(min(border.x,border.y)<320.0) {discard;}')
source=source.replace('void fragment() {', 'void fragment() {\n\tvec2 focus = abs(v_vertex.xz-v_camera_pos.xz);\n\tif(max(focus.x,focus.y)>1864.0) {discard;}')
(P/'Shaders/native_alpine.gdshader').write_text(source,encoding='utf-8')
m=ROOT/'05_Terrain_Masks/Capital'
a=np.stack([np.array(Image.open(m/f'{n}.png')) for n in ['curvature','moisture','snow']],axis=-1)
Image.fromarray(a).save(P/'Data/terrain_aux.png')
local=ROOT.parent
(P/'Lighting').mkdir(exist_ok=True)
for name in ['qwantani_dusk_2_puresky.hdr','kloofendal_overcast_puresky.hdr']:
    if not (P/'Lighting'/name).exists():shutil.copy2(local/'assets/city'/name,P/'Lighting'/name)
(P/'Meshes/Vegetation').mkdir(exist_ok=True)
if (local/'assets/vegetation').exists():
    for f in (local/'assets/vegetation').iterdir():
        if f.suffix in ['.glb','.jpg'] and not (P/'Meshes/Vegetation'/f.name).exists():shutil.copy2(f,P/'Meshes/Vegetation'/f.name)
templates=ROOT/'01_Source/TerrainGenerators/SkyTemplates'
source=(templates/'sky.gdshader').read_text().replace('res://materials/ultra/weather.gdshaderinc','res://Shaders/weather.gdshaderinc')
source=source.replace('storm_weight * photo_mask * 0.51','photo_mask * (0.66 + storm_weight * 0.24)')
source=source.replace('pow(max(overcast, vec3(0.0)), vec3(1.55)) * vec3(0.44, 0.56, 0.73)','overcast * mix(vec3(0.88, 0.93, 1.0), vec3(0.25, 0.34, 0.48), storm_weight)')
(P/'Shaders/sky.gdshader').write_text(source)
source=(templates/'weather.gdshaderinc').read_text()
source='\n'.join(line for line in source.splitlines() if not line.startswith('global uniform'))
(P/'Shaders/weather.gdshaderinc').write_text(source)
(P/'Camera_Matching').mkdir(exist_ok=True)
plan=json.loads((ROOT/'01_Source/Parameters/geography.json').read_text())
for i,camera in enumerate(plan['cameras']):
    (P/'Camera_Matching'/f'{camera["id"]}.tscn').write_text(f'''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/world.gd" id="1"]
[node name="{camera['id']}Validation" type="Node3D"]
script = ExtResource("1")
initial_camera = {i}
''')
print('Prepared native shader, CC0 vegetation/sky inputs and five camera scenes.')
