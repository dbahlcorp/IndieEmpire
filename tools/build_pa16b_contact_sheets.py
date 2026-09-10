#!/usr/bin/env python3
"""Build PA.16B static-asset contact sheets at intended mobile sizes.

The output is deliberately review-oriented: every tile carries the asset id and
shows the same source at several real display sizes. SVG rasterization is done
with ImageMagick so the sheets reflect the source files rather than Godot's
editor thumbnails.
"""

from __future__ import annotations

import argparse
import json
import math
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MAGICK = Path(r"C:\Program Files\ImageMagick-7.1.2-Q16-HDRI\magick.exe")
PAPER = "#f8e8c8"
CREAM = "#fff7df"
INK = "#263c40"
MUTED_INK = "#617174"
TEAL = "#315f65"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "artifacts" / "pa16b-before",
    )
    parser.add_argument("--magick", type=Path, default=DEFAULT_MAGICK)
    parser.add_argument(
        "--families",
        nargs="*",
        help="Optional family names to render (for focused before/after review).",
    )
    parser.add_argument("--label", default="before", help="Label shown in the sheet header.")
    return parser.parse_args()


def manifest_families() -> dict[str, dict[str, str]]:
    data = json.loads((ROOT / "data" / "asset_manifest.json").read_text(encoding="utf-8"))
    return data["families"]


def repo_path(resource_path: str) -> Path:
    if resource_path.startswith("res://"):
        resource_path = resource_path[6:]
    return ROOT / resource_path


def extras() -> dict[str, dict[str, str]]:
    groups: dict[str, dict[str, str]] = {}
    patterns = {
        "ui_icons": ["assets/ui/icons/*.svg", "assets/ui/remodel/*.svg"],
        "employee_sprites": ["assets/employees/*.png"],
        "office_props": ["assets/equipment/*.png", "assets/offices/components/**/*.svg"],
        "office_paintings": [
            "assets/offices/*.png",
            "assets/offices/foreground/*.png",
            "assets/offices/atmosphere/*.png",
        ],
        "branding": ["assets/branding/*.png"],
    }
    for family, patterns_for_family in patterns.items():
        entries: dict[str, str] = {}
        for pattern in patterns_for_family:
            for path in sorted(ROOT.glob(pattern)):
                if path.name.endswith(".import"):
                    continue
                key = path.relative_to(ROOT).with_suffix("").as_posix()
                entries[key] = path.relative_to(ROOT).as_posix()
        groups[family] = entries
    return groups


def display_sizes(family: str) -> tuple[int, ...]:
    if family in {"empty_states", "branding", "office_paintings"}:
        return (64, 128, 192)
    if family in {"eras", "office_props"}:
        return (48, 96, 160)
    if family in {"platforms", "awards", "award_presentation", "milestones"}:
        return (32, 48, 64, 96)
    if family == "employee_sprites":
        return (48, 64, 96, 128)
    return (24, 32, 48, 64)


def rasterize(source: Path, max_size: int, magick: Path, temp_dir: Path) -> Image.Image:
    if source.suffix.lower() == ".svg":
        target = temp_dir / f"{source.stem}-{max_size}-{abs(hash(source))}.png"
        subprocess.run(
            [
                str(magick),
                "-background",
                "none",
                str(source),
                "-resize",
                f"{max_size}x{max_size}",
                str(target),
            ],
            check=True,
            capture_output=True,
        )
        return Image.open(target).convert("RGBA")
    image = Image.open(source).convert("RGBA")
    image.thumbnail((max_size, max_size), Image.Resampling.LANCZOS)
    return image


def checker(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], step: int = 10) -> None:
    left, top, right, bottom = box
    colors = (CREAM, "#ecdfc3")
    for y in range(top, bottom, step):
        for x in range(left, right, step):
            draw.rectangle(
                (x, y, min(x + step, right), min(y + step, bottom)),
                fill=colors[((x - left) // step + (y - top) // step) % 2],
            )


def draw_sheet(
    family: str,
    entries: list[tuple[str, Path]],
    output_dir: Path,
    magick: Path,
    temp_dir: Path,
    label: str,
) -> list[Path]:
    sizes = display_sizes(family)
    dark_preview_size = 32
    tile_w = max(300, sum(sizes) + dark_preview_size + 18 * (len(sizes) + 2))
    tile_h = max(sizes) + 66
    columns = 4
    rows = 6
    per_page = columns * rows
    font = ImageFont.load_default(size=14)
    small_font = ImageFont.load_default(size=11)
    created: list[Path] = []

    for page_index in range(math.ceil(len(entries) / per_page)):
        page_entries = entries[page_index * per_page : (page_index + 1) * per_page]
        header_h = 64
        sheet = Image.new("RGB", (columns * tile_w, header_h + rows * tile_h), PAPER)
        draw = ImageDraw.Draw(sheet)
        draw.rectangle((0, 0, sheet.width, header_h), fill=INK)
        title = f"PA.16B {label} - {family.replace('_', ' ').title()}"
        draw.text((20, 13), title, font=font, fill=CREAM)
        draw.text(
            (20, 36),
            f"Page {page_index + 1} - rendered at {', '.join(str(s) for s in sizes)} px + dark-ground check",
            font=small_font,
            fill="#b9d7db",
        )

        for index, (asset_id, source) in enumerate(page_entries):
            column = index % columns
            row = index // columns
            left = column * tile_w
            top = header_h + row * tile_h
            draw.rectangle((left, top, left + tile_w - 1, top + tile_h - 1), outline="#d1bea0")
            label = asset_id if len(asset_id) <= 37 else asset_id[:34] + "…"
            draw.text((left + 10, top + 8), label, font=font, fill=INK)
            draw.text((left + 10, top + 26), source.suffix.lower()[1:].upper(), font=small_font, fill=MUTED_INK)
            x = left + 12
            preview_top = top + 50
            for size in sizes:
                checker(draw, (x, preview_top, x + size, preview_top + size), max(4, size // 6))
                try:
                    rendered = rasterize(source, size, magick, temp_dir)
                    px = x + (size - rendered.width) // 2
                    py = preview_top + (size - rendered.height) // 2
                    sheet.paste(rendered, (px, py), rendered)
                except Exception as error:  # preserve the review inventory even if one file fails
                    draw.rectangle((x, preview_top, x + size, preview_top + size), outline="#b94e48", width=2)
                    draw.text((x + 3, preview_top + 3), "ERR", font=small_font, fill="#b94e48")
                    print(f"Could not render {source}: {error}")
                draw.text((x, preview_top + size + 3), f"{size}px", font=small_font, fill=TEAL)
                x += size + 18

            draw.rectangle(
                (x, preview_top, x + dark_preview_size, preview_top + dark_preview_size),
                fill=INK,
            )
            try:
                dark_render = rasterize(source, dark_preview_size, magick, temp_dir)
                px = x + (dark_preview_size - dark_render.width) // 2
                py = preview_top + (dark_preview_size - dark_render.height) // 2
                sheet.paste(dark_render, (px, py), dark_render)
            except Exception:
                draw.rectangle(
                    (x, preview_top, x + dark_preview_size, preview_top + dark_preview_size),
                    outline="#b94e48",
                    width=2,
                )
            draw.text((x, preview_top + dark_preview_size + 3), "dark", font=small_font, fill=TEAL)

        suffix = f"-{page_index + 1:02d}" if len(entries) > per_page else ""
        output = output_dir / f"{family}{suffix}.png"
        sheet.save(output, optimize=True)
        created.append(output)
    return created


def main() -> int:
    args = parse_args()
    output_dir = args.output.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    if not args.magick.exists():
        raise SystemExit(f"ImageMagick not found: {args.magick}")

    groups = manifest_families()
    groups.update(extras())
    if args.families:
        requested = set(args.families)
        unknown = sorted(requested.difference(groups))
        if unknown:
            raise SystemExit(f"Unknown families: {', '.join(unknown)}")
        groups = {name: mapping for name, mapping in groups.items() if name in requested}
    index: dict[str, list[str]] = {}
    with tempfile.TemporaryDirectory(prefix="pa16b-contact-") as temp:
        temp_dir = Path(temp)
        for family, mapping in groups.items():
            entries = [(asset_id, repo_path(path)) for asset_id, path in mapping.items()]
            entries = [(asset_id, path) for asset_id, path in entries if path.exists()]
            if not entries:
                continue
            outputs = draw_sheet(family, entries, output_dir, args.magick, temp_dir, args.label)
            index[family] = [path.name for path in outputs]

    (output_dir / "contact-sheet-index.json").write_text(
        json.dumps(index, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Created {sum(len(paths) for paths in index.values())} contact sheets in {output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
