#!/usr/bin/env python3
"""Build labeled contact sheets from the deterministic PA.16B cover audit."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
INK = "#263c40"
PAPER = "#f8e8c8"
CREAM = "#fff7df"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=ROOT / "artifacts" / "pa16b-covers-before")
    parser.add_argument("--label", default="before")
    args = parser.parse_args()
    source = args.input.resolve()
    records = json.loads((source / "index.json").read_text(encoding="utf-8"))
    font = ImageFont.load_default(size=13)
    small = ImageFont.load_default(size=10)
    columns, rows = 5, 4
    tile_w, tile_h, header_h = 210, 292, 58
    for page in range(math.ceil(len(records) / (columns * rows))):
        page_records = records[page * columns * rows : (page + 1) * columns * rows]
        sheet = Image.new("RGB", (columns * tile_w, header_h + rows * tile_h), PAPER)
        draw = ImageDraw.Draw(sheet)
        draw.rectangle((0, 0, sheet.width, header_h), fill=INK)
        draw.text((16, 10), f"PA.16B covers {args.label} - page {page + 1}", font=font, fill=CREAM)
        draw.text((16, 31), "172 x 224 runtime captures; deterministic title/theme/genre/platform/year", font=small, fill="#b9d7db")
        for slot, record in enumerate(page_records):
            x = (slot % columns) * tile_w
            y = header_h + (slot // columns) * tile_h
            draw.rectangle((x, y, x + tile_w - 1, y + tile_h - 1), outline="#d1bea0")
            cover = Image.open(source / f"cover-{record['index']:03d}.png").convert("RGBA")
            sheet.paste(cover, (x + 19, y + 6), cover)
            draw.text((x + 7, y + 234), str(record["title"])[:29], font=small, fill=INK)
            meta = f"{record['year']} | {record['genre']} | {record['theme']}"
            draw.text((x + 7, y + 250), meta[:34], font=small, fill=INK)
            draw.text((x + 7, y + 266), str(record["platform"]), font=small, fill=INK)
        sheet.save(source / f"contact-sheet-{page + 1:02d}.png", optimize=True)
    print(f"Created {math.ceil(len(records) / (columns * rows))} cover contact sheets in {source}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
