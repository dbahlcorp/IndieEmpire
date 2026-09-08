"""Key and slice painterly office component sheets into game-ready PNGs."""
from pathlib import Path
import argparse
import numpy as np
from PIL import Image

CATEGORIES = [
    "walls", "flooring", "desks", "seating", "computers",
    "lighting", "storage", "lounge", "plants", "decor",
]

# Normalized boxes follow the deliberately spaced 5x2 generation layout while
# leaving room for wide rugs, desks and sofas without changing their aspect.
BOXES = [
    (0.000, 0.00, 0.195, 0.52), (0.195, 0.00, 0.417, 0.52),
    (0.417, 0.00, 0.651, 0.52), (0.651, 0.00, 0.791, 0.52),
    (0.791, 0.00, 1.000, 0.52), (0.000, 0.52, 0.182, 1.00),
    (0.182, 0.52, 0.397, 1.00), (0.397, 0.52, 0.661, 1.00),
    (0.661, 0.52, 0.830, 1.00), (0.830, 0.52, 1.000, 1.00),
]

def remove_background(image: Image.Image, mode: str) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.float32).copy()
    rgb = rgba[:, :, :3] / 255.0
    if mode == "chroma":
        strength = np.minimum(rgb[:, :, 1] - rgb[:, :, 0], rgb[:, :, 1] - rgb[:, :, 2])
        matte = np.clip((strength - 0.16) / 0.18, 0.0, 1.0)
    else:
        spread = rgb.max(axis=2) - rgb.min(axis=2)
        value = rgb.mean(axis=2)
        neutral = np.clip((0.16 - spread) / 0.10, 0.0, 1.0)
        bright = np.clip((value - 0.76) / 0.16, 0.0, 1.0)
        matte = neutral * bright
    rgba[:, :, 3] = np.minimum(rgba[:, :, 3], (1.0 - matte) * 255.0)
    return Image.fromarray(np.uint8(np.clip(rgba, 0, 255)), "RGBA")

def clean_edge_islands(image: Image.Image, category: str) -> Image.Image:
    rgba = np.asarray(image, dtype=np.uint8).copy()
    mask = rgba[:, :, 3] > 24
    height, width = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    components = []
    for y in range(height):
        for x in range(width):
            if not mask[y, x] or seen[y, x]:
                continue
            stack = [(x, y)]
            seen[y, x] = True
            pixels = []
            while stack:
                px, py = stack.pop()
                pixels.append((px, py))
                for nx, ny in ((px - 1, py), (px + 1, py), (px, py - 1), (px, py + 1)):
                    if 0 <= nx < width and 0 <= ny < height and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((nx, ny))
            components.append(pixels)
    if not components:
        return image
    largest = max(components, key=len)
    largest_x = [p[0] for p in largest]
    largest_y = [p[1] for p in largest]
    allows_multiple = category in ("computers", "decor")
    margin = 60
    lx0, lx1 = min(largest_x) - margin, max(largest_x) + margin
    ly0, ly1 = min(largest_y) - margin, max(largest_y) + margin
    keep = np.zeros_like(mask, dtype=bool)
    for pixels in components:
        xs = np.fromiter((p[0] for p in pixels), dtype=np.int32)
        ys = np.fromiter((p[1] for p in pixels), dtype=np.int32)
        centered = 0.12 * width < xs.mean() < 0.88 * width and 0.10 * height < ys.mean() < 0.90 * height
        touches_crop_edge = xs.min() <= 3 or xs.max() >= width - 4 or ys.min() <= 3 or ys.max() >= height - 4
        near_subject = lx0 <= xs.mean() <= lx1 and ly0 <= ys.mean() <= ly1
        if pixels is largest or (allows_multiple and len(pixels) >= 28 and centered
                                 and not touches_crop_edge and near_subject):
            keep[ys, xs] = True
    rgba[~keep, 3] = 0
    return Image.fromarray(rgba, "RGBA")

def slice_sheet(source: Path, destination: Path, mode: str) -> None:
    sheet = remove_background(Image.open(source), mode)
    destination.mkdir(parents=True, exist_ok=True)
    sheet.save(destination / "sheet.png", optimize=True)
    width, height = sheet.size
    for category, box in zip(CATEGORIES, BOXES):
        x0, y0, x1, y1 = box
        crop = sheet.crop((int(x0 * width), int(y0 * height), int(x1 * width), int(y1 * height)))
        side = max(crop.size)
        square = Image.new("RGBA", (side, side))
        square.alpha_composite(crop, ((side - crop.width) // 2, (side - crop.height) // 2))
        final = square.resize((256, 256), Image.Resampling.LANCZOS)
        clean_edge_islands(final, category).save(destination / f"{category}.png", optimize=True)

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--mode", choices=("chroma", "bright"), required=True)
    args = parser.parse_args()
    slice_sheet(args.source, args.destination, args.mode)

if __name__ == "__main__":
    main()
