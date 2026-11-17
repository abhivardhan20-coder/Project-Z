"""Metre-scale, directed terrain. All cameras sample one immutable elevation field.

Ridge graph controls uplift; small domain warps fracture cross sections, not geography.
Glacial and fluvial guides cut connected troughs. This is a deliberately bounded
art-directed erosion approximation, not a claim of geological simulation time.
"""
from pathlib import Path
import json
import numpy as np
from scipy.ndimage import gaussian_filter, map_coordinates

ROOT = Path(__file__).resolve().parents[2]
PLAN = json.loads((ROOT / '01_Source/Parameters/geography.json').read_text())

def smooth(a, b, x):
    q = np.clip((x-a)/(b-a), 0, 1)
    return q*q*(3-2*q)

def noise(x, z, scale=1000., seed=3):
    """Continuous global value noise: tile boundaries never reset their seed."""
    u, v = x/scale, z/scale
    ix, iz = np.floor(u), np.floor(v)
    u, v = smooth(0,1,u-ix), smooth(0,1,v-iz)
    def h(a,b):
        q = np.sin(a*127.1+b*311.7+seed*73.13)*43758.5453
        return (q-np.floor(q))*2-1
    return ((h(ix,iz)*(1-u)+h(ix+1,iz)*u)*(1-v)+
            (h(ix,iz+1)*(1-u)+h(ix+1,iz+1)*u)*v)

def segment(x,z,a,b):
    dx,dz = b[0]-a[0],b[1]-a[1]
    t=np.clip(((x-a[0])*dx+(z-a[1])*dz)/(dx*dx+dz*dz),0,1)
    return np.hypot(x-a[0]-t*dx,z-a[1]-t*dz),t

def height(x,z):
    x,z=np.broadcast_arrays(np.asarray(x,dtype=float),np.asarray(z,dtype=float))
    broad=320 + 200*np.exp(-((x/18500)**2+((z+16000)/17000)**2))
    broad+=430*np.exp(-((x/14500)**2+((z+25000)/19000)**2))
    wx=x+100*noise(x,z,1250,3)+35*noise(x,z,410,14)
    wz=z+85*noise(x,z,1550,17)+30*noise(x,z,370,9)
    ridge=np.zeros_like(x)+320
    for chain in PLAN['ridge_chains']:
        for a,b in zip(chain['points'],chain['points'][1:]):
            d,t=segment(wx,wz,a,b)
            crest=a[2]*(1-t)+b[2]*t
            # Asymmetric ridges retain steep exposed faces and broader dip slopes.
            orient=((b[0]-a[0])*(wz-a[1])-(b[1]-a[1])*(wx-a[0]))
            segment_length=np.hypot(b[0]-a[0],b[1]-a[1])
            width=chain['width']*(.985-.165*np.tanh(orient/(segment_length*650)))
            profile=np.maximum(0,1-(d/width)**0.82)**1.25
            ridge=np.maximum(ridge,320+(crest-320)*profile)
    h=np.maximum(broad,ridge)
    # Secondary ravines only modulate uplifted bedrock. Their amplitude is bounded.
    amplitude=smooth(620,2400,h)
    fracture=(noise(x+120*noise(x,z,2600,31),z,820,10)*78+
              noise(x,z,270,23)*32+noise(x,z,90,15)*10)
    h+=fracture*amplitude
    for valley in PLAN['valleys']:
        dist=np.full_like(x,1e12)
        for a,b in zip(valley['points'],valley['points'][1:]):
            d,_=segment(x,z,a,b); dist=np.minimum(dist,d)
        exponent=4 if valley['kind']=='U' else 1.25
        h-=valley['depth']*np.exp(-(dist/valley['width'])**exponent)*smooth(450,1600,h)
    # Alpine cirques incised on the sheltered side, with a preserved arête rim.
    for cx,cz,rad,cut in [(-8600,-18800,1200,170),(1550,-21750,1100,190),(8600,-24700,1350,180),(-2900,-26300,1000,140)]:
        r=np.hypot((x-cx),(z-cz)*1.2)/rad
        h-=cut*np.exp(-(r**4))*smooth(1700,2600,h)
    # Basin easing anchors the city at its 320 m datum, rather than compressing mountains.
    city=1-smooth(2100,5700,np.hypot(x,z))
    h=h*(1-city)+(320+4*noise(x,z,700,2))*city
    return np.maximum(h,20)

def erode(field,spacing,iterations=18):
    """Conservative thermal transport plus bounded drainage incision.

    Rock above a 39 degree repose angle sheds a small mass into its downhill
    neighbors. Every transfer has an equal deposit; borders are pinned. A D8
    receiver graph then provides contributing area and a bounded incision mask.
    """
    h=field.astype(np.float64).copy(); original=h.copy()
    talus=np.zeros_like(h)
    for _ in range(iterations):
        delta=np.zeros_like(h)
        for axis in (0,1):
            diff=np.diff(h,axis=axis)
            transfer=np.maximum(np.abs(diff)-spacing*0.81,0)*0.055*np.sign(diff)
            if axis==0:
                delta[:-1]+=transfer;delta[1:]-=transfer
            else:
                delta[:,:-1]+=transfer;delta[:,1:]-=transfer
        delta[0]=delta[-1]=0;delta[:,0]=delta[:,-1]=0
        h+=delta;talus+=np.maximum(delta,0)
    receiver,area=drainage(h,spacing)
    slope=np.hypot(*np.gradient(h,spacing))
    incision=np.minimum(14,np.log1p(area)*slope*0.8)*smooth(450,1400,h)
    edge=np.ones_like(h);edge[:2]=edge[-2:]=0;edge[:,:2]=edge[:,-2:]=0
    h-=incision*edge
    return h.astype(np.float32),talus.astype(np.float32),incision.astype(np.float32),area.astype(np.float32)

def drainage(h,spacing):
    rows,cols=h.shape
    flat=np.arange(h.size).reshape(h.shape)
    receiver=flat.copy(); steep=np.zeros_like(h)
    for dy,dx in ((-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1)):
        a=(slice(max(0,-dy),min(rows,rows-dy)),slice(max(0,-dx),min(cols,cols-dx)))
        b=(slice(max(0,dy),min(rows,rows+dy)),slice(max(0,dx),min(cols,cols+dx)))
        gradient=(h[a]-h[b])/(spacing*np.hypot(dy,dx))
        select=gradient>steep[a]
        steep[a][select]=gradient[select];receiver[a][select]=flat[b][select]
    r=receiver.ravel(); area=np.ones(h.size,dtype=np.float64)
    for i in np.argsort(h.ravel())[::-1]:
        if r[i]!=i:area[r[i]]+=area[i]
    return receiver,area.reshape(h.shape)

def masks(h,spacing,talus=None,flow=None):
    dz,dx=np.gradient(h,spacing)
    slope=np.hypot(dx,dz);norm=np.sqrt(1+dx*dx+dz*dz)
    curvature=gaussian_filter(h,2)-h
    shelter=smooth(-3,7,curvature)
    # North-facing surfaces retain more snow; wind-scoured convex crests retain less.
    north=np.clip(dz/norm,0,1)
    retention=np.clip(0.55+0.4*north+0.3*shelter-0.22*smooth(-2,-10,curvature),0,1)
    snow=smooth(1830,2650,h+retention*330)* (1-smooth(0.65,1.65,slope))
    trees=(1-smooth(1570,2010,h))*(1-smooth(.45,.9,slope))*smooth(340,600,h)
    moisture=smooth(0,5,np.log1p(flow)) if flow is not None else shelter
    biome=np.stack([trees,smooth(1250,1900,h)*(1-smooth(2100,2450,h))*(1-smooth(.5,1,slope)),snow],axis=-1)
    return {'slope':np.arctan(slope)/(np.pi/2),'curvature':np.clip(.5+curvature/30,0,1),
            'snow':snow,'vegetation':trees,'biomes':biome,'moisture':moisture,
            'normal':np.stack([-dx/norm,1/norm,-dz/norm],axis=-1)*.5+.5}

def sample(field,x,z,west,north,spacing):
    shape=np.broadcast(x,z).shape
    xx,zz=np.broadcast_arrays(x,z)
    return map_coordinates(field,[(zz.ravel()-north)/spacing,(xx.ravel()-west)/spacing],order=1,mode='nearest').reshape(shape)
