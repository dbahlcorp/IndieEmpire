#!/usr/bin/env python3
"""Fail fast on repository-side iOS/TestFlight release mistakes."""

from __future__ import annotations

import argparse
import re
import struct
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def parse_godot_config(path: Path) -> dict[tuple[str, str], str]:
    values: dict[tuple[str, str], str] = {}
    section = ""
    for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line or line.startswith((";", "#")):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            continue
        if "=" in line:
            key, value = line.split("=", 1)
            values[(section, key)] = value.strip().strip('"')
    return values


def png_info(path: Path) -> tuple[int, int, int, bool]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise ValueError("not a PNG")
    width, height, bit_depth, color_type = struct.unpack(">IIBB", data[16:26])
    has_alpha = color_type in (4, 6) or b"tRNS" in data
    return width, height, bit_depth, has_alpha


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ci", action="store_true", help="require injected signing fields")
    args = parser.parse_args()

    errors: list[str] = []
    project = parse_godot_config(ROOT / "project.godot")
    preset = parse_godot_config(ROOT / "export_presets.cfg")
    ios = lambda key: preset.get(("preset.0.options", key), "")

    def require(condition: bool, message: str) -> None:
        if not condition:
            errors.append(message)

    require(preset.get(("preset.0", "platform")) == "iOS", "preset.0 must target iOS")
    require(ios("application/export_project_only") == "true", "iOS export must produce an Xcode project")
    min_ios_version = ios("application/min_ios_version")
    require(
        re.fullmatch(r"[0-9]+(?:\.[0-9]+){0,2}", min_ios_version) is not None
        and tuple(int(part) for part in min_ios_version.split(".")) >= (16, 0),
        "minimum iOS version must be 16.0 or newer",
    )
    require(ios("application/targeted_device_family") == "1", "release must remain iPhone-only")
    require(ios("architectures/arm64") == "true", "arm64 must be enabled")
    require(project.get(("display", "window/handheld/orientation")) == "portrait", "project must remain portrait")
    require(project.get(("application", "config/version")) == ios("application/short_version"), "project and iOS marketing versions differ")
    require(project.get(("rendering", "textures/vram_compression/import_etc2_astc")) == "true", "iOS export requires ETC2/ASTC texture compression")
    require(re.fullmatch(r"[1-9][0-9]*(?:\.[0-9]+){0,2}", ios("application/version")) is not None, "iOS build number must contain one to three numeric components")
    require(ios("entitlements/increased_memory_limit") == "false", "increased-memory entitlement needs measured justification")
    require("ITSAppUsesNonExemptEncryption</key><false/>" in ios("application/additional_plist_content"), "export-compliance declaration is missing")

    icon_resource = "res://assets/branding/app_icon.png"
    for key in ("icons/iphone_120x120", "icons/iphone_180x180", "icons/app_store_1024x1024"):
        require(ios(key) == icon_resource, f"{key} must use the canonical app icon")
    icon_path = ROOT / icon_resource.removeprefix("res://")
    try:
        width, height, bit_depth, has_alpha = png_info(icon_path)
        require((width, height) == (1024, 1024), "app icon must be 1024x1024")
        require(bit_depth == 8, "app icon must use 8-bit channels")
        require(not has_alpha, "app icon must not contain transparency")
    except (OSError, ValueError, struct.error) as exc:
        errors.append(f"cannot validate app icon: {exc}")

    if args.ci:
        require(ios("application/name") == "Indie Empire", "CI must inject the display name")
        require(re.fullmatch(r"[A-Z0-9]{10}", ios("application/app_store_team_id")) is not None, "CI must inject a valid Team ID")
        require(re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", ios("application/bundle_identifier")) is not None, "CI must inject a valid bundle ID")

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("iOS release preflight passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
