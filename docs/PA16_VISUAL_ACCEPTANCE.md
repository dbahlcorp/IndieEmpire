# PA.16 visual acceptance

Date: 2026-09-09  
Reference viewport: 430 × 932 portrait  
Scope: visual identity and authored asset production; no M4 systems

## Automated and repository checks

| Check | Result | Evidence |
| --- | --- | --- |
| Pre-implementation audit exists | Pass | `docs/PA16_VISUAL_ASSET_AUDIT.md` |
| Visual identity rules documented before production | Pass | `docs/VISUAL_IDENTITY_GUIDE.md` |
| Data IDs have manifest coverage | Pass | `AssetValidationTest` covers 15 genres, 55 themes, 20 platforms, 64 technologies, 31 features and 10 awards |
| Unknown IDs resolve to visible family fallback | Pass | `AssetCatalog.path/texture`, fallback checks |
| Current year selects an era | Pass | boundary checks for 1985/1990/2000/2010/2020 |
| SVG structural audit | Pass | all 271 PA.16 SVGs report no findings via `design-svg/scripts/audit_svg.py` |
| Godot asset contract | Pass | `AssetValidationTest`: 1,528 checks |
| Complete headless regression matrix | Pass | 72 test scenes, 13,521 checks on Godot 4.7.2 stable |
| Graphical screen fixture | Pass | 22/22 PNGs captured at 430 × 932 with no script errors |
| Repository whitespace check | Pass | `git diff --check` |

Godot 4.7.2 stable imported the authored SVGs, completed the full headless test
matrix and rendered the deterministic screen fixture. Save-sensitive tests were
run with isolated `user://` directories so they could not interfere with one
another or with a real player save.

## Visual inspection

Representative vectors were rendered through Inkscape and inspected at 24,
64 and 128 px. The scale sheet and family montage are in:

- `artifacts/pa16-scale-check.png`
- `artifacts/pa16-vector-montage.png`
- `artifacts/pa16-era-milestone-montage.png`

The first review caught duplicate award-category insets. Award motifs were then
made category-specific and re-audited. Final sampled results retain clear
silhouettes, rounded teal outlines and the cream/orange/sky brand hierarchy at
mobile size. Era overlays were reviewed on a neutral room field; the real-screen
fixture then confirmed their in-game composition. The full-resolution screen
pass caught and corrected long-title wrapping on the Greenlight and release
surfaces; the final rerun produced 22/22 images without script errors or
viewport clipping.

## Deterministic screen matrix

`PA16VisualSnapshot.tscn` seeds a company progression from one founder to ten
staff, a long-title franchise game, sales history and an awards ceremony, then
captures 22 actual application scenes. The matrix includes every required
validation target:

1. Main Menu
2. New Company
3. 1985 founder Bedroom
4. 1995 Shared Workspace
5. 2005 five-person Small Office
6. 2015 Professional Studio
7. 2025 ten-person Large Studio
8. New Project
9. Greenlight
10. Research
11. Engine Lab
12. Hiring
13. Employee Detail
14. Game Detail
15. Franchise
16. Release/review reveal
17. Market
18. Awards
19. Statistics
20. Financial Crisis
21. Company
22. Game Over

Run with a graphical Godot renderer:

```text
godot --path . res://scripts/tests/PA16VisualSnapshot.tscn
```

Outputs go to `artifacts/pa16-visual-validation/`. Review the full set at 100%
and at physical phone scale. The fixture uses 430 × 932, the same viewport as
the mobile layout target.

## Reproducible runtime commands

```text
godot --headless --path . res://scripts/tests/AssetValidationTest.tscn
godot --headless --path . res://scripts/tests/OfficeFloorTest.tscn
godot --headless --path . res://scripts/tests/MobileLayoutTest.tscn
godot --headless --path . res://scripts/tests/ReleasePresentationTest.tscn
godot --path . res://scripts/tests/PA16VisualSnapshot.tscn
```

The 2026-09-09 acceptance run also executed every non-snapshot `.tscn` in
`scripts/tests/`: 72 test scenes and 13,521 checks passed.

## Visual acceptance matrix

| Area | Implementation status | Desktop visual | Physical iPhone |
| --- | --- | --- | --- |
| Branding/menu foundation | Existing production-ready art retained | Pass | Pending |
| Five office tiers | Existing production-ready paintings retained | Pass | Pending |
| Year-driven era props | Implemented | Pass: 1985/1995/2005/2015/2025 fixtures | Pending |
| Genre/theme/platform identity | Complete manifest coverage | Pass | Pending |
| Technology/feature identity | Complete manifest coverage | Pass | Pending |
| Covers/franchise continuity | Implemented with era and stable series seed | Pass | Pending |
| Awards/company identity | Implemented and integrated | Pass | Pending |
| Empty states | Implemented through shared builder | Pass | Pending |
| Character expression | Neutral/happy/stressed/worried/tired/excited | Pass: runtime states and representative screen | Pending |
| Long titles | Two-line cover treatment and long-title fixture | Pass after Greenlight/release wrap corrections | Pending |
| Large dynamic type | Existing text-scale system retained | Pass: `MobileLayoutTest` | Pending |

## Physical-device gate

PA.16 cannot honestly be marked physically accepted until an iPhone run checks:

- sharpness at native scale and safe-area composition;
- scrolling and touch targets at large text;
- office overlay alignment in all five tiers and all five eras;
- peak imported texture memory, thermal behavior and battery impact in a
  20-minute Studio session;
- no unreadable cover titles or clipped company/game names;
- reduced-motion behavior for release, award and status feedback.

Record device model, iOS version, build type, peak memory and any screenshot
exceptions below when that run is performed.

| Device | iOS | Build | Peak memory | Result / exceptions |
| --- | --- | --- | ---: | --- |
| Pending | Pending | Pending | Pending | Physical device unavailable in this environment |

## Completed art and remaining needs

Completed in PA.16: full data-catalog icon coverage; five decade overlays;
technology and feature scanning art; genre/theme/platform fallbacks; procedural
company and engine identity; era/franchise-aware covers; category trophies;
nominee/winner/stage components; twelve milestone marks; eleven empty states;
crisis status marks; and tired/excited portrait states. The new presentation is
wired into Studio, New Company, development setup, Greenlight, Research, Engine
Lab, Company, release, Game Detail, Franchise, Awards, Statistics and Game Over.

Deliberately retained, not placeholders: the product logo, splash and app icon;
five painted office rooms and their layer/customization systems; twelve employee
sprite sheets; the modular portrait system; and the existing mobile theme.

Remaining art needs after the reproducible desktop/device review:

- `studio_building` and `campus` still reuse the Large Studio painting and may
  merit dedicated late-game rooms in a future art-only milestone.
- Platform manufacturer marks and full wordmarks remain optional; the complete
  hardware illustration family carries recognition today.
- Era-specific employee clothing is not authored. Characters remain distinctive
  and readable, while decade recognition currently comes from environment,
  hardware and packaging.
- App Store composition remains a product decision. Native-scale sharpness,
  safe-area behavior and physical performance numbers remain pending because no
  iPhone is attached to this environment.
