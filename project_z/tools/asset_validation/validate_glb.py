"""Inspect GLB headers, dependency paths, scene roots, and selected animated assets."""

import json
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HEADER = struct.Struct("<4sIIII")


def load_glb(path):
    with path.open("rb") as source:
        magic, version, declared, size, chunk = HEADER.unpack(source.read(HEADER.size))
        if magic != b"glTF" or version != 2 or declared != path.stat().st_size or chunk != 0x4E4F534A:
            raise ValueError("invalid GLB 2.0 header")
        return json.loads(source.read(size))


def main():
    count = 0
    errors = []
    for asset in (ROOT / "assets").rglob("*.glb"):
        count += 1
        try:
            model = load_glb(asset)
            if not model.get("scenes") or not model.get("nodes") or not model.get("meshes"):
                raise ValueError("empty scene or missing geometry")
            for dependency in model.get("images", []) + model.get("buffers", []):
                uri = dependency.get("uri", "")
                if uri and not uri.startswith("data:") and not (asset.parent / uri).exists():
                    raise ValueError(f"missing external dependency {uri}")
            if asset.name == "PZ-188_Common_Infected_Animated_v01.glb":
                animations = {entry.get("name") for entry in model.get("animations", [])}
                needed = {"PZ188_Infected_" + clip for clip in ("Idle", "Shamble", "Pursuit", "LungeAttack", "HitReaction", "Death")}
                if not model.get("skins") or not needed <= animations:
                    raise ValueError("infected rig or gameplay animation is absent")
        except (OSError, ValueError, struct.error) as error:
            errors.append(f"{asset.relative_to(ROOT)} · {error}")
    for source in (ROOT / "scripts").rglob("*.gd"):
        for path in re.findall(r'"res://([^"]+\.glb)"', source.read_text(encoding="utf-8-sig")):
            if not (ROOT / path).is_file():
                errors.append(f"{source.relative_to(ROOT)} · missing {path}")
    for error in errors:
        print(error)
    print(f"Checked {count} GLB files, {len(errors)} errors.")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
