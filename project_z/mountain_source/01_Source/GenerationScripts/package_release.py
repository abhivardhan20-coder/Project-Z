"""Archive the real project and sources without machine-specific Godot caches."""
from pathlib import Path
import zipfile,hashlib,json

ROOT=Path(__file__).resolve().parents[3]
import argparse
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output',type=Path,required=True)
output=parser.parse_args().output.resolve()
if output.exists():raise SystemExit('Output already exists: '+str(output))
selected=[]
current_logs={'engine-qa.log','native-build.log','final-import.log','city-integration-qa.log','user-assets-bake.log','user-assets-qa.log','user-assets-atlas-fix.log','district-bake.log','user-assets-reimport-final.log'}
for path in sorted(ROOT.rglob('*')):
    if not path.is_file():continue
    rel=path.relative_to(ROOT)
    if any(part in rel.parts for part in ['builds','.git']) or path.suffix in {'.zip','.exe','.pck'}:continue
    if '.godot' in rel.parts or '__pycache__' in rel.parts or path.suffix=='.pyc':continue
    if path.suffix=='.log' and path.name not in current_logs:continue
    selected.append(path)
with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED,compresslevel=3) as z:
    for path in selected:z.write(path,arcname=str(Path(ROOT.name)/path.relative_to(ROOT)))
with zipfile.ZipFile(output) as z:
    bad=z.testzip()
    if bad:raise RuntimeError('Archive CRC verification failed: '+bad)
record={'archive':output.name,'files':len(selected),'bytes':output.stat().st_size,
        'sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'crc_check':'passed',
        'scope':'Unified city and mountain Godot project, editable sources and documentation'}
output.with_suffix('.json').write_text(json.dumps(record,indent=2))
print(json.dumps(record,indent=2))
