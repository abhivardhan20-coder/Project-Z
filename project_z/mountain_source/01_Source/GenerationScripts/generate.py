"""Rebuild Project Z's mountain prototype and precision source data.

Run with Python 3.11+, numpy, scipy, Pillow and matplotlib. No cloud services.
"""
import argparse, hashlib, json, math, shutil, struct, time
from pathlib import Path
import numpy as np
from scipy.ndimage import gaussian_filter
from PIL import Image
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import LightSource, LinearSegmentedColormap
from terrain_model import ROOT, PLAN, height, noise, masks, sample, smooth, erode, drainage

GODOT=ROOT.parent
DATA=GODOT/'Data'
PALETTE=LinearSegmentedColormap.from_list('Kaldran',[(0,'#213f43'),(.12,'#344e40'),(.29,'#647052'),(.45,'#78766a'),(.65,'#92918b'),(.8,'#b6c6cd'),(1,'#f3f5f2')])

def write_json(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,indent=2),encoding='utf-8')

def png(path,a):
    path.parent.mkdir(parents=True,exist_ok=True)
    Image.fromarray(np.uint8(np.clip(a,0,1)*255)).save(path)

def glb(path,vertices,faces,normals=None,colors=None,name='Kaldran',material=None):
    """Small standards-compliant glTF 2.0 writer; no external buffer dependencies."""
    vertices=np.asarray(vertices,dtype='<f4');faces=np.asarray(faces,dtype='<u4')
    blobs=[];views=[];accessors=[]
    def buffer(a,typ,component,target):
        raw=a.tobytes();offset=sum(len(b) for b in blobs)
        blobs.append(raw+b'\0'*((-len(raw))%4))
        views.append({'buffer':0,'byteOffset':offset,'byteLength':len(raw),'target':target})
        acc={'bufferView':len(views)-1,'componentType':component,'count':len(a),'type':typ}
        if typ=='VEC3':acc.update(min=a.min(axis=0).tolist(),max=a.max(axis=0).tolist())
        accessors.append(acc);return len(accessors)-1
    attrs={'POSITION':buffer(vertices,'VEC3',5126,34962)}
    if normals is not None:attrs['NORMAL']=buffer(np.asarray(normals,dtype='<f4'),'VEC3',5126,34962)
    if colors is not None:attrs['COLOR_0']=buffer(np.asarray(colors,dtype='<f4'),'VEC4',5126,34962)
    ind=buffer(faces.ravel(),'SCALAR',5125,34963)
    pbr={'baseColorFactor':[.42,.44,.45,1],'metallicFactor':0,'roughnessFactor':.84}
    if material:pbr.update(material)
    doc={'asset':{'version':'2.0','generator':'Project Z directed terrain pipeline'},'scene':0,
         'scenes':[{'nodes':[0]}],'nodes':[{'mesh':0,'name':name}],
         'meshes':[{'primitives':[{'attributes':attrs,'indices':ind,'material':0}]}],
         'materials':[{'name':'Alpine source','pbrMetallicRoughness':pbr,'doubleSided':False}],
         'buffers':[{'byteLength':sum(len(b) for b in blobs)}],'bufferViews':views,'accessors':accessors}
    j=json.dumps(doc,separators=(',',':')).encode();j+=b' '*((-len(j))%4);b=b''.join(blobs)
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_bytes(struct.pack('<4sII',b'glTF',2,12+8+len(j)+8+len(b))+struct.pack('<I4s',len(j),b'JSON')+j+struct.pack('<I4s',len(b),b'BIN\0')+b)

def mesh_grid(h,spacing,x0=0,z0=0):
    n,m=h.shape;z,x=np.mgrid[:n,:m]
    vertices=np.stack([x*spacing+x0,h,z*spacing+z0],axis=-1).reshape(-1,3)
    dz,dx=np.gradient(h,spacing);norm=np.stack([-dx,np.ones_like(h),-dz],axis=-1);norm/=np.linalg.norm(norm,axis=-1,keepdims=True)
    ids=np.arange(n*m).reshape(n,m);a=ids[:-1,:-1].ravel()
    # glTF is counter-clockwise viewed from above; Godot converts on import.
    faces=np.concatenate([np.stack([a,a+m,a+1],axis=-1),np.stack([a+1,a+m,a+m+1],axis=-1)])
    return vertices,faces,norm.reshape(-1,3)

def master_plan():
    x=np.linspace(-45000,49000,471);z=np.linspace(-62000,46000,541);X,Z=np.meshgrid(x,z)
    H=height(X,Z)
    for region in PLAN['regions']:
        cx,cz=region['center'];w,d=region['extent'];r=np.hypot((X-cx)/(w*.5),(Z-cz)/(d*.5))
        if region['id']=='Highvale_Plateau':v=320+1530*(1-smooth(.45,1.1,r))
        elif region['id']=='Southern_Highlands':v=320+1350*np.exp(-r*r*2)*(0.87+.13*noise(X,Z,6000,8))
        elif region['id']=='Mount_Veylor':
            v=320+2496*np.exp(-r*2.25)+130*np.exp(-((r-.09)/.045)**2)-260*np.exp(-(r/.065)**2)
        elif region['id']=='Frostfall_Range':v=320+2200*np.exp(-r*r*2)*(0.8+.2*noise(X,Z,2400,42))
        else:continue
        H=np.maximum(H,v)
    # This envelope only locates the planning regions; it is not the atlas coastline.
    island=((X-1000)/47000)**2+((Z+8500)/54000)**2<1
    H=np.where(island,H,0)
    out=ROOT/'03_Heightmaps/Master';out.mkdir(parents=True,exist_ok=True)
    H.astype('<f4').tofile(out/'island_plan_200m.f32')
    write_json(out/'island_plan_200m.json',{'shape':list(H.shape),'spacing':200,'west':-45000,'north':-62000,'dtype':'little-endian Float32 metres ASL','purpose':'coarse planning only; approximate coastline'})
    fig,ax=plt.subplots(figsize=(14,14),facecolor='#101b21');ax.set_facecolor('#101b21')
    rgb=LightSource(315,40).shade(H,PALETTE,vert_exag=1,dx=200,dy=200)
    rgb[~island,:3]=[.055,.13,.17]
    ax.imshow(rgb,extent=[-45,49,46,-62]);ax.contour(X/1000,Z/1000,H,[500,1500,2500,3500],colors='white',alpha=.16,linewidths=.55)
    for r in PLAN['regions']:
        cx,cz=r['center'];ax.text(cx/1000,cz/1000,r['id'].replace('_',' ')+'\n'+r['state'],color='white',ha='center',fontsize=10,bbox=dict(facecolor='#0f1d26',alpha=.65,edgecolor='none',pad=4))
    for ch in PLAN['ridge_chains']:
        p=np.array(ch['points']);ax.plot(p[:,0]/1000,p[:,1]/1000,color='#e8b876',lw=1,alpha=.75)
    for river in PLAN['rivers']:
        name,x0,z0,x1,z1=river;ax.annotate('',xy=(x1/1000,z1/1000),xytext=(x0/1000,z0/1000),arrowprops={'arrowstyle':'->','color':'#82d8ea','lw':1.4});ax.text(x1/1000,z1/1000,name,color='#b4e7f0',fontsize=8)
    ax.plot(0,0,'*',color='#ff5e52',ms=15);ax.text(1,1,'Kaldran • datum 320 m',color='white',fontsize=10)
    ax.add_patch(plt.Rectangle((-4,-4),8,8,fill=False,color='#f4d488',lw=1.5))
    ax.text(-44,44,'PROJECT Z / GEOGRAPHIC MASTER PLAN\nAtlas relationships retained • approximate registration • 200 m planning grid',color='white',fontsize=11)
    ax.set_xlabel('East from Kaldran / km',color='white');ax.set_ylabel('South from Kaldran / km (north is up)',color='white');ax.tick_params(colors='#9eb4bd')
    for s in ax.spines.values():s.set_color('#42535b')
    fig.tight_layout();fig.savefig(ROOT/'09_Documentation/Geographic_Master_Plan.png',dpi=145,facecolor=fig.get_facecolor());plt.close(fig)
    # Biome hypotheses remain separately editable from the elevation model.
    from matplotlib.colors import ListedColormap
    from matplotlib.patches import Patch
    names=['Sea / outside planning envelope','Lowland mixed woodland','Montane conifer forest','Subalpine meadow','Alpine rock and tundra','Persistent summit snow','Volcanic ash / basalt']
    colors=['#102e3b','#789768','#2c6659','#a1a16d','#8a8e8e','#e5edf0','#9f6251']
    biome=np.select([H<600,H<1450,H<1850,H<2600],[1,2,3,4],default=5)
    volcanic=np.hypot((X-2600)/7500,(Z-31700)/6800)<1
    biome[volcanic & (H>700)]=6;biome[~island]=0
    Image.fromarray(np.uint8(biome)).save(ROOT/'05_Terrain_Masks/island_biome_classes.png')
    fig,ax=plt.subplots(figsize=(11,12),facecolor='#101b21')
    ax.imshow(biome,extent=[-45,49,46,-62],cmap=ListedColormap(colors),vmin=0,vmax=6)
    for r in PLAN['regions']:ax.text(r['center'][0]/1000,r['center'][1]/1000,r['id'].replace('_',' '),ha='center',color='white',fontsize=9)
    ax.plot(0,0,'*',color='#ff7166',ms=14)
    ax.legend(handles=[Patch(color=c,label=n) for c,n in zip(colors,names)],loc='lower left',fontsize=8)
    ax.set_title('PROJECT Z / REGIONAL BIOME PLAN\nClimate and elevation hypotheses; future regions are not playable terrain',color='white')
    ax.tick_params(colors='white');fig.tight_layout();fig.savefig(ROOT/'09_Documentation/Regional_Biome_Plan.png',dpi=140,facecolor=fig.get_facecolor());plt.close(fig)

def align_collar(h, H, domain, X, Z, distance):
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

def make_sector(H,domain):
    s=PLAN['sector'];west=s['west']-s['halo'];north=s['north']-s['halo'];size=s['size']+2*s['halo'];spacing=s['spacing']
    X,Z=np.meshgrid(np.arange(west,west+size+spacing,spacing),np.arange(north,north+size+spacing,spacing))
    h=sample(H,X,Z,domain['west'],domain['north'],domain['spacing']).astype(float)
    # Fracture detail fades at the boundary so distant tiles and native terrain agree.
    distance=np.minimum.reduce([X-west,west+size-X,Z-north,north+size-Z]);blend=smooth(0,96,distance)
    detail=(noise(X,Z,38,28)*2.6+noise(X,Z,13,21)*.75+noise(X,Z,4,6)*.18)*blend
    h+=detail
    # Survey a contour on the existing slope instead of forcing a road through it.
    # Only a narrow walking bench is cut; the surrounding mountain stays intact.
    from scipy.spatial import cKDTree
    level=float(s.get('trail_elevation',1040))
    lo=int((s['halo']+32)/spacing);hi=int((s['halo']+s['size']-32)/spacing)+1
    fig,ax=plt.subplots()
    contours=ax.contour(X[lo:hi,lo:hi],Z[lo:hi,lo:hi],gaussian_filter(h,3)[lo:hi,lo:hi],levels=[level])
    candidates=[a for a in contours.allsegs[0] if len(a)>2]
    if not candidates:raise ValueError('Trail contour is outside the playable core')
    line=max(candidates,key=lambda a:np.linalg.norm(np.diff(a,axis=0),axis=1).sum())
    plt.close(fig)
    if line[0,1]<line[-1,1]:line=line[::-1]
    arc=np.r_[0,np.cumsum(np.linalg.norm(np.diff(line,axis=0),axis=1))]
    station=np.arange(0,arc[-1],4.0)
    p=np.stack([np.interp(station,arc,line[:,0]),np.interp(station,arc,line[:,1])],axis=-1)
    heights=np.full(len(p),level)
    best=cKDTree(p).query(np.stack([X.ravel(),Z.ravel()],axis=-1),workers=4)[0].reshape(h.shape)
    cut=(1-smooth(1.8,5.0,best))*blend
    change=(level-h)*cut
    h+=change
    trail=(1-smooth(1.4,3.0,best))*blend
    spawn_index=min(6,len(p)-2)
    look=p[min(spawn_index+6,len(p)-1)]-p[spawn_index]
    h=align_collar(h,H,domain,X,Z,distance)
    # Real runoff graph is exported; closed depressions remain explicitly identified.
    receiver,area=drainage(h,spacing);m=masks(h,spacing,flow=area)
    m['trail']=trail
    for key,a in m.items():png(ROOT/'05_Terrain_Masks/Sector'/f'{key}.png',a)
    data=DATA/'Sector';data.mkdir(parents=True,exist_ok=True)
    h.astype('<f4').tofile(data/'height.f32');png(data/'blend.png',np.stack([trail,m['vegetation'],m['snow']],axis=-1))
    cfg={'west':west,'north':north,'size':size,'spacing':spacing,'samples':len(h),'core':[s['west'],s['north'],s['size']],
         'spawn':[float(p[spawn_index,0]),float(heights[spawn_index]+2),float(p[spawn_index,1])],
         'spawn_yaw':float(math.atan2(-look[0],-look[1])),
         'trail_length_m':float(station[-1]),'trail_max_earthwork_m':float(np.max(np.abs(change))),
         'trail':[[float(v[0]),float(y),float(v[1])] for v,y in zip(p,heights)],
         'trail_max_grade':float(np.max(np.abs(np.diff(heights))/np.linalg.norm(np.diff(p,axis=0),axis=1)))}
    write_json(data/'sector.json',cfg)
    shutil.copy2(data/'height.f32',ROOT/'03_Heightmaps/Streamed_Regions/crown_approach_2m.f32')
    write_json(ROOT/'03_Heightmaps/Streamed_Regions/crown_approach_2m.json',cfg|{'dtype':'little-endian Float32 metres ASL'})
    v,f,n=mesh_grid(h[::8,::8],16,west,north)
    glb(ROOT/'02_Terrain/Kaldran_Mountain_Spine/Crown_Approach_source.glb',v,f,n,name='Crown Approach 16m editing proxy')
    rng=np.random.default_rng(PLAN['seed']);trees=[];rocks=[]
    for _ in range(10500):
        x=rng.uniform(west+16,west+size-16);z=rng.uniform(north+16,north+size-16)
        yi=float(sample(h,x,z,west,north,spacing));suit=float(sample(m['vegetation'],x,z,west,north,spacing));tr=float(sample(trail,x,z,west,north,spacing))
        density=.48+.52*float(smooth(-.2,.6,noise(x,z,140,7)))
        if tr<.05 and rng.random()<suit*density*.7:trees.append([round(x,3),round(yi,3),round(z,3),float(rng.uniform(8,17)),float(rng.uniform(0,math.tau))])
    for _ in range(1300):
        x=rng.uniform(s['west'],s['west']+s['size']);z=rng.uniform(s['north'],s['north']+s['size'])
        if float(sample(trail,x,z,west,north,spacing))>.05:continue
        y=float(sample(h,x,z,west,north,spacing));rocks.append([x,y-.18,z,float(rng.uniform(.5,2.8)),float(rng.uniform(0,math.tau)),int(rng.integers(0,3))])
    write_json(data/'instances.json',{'trees':trees,'rocks':rocks})
    fig,ax=plt.subplots(figsize=(10,10),facecolor='#122028');ax.imshow(LightSource(315,40).shade(h,PALETTE,dx=2,dy=2),extent=[west,west+size,north+size,north]);ax.plot(p[:,0],p[:,1],color='#e8bd76',lw=2);ax.scatter(p[0,0],p[0,1],c='#f26f56',s=60)
    ax.add_patch(plt.Rectangle((s['west'],s['north']),s['size'],s['size'],fill=False,color='white',lw=2));ax.set_title('CROWN APPROACH / 1.049 km² core + terrain collar\n2 m source samples • contour trail • streamed forest',color='white');ax.tick_params(colors='white');fig.tight_layout();fig.savefig(ROOT/'09_Documentation/Playable_Sector_Plan.png',dpi=135,facecolor=fig.get_facecolor());plt.close(fig)
    return cfg

def textures():
    out=GODOT/'materials/Textures';out.mkdir(parents=True,exist_ok=True)
    # Original, tileable procedural prototype PBR surfaces (not photogrammetry).
    n=512;z,x=np.mgrid[:n,:n]/n
    rng=np.random.default_rng(1790805)
    palettes={'granite':([.34,.35,.34],.87),'dark_bedrock':([.22,.25,.27],.87),'weathered_rock':([.43,.41,.36],.91),
              'sedimentary':([.44,.41,.35],.9),'scree':([.40,.41,.38],.94),'moss':([.26,.32,.21],.96),
              'soil':([.25,.22,.17],.96),'grass':([.31,.35,.22],.94),'subalpine':([.39,.40,.27],.93),
              'snow':([.88,.92,.94],.78),'packed_snow':([.72,.81,.85],.61),'ice':([.36,.57,.64],.25),
              'mud':([.19,.17,.13],.44),'river_gravel':([.35,.36,.31],.65),'basalt_ash':([.15,.16,.16],.91)}
    manifest=[]
    for i,(name,(base,rough)) in enumerate(palettes.items()):
        raw=rng.normal(0,1,(n,n));macro=gaussian_filter(raw,12,mode='wrap');macro/=max(macro.std(),.001)
        grain=gaussian_filter(raw,1.2,mode='wrap');grain/=max(grain.std(),.001)
        strata=np.sin((z*22+x*3)*math.tau+np.sin(x*math.tau)*.7)
        bump=.07*macro+.03*grain
        if name in ('granite','dark_bedrock','weathered_rock','sedimentary'):bump+=.025*strata
        if 'snow' in name:bump*=.22
        albedo=np.array(base)[None,None,:]*(1+bump[:,:,None])
        dz,dx=np.gradient(bump);normal=np.stack([-dx*2,-dz*2,np.ones_like(dx)],axis=-1);normal/=np.linalg.norm(normal,axis=-1,keepdims=True)
        png(out/f'{name}_albedo.png',np.dstack([albedo,np.clip(bump+.5,0,1)]))
        png(out/f'{name}_normal_roughness.png',np.dstack([normal*.5+.5,np.clip(rough+bump*.2,0,1)]))
        manifest.append({'name':name,'source':'original procedural prototype','metres_per_repeat':4,'albedo':name+'_albedo.png','normal_roughness':name+'_normal_roughness.png','status':'prototype material; requires photogrammetry/art pass for final AAA target'})
    write_json(ROOT/'04_Materials/material_library.json',manifest)

def rocks():
    # Convex boulders and a jointed cliff whose ledges overhang the heightfield.
    from scipy.spatial import ConvexHull
    out=GODOT/'Meshes';out.mkdir(parents=True,exist_ok=True)
    for variant in range(3):
        rng=np.random.default_rng(481+variant);v=rng.normal(size=(40,3));v/=np.linalg.norm(v,axis=1,keepdims=True);v*=rng.uniform(.65,1.08,(40,1));v[:,1]*=.72
        hull=ConvexHull(v);faces=hull.simplices.copy()
        # Orient all triangles outward.
        for i,f in enumerate(faces):
            if np.dot(np.cross(v[f[1]]-v[f[0]],v[f[2]]-v[f[0]]),v[f].mean(axis=0))<0:faces[i]=f[::-1]
        vv=v[faces].reshape(-1,3);nn=np.cross(v[faces[:,1]]-v[faces[:,0]],v[faces[:,2]]-v[faces[:,0]]);nn/=np.linalg.norm(nn,axis=1,keepdims=True);nn=np.repeat(nn,3,axis=0)
        glb(out/f'fractured_boulder_{variant}.glb',vv,np.arange(len(vv)).reshape(-1,3),nn,name=f'Fractured boulder {variant}')
        shutil.copy2(out/f'fractured_boulder_{variant}.glb',ROOT/f'06_Meshes/Boulders/fractured_boulder_{variant}.glb')
    vertices=[];faces=[]
    for row in range(6):
        for col in range(9):
            # Full 3D slab, including a 1.2 m overhang on alternating strata.
            x=col*3.7; y=row*3.3; z=(1.2 if row%2 else 0)+.4*math.sin(col*1.7)
            start=len(vertices);vertices.extend([[x,y,z],[x+3.65,y+.2,z+.1],[x+3.4,y+3.1,z+.65],[x-.2,y+3.25,z+.55],[x,y,z-3],[x+3.65,y,z-3],[x+3.4,y+3.1,z-3],[x,y+3.2,z-3]])
            for f in [[0,1,2],[0,2,3],[1,5,6],[1,6,2],[3,2,6],[3,6,7],[4,0,3],[4,3,7],[4,5,1],[4,1,0],[5,4,7],[5,7,6]]:faces.append([start+j for j in f])
    v=np.array(vertices);f=np.array(faces);vv=v[f].reshape(-1,3);nn=np.cross(v[f[:,1]]-v[f[:,0]],v[f[:,2]]-v[f[:,0]]);nn/=np.maximum(np.linalg.norm(nn,axis=1,keepdims=True),1e-8)
    glb(out/'jointed_cliff.glb',vv,np.arange(len(vv)).reshape(-1,3),np.repeat(nn,3,axis=0),name='Jointed cliff with overhangs')
    shutil.copy2(out/'jointed_cliff.glb',ROOT/'06_Meshes/Cliffs/jointed_cliff.glb')

def build():
    started=time.time()
    for folder in ['09_Documentation','03_Heightmaps/Streamed_Regions','03_Heightmaps/LOD','06_Meshes/Boulders','06_Meshes/Cliffs','06_Meshes/Distant_Mountains','08_Reference_Validation']:(ROOT/folder).mkdir(parents=True,exist_ok=True)
    DATA.mkdir(parents=True,exist_ok=True)
    for r in PLAN['regions']:(ROOT/'02_Terrain'/r['id']).mkdir(parents=True,exist_ok=True)
    print('Building geographic plan',flush=True);master_plan()
    d=PLAN['capital_domain'];xx=np.arange(d['west'],d['west']+d['size']+d['spacing'],d['spacing']);zz=np.arange(d['north'],d['north']+d['size']+d['spacing'],d['spacing']);X,Z=np.meshgrid(xx,zz)
    print(f'Building directed ridge graph on {len(xx)} x {len(zz)} grid',flush=True)
    original=height(X,Z);H,talus,incision,flow=erode(original,d['spacing'])
    # Pin authored summit elevations after erosion using local, smooth corrections.
    for name,x,z,elev in PLAN['summits']:
        if x<xx[0] or x>xx[-1] or z<zz[0] or z>zz[-1]:continue
        actual=float(sample(H,x,z,d['west'],d['north'],d['spacing']));H+=(elev-actual)*np.exp(-((X-x)**2+(Z-z)**2)/(600**2))
    H=np.minimum(H,3415).astype(np.float32)
    H.astype('<f4').tofile(DATA/'capital_height.f32')
    shutil.copy2(DATA/'capital_height.f32',ROOT/'03_Heightmaps/Master/capital_32m.f32')
    write_json(ROOT/'03_Heightmaps/Master/capital_32m.json',d|{'samples':len(H),'dtype':'little-endian Float32 metres ASL','row_direction':'+Z south'})
    print('Exporting terrain masks and tile sources',flush=True)
    m=masks(H,d['spacing'],talus,flow)
    for key,a in m.items():png(ROOT/'05_Terrain_Masks/Capital'/f'{key}.png',a)
    png(ROOT/'05_Terrain_Masks/Capital/thermal_deposition.png',smooth(0,15,talus));png(ROOT/'05_Terrain_Masks/Capital/erosion.png',incision/14);png(ROOT/'05_Terrain_Masks/Capital/flow.png',np.log1p(flow)/np.log1p(flow.max()))
    # Per-region raw source. Shared edge samples are byte-identical by construction.
    tile=d['tile_size'];stride=tile//d['spacing'];tiles=[]
    td=DATA/'Tiles';td.mkdir(exist_ok=True)
    for row in range(d['size']//tile):
        for col in range(d['size']//tile):
            a=H[row*stride:(row+1)*stride+1,col*stride:(col+1)*stride+1]
            name=f'{col:02}_{row:02}';a.astype('<f4').tofile(td/f'{name}.f32')
            errors=[]
            zz2,xx2=np.mgrid[:stride+1,:stride+1]
            for skip in (2,4,8):
                coarse=a[::skip,::skip];approx=sample(coarse,xx2,zz2,0,0,skip)
                errors.append(float(np.max(np.abs(a-approx))))
            tiles.append({'id':name,'west':d['west']+col*tile,'north':d['north']+row*tile,'size':tile,'samples':stride+1,'min':float(a.min()),'max':float(a.max()),'errors_m':errors})
    write_json(DATA/'world.json',{'schema':1,'datum':320,'domain':d,'tiles':tiles,'cameras':PLAN['cameras'],'seed':PLAN['seed']})
    for skip in (2,4,8):H[::skip,::skip].astype('<f4').tofile(ROOT/f'03_Heightmaps/LOD/capital_{d["spacing"]*skip}m.f32')
    # Standalone lightweight full-range editing mesh, source heights stay authoritative.
    v,f,n=mesh_grid(H[::4,::4],128,d['west'],d['north']);glb(ROOT/'06_Meshes/Distant_Mountains/Kaldran_Spine_128m.glb',v,f,n,name='Kaldran Mountain Spine, metres ASL')
    print('Building playable sector, path and biome placement',flush=True);sector=make_sector(H,d)
    print('Building material library and rock assets',flush=True);textures();rocks()
    write_json(DATA/'geography.json',PLAN)
    receiver,area=drainage(H,32);flat=H.ravel();r=receiver.ravel();active=r!=np.arange(len(r))
    metrics={'capital_source_samples':int(H.size),'capital_source_extent_km2':(d['size']/1000)**2,'source_min_m':float(H.min()),'source_max_m':float(H.max()),
        'tiles':len(tiles),'near_core_km2':(PLAN['sector']['size']/1000)**2,'near_source_spacing_m':2,
        'thermal_max_deposition_m':float(talus.max()),'maximum_incision_m':float(incision.max()),
        'd8_downhill_edges':int(active.sum()),'d8_uphill_edges':int(np.sum(flat[r[active]]>=flat[active])),
        'interior_closed_cells':int(np.sum(~active.reshape(H.shape)[1:-1,1:-1])),
        'trail_max_grade':sector['trail_max_grade'],'trail_length_m':sector['trail_length_m'],
        'trail_max_earthwork_m':sector['trail_max_earthwork_m'],'generation_seconds':round(time.time()-started,2),
        'height_sha256':hashlib.sha256((DATA/'capital_height.f32').read_bytes()).hexdigest(),
        'scope':'geographic plan + central spine/first playable prototype; other regions are planning data only'}
    write_json(ROOT/'09_Documentation/Generation_Report.json',metrics)
    print(json.dumps(metrics,indent=2),flush=True)

if __name__=='__main__':build()
