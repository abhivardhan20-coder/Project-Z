"""Download the exact CC0 surfaces used by the near material; verify source hashes."""
from pathlib import Path
import urllib.request,json,hashlib,concurrent.futures,sys
from PIL import Image
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'04_Materials/Photogrammetry'
OUT.mkdir(parents=True,exist_ok=True)
HEADERS={'User-Agent':'Project Z terrain prototype (local asset download)'}
OFFLINE='--offline' in sys.argv

def get(url):
    return urllib.request.urlopen(urllib.request.Request(url,headers=HEADERS),timeout=45).read()

def fetch(asset):
    if OFFLINE:
        cached=json.loads((OUT/'sources.json').read_text())
        info={}
        for label,token in [('Diffuse','_diff_'),('nor_gl','_nor_gl_'),('Rough','_rough_')]:
            record=next(r for r in cached if r['source'].endswith('/'+asset) and token in r['file'])
            info[label]={'1k':{'jpg':record}}
    else:
        info=json.loads(get('https://api.polyhaven.com/files/'+asset))
    records=[];images={}
    for label in ['Diffuse','nor_gl','Rough']:
        key=label if label in info else label.lower()
        file=info[key]['1k']['jpg'];path=OUT/file['url'].split('/')[-1]
        if not path.exists():
            if OFFLINE:raise FileNotFoundError('Bundled source missing: '+str(path))
            path.write_bytes(get(file['url']))
        digest=hashlib.md5(path.read_bytes()).hexdigest()
        if digest!=file['md5']:raise RuntimeError('Source checksum failed: '+path.name)
        records.append({'file':path.name,'url':file['url'],'md5':digest,'license':'CC0-1.0','source':'https://polyhaven.com/a/'+asset})
        images[label]=np.asarray(Image.open(path).convert('RGB').resize((512,512),Image.Resampling.LANCZOS))
    destination=ROOT.parent/'materials/Textures'
    prefix='granite' if asset=='rock_face_03' else 'grass'
    Image.fromarray(np.dstack([images['Diffuse'],np.full((512,512),128,dtype=np.uint8)])).save(destination/f'{prefix}_albedo.png')
    Image.fromarray(np.dstack([images['nor_gl'],images['Rough'][:,:,0]])).save(destination/f'{prefix}_normal_roughness.png')
    print('Packed CC0 material '+asset,flush=True)
    return records

if __name__=='__main__':
    records=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        for batch in pool.map(fetch,['rock_face_03','rocky_terrain']):records.extend(batch)
    (OUT/'sources.json').write_text(json.dumps(records,indent=2))
    library_path=ROOT/'04_Materials/material_library.json'
    library=json.loads(library_path.read_text())
    for item in library:
        if item['name'] in ['granite','grass']:
            asset='rock_face_03' if item['name']=='granite' else 'rocky_terrain'
            item.update(source='https://polyhaven.com/a/'+asset,license='CC0-1.0',
                        status='Photographic base color, OpenGL normal and roughness; 1K sources packed to 512px runtime maps')
    library_path.write_text(json.dumps(library,indent=2))
