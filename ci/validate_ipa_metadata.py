#!/usr/bin/env python3
"""Validate the metadata Apple will read from a packaged iPhone IPA."""

from __future__ import annotations

import argparse
import plistlib
import sys
import zipfile
from pathlib import Path


def version_tuple(value: str) -> tuple[int, ...]:
    return tuple(int(part) for part in value.split("."))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("ipa", type=Path)
    parser.add_argument("--bundle-id", required=True)
    args = parser.parse_args()

    errors: list[str] = []
    try:
        with zipfile.ZipFile(args.ipa) as archive:
            plist_paths = [
                name
                for name in archive.namelist()
                if name.startswith("Payload/") and name.endswith(".app/Info.plist")
            ]
            if len(plist_paths) != 1:
                raise ValueError(f"expected one app Info.plist, found {len(plist_paths)}")
            metadata = plistlib.loads(archive.read(plist_paths[0]))
    except (OSError, ValueError, zipfile.BadZipFile, plistlib.InvalidFileException) as exc:
        print(f"ERROR: cannot inspect IPA: {exc}", file=sys.stderr)
        return 1

    if metadata.get("UIDeviceFamily") != [1]:
        errors.append(
            f"UIDeviceFamily must be [1] for iPhone-only, got {metadata.get('UIDeviceFamily')!r}"
        )

    minimum_os = str(metadata.get("MinimumOSVersion", ""))
    try:
        if version_tuple(minimum_os) < (16, 0):
            errors.append(f"MinimumOSVersion must be 16.0 or newer, got {minimum_os!r}")
    except ValueError:
        errors.append(f"MinimumOSVersion is invalid: {minimum_os!r}")

    if metadata.get("CFBundleIdentifier") != args.bundle_id:
        errors.append(
            f"CFBundleIdentifier must be {args.bundle_id!r}, got {metadata.get('CFBundleIdentifier')!r}"
        )

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print(
        "IPA metadata passed: "
        f"UIDeviceFamily={metadata['UIDeviceFamily']}, "
        f"MinimumOSVersion={minimum_os}, "
        f"CFBundleIdentifier={metadata['CFBundleIdentifier']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
