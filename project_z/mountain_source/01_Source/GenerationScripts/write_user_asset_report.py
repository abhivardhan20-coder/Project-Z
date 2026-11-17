"""Audit selected copies and document the actual user-asset integration."""
from pathlib import Path
import json,hashlib,struct,collections

ROOT=Path(__file__).resolve().parents[2];GAME=ROOT.parent;DOC=ROOT/'09_Documentation'
read=lambda p:json.loads(p.read_text())
selected=read(GAME/'assets/User/catalog.json');baked=read(GAME/'assets/Baked/catalog.json')
placement=read(DOC/'User_Asset_Placement.json');qa=read(DOC/'User_Asset_QA.json')
runtime=read(DOC/'Engine_QA.json');instances=read(GAME/'Data/Sector/instances.json')
families=collections.defaultdict(list)
errors=[]
for row in selected:
    families[row['key']].append(row)
    p=GAME/row['path'].removeprefix('res://');raw=p.read_bytes()
    if hashlib.sha256(raw).hexdigest()!=row['adapted_sha256']:errors.append('Checksum '+row['key'])
    magic,version,length=struct.unpack_from('<4sII',raw)
    if magic!=b'glTF' or version!=2 or length!=len(raw):errors.append('GLB header '+row['key'])
    size=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+size])
    refs=collections.Counter(child for n in g.get('nodes',[]) for child in n.get('children',[]))
    if any(n>1 for n in refs.values()):errors.append('Shared child nodes '+row['key'])
    if any('uri' in im and not im['uri'].startswith('data:') for im in g.get('images',[])):errors.append('External image '+row['key'])
if errors:raise RuntimeError(errors)
integrity={'optimized_glbs':len(selected),'checks':['SHA-256 against intake record','glTF 2.0 header and byte length','unique parent per node','embedded texture references'],'failures':errors}
(DOC/'User_Asset_Source_QA.json').write_text(json.dumps(integrity,indent=2))

excluded=read(ROOT/'01_Source/AssetIntake/Excluded_Packages.json')
for record in excluded:
    name=Path(record['package']).name
    if name.startswith(('AIR-05','AIR-06','AIR-07','AIR-09','AIR-12')):reason='Secondary airport facility outside the authored evacuation-highway and terminal review area.'
    elif name.startswith('RAIL-05'):reason='Alternate full station overlaps the selected grand roof and concourse.'
    elif name.startswith('RAIL-07'):reason='Interior retail content is not needed for the outdoor railway composition.'
    elif name.startswith('HIL-04'):reason='Duplicate or older variant; the reference-refined v02 package is selected.'
    elif name.startswith('HIL-08'):reason='Additional residential content is outside the selected street frontage.'
    elif name.lower().endswith('.glb'):reason='Standalone high-detail vehicle or alternate model; selected local vehicles provide the required traffic at lower resource cost.'
    else:reason='Duplicate or secondary content not needed by the authored districts and walking sector.'
    record['reason']=reason
(ROOT/'01_Source/AssetIntake/Excluded_Packages.json').write_text(json.dumps(excluded,indent=2))

total=placement['authored_placements']+placement['background_buildings']+placement['undergrowth_instances']+len(instances['trees'])+len(instances['rocks'])
lines=['# Supplied asset integration','',
 f"Integrated **{len(families)} asset families / {len(selected)} optimized GLBs** from the two Kaldran archives and the local Godot asset project. Originals remain unchanged. The delivered copy contains {placement['authored_placements']} authored object placements, {placement['background_buildings']:,} distant buildings, {len(instances['trees']):,} conifers, {len(instances['rocks']):,} rocks and {placement['undergrowth_instances']:,} understory/deadwood placements ({total:,} placement records in total). Streaming and distance detail select which are active.",
 '', '## What was placed','',
 '| Scene | Supplied assets |','|---|---|',
 '| Airport | Terminal, canopy, gate pier, control tower, parking garage, evacuation cabins and tents; road, cars, police, buses, ambulance, luggage and wreckage |',
 '| Railway | Grand arch, concourse, platform canopy, signal building, bus shelter, footbridge, park-and-ride, transit police, twelve train carriages and evacuation traffic |',
 '| Hillside | Balcony and terraced apartments, corner housing, rowhouses, shops, parking shed, playground pavilion, trees and street props |',
 '| Capitol | Assembly hall, ministry wings, midrise blocks, boulevard trees, traffic and emergency staging |',
 '| Crown Approach | Mature pine LODs, winter pines, alpine fir, juniper, fern, grass, lichen, four granite/moss forms, logs, stumps and roots; radio hut/tower and static cable station |',
 '', '## Adaptations','',
 '- Embedded textures are limited to 512 px for most mid/far assets and 1024 px for selected close assets. Geometry, material slots and metre scale are preserved in the copied GLBs.',
 '- Native meshes combine static parts by material/vertex format and generate mesh LODs, normals and tangents. Unused custom vertex channels are removed. Source animations remain in the GLBs; these background placements use static geometry.',
 '- AIR08 had shared children under orphan source parents. The copied hierarchy is made a valid tree without changing visible geometry.',
 '- HIL10, the alpine kit, radio hut/tower, and three local vehicles require an up-axis correction. Native pivots are normalized to ground centre, with the same family offset retained across LODs.',
 '- The alpine atlas uses bottom-up V coordinates. Correcting its UVs and tangent handedness restores the foliage cutouts instead of sampling opaque stone tiles.',
 '- The road kit is widened across the street and aligned to a graded longitudinal profile. Traffic follows that profile. Foundations bridge uneven ground beneath larger buildings; the terrain source itself is unchanged.',
 '- Buildings have authored LOD/HLOD distance bands. Distant buildings use saved instance buffers, verified after loading. The four main districts load asynchronously, with distant landmarks present while their detailed scenes are unloaded.',
 '- Trees and rocks stream in 64 m cells. Near trees and deadwood/rocks have collision. Understory avoids the trail and steep slopes. Terrain snow blends continuously; the provided winter tree model switches during the winter phase.',
 '', '## Editable files','',
 '- `scenes/Districts/`: Airport, Railway, Hillside, Capitol, Alpine and Background scenes. Building and prop nodes can be moved directly in Godot.',
 '- `Data/asset_placements.json`: reproducible placement authority; `Data/Sector/undergrowth.json` holds trail dressing.',
 '- `assets/User/catalog.json`: exact original local path or archive/package/member, original and adapted SHA-256, texture changes and model statistics.',
 '- `assets/Baked/catalog.json`: native resource, combined surface counts, normalized bounds and source correspondence.',
 '- `01_Source/AssetIntake/Excluded_Packages.json`: packages left out; `Unused_Modules.json`: evaluated facade pieces that were not needed. Other local asset families were not copied.',
 '', '## Verification and limits','',
 f"Source integrity failures: {integrity['failures']}. Native asset check failures: {qa['failures']}. Runtime failures: {runtime['failures']}. The asset test checks normals, normal-map tangents, selected metre-scale/up-axis dimensions, resource links, and {qa.get('saved_transforms_checked',0)} persisted distant transforms. The full runtime test captures all five views and eight weather presets and checks standing, walking, boundary collision and terrain/district streaming.",
 '', 'See `Performance_Report.md` for actual 1080p static frame samples, including the four detailed urban views. They are not a complete traversal, load-time or full-game benchmark.',
 '', 'The distant city remains sparse, repetitive context with simplified supplied HLODs. Source-model art, street composition, weathering, terrain detail and lighting do not yet match the photographic references. Urban streets are review compositions, not a completed navigable city; the tested walking gameplay remains the mountain sector. The cable station is a static landmark, not an operating transport system.',
 '', 'ChatGPT Library-only models were not accessed. Computer use stopped when browser URL verification could not be completed; all integrated models come from the supplied local sources. No source generation script from an asset archive was executed.',
 '', 'User-provided models retain their source terms and are not reclassified as CC0. The existing third-party terrain/material/sky credits remain in `Asset_Provenance.md`.',
 '', '## Family register','', '| Family | Variants | Original source |','|---|---|---|']
for key,items in sorted(families.items()):
    src=items[0]['source'];label=Path(src.get('package',src.get('file',''))).name
    lines.append(f"| {key} | {', '.join(r['variant'] for r in items)} | {label} |")
(DOC/'User_Asset_Integration.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(json.dumps({'families':len(families),'GLBs':len(selected),'total_placement_records':total,'source_checks':integrity,'native_checks':qa},indent=2))
