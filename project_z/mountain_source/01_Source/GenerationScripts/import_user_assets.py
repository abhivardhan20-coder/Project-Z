"""Select and adapt the user's real GLBs; never run bundled generation scripts.

Original archives and local models remain untouched. Runtime copies keep geometry,
materials, pivots and UVs, with bounded embedded texture resolution.
"""
from pathlib import Path
import io,json,struct,zipfile,tempfile,shutil,hashlib,re,sys,copy
from PIL import Image
from inspect_user_assets import ROOT,LOCAL,inspect_glb

INTAKE=ROOT/'01_Source/AssetIntake'
DEST=ROOT.parent/'assets/User'
DEST.mkdir(parents=True,exist_ok=True)
ARCHIVES={
 'AIR01':(1,'AIR-01_Kaldran_Terminal_REFIT_03.zip',[1,2,'HLOD']),
 'AIR02':(2,'AIR-02_Reference_Faithful_Rebuild_v2_1.zip',[2]),
 'AIR03':(1,'AIR-03_Reference_Reconstruction_v3.zip',[2,'HLOD']),
 'AIR04':(1,'AIR-04_Kaldran_Control_Tower_3D_Package.zip',[2,'HLOD']),
 'AIR08':(2,'AIR-08_Terminal_Parking_Structure_V03.zip',[2,'HLOD']),
 'AIR10':(2,'AIR-10_Refined_v2_Production.zip',[2,'HLOD']),
 'AIR11':(1,'AIR-11_Production_Package.zip',[2]),
 'CIV01':(1,'CIV-01_Kaldran_Capitol_Assembly_Hall_v02.zip',[1,2,'HLOD']),
 'CIV03':(1,'CIV-03_v3_Full_Reconstruction.zip',[2]),
 'HIL01':(1,'HIL-01_V3_BALANCED.zip',[0,'HLOD']),
 'HIL02':(2,'HIL-02_ReferenceRefined_v2_FULL.zip',[1,2,'HLOD']),
 'HIL03':(1,'HIL-03_Asset_Package.zip',[2]),
 'HIL04':(1,'HIL-04_Reference_Refined_v02.zip',[1,2,'HLOD']),
 'HIL05':(2,'HIL-05_Powered_Storefront_Full_Package.zip',[2,'HLOD']),
 'HIL06':(2,'HIL-06_v4_Full_Asset_Package.zip',[2,'HLOD']),
 'HIL07':(2,'HIL-07_Refined_Complete_Package.zip',[2]),
 'HIL09':(2,'HIL-09_Full_Asset_Package.zip',[2,'HLOD']),
 'HIL10':(1,'HIL-10_Full_Production_Package.zip',[2,'HLOD']),
 'RAIL01':(1,'RAIL-01_v02_REFINED_FULL_PACKAGE.zip',[1,2,'HLOD']),
 'RAIL02':(1,'RAIL-02_V3_Fixed_Escalators_and_Interior.zip',[2,'HLOD']),
 'RAIL03':(1,'RAIL-03_Kaldran_Full_Asset_Package.zip',[2,'HLOD']),
 'RAIL04':(1,'RAIL-04_Refined_Doors_and_Facade_v5.zip',[2]),
 'RAIL06':(1,'RAIL-06_ReferenceRefined_v2_Godot4.zip',[2,'HLOD']),
 'RAIL08':(1,'RAIL-08_Refined_v04_FULL.zip',[2,'HLOD']),
 'RAIL09':(2,'RAIL-09_Kaldran_Park_and_Ride_Garage_v02_Connected_Ramps.zip',[2]),
 'RAIL10':(1,'RAIL-10_Transit_Police_First_Aid_Refined_v02.zip',[2,'HLOD']),
 'AMBULANCE':(1,'Shvan92_Ambulance_Upgrade_Package.zip',['single'])
}
LOCAL_FILES={
 'PINE0':'ProjectZ_PINE10_Conifer_Summer_LOD0.glb','PINE1':'ProjectZ_PINE10_Conifer_Summer_LOD1.glb',
 'WINTER_PINE':'ProjectZ_PINE10_Conifer_Winter_LOD1.glb',
 'OAK':'PROJECT_Z_Temperate_Oak_Tree_LOD2.glb',
 'FIR':'PZ_ALP_02_Young_Alpine_Fir_2p2m.glb','FIR_LOW':'PZ_ALP_LOD1_12_Alpine_Fir.glb',
 'JUNIPER':'PZ_ALP_05_Low_Juniper_Shrub.glb','GRASS':'PZ_ALP_07_Dry_Tussock_Grass_Silver.glb',
 'FERN':'FERN_02_Woodland_Fan.glb','LICHEN':'PZ_ALP_08_Crust_Lichen_GroundPatch.glb',
 'ROCK1':'PZ_R02_Angular_Fieldstone_Granite.glb','ROCK2':'PZ_R06_Layered_Shale_Boulder_Granite.glb',
 'ROCK3':'PZ_R07_Fractured_Outcrop_Granite.glb','ROCK4':'PZ_R08_Massive_Moss_Boulder_Moss.glb',
 'LOG':'PZ_FallenWood_01_FallenPine_Log_3p6m.glb','STUMP':'PZ_FallenWood_06_Splintered_RottenStump_1p1m.glb',
 'ROOTS':'PZ_FallenWood_08_ExposedRootSnarl_1p8m.glb',
 'CABLE_STATION':'PROJECT_Z_Mountain_Cable_Car_Station.glb',
 'RADIO_HUT':'PZ_RAD_03_Accessible_Maintenance_Hut.glb',
 'RADIO_TOWER':'PZ_RAD_01_Telecom_Lattice_Tower_29m.glb',
 'MIDRISE':'PZ_Midrise_SIX_FLOOR_Assembly_Reference.glb',
 'ROAD':'PROJECT_Z_Road_Straight_Asphalt_10m.glb',
 'BUS':'PROJECT_Z_City_Bus.glb','SEDAN':'PROJECT_Z_Unbranded_2026_Sedan_CloseUp.glb',
 'POLICE':'PROJECT_Z_Police_Patrol_Sedan.glb',
 'TRAIN':'PROJECT_Z_Metro_Train_Carriage.glb',
 'BENCH':'PZ_GCR_12_Platform_Bench_Bin.glb',
 'SUITCASE':'KAL-01_v03_Suitcase_Open_Hero.glb',
 'BARRIER':'ProjectZ_CBW26_CrashBarrierWreckage.glb',
}

def repack_glb(raw,limit):
    jlen=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+jlen]);start=20+jlen
    # Some supplied parking assets reuse one node under two parents. glTF requires
    # a tree: clone node hierarchies, preserving shared mesh/material resources.
    seen=set();clones=0
    def unique_node(index,ancestry):
        nonlocal clones
        if index in ancestry:raise ValueError('Cyclic source node hierarchy')
        original=index
        if index in seen:
            doc['nodes'].append(copy.deepcopy(doc['nodes'][index]));index=len(doc['nodes'])-1;clones+=1
        seen.add(index);node=doc['nodes'][index]
        if 'children' in node:node['children']=[unique_node(c,ancestry|{original}) for c in node['children']]
        return index
    for scene in doc.get('scenes',[]):
        scene['nodes']=[unique_node(n,set()) for n in scene.get('nodes',[])]
    for i,node in enumerate(doc.get('nodes',[])):
        if i not in seen:node.pop('children',None)
    doc.setdefault('extras',{})['project_z_node_clones']=clones
    binlen=struct.unpack_from('<I',raw,start)[0];binary=raw[start+8:start+8+binlen]
    replacements={};changes=[]
    for image in doc.get('images',[]):
        if 'bufferView' not in image:continue
        view=doc['bufferViews'][image['bufferView']];at=view.get('byteOffset',0)
        blob=binary[at:at+view['byteLength']]
        im=Image.open(io.BytesIO(blob))
        if max(im.size)<=limit:continue
        original=im.size;im.thumbnail((limit,limit),Image.Resampling.LANCZOS)
        target=io.BytesIO()
        fmt='PNG' if im.mode in ('RGBA','LA','P') else 'JPEG'
        if fmt=='JPEG':im.convert('RGB').save(target,format=fmt,quality=91)
        else:im.save(target,format=fmt,optimize=True)
        image['mimeType']='image/png' if fmt=='PNG' else 'image/jpeg'
        replacements[image['bufferView']]=target.getvalue();changes.append([list(original),list(im.size)])
    parts=[];offset=0
    for index,view in enumerate(doc.get('bufferViews',[])):
        at=view.get('byteOffset',0);blob=replacements.get(index,binary[at:at+view['byteLength']])
        view['byteOffset']=offset;view['byteLength']=len(blob);view['buffer']=0
        padded=blob+b'\0'*((-len(blob))%4);parts.append(padded);offset+=len(padded)
    doc['buffers']=[{'byteLength':offset}]
    j=json.dumps(doc,separators=(',',':')).encode();j+=b' '*((-len(j))%4);b=b''.join(parts)
    output=struct.pack('<4sII',b'glTF',2,28+len(j)+len(b))+struct.pack('<I4s',len(j),b'JSON')+j+struct.pack('<I4s',len(b),b'BIN\0')+b
    return output,changes,clones

def main():
    catalog=json.loads((INTAKE/'Archive_Model_Catalog.json').read_text());index=[];selections={}
    only=set(sys.argv[sys.argv.index('--keys')+1].split(',')) if '--keys' in sys.argv else None
    if only and (DEST/'catalog.json').exists():index=[r for r in json.loads((DEST/'catalog.json').read_text()) if r['key'] not in only]
    def save(key,variant,raw,provenance,limit):
        output,changes,clones=repack_glb(raw,limit);path=DEST/f'{key}_{variant}.glb';path.write_bytes(output)
        info=inspect_glb(io.BytesIO(output));assert not info['external_uris'],(key,info['external_uris'])
        index.append({'key':key,'variant':variant,'path':'res://assets/User/'+path.name,'source':provenance,
                      'source_sha256':hashlib.sha256(raw).hexdigest(),'adapted_sha256':hashlib.sha256(output).hexdigest(),
                      'texture_resizes':changes,'texture_limit':limit,'shared_nodes_repaired':clones,**info})
        selections.setdefault(key,[]).append(variant)
        print(key,variant,info['triangles_in_mesh_library'],'triangles',round(len(output)/1048576,1),'MiB',flush=True)
    for part in [1,2]:
        archive=Path(fr'C:\Users\abhi\Downloads\Telegram Desktop\Kaldran_Assets_Part{part}.zip')
        with zipfile.ZipFile(archive) as outer:
            for key,(part_id,name,lods) in ARCHIVES.items():
                if only and key not in only:continue
                if part_id!=part:continue
                record=next(r for r in catalog if r['part']==part and Path(r['outer_entry']).name==name)
                with tempfile.SpooledTemporaryFile(max_size=32*1024**2,dir=INTAKE) as cache:
                    with outer.open(record['outer_entry']) as f:shutil.copyfileobj(f,cache,4*1024**2)
                    cache.seek(0)
                    with zipfile.ZipFile(cache) as inner:
                        for lod in lods:
                            token='LOD'+str(lod) if isinstance(lod,int) else lod
                            candidates=[m for m in record['models'] if token=='single' or token in Path(m['path']).stem]
                            if not candidates:continue
                            chosen=min(candidates,key=lambda m:len(m['path']))
                            raw=inner.read(chosen['path']);variant=token.lower()
                            save(key,variant,raw,{'archive':str(archive),'package':record['outer_entry'],'entry':chosen['path']},1024 if lod in [0,1,'single'] else 512)
    local=list(LOCAL.rglob('*.glb'))
    for key,name in LOCAL_FILES.items():
        if only and key not in only:continue
        candidates=[p for p in local if p.name==name and 'collision' not in str(p).lower()]
        if not candidates:
            print('SKIP missing optional local asset',key,name,flush=True);continue
        path=candidates[0];save(key,'local',path.read_bytes(),{'file':str(path)},1024 if key in ['PINE0','ROCK1','ROCK2','ROCK3','ROCK4','LOG'] else 512)
    (DEST/'catalog.json').write_text(json.dumps(index,indent=2))
    (INTAKE/'Selected_Assets.json').write_text(json.dumps(index,indent=2))
    excluded=[{'part':r['part'],'package':r['outer_entry'],'reason':'Duplicate variant, secondary facility outside current review areas, interior-only content, or high-cost vehicle not needed by this mountain pass'} for r in catalog if not any(v[0]==r['part'] and v[1]==Path(r['outer_entry']).name for v in ARCHIVES.values())]
    (INTAKE/'Excluded_Packages.json').write_text(json.dumps(excluded,indent=2))
    print('ASSET_IMPORT_COMPLETE',len(index),'GLBs;',len(selections),'asset families',flush=True)

if __name__=='__main__':main()
