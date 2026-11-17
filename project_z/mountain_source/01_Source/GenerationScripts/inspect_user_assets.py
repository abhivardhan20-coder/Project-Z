"""Inspect user-supplied archives without executing any bundled scripts."""
from pathlib import Path
import zipfile,json,struct,tempfile,shutil,re
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'01_Source/AssetIntake'
OUT.mkdir(exist_ok=True)
LOCAL=Path(r'C:\Users\abhi\OneDrive\Desktop\Project Z (Godot)\PROJECT_Z')

def inspect_glb(stream):
    header=stream.read(20)
    magic,version,total,length,kind=struct.unpack('<4sIIII',header)
    if magic!=b'glTF' or version!=2:raise ValueError('Not GLB 2.0')
    doc=json.loads(stream.read(length))
    meshes=doc.get('meshes',[]);acc=doc.get('accessors',[])
    tris=sum((acc[p['indices']]['count'] if 'indices' in p else acc[p['attributes']['POSITION']]['count'])//3 for m in meshes for p in m['primitives'] if p.get('mode',4)==4)
    return {'bytes':total,'mesh_count':len(meshes),'nodes':len(doc.get('nodes',[])),
            'triangles_in_mesh_library':tris,'materials':len(doc.get('materials',[])),
            'images':len(doc.get('images',[])),'external_uris':[v['uri'] for key in ['images','buffers'] for v in doc.get(key,[]) if 'uri' in v and not v['uri'].startswith('data:')],
            'mesh_names':[n.get('name','') for n in meshes][:15],
            'generator':doc.get('asset',{}).get('generator','')}

def main():
    records=[]
    for part in [1,2]:
        archive=Path(fr'C:\Users\abhi\Downloads\Telegram Desktop\Kaldran_Assets_Part{part}.zip')
        with zipfile.ZipFile(archive) as outer:
            for item in outer.infolist():
                if item.is_dir():continue
                record={'part':part,'outer_entry':item.filename,'bytes':item.file_size,'files':[],'models':[]}
                if item.filename.lower().endswith('.zip'):
                    with tempfile.SpooledTemporaryFile(max_size=32*1024**2,dir=OUT) as cache:
                        with outer.open(item) as src:shutil.copyfileobj(src,cache,4*1024**2)
                        cache.seek(0)
                        with zipfile.ZipFile(cache) as inner:
                            record['files']=[{'path':f.filename,'bytes':f.file_size} for f in inner.infolist() if not f.is_dir()]
                            for entry in inner.infolist():
                                if entry.filename.lower().endswith('.glb'):
                                    with inner.open(entry) as f:
                                        record['models'].append({'path':entry.filename,**inspect_glb(f)})
                elif item.filename.lower().endswith('.glb'):
                    with outer.open(item) as f:record['models'].append({'path':item.filename,**inspect_glb(f)})
                records.append(record)
                print(part,Path(item.filename).name,[(Path(m['path']).name,m['triangles_in_mesh_library']) for m in record['models'][:5]],flush=True)
    (OUT/'Archive_Model_Catalog.json').write_text(json.dumps(records,indent=2))
    local=[]
    for path in LOCAL.rglob('*.glb'):
        if '.godot' in path.parts:continue
        if not re.search(r'pz_(127|128|129|130|131|136|137|138|174|175|032|033)_',str(path)):continue
        if 'collision' in str(path).lower():continue
        with path.open('rb') as f:local.append({'path':str(path),**inspect_glb(f)})
    (OUT/'Local_Model_Catalog.json').write_text(json.dumps(local,indent=2))
    print('INVENTORY_COMPLETE',len(records),'archive packages;',len(local),'relevant local models',flush=True)

if __name__=='__main__':main()
