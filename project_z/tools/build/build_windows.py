"""Build a Windows release with a clean staging copy of the reusable source GLBs."""

import argparse
import shutil
import subprocess
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[2]
GROUPS = ("scripts", "scenes", "materials", "resources", "assets")


def stage_project(staging):
    for name in ("project.godot", "export_presets.cfg"):
        shutil.copyfile(PROJECT / name, staging / name)
    for group in GROUPS:
        for source in (PROJECT / group).rglob("*"):
            if not source.is_file():
                continue
            relative = source.relative_to(PROJECT)
            if group == "assets":
                if source.suffix not in {".glb", ".json", ".bin", ".png", ".jpg", ".hdr"}:
                    continue
                if source.suffix == ".png" and (
                    relative.parts[1] != "pilot" or
                    (source.name not in {"ground_blend.png", "water_mask.png"} and source.parent.name != "materials")
                ):
                    continue
            target = staging / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            # The runtime loader reads these bytes from the PCK. The editable project
            # keeps the standard GLB and PNG extensions for Godot and Blender.
            if group == "assets" and source.suffix in {".glb", ".png", ".jpg"}:
                target = target.with_suffix(target.suffix + ".runtime")
            shutil.copyfile(source, target)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--template", type=Path, help="Optional Godot 4.7.2 Windows x86-64 release template")
    options = parser.parse_args()
    editor = options.godot.resolve(strict=True)
    build = PROJECT / "builds/windows"
    build.mkdir(parents=True, exist_ok=True)
    # Each invocation gets a fresh staging directory under the ignored Godot cache.
    import tempfile
    cache = PROJECT / ".godot"
    cache.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="release-", dir=cache) as temporary:
        staging = Path(temporary)
        stage_project(staging)
        if options.template:
            template = options.template.resolve(strict=True).as_posix()
            preset = staging / "export_presets.cfg"
            text = preset.read_text(encoding="utf8")
            preset.write_text(text.replace('custom_template/release=""', f'custom_template/release="{template}"'), encoding="utf8")
        subprocess.run([str(editor), "--headless", "--path", str(staging), "--log-file",
                        str(cache / "export.log"), "--export-release", "Windows Desktop", str(build / "ProjectZ.exe")],
                       check=True)
    shutil.copyfile(PROJECT / "LICENSES.md", build / "LICENSES.md")
    print(build / "ProjectZ.exe")


if __name__ == "__main__":
    main()
