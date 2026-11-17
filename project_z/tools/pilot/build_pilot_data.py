"""Build the graded pilot inputs from the New Assets archives."""

import argparse
import csv
import io
import json
from pathlib import Path
from zipfile import ZipFile

import numpy as np
from PIL import Image

ORIGIN = (4150.0, 4800.0, 118.0)
WEST, NORTH, STEP = 3500, 5500, 2
WIDTH = 501
BRIDGE_START, BRIDGE_END, BRIDGE_NORTH, BRIDGE_HEIGHT = 4288, 4360, 4805, 125.5
ROAD = np.array([
    [3903,4764,143.9], [3972,4764,143.9], [4020,4764,141.4], [4070,4775,138.6],
    [4130,4792,135.4], [4180,4805,132.4], [4230,4805,128.5], [BRIDGE_START,BRIDGE_NORTH,BRIDGE_HEIGHT],
    [BRIDGE_END,BRIDGE_NORTH,BRIDGE_HEIGHT], [4390,4805,128.05], [4420,4805,130.4], [4464,4805,130.4],
], dtype=float)
SITES = [
    ("Northline", [3902, 3972, 4748, 4803], 143.9),
    ("Industrial yard", [4420, 4467, 4774, 4843], 130.4),
]
RELOCATED_PADS = {
    "Works Warehouse C": (4445, 4851),
    "Works Repair Shed": (4454, 4791),
    "Works Cold Storage": (4461, 4888),
    "Bank Pump House": (4380, 4849),
}
SURFACES = ["grass", "compacted_dirt", "wet_mud", "gravel", "exposed_rock"]
INDUSTRIAL = {
    "PZ194_01_YardPavement": [0, 0, 0],
    "PZ194_08_WorkshopShell": [24, 0, 15],
    "PZ194_09_WorkshopRoof": [24, 0, 15],
    "PZ194_12_PitCover": [31.6, 0, 19],
    "PZ194_21_PreviewBench": [26, 0, 19],
    "PZ194_22_WorkshopApron": [24, 0, 0],
}


def member(archive, suffix, prefix=""):
    matches = [name for name in archive.namelist() if name.startswith(prefix) and name.endswith(suffix)]
    if len(matches) != 1:
        raise ValueError(f"Expected one {suffix}, found {matches}")
    return archive.read(matches[0])


def smoothstep(t):
    t = np.clip(t, 0, 1)
    return t*t*(3-2*t)


def interpolate(x, knots, vals):
    """Shape-preserving Hermite profile with zero tangent at flat joins."""
    ds = np.diff(knots)
    slopes = np.diff(vals)/ds
    tangents = np.zeros(len(knots))
    valid = slopes[:-1]*slopes[1:] > 0
    tangents[1:-1][valid] = 2 / (1/slopes[:-1][valid] + 1/slopes[1:][valid])
    i = np.clip(np.searchsorted(knots,x,side="right")-1,0,len(knots)-2)
    t = np.clip((x-knots[i])/ds[i],0,1)
    return ((2*t**3-3*t**2+1)*vals[i] + (t**3-2*t**2+t)*ds[i]*tangents[i]
            + (-2*t**3+3*t**2)*vals[i+1] + (t**3-t**2)*ds[i]*tangents[i+1])


def image(raw):
    return np.array(Image.open(io.BytesIO(raw)))


def grade_terrain(original, water, X, N):
    result = original.copy()
    paved = np.zeros_like(original)
    for _,(w,e,s,n),height in SITES:
        outside = np.hypot(np.maximum.reduce([w-X,X-e,np.zeros_like(X)]),
                           np.maximum.reduce([s-N,N-n,np.zeros_like(N)]))
        weight = (1-smoothstep(outside/26)) * (water == 0)
        result += (height-0.12-result)*weight
        paved = np.maximum(paved,(1-smoothstep(outside/3))*0.66)
    center = interpolate(X, ROAD[:,0], ROAD[:,1])
    road_height = interpolate(X, ROAD[:,0], ROAD[:,2])
    distance = np.abs(N-center)
    cutoff = 1-smoothstep(np.maximum(ROAD[0,0]-X,X-ROAD[-1,0])/10)
    weight = (1-smoothstep((distance-5.6)/19))*cutoff
    # Keep the river bed and floodplain under the bridge in their original state.
    weight[(X>=BRIDGE_START)&(X<=BRIDGE_END)] = 0
    weight[water>0] = 0
    result += (road_height-0.16-result)*weight
    paved = np.maximum(paved,(1-smoothstep((distance-4.8)/4))*weight)
    assert np.array_equal(result[water>0],original[water>0])
    return result,paved


def build(source, project):
    data = project/"assets"/"pilot"
    data.mkdir(parents=True,exist_ok=True)
    for folder in ("materials","industrial"):
        (data/folder).mkdir(exist_ok=True)
    with ZipFile(next(source.glob("*PZ179_PZ194*"))) as original, ZipFile(next(source.glob("*Supplement_v01.zip"))) as pack:
        terrain = image(member(original,"Mosaic_501x501_R16.png","Deliverables/PZ-179"))
        wet = image(member(pack,"PZ180_water_pilot.png","PZ-180"))
        assert terrain.shape == wet.shape == (WIDTH, WIDTH)
        original_height = terrain.astype(np.float64)*.1-500
        X,N = np.meshgrid(WEST+np.arange(WIDTH)*STEP,NORTH-np.arange(WIDTH)*STEP)
        elevation, paving = grade_terrain(original_height,wet,X,N)
        (data/"height_f32.bin").write_bytes((elevation-ORIGIN[2]).astype("<f4").tobytes())
        Image.fromarray(wet).save(data/"water_mask.png")

        cover = {name:image(member(pack,f"{name}_pilot_501.png","PZ-182"))/255
                 for name in ("grass","tree_cover","dirt","mud","exposed_rock")}
        # Paint graded areas gravel and preserve the material blend outside the pilot work.
        blend = np.stack((cover["grass"]+cover["tree_cover"],cover["dirt"],cover["mud"],cover["exposed_rock"]))
        blend[2] = np.maximum(blend[2],np.asarray(wet)/255)
        blend[0] += 0.025
        blend /= blend.sum(axis=0)
        blend *= 1-paving
        control = np.stack((blend[0],blend[1],blend[2],paving),axis=-1)
        Image.fromarray(np.floor(control*255).astype(np.uint8)).save(data/"ground_blend.png")
        for name in SURFACES:
            color = member(pack,f"/{name}_base_color.png","PZ-181")
            (data/"materials"/f"{name}_albedo.png").write_bytes(color)
            normal = image(member(pack,f"/{name}_normal_gl.png","PZ-181"))
            roughness = image(member(pack,f"/{name}_roughness.png","PZ-181"))
            Image.fromarray(np.dstack((normal,roughness))).save(data/"materials"/f"{name}_normal_roughness.png")
        for path in ["PZ-188_Common_Infected_Animated_v01.glb","PZ-196_PZ141_Driving_Sedan_v01.glb"]:
            (data/path).write_bytes(member(pack,path))
        for module in INDUSTRIAL:
            (data/"industrial"/f"{module}.glb").write_bytes(member(original,f"/glb/{module}.glb","Deliverables/PZ194"))
        collisions = json.loads(member(original,"PZ194_collision_boxes.json","Deliverables/PZ194"))

        water_geo = json.loads(member(pack,"PZ180_waterways_local_m.geojson"))
        water_features = {f["id"]: f["geometry"]["coordinates"] for f in water_geo["features"]}
        profiles = list(csv.DictReader(io.StringIO(member(pack,"PZ180_water_levels.csv").decode())))
        water_strips = []
        for reach in ("KAL-MAIN","KAL-CREEK"):
            levels = [float(row["surface_m"]) for row in profiles if row["reach_id"]==reach]
            left,right = (water_features[reach+side] for side in ("-LEFT","-RIGHT"))
            assert len(left) == len(right) and len(left) <= len(levels)
            water_strips.append({"id":reach,"left":[[x,y,z] for (x,y),z in zip(left,levels)],
                                 "right":[[x,y,z] for (x,y),z in zip(right,levels)]})
        pads = list(csv.DictReader(io.StringIO(member(pack,"PZ183_draft_pad_terrain_samples.csv").decode())))
        wet_pads = {r["name"]:r for r in pads if r["overlaps_water"]=="True"}
        assert wet_pads.keys()==RELOCATED_PADS.keys()
        relocated = []
        footprints = list(csv.DictReader(io.StringIO(member(pack,"footprints.csv","Source/ground_inputs").decode("utf-8-sig"))))
        by_name = {f["name"]:f for f in footprints}
        for name,(east,north) in RELOCATED_PADS.items():
            prior = wet_pads[name]
            original_poly = np.array(json.loads(by_name[name]["polygon_m"])) + [WEST,NORTH-1000]
            placed = original_poly - original_poly[:-1].mean(axis=0) + [east,north]
            rows = slice(int(np.floor((NORTH-placed[:,1].max())/STEP)),int(np.ceil((NORTH-placed[:,1].min())/STEP))+1)
            cols = slice(int(np.floor((placed[:,0].min()-WEST)/STEP)),int(np.ceil((placed[:,0].max()-WEST)/STEP))+1)
            assert not wet[rows,cols].any(),name
            relocated.append({"id":prior["footprint_id"],"name":name,
                              "previous_sample_m":[float(prior["east_m"]),float(prior["north_m"])],
                              "dry_footprint_m":placed.round(2).tolist(),
                              "candidate_elevation_m":round(float(np.median(elevation[rows,cols])),2)})

    stations = np.r_[np.arange(ROAD[0,0],BRIDGE_START,5),np.arange(BRIDGE_START,BRIDGE_END,12),
                     np.arange(BRIDGE_END,ROAD[-1,0],5),ROAD[-1,0]]
    road_points = np.column_stack((stations,interpolate(stations,ROAD[:,0],ROAD[:,1]),
                                   interpolate(stations,ROAD[:,0],ROAD[:,2])))
    grades = np.abs(np.diff(road_points[:,2])) / np.linalg.norm(np.diff(road_points[:,:2],axis=0),axis=1)
    assert grades.max() < .13
    profile = {
        "grid": {"origin_m":ORIGIN,"west":WEST,"north":NORTH,"samples":WIDTH,"spacing":STEP},
        "road_m":road_points.round(4).tolist(),
        "bridge":{"east_start":BRIDGE_START,"east_end":BRIDGE_END,"north":BRIDGE_NORTH,
                  "surface_m":BRIDGE_HEIGHT,"width_m":11.4,"spans":6},
        "route_grade_max_pct":round(float(grades.max()*100),2),
        "sites":[{"name":name,"bounds_m":bounds,"elevation_m":elevation} for name,bounds,elevation in SITES],
        "relocated_draft_pads":relocated,"water_strips":water_strips,
        "industrial_origin":[4420,4813,130.4],"warehouse_origin":[4425,4819,130.4],
        "industrial_modules":[{"name":name,"offset":offset,"collision":collisions["modules"].get(name,[])}
                              for name,offset in INDUSTRIAL.items()],
    }
    (data/"pilot_layout.json").write_text(json.dumps(profile,separators=(",",":"))+"\n",encoding="utf-8")
    print(f"Graded {len(road_points)} road stations, {grades.max():.1%} max grade, 4 terrain tiles, {len(relocated)} dry pad locations")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--new-assets",required=True,type=Path)
    parser.add_argument("--project",type=Path,default=Path(__file__).resolve().parents[2])
    args = parser.parse_args()
    build(args.new_assets,args.project)
