"""Fit a generated 4x4 RGBA character atlas into exact 256px cells.

Generated poses sometimes extend a few pixels beyond an ideal mathematical
quadrant. Cropping at those quadrant lines cuts limbs. This tool finds each
disconnected alpha component, assigns it to the nearest atlas cell, groups the
pose and its shadow, then fits the complete group inside a safe cell gutter.
"""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image


GRID = 4
CELL = 256
CANVAS = GRID * CELL
SAFE_SIZE = 232
CORE_ALPHA_THRESHOLD = 64
MIN_COMPONENT_PIXELS = 1_000
SOURCE_PADDING = 8


def connected_components(mask: np.ndarray):
    height, width = mask.shape
    visited = np.zeros_like(mask, dtype=bool)
    for start_y, start_x in np.argwhere(mask):
        if visited[start_y, start_x]:
            continue
        queue = deque([(int(start_x), int(start_y))])
        visited[start_y, start_x] = True
        points: list[tuple[int, int]] = []
        while queue:
            x, y = queue.popleft()
            points.append((x, y))
            if x > 0 and mask[y, x - 1] and not visited[y, x - 1]:
                visited[y, x - 1] = True
                queue.append((x - 1, y))
            if x + 1 < width and mask[y, x + 1] and not visited[y, x + 1]:
                visited[y, x + 1] = True
                queue.append((x + 1, y))
            if y > 0 and mask[y - 1, x] and not visited[y - 1, x]:
                visited[y - 1, x] = True
                queue.append((x, y - 1))
            if y + 1 < height and mask[y + 1, x] and not visited[y + 1, x]:
                visited[y + 1, x] = True
                queue.append((x, y + 1))
        if len(points) >= MIN_COMPONENT_PIXELS:
            yield points


def normalize(source_path: Path, output_path: Path) -> None:
    source = Image.open(source_path).convert("RGBA")
    pixels = np.array(source)
    alpha = pixels[:, :, 3]
    # A stricter core threshold ignores faint one-pixel extraction bridges
    # that can otherwise join two vertically adjacent poses.
    mask = alpha > CORE_ALPHA_THRESHOLD
    height, width = mask.shape
    groups: list[list[list[tuple[int, int]] | None]] = [
        [None for _ in range(GRID)] for _ in range(GRID)
    ]

    for points in connected_components(mask):
        mean_x = sum(point[0] for point in points) / len(points)
        mean_y = sum(point[1] for point in points) / len(points)
        col = min(int(mean_x * GRID / width), GRID - 1)
        row = min(int(mean_y * GRID / height), GRID - 1)
        current = groups[row][col]
        if current is None or len(points) > len(current):
            groups[row][col] = points

    output = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    for row in range(GRID):
        for col in range(GRID):
            points = groups[row][col]
            if points is None:
                raise ValueError(f"No character content found in cell {col},{row}")
            xs = [point[0] for point in points]
            ys = [point[1] for point in points]
            left = max(min(xs) - SOURCE_PADDING, 0)
            right = min(max(xs) + SOURCE_PADDING + 1, width)
            top = max(min(ys) - SOURCE_PADDING, 0)
            bottom = min(max(ys) + SOURCE_PADDING + 1, height)
            crop_pixels = pixels[top:bottom, left:right].copy()
            crop = Image.fromarray(crop_pixels, "RGBA")

            scale = min(SAFE_SIZE / crop.width, SAFE_SIZE / crop.height)
            draw_size = (
                max(1, round(crop.width * scale)),
                max(1, round(crop.height * scale)),
            )
            crop = crop.resize(draw_size, Image.Resampling.LANCZOS)
            destination = (
                col * CELL + (CELL - draw_size[0]) // 2,
                row * CELL + (CELL - draw_size[1]) // 2,
            )
            output.alpha_composite(crop, destination)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output.save(output_path, optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    normalize(args.source, args.output)


if __name__ == "__main__":
    main()
