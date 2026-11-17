"""Reproducible district dressing and slope-aware trail ecology from supplied assets."""
from pathlib import Path
import json,math,collections
import numpy as np
from scipy.ndimage import map_coordinates
from scipy.spatial import cKDTree

ROOT=Path(__file__).resolve().parents[2]
GAME=ROOT.parent
catalog=json.loads((GAME/'assets/Baked/catalog.json').read_text())
assets=collections.defaultdict(list)
for row in catalog:assets[row['key']].append(row)
H=np.fromfile(GAME/'Data/capital_height.f32',dtype='<f4').reshape(1537,1537)
S=np.fromfile(GAME/'Data/Sector/height.f32',dtype='<f4').reshape(1537,1537)
world=json.loads((GAME/'Data/world.json').read_text())
layout=json.loads((ROOT/'01_Source/Parameters/district_layout.json').read_text())['districts']
sector=json.loads((GAME/'Data/Sector/sector.json').read_text())
rng=np.random.default_rng(1790805)
def ground(x,z,alpine=False):
    a,west,north,step=(S,-3072,-13312,2) if alpine else (H,-24576,-40960,32)
    return float(map_coordinates(a,[[(z-north)/step],[(x-west)/step]],order=1,mode='nearest')[0])
def bounds(key):return assets[key][0]['bounds_size']
districts={
 'Airport':{'center':[4240,650],'radius':1200},
 'Railway':{'center':[1660,650],'radius':800},
 'Hillside':{'center':[-3000,1900],'radius':950},
 'Capitol':{'center':[100,1050],'radius':1100},
 'Alpine':{'center':[-1630,-11800],'radius':1600}}
rows=[];surfaces=[]
road_profiles={}
def add(group,key,x,z,y=None,yaw=0,scale=1,foundation=False,label=None):
    if key in ['ROAD','BUS','SEDAN','POLICE','TRAIN','AMBULANCE','RAIL03']:yaw+=math.pi/2
    size=np.array(bounds(key))*scale
    base=ground(x,z,group=='Alpine') if y is None else y
    low=base
    if foundation:
        samples=[ground(x+dx,z+dz,group=='Alpine') for dx in [-size[0]/2,0,size[0]/2] for dz in [-size[2]/2,0,size[2]/2]]
        low=min(samples)-.15
        base=max(base,max(samples)+.08) if y is None else max(base,max(samples)+.08)
        if base-low>.05:surfaces.append({'group':group,'name':(label or key)+'_Foundation','position':[x,(low+base)/2,z],'size':[size[0]+.4,base-low,size[2]+.4],'yaw':yaw,'material':'stone'})
    row={'id':label or f'{group}_{key}_{len(rows):04d}','group':group,'key':key,'position':[round(x,3),round(base,3),round(z,3)],'yaw':yaw,'scale':scale,'collision':group=='Alpine'}
    rows.append(row);return row
def plate(group,label,x,z,width,length,y,yaw=0,material='asphalt',thickness=.18):
    surfaces.append({'group':group,'name':label,'position':[x,y-thickness/2,z],'size':[width,thickness,length],'yaw':yaw,'material':material})
def frame(camera):
    c=layout[camera]
    x,z=c['origin_xz'];yaw=c['heading_rad'];co,si=math.cos(yaw),math.sin(yaw)
    def xy(dx,dz):return x+co*dx-si*dz,z+si*dx+co*dz
    return xy,-yaw
def street(group,length,width,height=None):
    xy,yaw=frame(group)
    def level(dz):
        return height if height is not None else max(ground(*xy(dx,dz)) for dx in [-width*.5,0,width*.5])+.1
    road_profiles[group]=level
    for dz in range(0,-length,-10):
        x,z=xy(0,dz);front,back=level(dz-5),level(dz+5)
        # Length remains ten metres; the kit's two pavements frame one road.
        # Its cross-section is widened and each section follows a graded plane.
        row=add(group,'ROAD',x,z,(front+back)*.5,yaw)
        row['scale_xyz']=[math.hypot(10,front-back)/10*1.002,1,width/bounds('ROAD')[2]]
        row['roll']=math.atan2(front-back,10)
    return xy,yaw
def traffic(group,xy,yaw,length,y=None,density=.65):
    for distance in range(12,length,14):
        for lane in [-7,-2.5,3,8]:
            if rng.random()>density:continue
            dz=-distance+rng.uniform(-2,2);x,z=xy(lane+rng.uniform(-.5,.5),dz)
            key='POLICE' if rng.random()<.1 else 'SEDAN'
            row=add(group,key,x,z,road_profiles[group](dz)+.19,yaw+rng.uniform(-.22,.22))
            row['roll']=math.atan2(road_profiles[group](dz-2.5)-road_profiles[group](dz+2.5),5)
    for i in range(12):
        dz=-rng.uniform(8,min(length,110));x,z=xy(rng.uniform(-12,12),dz)
        add(group,'SUITCASE',x,z,road_profiles[group](dz)+.2,yaw+rng.uniform(-3,3))
    for side in [-1,1]:
        for distance in [45,52,59]:
            x,z=xy(side*16,-distance);add(group,'BARRIER',x,z,road_profiles[group](-distance)+.2,yaw)

# Airport: raised evacuation highway with a connected terminal forecourt.
xy,yaw=street('Airport',620,26,418.3)
traffic('Airport',xy,yaw,260,418.5,.83)
for dz in range(0,-620,-50):
    x,z=xy(0,dz);bottom=ground(x,z);plate('Airport','ViaductSupport',x,z,3,7,(bottom+416.8)/2,yaw,'stone',max(1,416.8-bottom))
for key,dx,dz in [('AIR01',250,-320),('AIR02',240,-210),('AIR03',250,-412),('AIR04',390,-475),('AIR08',-130,-280),('AIR10',-50,-85)]:
    x,z=xy(dx,dz);add('Airport',key,x,z,418.3,yaw,foundation=True)
x,z=xy(250,-310);plate('Airport','TerminalApron',x,z,550,390,418.1,yaw)
for i in range(3):
    x,z=xy(-26-i*10,-32);add('Airport','AIR11',x,z,418.3,yaw)
for dx,dz,key in [(6,-75,'BUS'),(-13,-20,'AMBULANCE'),(8,-148,'BUS')]:
    x,z=xy(dx,dz);add('Airport',key,x,z,418.5,yaw)

# Railway terminal and parallel platform tracks share a 322 m site datum.
xy,yaw=street('Railway',240,24,322.15)
traffic('Railway',xy,yaw,105,322.35,.42)
for key,dx,dz in [('RAIL01',38,-300),('RAIL02',-90,-265),('RAIL03',145,-340),('RAIL04',-153,-340),('RAIL06',-48,-115),('RAIL08',45,-85),('RAIL09',-175,-100),('RAIL10',80,-125)]:
    x,z=xy(dx,dz);add('Railway',key,x,z,322,yaw,foundation=True)
x,z=xy(20,-160);plate('Railway','StationForecourt',x,z,250,170,322.05,yaw)
for lane in range(3):
    for car in range(4):
        x,z=xy(128+lane*10,-200-car*23);add('Railway','TRAIN',x,z,323.2,yaw)
for dx,dz,key in [(-8,-48,'BUS'),(-25,-96,'BUS'),(25,-24,'AMBULANCE'),(-15,-20,'BENCH'),(18,-50,'BENCH')]:
    x,z=xy(dx,dz);add('Railway',key,x,z,322.35,yaw)

# Hillside is now at ground level, instead of the old elevated framing proxy.
cam=next(c for c in world['cameras'] if c['id']=='Hillside')
dy=ground(cam['position'][0],cam['position'][2])+1.9-cam['position'][1]
cam['position'][1]+=dy;cam['target'][1]+=dy
xy,yaw=street('Hillside',480,19)
traffic('Hillside',xy,yaw,150,None,.35)
for side in [-1,1]:
    for i,key in enumerate(['HIL01','HIL02','HIL04','HIL03','HIL07','HIL09']):
        x,z=xy(side*(23+(i%2)*4),-16-i*62)
        add('Hillside',key,x,z,yaw=yaw+side*math.pi/2,foundation=True)
for key,dx,dz in [('HIL05',-24,-410),('HIL06',27,-410),('HIL10',40,-150),('AMBULANCE',8,-37),('BENCH',-12,-10),('SUITCASE',-8,-16)]:
    x,z=xy(dx,dz);add('Hillside',key,x,z,yaw=yaw,foundation=key.startswith('HIL'))
for i in range(32):
    x,z=xy((-1 if i%2 else 1)*rng.uniform(15,20),-rng.uniform(5,450))
    add('Hillside','OAK',x,z,yaw=rng.uniform(0,6.28),scale=rng.uniform(.65,1.1))

# Government axis: real assembly hall, ministry wings and street evacuation.
xy,yaw=street('Capitol',1100,36)
traffic('Capitol',xy,yaw,220,None,.68)
x,z=xy(0,-910);add('Capitol','CIV01',x,z,yaw=yaw,foundation=True)
for side in [-1,1]:
    for i in range(7):
        x,z=xy(side*(49 if i<2 else 68),-60-i*117)
        add('Capitol','CIV03' if i%3 else 'MIDRISE',x,z,yaw=yaw,foundation=True)
    for i in range(25):
        x,z=xy(side*23,-10-i*35);add('Capitol','OAK',x,z,yaw=rng.uniform(0,6.28),scale=.8)
for key,dx,dz in [('BUS',5,-68),('AIR11',-29,-112),('AMBULANCE',-15,-85),('BENCH',-23,-22),('RAIL06',-25,-35)]:
    x,z=xy(dx,dz);add('Capitol',key,x,z,yaw=yaw)

# A small, walkable service outpost on the trail's downhill side.
trail=np.array(sector['trail']);tree=cKDTree(trail[:,[0,2]])
for key,index,dx,dz in [('RADIO_HUT',38,-12,0),('RADIO_TOWER',45,-24,0),('CABLE_STATION',198,-31,0),('BENCH',22,-5,0),('BARRIER',205,-6,0)]:
    x,_,z=trail[index];add('Alpine',key,x+dx,z+dz,yaw=.15,foundation=key in ['RADIO_HUT','RADIO_TOWER','CABLE_STATION'])

# Broad city fabric is true instanced supplied architecture, at terrain elevations.
background=[]
for z in range(-4500,3900,145):
    for x in range(-7100,6500,145):
        if rng.random()>.61:continue
        if any(math.hypot(x-v['center'][0],z-v['center'][1])<v['radius']*.75 for k,v in districts.items() if k!='Alpine'):continue
        y=ground(x,z)
        if y>610:continue
        slope=max(abs(ground(x+50,z)-y),abs(ground(x,z+50)-y))/50
        if slope>.20:continue
        key=rng.choice(['HIL01','HIL02','HIL04','HIL09'])
        background.append({'key':str(key),'position':[x+rng.uniform(-18,18),y,z+rng.uniform(-18,18)],'yaw':float(rng.choice([0,math.pi/2,math.pi,math.pi*1.5])),'scale':float(rng.uniform(.9,1.2))})

# Cluster understory beside, never on, the walking corridor. Slope and altitude
# filters retain bare rock slopes, and deadwood receives physical collision.
details=[]
for i in range(7000):
    center=trail[rng.integers(len(trail))];x=center[0]+rng.normal(0,65);z=center[2]+rng.normal(0,32)
    distance=tree.query([x,z])[0]
    if distance<3.2 or distance>140:continue
    y=ground(x,z,True)
    slope=math.hypot(ground(x+2,z,True)-y,ground(x,z+2,True)-y)/2
    if slope>.65 or y>1500:continue
    key=str(rng.choice(['GRASS','FERN','JUNIPER','FIR','FIR_LOW','LICHEN','LOG','STUMP','ROOTS'],p=[.39,.18,.16,.09,.06,.08,.015,.015,.01]))
    if key in ['LOG','STUMP','ROOTS'] and (distance<6 or slope>.3):continue
    details.append({'key':key,'position':[round(x,3),round(y-.03,3),round(z,3)],'yaw':float(rng.uniform(0,math.tau)),'scale':float(rng.uniform(.65,1.25))})
out={'schema':1,'seed':1790805,'units':'metres; Y up; north -Z','districts':districts,'placements':rows,'surfaces':surfaces,'background':background}
(GAME/'Data/asset_placements.json').write_text(json.dumps(out,indent=2))
(GAME/'Data/Sector/undergrowth.json').write_text(json.dumps(details,separators=(',',':')))
(GAME/'Data/world.json').write_text(json.dumps(world,indent=2))
report={'authored_placements':len(rows),'background_buildings':len(background),'undergrowth_instances':len(details),'by_asset':dict(collections.Counter(r['key'] for r in rows+background+details)),'surface_count':len(surfaces),'source':'Data/asset_placements.json and Data/Sector/undergrowth.json','camera_change':'Hillside lowered to terrain +1.9 m; orientation is subsequently recalibrated against the shared skyline.'}
(ROOT/'09_Documentation/User_Asset_Placement.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
