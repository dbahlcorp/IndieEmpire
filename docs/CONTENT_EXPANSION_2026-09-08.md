# PA.5 — Content Expansion (2026-09-08)

Data/content pass against schemas that already existed. No new simulation
managers; one new pure simulator (`EmployeeTraitSimulator`) that centralises
trait maths the hand-coded call sites were duplicating, and one new content
lint suite (`ContentValidationTest`).

## Volume before → after

| Catalog | Before | After | Notes |
|---|---:|---:|---|
| `data/genres.json` | 15 | 15 | Left as-is — already inside the 10–15 target and every downstream affinity matrix is keyed to exactly this set. Platformer / Sports read through Action / Simulation and the platform `audience` maps rather than as micro-genres. |
| `data/themes.json` | 25 | 55 | 30 new themes, each with a complete 15-genre `genre_affinity` map. |
| `data/platforms.json` | 17 | 20 | Added `optix_cd` (1992 CD console), `pocket_vue` (2010 handheld), `vessel` (2017 hybrid) to close real gaps. Timeline is now continuous release→peak coverage every year 1985–2026. |
| `data/technologies.json` | 40 | 64 | 24 new nodes across all nine branches, restrained `engine_effects` (0.80–1.20). |
| `data/game_features.json` | 20 | 31 | 11 new features; `engine_requirements` only ever names engine-capable tech. |
| tech + features combined | 60 | 95 | Target was 75+. |
| `data/employee_traits.json` | 9 | 32 | Now data-driven — see below. |
| `data/office_customizations.json` | 5 | 22 | Cosmetic studio styles (tint/accent presets). |
| `data/studio_events.json` | 3 | 112 | The headline gap. Same three-token grammar, same typed effects. The three original events are behaviourally unchanged (`StudioEventTest` still green); the file is pretty-printed so their formatting shifts. |

## Employee traits are now data-driven

Trait effects used to be `if "workhorse" in employee.trait_ids` checks spread
across `EmployeeValueSimulator`, `MoraleSimulator`, `ProjectStaffSimulator`,
`TrainingSimulator`, `TeamManager` and `EmployeeManager`. Each trait now
carries a structured `effects` block and a top-level `market_value`;
`EmployeeTraitSimulator` (pure, static) is the one reader, and the call sites
consult it. The nine original traits were ported number-for-number
(`EmployeeTraitTest` pins every one), so behaviour is unchanged; the 23 new
traits get real mechanical effect through the same path.

Effect keys: `skill_contribution` (`{discipline: mult, "all": mult}`),
`polish_multiplier`, `speed_multiplier`, `innovation_multiplier`,
`overload_work_factor`, `overload_morale_factor`, `xp_multiplier`,
`teamwork_delta`. Multipliers compose, deltas add, missing keys are the
identity. Generated candidates now draw from the whole catalogue
(`"generated": false` opts a trait out; nothing does today).

## Restraint

- Theme `genre_affinity` and platform `audience`: 0.5–1.6, signature fits
  1.05–1.35, poor fits 0.55–0.80. No value exceeds what the existing content
  already used (racing_theme→racing was 1.5).
- Technology `engine_effects`: 0.80–1.20.
- Feature `genre_relevance`: 0.5–1.5, soft — never a hard gate.
- Trait `market_value`: −0.10..0.10, summed then clamped to −0.06..0.16 as before.
- Studio-event effects match the three shipped events: morale ±2..±10,
  skill_xp 30..90, reputation ±0.4..±2.0, culture ±1.5..±4.0, dev_efficiency
  −0.05..−0.10 for 2–4 weeks. Every event has one marked default (the mild /
  free option); ~⅓ of defaults are neutral-to-slightly-positive so a career
  that ignores every event is not quietly taxed. This matters because the
  headless probe auto-resolves every event to its default.

## Validation tooling — `ContentValidationTest`

A content lint suite (not a balance test) over every `data/*.json` catalog:

- duplicate ids, per catalog
- missing display names (resolved, not just present)
- broken prerequisites — technology prereqs, feature tech/feature/engine
  requirements
- invalid references — theme/platform/feature genre keys against the genre
  set; event condition variables, culture ids, skill ids, role ids; feature
  engine requirements must be engine-capable
- impossible unlocks — `unlock_year` ≥ 1985, `unlock_games` ≥ 0; a technology
  never available before a prerequisite; no prerequisite cycles; a feature's
  unlock year inside its compatible era
- platform timelines — announce ≤ release ≤ peak ≤ retire; market curve
  non-empty, gap-free, within [release, retire], peak never below the curve
- affinity ranges — genre_affinity / audience 0.5–1.6, trait market_value
  −0.10..0.10, engine effects 0.80–1.20
- timeline continuity — a platform between release and peak every year 1985–2026

## Balance

`BalanceProbe` re-run against a fresh **baseline on `main` HEAD** (not the
`tiny-bar` report, which predates PA.2/PA.4 and no longer reflects the shipped
economy). Reports in `artifacts/content-expansion-2026-09-08/`.

**To 1996** — PA.5 (16 seeds) vs `main` (8 seeds):

| | main HEAD | PA.5 |
|---|---:|---:|
| review mean / median | 6.59 / 6.80 | 6.70 / 6.80 |
| releases that lost money | 35% | 39% |
| of releases built by paid staff | 8.6% | 14.3% |
| median profit / release | $82k | $85k |
| 1996 median cash | $7.75M | $8.14M |
| 1996 staff | 20 | 20 |

**To 2010** — 6 seeds each:

| | main HEAD | PA.5 |
|---|---:|---:|
| review mean | ~7.2 | 7.20 |
| releases that lost money | 16.5% | 19.6% |
| median profit / release | $1.23M | $1.84M |
| revenue / total-cost | 4.2x | 4.5x |
| 2011 cash (nominal / 1985$) | $244M / $113M | $267M / $123M |
| 2011 real-growth flag | +21.5%/yr "compounding" | +17.8%/yr "compounding" |

Every difference sits inside the seed-to-seed spread (the 6-seed baseline
alone ranged $210M–$288M at 2011). The "still compounding" warning fires for
**both** runs — it is a pre-existing property of `main` that the late-game
sink pass (`docs/LATE_GAME_ECONOMY_2026-09-08.md`) resolves at a ~2019
plateau, well past these cutoffs. PA.5's growth *rate* is slightly lower than
baseline's, not higher.

Two things that could have gone wrong and were caught:

1. First pass set off-signature theme affinities to a "mild" 0.95. The
   economy is sharp enough around the existing content's *average* affinity
   that this ~3% shift collapsed 1996 median cash ~10x in the probe. Fixed by
   solving the off-signature default (0.995) so the 30 new themes' pooled
   affinity distribution matches the existing 25's.
2. The 32-trait pool is marginally more buff-heavy than the old 9. Measured
   effect on the economy is within noise; left as-is.

Acceptance career chain (`PhaseA`→`B`→`C`→`D`) green 3/3 runs.
`ContentValidationTest` 7,639 checks, `EmployeeTraitTest` 100 checks, and the
trait-adjacent regression suites (`M3EmployeeSmokeTest`, `MoraleTest`,
`EmployeeValueTest`, `FounderTraitTest`, `StudioEventTest`, `TrainingTest`,
`ResearchTest`, `FeatureTest`, `EngineProgressionTest`, …) all pass.
