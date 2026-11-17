"""Package and CRC-check the Windows build and editable Godot source."""

import argparse
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

PROJECT = Path(__file__).resolve().parents[2]
OUTPUT = PROJECT / "builds"
PREFIX = "ProjectZ_Kaldran_1km2"


def create_archive(target, files, base):
    with ZipFile(target, "w", compression=ZIP_DEFLATED, compresslevel=1) as archive:
        for file in files:
            archive.write(file, file.relative_to(base))
    with ZipFile(target) as archive:
        bad_file = archive.testzip()
        if bad_file:
            raise RuntimeError(f"{target.name}: bad CRC for {bad_file}")
        print(f"{target.name}: {len(archive.infolist())} files, {target.stat().st_size:,} bytes")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ultra", action="store_true", help="Use the Ultra Graphics release names")
    args = parser.parse_args()
    windows = OUTPUT / "windows"
    required = [windows / file for file in ("ProjectZ.exe", "ProjectZ.pck", "LICENSES.md")]
    if any(not file.is_file() or file.stat().st_size == 0 for file in required):
        raise SystemExit("Build the Windows release before packaging.")
    sources = []
    for file in sorted(PROJECT.rglob("*")):
        if not file.is_file():
            continue
        relative = file.relative_to(PROJECT)
        if any(part in {".godot", "builds", "__pycache__"} for part in relative.parts):
            continue
        if file.suffix in {".log", ".import", ".tmp"}:
            continue
        if relative.parts[0] == "assets" and file.suffix == ".png":
            if len(relative.parts) < 3 or relative.parts[1] != "pilot":
                continue
            if file.name not in {"ground_blend.png", "water_mask.png"} and file.parent.name != "materials":
                continue
        sources.append(file)
    prefix = "ProjectZ_UltraGraphics_v1" if args.ultra else PREFIX
    demo = "Integrated_Demo" if args.ultra else "Windows"
    create_archive(OUTPUT / f"{prefix}_{demo}.zip", required, windows)
    create_archive(OUTPUT / f"{prefix}_Source.zip", sources, PROJECT.parent)


if __name__ == "__main__":
    main()
