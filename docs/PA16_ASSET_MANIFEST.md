# PA.16 asset manifest

The runtime source of truth is `data/asset_manifest.json`. `AssetCatalog` loads
that file lazily, caches textures by resource path and resolves an unknown ID to
an explicit family fallback. UI code must request art by family and stable data
ID; it must not add a new hard-coded asset dictionary.

## Coverage

| Family | Mappings | Canonical location | Runtime consumer |
| --- | ---: | --- | --- |
| Genres | 15 | `assets/ui/genres`, `assets/icons/genres` | `IdentityArtwork.genre_texture` |
| Themes/topics | 55 | `assets/icons/themes` | `IdentityArtwork.theme_texture` |
| Platforms | 20 | `assets/ui/platforms`, `assets/platforms/hardware` | `IdentityArtwork.platform_texture` |
| Technologies | 64 | `assets/icons/technologies` | Research, Engine Lab |
| Game features | 31 | `assets/icons/features` | feature/detail surfaces |
| UI concepts | 37 | `assets/icons/ui` | `UiIcons` / `AssetCatalog` |
| Statuses | 12 | `assets/icons/statuses` | semantic and crisis states |
| Awards | 10 | `assets/awards/trophies` | awards ceremony/history |
| Empty states | 11 | `assets/backgrounds/empty_states` | `UiBuilder.empty_state` |
| Office eras | 5 | `assets/offices/era_overlays` | `EraVisuals` / `OfficeFloorView` |
| Milestones | 12 | `assets/icons/milestones` | milestone cards/banners |
| Award presentation | 3 | `assets/awards/badges`, `assets/awards/ceremony` | nominee/winner/stage treatment |

The catalog contains 275 data-to-art mappings. Fourteen strong existing genre
and platform vectors remain canonical; the remaining mappings plus family
fallbacks are lightweight authored SVGs.
Together the 271 PA.16 SVG sources occupy about 123 KiB before Godot import.

## Lookup contract

```gdscript
AssetCatalog.texture("themes", "space")
AssetCatalog.texture("technologies", "ray_tracing")
AssetCatalog.texture("platforms", "unknown_future_platform") # family fallback
```

Higher-level UI should normally use `IdentityArtwork`, which exposes platform,
genre, theme, technology, feature and award helpers. General navigation uses
`UiIcons`. `EraVisuals` is the sole year-to-era resolver.

## Fallback policy

- Every family has a valid fallback path in the manifest.
- Missing keys use that fallback and never return a broken texture rectangle.
- A missing manifest file or malformed JSON reports an error; it does not hide
  the packaging defect.
- `AssetValidationTest` compares the manifest against every relevant data JSON,
  loads every texture, tests fallbacks and pins all five era boundaries.

## Authoring and regeneration

Run `scripts/tools/generate_pa16_visual_assets.py` from the repository root with
Python 3. It reads the canonical data JSON files, preserves the existing
production-ready paths, authors the missing SVG families and rewrites the
manifest deterministically. Review generated diffs and run the SVG audit before
committing. The script is a source tool and is never used at runtime.

## Import rules

- SVGs contain no text, filters, embedded fonts or raster payloads.
- UI assets use small view boxes and share a 4 px rounded stroke grammar.
- Office overlays are transparent 768 × 512 vectors and contain only a compact
  prop cluster so they do not obstruct movement or hit regions.
- Existing painted office PNGs, branding PNGs and employee sheets are retained
  at their current authored sizes; PA.16 adds no 4K or catalog-preloaded raster.
