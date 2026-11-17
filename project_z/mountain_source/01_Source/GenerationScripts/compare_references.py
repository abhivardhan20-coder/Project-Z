"""Compare actual Godot silhouette captures to explicitly annotated visible skylines."""
from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[2]
REFERENCE=ROOT/'01_Source/References'
world=json.loads((ROOT.parent/'Data/world.json').read_text())
calibration=json.loads((ROOT/'09_Documentation/Camera_Calibration.json').read_text())
font_path=Path(r'C:\Windows\Fonts\segoeui.ttf')
font=ImageFont.truetype(str(font_path),20)
small=ImageFont.truetype(str(font_path),16)
metrics={};contact=[]
for camera in world['cameras']:
    name=camera['id'];directory=ROOT/'08_Reference_Validation'/name
    ref=Image.open(REFERENCE/camera['ref']).convert('RGB')
    render=Image.open(directory/'render.png').convert('RGB')
    silhouette=Image.open(directory/'silhouette.png').convert('RGB')
    pixels=np.asarray(silhouette);mask=np.max(pixels,axis=-1)<130
    valid=mask.any(axis=0);outline=np.argmax(mask,axis=0).astype(float);outline[~valid]=np.nan
    w,h=silhouette.size
    trace=np.array(calibration[name]['trace_pixels_1672x941'],float)*[w/1672,h/941]
    xs=np.arange(w);reference=np.interp(xs,trace[:,0],trace[:,1]);included=np.zeros(w,dtype=bool)
    for start,end in calibration[name]['visible_intervals_pixels']:included|=(xs>=start*w/1672)&(xs<=end*w/1672)
    included&=valid
    difference=outline[included]-reference[included]
    metrics[name]={'comparison':'actual Godot silhouette vs manually traced visible reference horizon',
        'capture_size':[w,h],'evaluated_columns':int(included.sum()),
        'vertical_mae_pixels':float(np.mean(abs(difference))),
        'vertical_rmse_pixels':float(np.sqrt(np.mean(difference**2))),
        'p95_absolute_pixels':float(np.percentile(abs(difference),95)),
        'reference_sha256':hashlib.sha256((REFERENCE/camera['ref']).read_bytes()).hexdigest(),
        'limits':'Only annotated visible mountain spans. Does not score foreground, materials, snow or atmospheric fidelity. Sparse manual traces have 5–15 px uncertainty at original resolution.'}
    # Annotated overlay is a diagnostic plot, not a replacement scene render.
    overlay=ref.resize((w,h),Image.Resampling.LANCZOS)
    draw=ImageDraw.Draw(overlay)
    for start,end in calibration[name]['visible_intervals_pixels']:
        columns=np.arange(int(start*w/1672),min(w,int(end*w/1672)+1))
        draw.line([(int(x),float(reference[x])) for x in columns],fill='#f6be62',width=4)
        draw.line([(int(x),float(outline[x])) for x in columns if valid[x]],fill='#6cdbed',width=3)
    overlay.save(directory/'skyline_overlay.png')
    cw=960;ch=540;canvas=Image.new('RGB',(cw*2,2*ch+170),'#111d25');d=ImageDraw.Draw(canvas)
    d.text((24,15),f'PROJECT Z / {name.upper()} / CAMERA VALIDATION',font=font,fill='#e7c186')
    d.text((24,49),'Reference photograph',font=small,fill='white');d.text((cw+24,49),'Actual Godot 4.7.2 render · prototype urban context',font=small,fill='white')
    canvas.paste(ref.resize((cw,ch),Image.Resampling.LANCZOS),(0,78));canvas.paste(render.resize((cw,ch),Image.Resampling.LANCZOS),(cw,78))
    d.text((24,ch+91),'Reference trace (gold) / rendered horizon (cyan)',font=small,fill='white');d.text((cw+24,ch+91),'Untextured geometry · same physical range',font=small,fill='white')
    canvas.paste(overlay.resize((cw,ch),Image.Resampling.LANCZOS),(0,ch+120));canvas.paste(Image.open(directory/'clay.png').resize((cw,ch),Image.Resampling.LANCZOS),(cw,ch+120))
    metric=metrics[name];d.text((24,2*ch+132),f'Visible-span MAE {metric["vertical_mae_pixels"]:.1f} px / RMSE {metric["vertical_rmse_pixels"]:.1f} px at 1080p. Manual annotation, not a full-scene accuracy score.',font=small,fill='#9fb8c3')
    canvas.save(directory/'comparison.png')
    contact.append((name,render.resize((640,360),Image.Resampling.LANCZOS)))
board=Image.new('RGB',(1920,840),'#111d25');d=ImageDraw.Draw(board);d.text((24,17),'KALDRAN MOUNTAIN SPINE / FIVE CAMERAS / ONE TERRAIN',font=font,fill='#e7c186')
for i,(name,img) in enumerate(contact):
    x=(i%3)*640;y=60+(i//3)*390;board.paste(img,(x,y));d.text((x+15,y+365),name,font=small,fill='white')
sector=Image.open(ROOT/'08_Reference_Validation/PlayableSector/trail.png').resize((640,360),Image.Resampling.LANCZOS)
board.paste(sector,(1280,450));d.text((1295,815),'Crown Approach / playable sector',font=small,fill='white')
board.save(ROOT/'08_Reference_Validation/Contact_Sheet.png')
(ROOT/'09_Documentation/Silhouette_Measurements.json').write_text(json.dumps(metrics,indent=2))
print(json.dumps(metrics,indent=2))
