"""Fit camera framing to manually traced, unoccluded reference mountain horizons.

The traces are annotations, not recovered ground truth. Positions are fixed world
estimates. Only yaw, pitch and vertical FOV vary; the terrain never moves per view.
The final QA also measures actual Godot silhouette renders, separately from this fit.
"""
import json, hashlib
from pathlib import Path
import numpy as np
from scipy.ndimage import map_coordinates
from scipy.optimize import differential_evolution
from terrain_model import ROOT

TRACE={
 'Airport':[[460,218],[505,207],[550,211],[591,220],[634,216],[674,225],[716,219],[754,231],[800,229],[847,240],[898,236],[949,250]],
 'Hillside':[[650,239],[690,220],[726,215],[757,207],[791,222],[825,216],[868,231],[909,227],[952,243],[998,240],[1040,249],[1100,252],[1160,265]],
 'Railway':[[126,159],[165,148],[194,130],[222,135],[257,117],[291,126],[319,106],[349,114],[376,105],[407,98],[435,115],[465,111],[488,129]],
 'Capitol':[[784,168],[806,151],[829,173],[850,159],[874,176],[896,153],[916,168],[935,145],[1051,181],[1080,171],[1116,184],[1152,168]],
 'Panorama':[[203,139],[270,115],[343,102],[420,106],[520,119],[628,96],[724,65],[781,83],[832,65],[895,83],[973,69],[1033,103],[1115,86],[1181,66],[1228,90],[1311,68],[1381,84],[1438,70],[1480,86],[1560,77],[1654,113]]
}
MASKS={'Airport':[[460,949]],'Hillside':[[650,1160]],'Railway':[[126,488]],'Capitol':[[784,935],[1051,1152]],'Panorama':[[203,1654]]}
P=ROOT.parent/'Data/world.json'
world=json.loads(P.read_text());H=np.fromfile(P.parent/'capital_height.f32',dtype='<f4').reshape(1537,1537)
angles=np.linspace(-1.4,1.4,5001)
dist=np.geomspace(1500,58000,1100)
report={}
for camera in world['cameras']:
    eye=np.array(camera['position'],float)
    X=eye[0]+np.sin(angles[:,None])*dist
    Z=eye[2]-np.cos(angles[:,None])*dist
    heights=map_coordinates(H,[(Z.ravel()+40960)/32,(X.ravel()+24576)/32],order=1,mode='constant',cval=-10000).reshape(X.shape)
    elev=np.max(np.arctan2(heights-eye[1],dist),axis=1)
    directions=np.stack([np.sin(angles)*np.cos(elev),np.sin(elev),-np.cos(angles)*np.cos(elev)],axis=-1)
    trace=np.array(TRACE[camera['id']],float);tx=trace[:,0]/1672;ty=trace[:,1]/941
    def projected(params):
        yaw,pitch,fov=params
        forward=np.array([np.sin(yaw)*np.cos(pitch),np.sin(pitch),-np.cos(yaw)*np.cos(pitch)])
        right=np.array([np.cos(yaw),0,np.sin(yaw)])
        up=np.cross(right,forward)
        depth=directions@forward;f=1/(2*np.tan(np.radians(fov)*.5))
        xx=.5+(directions@right)/depth*f/(1672/941)
        yy=.5-(directions@up)/depth*f
        select=depth>.2
        order=np.argsort(xx[select]);xs=xx[select][order];ys=yy[select][order]
        return np.interp(tx,xs,ys)
    def loss(params):
        values=projected(params)
        return np.mean((values-ty)**2)+.00005*((params[2]-38)/20)**2
    # One fixed physical camera per urban district; changes are lens and orientation only.
    fit=differential_evolution(loss,[(-.25,.25),(-.26,.08),(25,60)],seed=1790805,popsize=12,maxiter=100,tol=1e-7)
    yaw,pitch,fov=fit.x
    direction=np.array([np.sin(yaw)*np.cos(pitch),np.sin(pitch),-np.cos(yaw)*np.cos(pitch)])
    camera['target']=(eye+direction*20000).tolist();camera['fov']=float(fov)
    camera['calibration']='fixed estimated position; lens and orientation fitted to hand-annotated visible skyline'
    report[camera['id']]={'yaw_deg':float(np.degrees(yaw)),'pitch_deg':float(np.degrees(pitch)),'vertical_fov':float(fov),
        'annotation_rmse_px_at_941h':float(np.sqrt(np.mean((projected(fit.x)-ty)**2))*941),
        'trace_pixels_1672x941':TRACE[camera['id']],'visible_intervals_pixels':MASKS[camera['id']],
        'uncertainty':'manual sparse trace ~5-15 pixels; trees, buildings and cloud-hidden sections excluded; not pixel-perfect reconstruction'}
    print(camera['id'],round(fov,2),report[camera['id']]['annotation_rmse_px_at_941h'],flush=True)
P.write_text(json.dumps(world,indent=2))
(ROOT/'09_Documentation/Camera_Calibration.json').write_text(json.dumps(report,indent=2))
