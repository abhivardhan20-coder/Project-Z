"""Verify precision, tile continuity, bounds, camera clearance and source meshes."""
import json,struct,hashlib
import numpy as np
from terrain_model import ROOT,PLAN,sample

data=ROOT.parent/'Data'
world=json.loads((data/'world.json').read_text())
h=np.fromfile(data/'capital_height.f32',dtype='<f4').reshape(1537,1537)
assert np.isfinite(h).all() and h.max()<=3415.01
tile_edges=0
for tile in world['tiles']:
    a=np.fromfile(data/'Tiles'/f"{tile['id']}.f32",dtype='<f4').reshape(129,129)
    x,z=map(int,tile['id'].split('_'))
    assert np.array_equal(a,h[z*128:z*128+129,x*128:x*128+129])
    if x<11:
        b=np.fromfile(data/'Tiles'/f'{x+1:02}_{z:02}.f32',dtype='<f4').reshape(129,129)
        assert np.array_equal(a[:,-1],b[:,0]);tile_edges+=1
    if z<11:
        b=np.fromfile(data/'Tiles'/f'{x:02}_{z+1:02}.f32',dtype='<f4').reshape(129,129)
        assert np.array_equal(a[-1],b[0]);tile_edges+=1
d=world['domain'];clearance={}
for c in world['cameras']:
    x,y,z=c['position'];ground=float(sample(h,x,z,d['west'],d['north'],32))
    clearance[c['id']]=round(y-ground,3);assert y-ground>1.5,(c['id'],y,ground)
cfg=json.loads((data/'Sector/sector.json').read_text())
near=np.fromfile(data/'Sector/height.f32',dtype='<f4').reshape(cfg['samples'],cfg['samples'])
assert np.isfinite(near).all()
path=np.array(cfg['trail']);ys=sample(near,path[:,0],path[:,2],cfg['west'],cfg['north'],2)
assert np.max(abs(ys-path[:,1]))<.35
assert cfg['trail_max_earthwork_m']<2
glbs=[]
for folder in ['06_Meshes','02_Terrain/Kaldran_Mountain_Spine']:
    for f in (ROOT/folder).rglob('*.glb'):
        raw=f.read_bytes();magic,version,size=struct.unpack('<4sII',raw[:12])
        assert magic==b'glTF' and version==2 and size==len(raw)
        length=struct.unpack('<I',raw[12:16])[0];doc=json.loads(raw[20:20+length])
        assert doc['meshes'] and doc['accessors'][0]['count']>0
        glbs.append({'file':str(f.relative_to(ROOT)),'vertices':doc['accessors'][0]['count']})
report={'status':'passed','shared_tile_edges_byte_identical':tile_edges,'camera_clearance_m':clearance,
        'trail_max_sample_deviation_m':float(np.max(abs(ys-path[:,1]))),'glb_meshes':glbs,
        'height_sha256':hashlib.sha256((data/'capital_height.f32').read_bytes()).hexdigest(),
        'scope':'source data checks; separate Engine_QA.json records runtime tests'}
(ROOT/'09_Documentation/Source_QA.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
