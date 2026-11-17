"""Copy and verify the mountain project into the existing Godot project.

The source is retained until the merged runtime passes validation. No user asset
archive or the separate Project Z (Godot) directory is modified.
"""
from pathlib import Path
import hashlib
import json
import shutil

WORKSPACE = Path(__file__).resolve().parents[1]
OLD = WORKSPACE / 'ProjectZ_Kaldran_Mountains'
GAME = WORKSPACE / 'project_z'
SOURCE = GAME / 'mountain_source'
CASE = {s: s.lower() for s in ('Assets', 'Materials', 'Scripts', 'Scenes', 'Tests')}

def digest(data):
    return hashlib.sha256(data).hexdigest()

def run():
    records = []
    for src in sorted(OLD.rglob('*')):
        if not src.is_file() or '.godot' in src.parts or '__pycache__' in src.parts:
            continue
        rel = src.relative_to(OLD)
        if rel.parts[0] == '07_Godot':
            tail = Path(*rel.parts[1:])
            if tail.name == 'project.godot':
                dst = SOURCE / '09_Documentation/original_project.godot.txt'
            else:
                dst = GAME / CASE.get(tail.parts[0], tail.parts[0]) / Path(*tail.parts[1:]) if len(tail.parts)>1 else GAME / tail
        else:
            dst = SOURCE / rel
        raw = src.read_bytes()
        content = raw
        if src.suffix.lower() in {'.gd', '.tscn', '.tres', '.json', '.gdshader', '.gdshaderinc', '.import', '.res'}:
            # Equal-length case normalization preserves native resource string lengths.
            for old, new in CASE.items():
                content = content.replace(('res://'+old+'/').encode(), ('res://'+new+'/').encode())
        if dst.exists() and dst.read_bytes() != content:
            raise RuntimeError('Refusing to overwrite conflicting file: '+str(dst))
        dst.parent.mkdir(parents=True, exist_ok=True)
        if not dst.exists():
            dst.write_bytes(content)
            shutil.copystat(src, dst)
        if digest(dst.read_bytes()) != digest(content):
            raise RuntimeError('Copy verification failed: '+str(dst))
        records.append({'source':rel.as_posix(), 'destination':dst.relative_to(GAME).as_posix(),
                        'bytes':len(raw), 'source_sha256':digest(raw), 'copied_sha256':digest(content)})
    report = SOURCE / '09_Documentation/Consolidation_Manifest.json'
    report.write_text(json.dumps({'source':str(OLD), 'target':str(GAME), 'files':records},indent=2))
    print(json.dumps({'verified_files':len(records), 'bytes':sum(r['bytes'] for r in records), 'manifest':str(report)}))

if __name__ == '__main__':
    run()
