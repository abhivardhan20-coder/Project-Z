"""Rebuild the delivered source pipeline using bundled assets, without downloads.

python rebuild.py --godot PATH_TO_GODOT [--validate] [--integrate-city]
Existing generated outputs are replaced. Hand edits to baked resources should be
exported or copied before rebuilding; parameter JSON and source scripts are inputs.
"""
import argparse,subprocess,sys,re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
SCRIPTS=Path(__file__).resolve().parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--godot',required=True,type=Path)
parser.add_argument('--validate',action='store_true')
parser.add_argument('--integrate-city',action='store_true')
args=parser.parse_args()
engine=str(args.godot.resolve())
if not Path(engine).is_file():raise SystemExit('Godot executable not found: '+engine)

def run(command,logname=None,success=None):
    print('RUN '+str(command[0])+' '+' '.join(map(str,command[1:])),flush=True)
    result=subprocess.run(list(map(str,command)),cwd=ROOT,capture_output=True,text=True,encoding='utf-8',errors='replace')
    output=result.stdout+'\n'+result.stderr
    if logname:(ROOT/'09_Documentation'/logname).write_text(output,encoding='utf-8')
    print(output[-8000:],flush=True)
    if result.returncode or re.search(r'(^|\n)(SCRIPT ERROR:|ERROR:|FAIL )',output) or (success and success not in output):
        raise SystemExit('Build stopped: '+str(command))

for script,extra in [('generate.py',[]),('fetch_surfaces.py',['--offline']),('prepare_engine.py',[]),('validate_sources.py',[])]:
    run([sys.executable,SCRIPTS/script,*extra])
run([engine,'--headless','--editor','--path',ROOT.parent,'--import'],'final-import.log')
run([engine,'--headless','--path',ROOT.parent,'--script','res://scripts/build_native.gd'],'native-build.log','NATIVE_BUILD_OK')
run([engine,'--headless','--path',ROOT.parent,'--script','res://scripts/bake_user_assets.gd'],'user-assets-bake.log','USER_ASSET_BAKE_COMPLETE')
run([sys.executable,SCRIPTS/'place_user_assets.py'])
run([sys.executable,SCRIPTS/'calibrate_cameras.py'])
run([engine,'--headless','--path',ROOT.parent,'--script','res://scripts/bake_districts.gd'],'district-bake.log','DISTRICT_BAKE_COMPLETE')
if args.validate:
    run([engine,'--path',ROOT.parent,'--script','res://tests/validate_assets.gd'],'user-assets-qa.log','USER_ASSET_QA')
    run([engine,'--path',ROOT.parent,'--script','res://tests/validate.gd'],'engine-qa.log','MOUNTAIN_QA_COMPLETE failures=0')
    run([sys.executable,SCRIPTS/'compare_references.py'])
if args.integrate_city:
    run([sys.executable,SCRIPTS/'integrate_city.py'])
if args.validate:
    run([sys.executable,SCRIPTS/'write_reports.py'])
    run([sys.executable,SCRIPTS/'write_user_asset_report.py'])
print('REBUILD_COMPLETE',flush=True)
