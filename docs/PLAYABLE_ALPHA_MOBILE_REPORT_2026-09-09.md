# Mobile Playable Alpha report — 2026-09-09

## Recommendation

**PHYSICAL DEVICE ACCEPTANCE REQUIRED**

The repository implementation and automated gate are ready for a device
candidate. A physical iPhone playthrough has not occurred, so Mobile Playable
Alpha is not declared complete.

## Current status

PA.1–PA.13 are implemented with automated evidence. PA.14's settings, text
scaling, Reduced Motion, safe-area helper and lifecycle protection are
implemented; real-device accessibility and keyboard behavior remain pending.
PA.15 is incomplete until the connected first-15-minute, first-hour,
ten-person-studio and long-session device gates are recorded. M4 was not begun.

This pass completed the previously missing PA.12 surface. The old text-only
Records page is now a portrait-first Statistics scrapbook with six overview
cards, best-seller/highest-rated/biggest-loss records, one focused annual chart
at a time, large Revenue/Profit and 1Y/5Y/10Y/ALL controls, readable chart text,
a career timeline, franchise value/health cards, awards history and useful
empty states. The release timeline defaults to the latest 20 games so a long
career does not instantiate hundreds of cards until the player asks.

## Automated test results

- Fresh pre-change baseline: **74/74 suites passed**.
- Statistics focused verification: **14/14 checks passed**.
- Final full regression: **75/75 suites passed** after implementation.
- Content validation: **7,770 checks passed**.
- Mobile layout: **184 checks passed** across base portrait, tall phones,
  larger phones and iPad portrait (plus non-acceptance desktop smoke sizes).
- Connected simulation phases A–D: **56, 40, 14 and 68 checks passed**.
- Full-career 1985–2050 economy plateau: **12 checks passed**.

The first sandboxed attempt could not write `user://` saves/settings. The same
suites passed when Godot used its normal user-data directory; those permission
errors were test-environment restrictions, not game failures.

## Balance probe

The probe now records and exercises project priorities, appropriately scoped
features, research and engine work, and records engine/sequel use, franchises,
awards and loans alongside its existing employee, office, payroll, contract and
difficulty coverage. It deliberately leaves optional features off founder-only
projects, matching onboarding rather than making the automated manager perfect.

A deterministic seed-1 measurement completed the 1985–1995 window solvent with
$1.54M cash, 19 games, 12 staff, a Studio Building, 14 research projects and one
custom engine started, and a 5.79 average review. It selected no sequel in this
seed because its conservative fan-interest/fatigue gate did not trigger. One
seed is diagnostic, not a tuning basis. No economy formula changed in this pass;
existing multi-seed evidence remains the balance baseline, and no retune is
justified from this single strategy run.

## Mobile UI findings

- Shared generated controls are 54 px high and primary actions 64 px.
- Management screens use vertical scrolling, readable portrait measure and
  summary-first cards; no new horizontal table or hover interaction was added.
- `VisualTheme` converts the OS safe area to logical viewport insets.
- Release results already support tap-to-advance, later-view skip and Reduced
  Motion. Statistics uses one chart per section and large period selectors.
- Software keyboard occlusion/dismissal cannot be accepted headlessly and is a
  required physical check for company, founder, game and engine names.

## Performance and memory findings

Static inspection found per-frame work only in the real-time clock and bounded
presentation systems: audio fading, release animation, office character
animation, portrait/preview animation and tutorial focus. Simulation remains on
the weekly world tick. The new Statistics chart has no `_process()` loop and
redraws only when configured or resized by Godot.

News is bounded to 250 items and ledger detail to 600 entries. Annual finance,
released games, franchises, awards and employee histories are intentional
career records; their real save-size cost in a decades-long physical session is
not measured here. Office visuals and audio assets require device memory/thermal
profiling before acceptance.

## Save and lifecycle findings

`AppLifecycle` pauses and safety-saves on background, focus loss/lock,
low-memory warning and close request, even when routine autosave is disabled.
Resume does not silently restart time. Automated coverage round-trips an active
project and a just-released game and prevents duplicate tight-loop saves.
Actual iOS suspend/termination timing remains a physical gate.

## Accessibility findings

Text scaling, Reduced Motion, independent volumes, optional haptics and
non-audio textual outcomes are implemented. Statistics charts expose both a
concise visible description and an expandable year-by-year equivalent. Warning
surfaces use text/icons in addition to color. VoiceOver behavior, maximum text
size clipping, contrast under device display settings and one-handed reach need
human validation.

## Known issues and remaining gaps

- No physical iPhone acceptance evidence exists yet.
- The M3 connected ten-person UI journey remains unrecorded even though its
  automated workforce and career phases pass.
- Keyboard avoidance is not proven on a real software keyboard.
- Long-session heat, battery, frame pacing, thumb fatigue, audio fatigue and
  haptic intensity are unknown.
- BalanceProbe now understands current systems but still models one conservative
  manager strategy; growth and risky strategy cohorts remain desirable before
  broad economy retuning.
- Historical import emits UID-duplicate warnings from archived CSV artifacts;
  they do not produce script errors but should be cleaned separately if those
  artifacts remain inside `res://`.

## Physical-device work required

Run and record the checklist in `docs/PLAYABLE_ALPHA_ACCEPTANCE.md` on a modern
iPhone. Treat every confusion point as a UX defect, then repeat the affected
portion after fixes. Only that evidence can change the recommendation to PASS.
