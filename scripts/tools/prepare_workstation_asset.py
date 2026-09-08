"""Turn an ImageGen checkerboard cutout into a compact transparent sprite."""

from pathlib import Path
import argparse

import numpy as np
from PIL import Image, ImageFilter


def prepare(source: Path, destination: Path, size: int) -> None:
    image = Image.open(source).convert("RGB")
    rgb = np.asarray(image, dtype=np.float32) / 255.0
    value = rgb.mean(axis=2)
    saturation = rgb.max(axis=2) - rgb.min(axis=2)

    # ImageGen occasionally rasterizes its transparency preview.  The two
    # neutral checker tones have almost no chroma and sit near white, while the
    # painted prop is either darker or warmer.  Combining both signals keeps
    # beige plastic and screen glow without preserving the checkerboard.
    chroma_alpha = np.clip((saturation - 0.018) / 0.075, 0.0, 1.0)
    dark_alpha = np.clip((0.91 - value) / 0.20, 0.0, 1.0)
    alpha = np.maximum(chroma_alpha, dark_alpha)
    alpha = np.uint8(np.clip(alpha * 255.0, 0, 255))
    alpha = np.asarray(Image.fromarray(alpha).filter(ImageFilter.GaussianBlur(0.7)))

    rgba = np.dstack((np.uint8(rgb * 255.0), alpha))
    result = Image.fromarray(rgba, "RGBA")
    bounds = result.getchannel("A").getbbox()
    if bounds is None:
        raise RuntimeError(f"No foreground found in {source}")
    result = result.crop(bounds)

    padding = max(8, int(max(result.size) * 0.07))
    side = max(result.size) + padding * 2
    square = Image.new("RGBA", (side, side))
    square.alpha_composite(result, ((side - result.width) // 2, (side - result.height) // 2))
    square = square.resize((size, size), Image.Resampling.LANCZOS)
    destination.parent.mkdir(parents=True, exist_ok=True)
    square.save(destination, optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--size", type=int, default=256)
    args = parser.parse_args()
    prepare(args.source, args.destination, args.size)


if __name__ == "__main__":
    main()
