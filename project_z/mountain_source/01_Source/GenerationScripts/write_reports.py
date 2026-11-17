"""Summarize measured QA data without inventing performance or accuracy scores."""
import json,hashlib,sys
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[2]
D=ROOT/'09_Documentation'
read=lambda name:json.loads((D/name).read_text())
qa=read('Engine_QA.json');scores=read('Silhouette_Measurements.json');generation=read('Generation_Report.json');source_qa=read('Source_QA.json')
plan=json.loads((ROOT/'01_Source/Parameters/geography.json').read_text())
world=json.loads((ROOT.parent/'Data/world.json').read_text())
sector=json.loads((ROOT.parent/'Data/Sector/sector.json').read_text())
instances=json.loads((ROOT.parent/'Data/Sector/instances.json').read_text())
weather=json.loads((ROOT.parent/'Lighting/presets.json').read_text())

lines=['# Performance report','',f"Measured {qa['capture_date']} on {qa['cpu']} / {qa['gpu']}; Godot {qa['engine']}, {qa['renderer']}, 1920 × 1080.",
       '', 'These are short static runtime samples: 120 process-frame intervals per view/profile after a brief streaming settle. Frame time is wall time between process frames, not a GPU timestamp. The test does not disable display synchronization or control laptop power, temperature, clock speed or background activity. Results near 144 FPS may reflect the display cadence.',
       '', '| View | Profile | Median ms | p95 ms | FPS from median | Reported video MiB | Draw calls | Rendered primitives |',
       '|---|---|---:|---:|---:|---:|---:|---:|']
for p in qa['profiles']:
    lines.append(f"| {p['view']} | {'Development' if p['profile']==0 else 'Cinematic'} | {p['median_ms']:.2f} | {p['p95_ms']:.2f} | {p['fps_from_median']:.1f} | {p['video_memory_mib']:.1f} | {int(p['draw_calls'])} | {int(p['primitives']):,} |")
lines+=['','The video-memory figure is Godot\'s allocation monitor, not the total GPU process residency reported by a driver. Rendered primitives are engine draw counters, not unique source triangles.',
        '', 'These measurements include the supplied asset pass. Urban views now contain real building and vehicle meshes; compare their frame times separately from the distant panorama. Streaming and resource compilation can produce stalls beyond the static medians.',
        '', '## Profiles and working budgets','',
        '| Setting | Development | Cinematic |','|---|---|---|',
        '| Distant LOD screen-error target | 4 px | 1.6 px |',
        '| Native mesh size | 32 | 48 |',
        '| MSAA | 2× | 4× |',
        '| Shadow range / splits | 160 m / 2 | 300 m / 4 |',
        '| Detailed vegetation / undergrowth range | 115 m | 180 m |',
        '| SSAO / volumetric fog | Off | On |',
        '', 'Planning targets are 16.7 ms per frame for development and 33.3 ms for cinematic review at 1080p on this machine. The table above records whether each slice approaches those targets; p95 is relevant even when the median is fast. These are scene targets, not reserved costs for the complete game. Start-up, traversal stalls and worst-case visibility remain unbounded.',
        '', '## Verified behavior','',
        f"Runtime failure list: `{qa['failures']}`. During the test the streamer recorded {qa['streaming']['loads']} loads, {qa['streaming']['unloads']} unloads and {qa['streaming']['lod_transitions']} LOD transitions. All {qa['weather_presets_rendered']} lighting presets rendered.",
        '', 'The full log verifies native terrain standing and ray collision, both sides of a native region boundary, a walk driven by W input, continued ground contact, near-region unload and distant-tile removal. Source QA verifies 264 byte-identical shared tile edges, finite Float32 data and GLB headers/accessors.',
        '', 'Still required: a long instrumented traversal, cold-cache hitch timings, peak RAM/VRAM, worst-case weather and vegetation views, collision against every prop, NPC navigation, and performance of the complete city-plus-mountains gameplay workload. Native/distant interfaces and moving LODs also need a visual camera sweep; source continuity and one boundary test do not prove every runtime seam is invisible.',
        '', 'Raw evidence: `Engine_QA.json`, `Source_QA.json`, `Generation_Report.json`, `engine-qa.log`, `native-build.log` and `city-integration-qa.log`.']
(D/'Performance_Report.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')

lines=['# Reference comparison','', 'Each comparison sheet contains the supplied reference, an actual Godot render, an annotated horizon overlay, and an untextured view. No concept image is substituted for engine output. The same terrain is used for all cameras.',
       '', 'The visible skyline was manually traced in the 1,672 × 941 reference images. Yaw, pitch and vertical FOV were fitted at fixed estimated camera positions. Final measurements use separate actual 1,920 × 1,080 solid-terrain renders. Gold is the reference annotation; cyan is the rendered horizon. Only the explicitly annotated visible spans are scored.',
       '', '| Camera | Columns scored | Vertical MAE, px | Vertical RMSE, px | p95 absolute error, px | Comparison |',
       '|---|---:|---:|---:|---:|---|']
for name,m in scores.items():
    lines.append(f"| {name} | {m['evaluated_columns']} | {m['vertical_mae_pixels']:.1f} | {m['vertical_rmse_pixels']:.1f} | {m['p95_absolute_pixels']:.1f} | [Sheet](../08_Reference_Validation/{name}/comparison.png) |")
lines+=['','Manual trace uncertainty is roughly 5–15 px at original resolution. Occluded and unannotated spans are excluded. These are vertical image-space errors after camera fitting; they are not independent validation of a surveyed landscape, an accuracy percentage, or a score for materials, snow, lighting, city proportions or photographic realism.',
        '', '## Visible deviations','',
        '- The central range has a coherent broad skyline, but its major faces are smoother and less geologically varied than the references. More branching ridges, exposed cliffs and erosion detail are needed.',
        '- Urban foregrounds use supplied terminal, station, government and residential models, with evacuation traffic and props. The layout, surface weathering, distant skyline density and lighting still differ substantially from the photographic references.',
        '- The panorama remains substantially elevated above local ground. The hillside camera is now grounded at terrain plus 1.9 m; railway and panorama viewpoints remain composition estimates. A matching horizon does not resolve those camera and terrain ambiguities.',
        '- Supplied mature conifers, firs, shrubs, grass, deadwood and granite replace the initial vegetation proxies. Their procedural source art, density and material repetition remain visible limitations. Terrain snow is a continuous shader approximation; foliage switches to the supplied winter model. There is no volumetric snow depth or glacier geometry.',
        '- Cloud cards and the sky blend provide weather context but do not reproduce the reference cloud shapes, detailed scattering or moving cloud shadows.',
        '', '## Acceptance status','',
        '| Criterion | Current result |','|---|---|',
        '| One shared physical range / five cameras | Implemented and rendered |',
        '| Editable terrain, Float32 sources and GLBs | Implemented; source checks pass |',
        '| Walking, collision, native-region boundary | Runtime checks pass |',
        '| LOD and resource streaming | Runtime activity and unload verified; exhaustive visual sweep outstanding |',
        '| Seasons and eight lighting presets | Rendered; physical weather simulation not implemented |',
        '| Exact atlas coastline / all island regions | Planning approximation only |',
        '| Reference photorealism and geological benchmark | Not achieved; production art work remains |',
        '| Complete 64 km² release gameplay | Not implemented |',
        '| Full-game performance guarantee | Not established |',
        '', 'The result is the requested first playable prototype and an editable basis for the next art pass. It is not accepted as a finished AAA mountain sector.',
        '', '![Camera contact sheet](../08_Reference_Validation/Contact_Sheet.png)',
        '', '![Integration in the existing city](../08_Reference_Validation/Existing_City_Integration.png)']
(D/'Reference_Comparison.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')

manifest={'schema':1,'name':'Project Z — Kaldran Mountain Spine','status':'first playable prototype; final AAA art target not achieved',
 'engine':qa['engine'],'renderer':qa['renderer'],'tested_platform':'Windows x64','native_terrain':'Terrain3D 1.1.0 (MIT)',
 'units':'metres; +X east, -Z north, +Y elevation ASL','capital_datum_m':320,
 'lore':plan['lore'],'regions':plan['regions'],'central_source':{'side_samples':1537,'spacing_m':32,'type':'little-endian Float32','bounds':world['domain'],'sha256':generation['height_sha256']},
 'background':{'tiles':144,'meshes':432,'tile_size_m':4096,'lod_spacing_m':[64,128,256],'collision':False,'load_method':'threaded native resources','morph_seconds':.45,'edge_skirt_m':180},
 'near_sector':{k:sector[k] for k in ['west','north','size','spacing','samples','core','spawn','trail_length_m','trail_max_grade','trail_max_earthwork_m']},
 'native_regions':{'count':9,'region_samples':512,'vertex_spacing_m':2,'collision_radius_m':96,'collision_shape_size':32},
 'instances':{'trees_total_in_collar':len(instances['trees']),'rocks_in_core':len(instances['rocks']),'stream_chunk_m':64,'max_ecology_distance_m':1550,'user_asset_placements':read('User_Asset_Placement.json')},
 'materials':{'library_entries':15,'photographic_sets':2,'procedural_sets':13,'runtime_map_size':512,'custom_shader_uses_all_painted_layers':False},
 'cameras':world['cameras'],'weather_presets':[p['name'] for p in weather],
 'runtime_qa':qa,'source_qa':source_qa,'hydrology':{'d8_uphill_edges':generation['d8_uphill_edges'],'interior_closed_cells':generation['interior_closed_cells'],'resolved_water_geometry':False},
 'navigation':{'npc_navmesh_baked':False,'walker_max_floor_degrees':46},
 'city_integration':{'scene':'scenes/world/kaldran_city.tscn','default_scene_changed':True,'height_offset_m':-320,'collar_collision':False,'continuous_city_to_sector_route':False,'menu_travel_to_trail':True,'shared_resources':True},
 'blender':{'blend_file_delivered':False,'glb_interchange_delivered':True,'reason':'Blender unavailable; real editable Godot resources and GLBs supplied'},
 'remaining':['geological sculpting','production vegetation and material art','precise city foregrounds and terrain grading','hydrology and water geometry','visual LOD sweep and long profiling','NPC navigation','full release-region expansion']}
(D/'Technical_Manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')

hashes={}
for folder in [ROOT/'04_Materials/Photogrammetry',ROOT.parent/'Lighting',ROOT.parent/'Meshes/Vegetation',ROOT.parent/'addons/terrain_3d/bin']:
    for p in folder.rglob('*'):
        if p.is_file() and p.suffix.lower() in ['.jpg','.png','.hdr','.glb','.dll']:
            hashes[str(p.relative_to(ROOT.parent)).replace('\\','/')]=hashlib.sha256(p.read_bytes()).hexdigest()
(D/'Asset_Hashes.json').write_text(json.dumps(hashes,indent=2))
for region in plan['regions']:
    directory=ROOT/'02_Terrain'/region['id']
    (directory/'region.json').write_text(json.dumps(region,indent=2))
    text='Central terrain sources and native runtime resources are delivered; see the package README.' if region['state']=='prototype' else 'Planning metadata only. No finished or playable terrain for this region is claimed. See Geography_Constraints.md.'
    (directory/'README.md').write_text('# '+region['id'].replace('_',' ')+'\n\n'+text+'\n')

font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',19)
board=Image.new('RGB',(1920,1260),'#111d25');draw=ImageDraw.Draw(board)
draw.text((24,18),'KALDRAN / EIGHT LIGHTING PRESETS / ACTUAL GODOT CAPTURES',font=font,fill='#e7c186')
for i,preset in enumerate(weather):
    x=(i%3)*640;y=60+(i//3)*395
    shot=ROOT/'08_Reference_Validation/Weather'/f'{i:02d}.png'
    board.paste(Image.open(shot).resize((640,360),Image.Resampling.LANCZOS),(x,y))
    draw.text((x+14,y+366),preset['name'],font=font,fill='white')
board.save(ROOT/'08_Reference_Validation/Weather/Contact_Sheet.png')
print('Wrote measured reports, technical manifest, region metadata and asset hashes.')
