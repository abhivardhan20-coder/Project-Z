"""Pack linear grayscale occlusion, roughness and metallic maps for UltraSurface."""

import argparse
from pathlib import Path

from PIL import Image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ao", type=Path)
    parser.add_argument("--roughness", type=Path, required=True)
    parser.add_argument("--metallic", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    with Image.open(args.roughness) as source:
        roughness = source.convert("L")

    def load_channel(path, default):
        if path is None:
            return Image.new("L", roughness.size, default)
        with Image.open(path) as source:
            if source.size != roughness.size:
                parser.error(f"{path} has size {source.size}. Expected {roughness.size}.")
            return source.convert("L")

    if args.output.suffix.lower() != ".png":
        parser.error("Use a .png output for lossless channel packing.")
    if args.output.resolve() in {path.resolve() for path in (args.ao, args.roughness, args.metallic) if path}:
        parser.error("The packed output must have a different path from the source maps.")
    orm = Image.merge("RGB", (load_channel(args.ao, 255), roughness, load_channel(args.metallic, 0)))
    orm.save(args.output)


if __name__ == "__main__":
    main()
