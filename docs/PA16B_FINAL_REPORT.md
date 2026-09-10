# PA.16B final report

Date: 2026-09-10  
Reference viewport: 430 × 932 portrait  
Starting revision: `a38938957a2f210dafe0d353d12e89a907c4e61e`  
Scope: final visual pass and Alpha RC1 preparation; no M4 systems

## Recommendation

**RC FIXES REQUIRED — physical iPhone acceptance is the remaining gate.**

No automated release-blocking defect is known. The repository is ready for the
first Alpha RC1 device session, but it is not ready for M4 and is not physically
accepted until `docs/ALPHA_RC1_DEVICE_TEST.md` is completed with real evidence.

## Final grades

| Family | Before | Final | Evidence |
| --- | --- | --- | --- |
| Themes (55) | D | **B+** | Distinct object silhouettes at 24/32/48/64 px; all catalog IDs reviewed on contact sheets. |
| Technologies (64) | D | **B** | Nine color-coded branch grammars with shared silhouettes and visible progression markers. |
| Game features (31) | D | **B+** | Concrete player-facing objects and experiences, visually distinct from technology branches. |
| Era integration (5) | D | **B** | Props distributed across three room anchors, softly shaded, and occluded under runtime furniture/people. |
| Procedural covers | C | **B** | 100 deterministic before/after samples; genre-aware archetypes, era language, measured title fitting, stable franchise palette/composition. |

The stop condition is met for desktop visual QA: these families are B or better,
and the complete high-frequency fixture contains no obvious C/D art. Asset
production stops here. Physical native-scale judgment remains a human gate.

## Assets changed and retained

Changed: 55 theme SVGs, 64 technology SVGs, 31 feature SVGs, five era overlay
SVGs, and the runtime `GameCoverArt` composition system. The PA.16B tooling now
includes deterministic 100-cover capture/contact sheets and corrected family
contact-sheet labels.

Retained unchanged by design: logo, app icon, splash, five painted office bases
and their painted/atmospheric layers, employee sprites and portraits, the original
and PA.16B genre families, status icons, platforms, awards, empty states,
milestones, established UI icons, simulation, save/load, clock, navigation, and
manager integrations. No M4 or competitor-studio work was introduced.

No Aseprite source was added. Vector props were sufficient for this bounded pass;
Godot has no runtime dependency on editable art-source formats.

## Cover audit

`artifacts/pa16b-covers-before/` and `artifacts/pa16b-covers-after/` each contain
100 deterministic runtime captures, an index, and five labeled contact sheets.
The matrix varies theme, genre, platform, year, title length, roman/numeric sequel
language, and franchise identity.

The before system was readable but repeated one centered-icon card composition.
The final system uses hero-object, character-focus, landscape, symbolic,
action-diagonal, editorial, and poster treatments selected by genre. 1980s through
2020s packaging language changes independently. Long titles fit by measured font
width rather than character count. Franchise covers retain one stable palette and
composition while their motif, title and era treatment evolve.

## Contact sheets and complete fixture

- `artifacts/pa16b-final/`: nine family sheets at target mobile sizes, including dark-ground checks.
- `artifacts/pa16b-final/mobile-scale-screen-montage.png`: the complete fixture reduced to approximately phone presentation scale.
- `artifacts/pa16-visual-validation-current/`: 22 current 430 × 932 application
  captures plus 13 bottom-of-scroll captures for every screen whose primary
  content extends below the fold.

All 22 required screens rendered successfully with the real Godot compatibility
renderer: Main Menu, New Company, five office eras, New Project, Greenlight,
Research, Engine Lab, Hiring, Employee Detail, Game Detail, Franchise, release,
Market, Awards, Statistics, Financial Crisis, Company, and Game Over. Visual review
found no title clipping, broken icon, obvious placeholder, or blocking portrait
layout defect. Device sharpness and safe areas are not inferred from this run.

## Performance impact

The 155 reviewed SVG sources total 85,317 bytes, an increase of 16,221 bytes over
the starting revision. Current imported icon data is approximately 266 KB across
themes, technologies, and features. Covers remain runtime-drawn and reuse cached
manifest textures; no cover atlas or source-resolution raster catalog was added.
`AssetCatalog` still loads on demand, and no complete-catalog preload was added.

The real renderer used OpenGL Compatibility on an NVIDIA GeForce RTX 5070 Ti for
fixture generation. This is desktop evidence only; iPhone memory, draw calls,
screen-loading latency, thermal behavior, battery, and frame pacing remain pending.

## Automated validation

| Check | Result |
| --- | --- |
| Python tooling compilation | PASS |
| Configured main-scene graphical boot | PASS — OpenGL Compatibility, clean exit |
| SVG structural audit | PASS — 155/155, no findings |
| Generator protection | PASS — coverage generator changed 0/155 reviewed assets |
| `AssetValidationTest` | PASS — 1,528 checks |
| Complete root regression | PASS — 72/72 suites, 13,522 checks |
| Connected Phase A | PASS — 56 checks |
| Connected Phase B | PASS — 40 checks |
| Connected Phase C | PASS — 14 checks |
| Connected Phase D | PASS — 68 checks on isolated rerun |
| `BalanceProbe` | PASS — diagnostic only, one check |
| 100-cover before/after fixtures | PASS — 100/100 captured in each set |
| 430 × 932 visual fixture | PASS — 22/22 screens plus 13 bottom-scroll captures |

Phase D's first batch run sampled the real-time clock at exactly 2.0 weeks rather
than greater than 2.0; every other check ran. The isolated rerun passed all 68
checks, so this is recorded as timing flakiness rather than a product regression.
The balance probe's single default career went bankrupt and is diagnostic evidence,
not a tuning basis; no balance formula was changed.

## RC visual regression audit — 2026-09-10

A complete runtime-themed fixture review found and corrected several concrete
phone-scale defects: four project-stage chips and three hiring-skill headings
wrapped mid-word; empty text fields had insufficient placeholder contrast;
release-impact values wrapped vertically at the right edge; culture and franchise
ratings used placeholder-like ASCII marks; undiscovered compatibility displayed
as `???`; and Statistics called the least-profitable positive release a "biggest
flop." All were corrected without changing simulation balance.

The audit also fixed two evidence defects. Embedded fixture screens now receive
the same `VisualTheme` styling as scenes reached through normal navigation, and
captures use the settled Reduced Motion frame instead of sampling a fade. The
fixture accepts a fresh output directory, captures the bottom of every scrollable
screen, and exits unsuccessfully if any PNG cannot be written. The cover fixture
now defaults to `pa16b-covers-current`, protecting historical before/after sets.

Fresh OpenGL Compatibility output completed with zero capture errors: 22 top
screens, 13 bottom-of-scroll views, 100 current covers, and two studio-motion
views. Every primary action was reachable; no unresolved placeholder, broken
icon, mid-word wrapping, footer overlap, or blocking clipping remained in the
reviewed captures.

## Physical-device status and known issues

Physical iPhone testing: **not performed**. Required checks include notch/Dynamic
Island/home indicator, software keyboard, background/lock/termination recovery,
silent switch, haptics, Reduced Motion, larger text, native icon/cover sharpness,
long-session comfort, heat, battery, memory and frame pacing.

Known issues/gates:

- physical device acceptance is open;
- Phase D has one non-reproducing real-time batch timing flake;
- historical artifact CSVs still emit pre-existing duplicate-UID import warnings;
- late-game `studio_building`/`campus` room reuse remains outside this bounded pass;
- no balance change is justified from the single default BalanceProbe outcome.

Do not start M4. Begin the physical test script, enter RC mode on that first run,
and fix only demonstrated defects.
