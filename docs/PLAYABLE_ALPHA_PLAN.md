# Playable Alpha implementation plan

Roadmap only. Nothing in this document has been implemented. It is built from
reading the current repository, not from an older design document, and every
"existing" claim below was verified against actual files before being written
down.

## Target

Bring Indie Empire from its current M3-level simulation to a **Playable
Alpha** comparable to Game Dev Tycoon in accessibility, progression, feedback
and replayability, while keeping the deeper workforce, financial, market and
studio-management simulation that already exists here. A new player should be
able to install the game, create a company in 1985, understand how to make
games without external instructions, research technology, unlock features,
build engines, hire staff, move offices, manage projects and finances, create
franchises, experience successes and failures, progress through multiple
technological eras, save/reload safely, and stay engaged by meaningful
decisions and strong audiovisual feedback.

Explicitly **out of scope** for this plan: M4 competitor simulation,
acquisitions, console manufacturing, global studios, MMOs, or any other
late-milestone system named in the README's M4+ list. If a PA section below
brushes against one of those (poaching, rival studios), it says so and stops.

## Baseline

Run:

```
godot --headless --path . res://scripts/tests/<Suite>.tscn
```

**54 of 54 committed suites pass** (50 `scripts/tests/*.tscn` unit suites +
4 `scripts/tests/acceptance/Phase{A,B,C,D}.tscn` career-phase suites). No
`SCRIPT ERROR` or `ERROR:` lines in any log.

Two things in the working tree are not part of that count and should not be
mistaken for regressions:

- `scripts/tests/StudioWalkingSnapshot.gd`/`.tscn` are **untracked** (`git
  status` shows `??`) — a local, uncommitted screenshot-capture fixture, not
  a `TestCase` suite (it never prints `PASSED`/`FAILED`). It fails under
  `--headless` because Godot's dummy renderer returns a null viewport
  texture (`ERROR: Parameter "t" is null.` at `texture_2d_get`), which is an
  environment limitation of headless screenshotting, not a code fault. It is
  not part of the 54.
- The working tree also carries **uncommitted edits** to
  `scripts/ui/OfficeFloorView.gd`, `scripts/ui/OfficeLayout.gd` and
  `scripts/tests/OfficeFloorTest.gd` (a foreground-occlusion fix for the
  office-floor renderer, plus a `route_is_walkable` guard and two new
  assertions) that this plan did not make and does not touch. `git diff`
  shows the change; it is out of scope here and left as-is. `OfficeFloorTest`
  still passes with it applied (234 checks in the baseline run above).

## Architecture already in place — reuse, do not duplicate

The README's architecture section is accurate and current; read it before
touching anything. The load-bearing rules that constrain every PA section
below:

- **Managers** (`autoload/`, has state) vs. **simulators**
  (`scripts/simulation/`, pure static maths, no state, calls no manager). New
  systems follow this split.
- **`World.gd`** is the only subscriber to `TimeManager.week_advanced`; new
  weekly behaviour is added to its ordered list, not hung off a second timer.
- **`EventBus.gd`** (57 signals today) is the only channel from simulation to
  UI. New cross-system facts are new signals here, not direct screen calls.
- **Data-driven content** lives in `data/*.json` and is read through
  `DataManager`. `autoload/EngineManager.gd`'s `FEATURES` constant is the one
  significant exception — engine-tech data is hardcoded in GDScript instead
  of JSON, unlike its sibling `data/game_features.json`. PA.2 below proposes
  fixing that inconsistency rather than building around it.
- **Saves** are versioned (`SaveManager.SAVE_VERSION := 19`,
  `MIN_SUPPORTED_VERSION := 5`) with numbered migration branches
  (`if int(data.get("version", 0)) < 15: ...`). Every PA section that adds a
  `GameState` field needs a version bump and a migration branch in this same
  style — never a silent schema change.
- **Balance is measured, not argued.** `scripts/tests/balance/BalanceProbe.gd`
  plays a scripted manager career and dumps CSVs; `scripts/tests/balance/
  analyse.py` aggregates them. `docs/QUALITY_ANCHOR_2026-09-08.md`,
  `docs/BONUS_STACKING_2026-09-08.md`, `docs/LATE_GAME_ECONOMY_2026-09-08.md`
  and `docs/MEDIOCRE_GAMES_2026-09-08.md` are the record of that discipline
  in practice. Any PA section that changes cost, sales, morale or event
  frequency must be re-measured this way (PA.15) before being called done.
- **Custom canvas drawing**, not a UI plugin, is the established way to
  render anything bespoke: `scripts/ui/StudioRoomRenderer.gd` and
  `scripts/ui/OfficeFloorView.gd` both draw directly via `_draw()`. PA.12's
  charts should follow this precedent rather than pulling in a charting
  library (there is no charting library on the project's dependency
  allowlist, and Godot ships none).
- **Regression tests** are `extends TestCase` scenes with `section()` /
  `check_*()` calls (see `scripts/tests/TestCase.gd`), one `.tscn` per
  `.gd`, discovered by filename. New suites follow this pattern exactly so
  they run the same way as the other 54.

## Status at a glance

| # | Section | Status | Relative complexity |
|---|---|---|---|
| PA.1 | Game Creation & Project Decisions | **Implemented** (2026-09-08; pricing/marketing still out) | Low |
| PA.2 | Research & Technology | **Partial** (works, not data-driven) | Low–Medium |
| PA.3 | Game Features | **Implemented** (2026-09-08) | Complete |
| PA.4 | Engine Progression | **Partial** | Medium |
| PA.5 | Content Expansion | **Partial** (breadth uneven) | Low–Medium (content authoring, not engineering) |
| PA.6 | Onboarding & Progressive Disclosure | **Missing** | Medium–High |
| PA.7 | Release/Review Presentation | **Partial** | Low–Medium |
| PA.8 | Audio & Feedback | **Mostly missing** | Medium (asset-bound) |
| PA.9 | Studio Visual Feedback | **Substantially complete** | Low–Medium (polish only) |
| PA.10 | Sequels & Franchises | **Missing** | Medium–High |
| PA.11 | Awards | **Missing** (one placeholder field) | Medium |
| PA.12 | Statistics & Graphs | **Missing UI, data exists** | Medium |
| PA.13 | Financial Crisis/Recovery | **Partial** (cliff exists, no guided recovery) | Medium |
| PA.14 | Difficulty & Accessibility | **Partial** (difficulty done, accessibility not) | Medium (breadth, not depth) |
| PA.15 | Human Playtest & Balance | **Process exists, needs a human gate + updated probe** | Low–Medium |

---

## PA.1 — Game Creation & Project Decisions

**Status: implemented, 2026-09-08.** 54 pre-existing suites plus three new
ones (`ProjectPriorityTest`, `ProjectEstimateTest`, `GreenlightScreenTest`)
all pass — 57 committed suites total. See "Implementation notes" below for
what shipped, what was deliberately left out, and why.

### Implementation notes (as built)

Everything in the section below this note describes the *plan* as written
before implementation and is left unedited as the historical record. What
actually shipped:

- **New pure simulators**, following the project's manager/simulator split:
  `scripts/simulation/ProjectPrioritySimulator.gd` (the point-budget
  tradeoff — five categories, three levels each, `BUDGET := 5`, so an
  all-Normal selection is always free and raising one category to High can
  only be paid for by dropping another to Low) and
  `scripts/simulation/ProjectEstimateSimulator.gd` (schedule/cost — moved
  out of `NewGameScreen._estimate_schedule` verbatim so the setup screen and
  the new confirmation screen can never quietly show different numbers for
  the same choices — plus the new market fit, team experience and risk
  assessment). `BottleneckSimulator.find()` was refactored (not duplicated)
  to share its worst-role search with a new `preview()` entry point that
  works from a raw `assignments`/`effects` pair, for the risk check to use
  before a real `GameProject` exists.
- **A new confirmation screen**, `scenes/development/GreenlightScreen.gd/
  .tscn`, matches the brief's mock-up section for section (NEW PROJECT /
  title / Genre / Theme / Platform / Scope / Engine / FEATURES / TEAM /
  PROJECT PRIORITIES / ESTIMATE / GREENLIGHT PROJECT), reached from
  `NewGameScreen`'s renamed REVIEW PROJECT button. `DevelopmentSimulator.
  start_project()` is now called from exactly one place: pressing GREENLIGHT
  PROJECT. `ScreenRouter.draft_project` (a new field, following the same
  "navigation state, not GameState" convention as `selected_game_id` etc.)
  carries the setup screen's choices across the scene change; it is
  deliberately not part of saves, the same way the rest of `ScreenRouter`
  isn't.
- **Priorities reach production quality** through the existing
  `_add_focused_quality()` choke point `DevelopmentSimulator` already used
  for `DevelopmentFocusSimulator` — the two tradeoff layers compose there
  (phase focus × whole-project priority) rather than either replacing the
  other. `GameProject.priority_choices` follows `focus_choices`'s exact
  serialization and old-save migration pattern (missing choices default to
  Normal).
- **Target audience was deliberately not built.** The brief said "if
  supported by current architecture," and it is not: there is no
  demographic/audience-segment model anywhere in the simulation distinct
  from a platform's own per-genre `audience` affinity, which the KNOWLEDGE
  panel and the new Market Fit line already surface. Inventing a parallel
  audience-segment system was out of scope for assembling existing systems
  into a creation flow, and risked exactly the kind of unrelated new
  mechanic the task asked not to start.
- **Pricing and marketing spend were not built** (retail_price stays
  size-derived, as it was) — flagged in the plan below as a real PA.1 gap,
  but a second new economic lever alongside priorities was more than this
  pass should measure at once. Left for a follow-up, sequenced after
  priorities have been played and measured for a while.
- **Mobile progressive disclosure**: a new `UiBuilder.collapsible_section()`
  helper (tap-to-expand header, body hidden until opened) was added and used
  for the new PROJECT PRIORITIES card on `NewGameScreen`. The pre-existing
  FEATURES and PROJECT ROLES sections were deliberately left as their
  existing always-visible `VBoxContainer`s rather than retrofitted into
  collapsible cards — the plan below had already flagged that reparenting
  well-tested existing sections was a real risk versus the value of one
  more example of the pattern, and the new Priorities card plus the whole
  Greenlight screen already demonstrate it.
- **Risk explainability** reuses real thresholds and existing systems
  end-to-end, never a bare label: understaffed scope and a specific
  under-covered role (via `BottleneckSimulator.preview`), low genre
  experience (`ExperienceManager.genre_level`), an outdated or unselected
  custom engine (a new, presentation-only age heuristic —
  `ENGINE_OUTDATED_YEARS := 6` — that changes nothing about how an engine
  actually performs), overstaffing, and an ambitious feature load
  (`FeatureSimulator.effort_bonus` against the size's own required effort).
  Each reason is a real, named sentence, matching the brief's own worked
  example almost verbatim (`BottleneckSimulator`'s existing `workload_name`
  field for the "Art team is understaffed" role naming was already exactly
  the wording the mock-up used).

### Current repository state
`scenes/development/NewGameScreen.gd` (475 lines) is a fully wired project-
creation screen: title, genre, theme, platform, project size, feature
picklist (gated by `FeatureSimulator.missing_tech` against
`GameState.researched_engine_features`), team/role assignment with a live
workload preview, an optional custom engine choice, an optional budget
target, and a real schedule/cost estimate built from the exact staff and
roles chosen (`_estimate_schedule`, mirroring
`DevelopmentSimulator.estimate_remaining`). `DevelopmentFocusSimulator` adds
per-phase focus decisions (prototyping/world-building/scope in planning;
systems/technology/presentation/narrative in production; stability/
optimization/tuning/audiovisual in polish), changeable while a phase is
active. A project can be given an optional target release date
(`DeadlineSimulator`), and mid-project a feature can be cut for a schedule
win. `EventBus.project_abandoned` exists, so cancellation is already a real
signal, though no screen currently surfaces the action.

### Existing systems that can be reused
`DevelopmentSimulator`, `FeatureSimulator`, `DevelopmentFocusSimulator`,
`DeadlineSimulator`, `KnowledgeSimulator` (theme/genre compatibility
preview), `ScopeSimulator`, `TeamManager`.

### Missing functionality
- **Pricing is not a player decision.** `retail_price` is set once from
  `game_sizes.json` in `SalesManager.gd:28` and never exposed. GDT-style
  play expects a price slider with a visible demand tradeoff.
- **No marketing spend.** There is no `Ledger.Kind.MARKETING` and no lever
  that trades cash for reach/awareness pre-launch.
- **No visible cancel/abandon action.** The signal exists; no button calls
  it.
- **No project renaming after start**, and no working-title vs. box-title
  distinction (not necessarily needed — flagging as a design question, not
  a gap to definitely fill).

### Required data/model changes
Add `marketing_spend: int` to `GameProject` if marketing is built (see
`STRING_FIELDS`/numeric field lists at `GameProject.gd:142` for the save
serialization pattern to extend). A player-set `retail_price` would move
from a size-derived constant to a project field with a min/max clamp per
size (`game_sizes.json` already carries `retail_price` as the *default*, so
add `price_min_multiplier`/`price_max_multiplier` there rather than
inventing new absolute bounds).

### Required simulation changes
If pricing becomes a decision: `SalesSimulator.base_demand`/`units_for_week`
need a price-elasticity term (a new pure function, e.g.
`price_multiplier(retail_price, size_default_price)`), measured with
BalanceProbe before landing, exactly like `QUALITY_EXPONENT`. If marketing
is built: a pure `awareness_multiplier(spend, size)` in `SalesSimulator`.

### Required UI
Price slider and (if built) marketing spend field on `NewGameScreen`;
"Abandon Project" control on `DevelopmentScreen` with a confirmation (this
is a destructive, hard-to-reverse action for the player's money and time —
confirm before submitting `project_abandoned`).

### Save migration requirements
New `GameProject` fields need default values so old saves deserialize
cleanly (existing pattern: fields not present in an old save load to their
`var` default already, per `GameProject.gd`'s field-list-driven
(de)serialization — confirm the exact mechanism before adding fields, since
it's list-driven rather than reflection-based).

### Tests required
Extend `EstimateScheduleTest` and add a `PricingTest` (or fold into
`SaturationTest`/`AaaProjectTest`) pinning the price-elasticity shape the
same way `QualityAnchorTest` pins the review-elasticity shape. An
`AbandonProjectTest` covering refund/no-refund of sunk cost, team release
back to unassigned, and save/reload after abandonment.

### Acceptance criteria
A player can set a price other than the default and see it change forecast
revenue before committing; abandoning a project through the UI frees the
team and is reflected in the books; both survive save/reload.

### Dependencies on other sections
PA.12 (a price-vs-demand chart makes the tradeoff legible); PA.15 (both
levers need BalanceProbe re-measurement once built, since they touch
`SalesSimulator`).

---

## PA.2 — Research & Technology

### Current repository state
`autoload/EngineManager.gd` defines a **hardcoded** `const FEATURES` array
(8 entries, `2d_renderer` through `optimization`, 1985–1996), each with a
`year`, `cost`, and one or more numeric effect multipliers
(`graphics`/`sound`/`bugs`/`progress`/`technology`/`performance`).
`can_research`/`research` gate on year-availability, not-already-researched,
and affordability; researching is instant once affordable (no time cost,
no staff assignment). `EngineLabScreen.gd` (121 lines) presents this list
and lets the player spend cash to unlock each one.

### Existing systems that can be reused
`FinanceManager.spend`/`can_afford` for cost gating; `TimeManager.
current_year` for era gating; the exact `DataManager`-driven JSON pattern
already used for `data/game_features.json`, `data/training.json`, etc.

### Missing functionality
- **Not data-driven.** Every other content catalog in the game
  (`game_features.json`, `training.json`, `contracts.json`, ...) lives in
  `data/`; engine features are the one exception, hardcoded in
  `EngineManager.gd`. This is the single clearest architectural
  inconsistency in the repository and should be fixed before more engine
  content is authored on top of it.
- **No prerequisite chain among engine features themselves** (only
  `game_features.json` references engine-tech ids via `requires_tech`;
  engine features don't reference each other, so there's no "3D Graphics
  requires 2D Graphics" style tree).
- **No time cost.** Research is bought instantly; nothing simulates a
  research effort/duration the way project development has one.

### Required data/model changes
Move `EngineManager.FEATURES` to `data/engine_features.json` verbatim (same
fields, `requires: []` array added for prerequisites), read through
`DataManager` the same way `data/game_features.json` already is. This is a
pure refactor with no behavior change and should ship with its own
before/after test run rather than bundled into a feature commit.

### Required simulation changes
None required for the data move itself. If a prerequisite chain is added,
`EngineManager.can_research` gains a check against `requires` the same
shape as `FeatureSimulator.missing_tech` already does for game features —
reuse that function's structure rather than writing a second one.

### Required UI
None for the data move (screen reads through the same manager API).
Prerequisite display on `EngineLabScreen` if that's added (locked/greyed
entries with a "requires X" label, following the existing feature-picker
pattern in `NewGameScreen._feature_row`).

### Save migration requirements
None for the data move — `GameState.researched_engine_features` stores ids,
which are unchanged.

### Tests required
`EngineTest.gd` is currently 38 lines against a system with real
year-gating, cost-gating and multiplicative effect composition
(`effects_for`) — thin for what it covers. Extend it to assert every
feature in the new JSON round-trips through `DataManager`, and pin
`effects_for` composing correctly for a multi-feature engine (guards
against a future data typo silently changing a multiplier).

### Acceptance criteria
`EngineManager.FEATURES` no longer exists as a GDScript constant;
`data/engine_features.json` is the single source of truth; every existing
`EngineTest`/`AaaProjectTest`/acceptance-phase check involving engines still
passes unmodified.

### Dependencies on other sections
PA.4 (engine progression is built on this catalog); PA.5 (new technology
entries are the natural way to expand content here).

---

## PA.3 — Game Features

**Status: implemented, 2026-09-08.** The existing partial feature path was
extended rather than replaced. `data/game_features.json` now authors 19
features in seven categories, including every feature named in the PA.3 brief.
Every definition carries display/category copy, compound unlock requirements,
research and selected-engine requirements, compatible eras, development
effort, six discipline demands, bug risk, complexity, quality and innovation
potential, soft genre relevance and player-facing known benefits.

`FeatureSimulator.gd` is the single rules surface for loading validation,
availability, engine capability checks, effort, complexity, discipline demand,
bug risk, genre relevance and realised potential. A feature's upside is no
longer automatic: it is earned with production progress and scaled by how well
the assigned team's programming/design/art/writing/audio/QA capacity matches
the feature. Feature-heavy projects therefore take longer and cost more through
the existing weekly development economy; over-scoped projects add further bug
risk and widen their schedule forecast. Genre relationships remain soft — they
can improve effectiveness but never make an unusual feature choice invalid.

`game_sizes.json` now provides an authored recommended complexity range for
every scope. Project creation and greenlight show `current / recommended`, an
explicit `OVER-SCOPED` state and its consequences while still allowing the
player to proceed. The selector is grouped from authored categories and shows
effort, complexity, discipline demand, known benefits, technology requirements
and human-readable lock reasons; simulation multipliers remain hidden.

`GameProject.feature_ids` and the new per-feature `feature_outcomes` both
serialize. Save version 19 also persists `GameState.feature_knowledge`, awarded
only when a postmortem is completed. Postmortems name strong feature/genre
interactions, identify features that exceeded the team's discipline capacity,
and explain when the overall feature set exceeded production capacity. Active
development and released-game detail screens use the catalog's display names.

`FeatureTest` is now deterministic and covers 87 checks: catalog/schema loading,
compound unlock requirements, selected-engine requirements, complexity,
development effort, discipline demand/execution, bug generation, soft genre
interaction, over-scoping, full save/load of selections and outcomes, and
postmortem knowledge. The full 53 regression suites plus all four connected
acceptance phases pass after integration.

No PA.3 functionality remains. Feature icons and post-launch DLC/patches remain
optional future presentation/content work, not part of the Playable Alpha gate.

---

## PA.4 — Engine Progression

### Current repository state
`EngineLabScreen.gd` + `EngineManager.gd` let a studio research individual
features, then combine researched features into a named, immutable,
reusable custom engine (`build`/`build_cost` = `BASE_BUILD_COST +
COST_PER_FEATURE * feature_count`). `NewGameScreen` lets any project pick
any built engine. `effects_for` composes an engine's features into a single
multiplier dictionary consumed by development.

### Existing systems that can be reused
Everything under PA.2; `GameState.custom_engines`/`next_engine_number`
already persist multiple named engines per studio.

### Missing functionality
- **No obsolescence pressure.** Nothing in `data/platforms.json` ever
  requires a specific engine feature (there is no `required_tech` field on
  platforms), so an engine built in 1986 remains exactly as viable in 2020
  as a freshly built one except for the flat effect multipliers. A studio
  is never pushed to keep researching.
- **No engine identity beyond a name.** No generation/version label, no
  visual badge, no "built for" genre affinity.
- Engine selection is a bare dropdown in `NewGameScreen`; no comparison
  view of what an engine's composed effects actually are before picking it
  (the player has to go back to the Engine Lab to check).

### Required data/model changes
If platform gating is added: `required_tech: []` on platform entries in
`data/platforms.json`, read the same way `game_features.json.requires_tech`
already is.

### Required simulation changes
`PlatformManager.available_platforms` (or wherever platform eligibility is
decided today — confirm exact call site before implementing) would need a
tech check mirroring `FeatureSimulator.missing_tech`. This changes which
platforms a studio can develop for, which is a real balance change and
needs BalanceProbe re-measurement (PA.15) — it changes early-game platform
choice pacing.

### Required UI
An engine-effects preview (reuse `EngineManager.effects_for`, already
exists) surfaced directly in the engine dropdown row on `NewGameScreen`
rather than requiring a screen switch.

### Save migration requirements
None unless platform gating is added, and even then none — gating is
computed at read time from existing `researched_engine_features`, not
stored.

### Tests required
An `EngineProgressionTest` (or extension of `EngineTest`) asserting: an
engine's composed effects match the product of its features' individual
effects (regression-proofs `effects_for`); if platform gating ships, a test
that an ungated platform remains available on a fresh save (protects new
players from an accidental total-lockout bug).

### Acceptance criteria
The player can see an engine's effects without leaving the project-setup
screen. If platform gating ships: a studio with zero engine tech can still
start on at least one platform (no fresh-save deadlock), and BalanceProbe
shows no meaningful shift in 1996 median cash versus the PA.15 baseline in
`docs/MEDIOCRE_GAMES_2026-09-08.md`.

### Dependencies on other sections
PA.2 (data move should land first — building progression pressure on top of
a hardcoded catalog just means redoing it); PA.15 (re-measurement).

---

## PA.5 — Content Expansion

### Current repository state (volume by file)

| File | Entries |
|---|---:|
| `data/genres.json` | 15 |
| `data/themes.json` | 25 |
| `data/platforms.json` | 17 (1980 → 2047, fictional eras through VR and beyond) |
| `data/game_sizes.json` | 4 |
| `data/game_features.json` | 12 |
| `data/training.json` | 41 |
| `data/employee_traits.json` | 9 |
| `data/specializations.json` | 32 |
| `data/contracts.json` | 9 |
| `data/publishers.json` | 5 |
| `data/office_customizations.json` | 5 |
| `data/offices.json` | 7 |
| `data/candidate_rarities.json` | 4 |
| `data/studio_events.json` | **3** |

### Existing systems that can be reused
Every catalog above is already data-driven and read through `DataManager`;
adding entries is authoring work, not engineering work, for all of them
except engine features (PA.2).

### Missing functionality
- **`data/studio_events.json` has only 3 entries** despite a complete,
  general-purpose grammar behind it (`StudioEventSimulator`,
  `StudioEventManager`, `StudioEventScreen`, a documented three-token
  condition grammar, weights, cooldowns, typed choice effects — see the
  README's Studio Events paragraph). This is the single largest
  content-to-infrastructure gap in the repository: the system that most
  directly buys "replayability and meaningful decisions" is nearly unused.
  Recommend this be the first PA.5 deliverable — it's pure content
  authoring against an already-built, already-tested system.
- **Project-size naming is internally inconsistent** and worth fixing
  alongside any size-tier work: the *id* `"small"` displays as **"Tiny"**,
  `"medium"` displays as **"Small"**, `"large"` displays as **"Medium"**,
  and `"aaa"` displays as **"Large"** (`data/game_sizes.json`). This is a
  pre-existing landmine for anyone adding a size tier without reading the
  `name` field, not a bug to fix under this plan — flagging it so PA.5
  content work doesn't propagate the confusion into new ids.
- No size tier above `aaa`/"Large" (unlocked 2006) — by the fictional 2047
  platform era, project scope has nowhere further to grow. Whether that's
  wanted depends on whether the Alpha's endgame is meant to feel
  open-ended; noting it as a design question, not asserting it's missing.

### Required data/model changes
None — this section is almost entirely `data/*.json` additions against
existing schemas.

### Required simulation changes
None for studio events specifically (the simulator already generalizes
over whatever's authored). A new size tier, if added, needs
`MarketManager.unlocked_sizes`-style gating (confirm exact call site) and a
`reputation_weight`/`sales_multiplier` calibrated the way
`docs/MEDIOCRE_GAMES_2026-09-08.md` calibrated `QUALITY_EXPONENT` — by
measurement.

### Required UI
None — existing screens already render whatever's in these JSON files.

### Save migration requirements
None — new data entries referenced by id are additive; old saves that never
saw a new id simply never trigger it.

### Tests required
A `StudioEventContentTest` (or extend `StudioEventTest`) that validates
every entry in `data/studio_events.json` parses its condition grammar
correctly and every choice's effects are well-typed — a content-lint test,
not a balance test, so bad authoring fails fast instead of surfacing as a
runtime parse error mid-playthrough.

### Acceptance criteria
`data/studio_events.json` has enough entries (recommend ≥15 as a first
milestone, matching the variety already present in `employee_traits.json`/
`training.json`-scale catalogs) that a multi-year BalanceProbe run shows
event variety, not the same 3 repeating. Re-measure event-driven morale/
culture/cash impact with BalanceProbe after the expansion (PA.15).

### Dependencies on other sections
PA.15 (any content addition that touches cost, morale or cash needs
re-measurement); PA.11 (awards content can follow the same JSON-authoring
pattern once that system exists).

---

## PA.6 — Onboarding & Progressive Disclosure

### Current repository state
**Nothing exists.** `docs/ASSET_UI_PLAN.md` Batch 4 lists "First-run
onboarding and contextual explanations" as unchecked, and no code
implements any part of it: no tutorial flag in `GameState`, no first-run
detection, no contextual tooltip system, no guided first-project flow.

This is also, concretely, the missing piece of the still-open **M3
acceptance gate**: `docs/M3_ACCEPTANCE.md` states the player "must be able
to explain the consequences from information available on screen" and that
this has not yet been demonstrated. Onboarding work here directly serves
that unmet M3 requirement as well as the Playable Alpha goal — it is not
duplicate scope.

### Existing systems that can be reused
`Notifications.gd`'s toast system (`notification_requested` signal,
`_build` toast construction) is a working, tested pattern for surfacing
short contextual messages without a new UI primitive. `StudioEventScreen`'s
modal-decision pattern (pause the clock, present a focused choice, resume)
is the right template for a guided first-project walkthrough rather than
inventing a second modal system. `EventBus` already has the granular
signals (`game_started`, `employee_hired`, `office_moved`,
`game_released`, ...) that a contextual-tips system would key off of — no
new signals should be needed for the triggers themselves.

### Missing functionality
Everything: first-run detection, a tutorial/tip state machine, contextual
tooltips, a guided first-project flow, and — per
`docs/ASSET_UI_PLAN.md`'s Batch 4 accessibility items filed in the same
batch — screen-reader names and non-colour status cues (also covered under
PA.14; the two should be designed together since they touch the same
screens).

### Required data/model changes
`GameState` needs persistent onboarding progress (e.g.
`completed_tutorial_steps: Array[String]` or a simpler
`onboarding_dismissed: bool`) so a returning player on a loaded save isn't
re-shown the first-run flow. Content itself (tip text, trigger conditions)
should be data-driven from the start, in a new `data/onboarding_tips.json`
following the `studio_events.json` condition-grammar precedent, rather than
hardcoded strings scattered through screen scripts.

### Required simulation changes
None — this is UI/state, not simulation. A thin `OnboardingManager`
autoload (state only, so it belongs under `autoload/` by the project's own
manager/simulator split) watching `EventBus` signals and GameState flags to
decide what to show next.

### Required UI
A tooltip/callout primitive usable from any screen; a first-run flow over
the new-company screen; contextual one-shot tips triggered off the
`EventBus` signals named above (first hire, first office move, first
release, first bankruptcy warning, etc.).

### Save migration requirements
New `GameState` field(s) for onboarding progress — version bump + migration
branch defaulting existing saves to "already onboarded" (an existing save
implies the player has already learned the basics; don't re-trigger the
first-run flow for them).

### Tests required
A new `OnboardingTest` asserting: a fresh company shows the first-run flow;
a loaded pre-existing save does not; each contextual tip fires exactly once
per studio. This is exactly the kind of assertion `TestCase`'s `check_*`
family already supports without new test infrastructure.

### Acceptance criteria
A player with zero prior instruction can complete the connected career
demonstration in `docs/M3_ACCEPTANCE.md` (start alone, earn an office, hire,
train, promote, grow to two teams) using only in-game guidance — this is
the same bar M3 already set and never cleared, so PA.6's acceptance
criterion *is* clearing it.

### Dependencies on other sections
PA.14 (accessibility labeling overlaps almost every screen this section
touches — sequence them together, not separately); indirectly touches every
other PA section, since onboarding has to explain whatever they add.

---

## PA.7 — Release/Review Presentation

### Current repository state
More built than the checklist in `docs/ASSET_UI_PLAN.md` suggests at a
glance. `ReviewSimulator.critic_scores` generates four fictional-outlet
numeric scores (`Pixel Monthly`, `GameWorld`, `Joystick Weekly`, `Computer
Player`) scattered around the true review score. `ReleaseResultsScreen.gd`
(264 lines) already staggers a reveal animation per critic
(`_advance_reveal`, `FIRST_REVIEW_DELAY`), color-codes each score
(`score_color`), and assigns a short verdict word per score band
(`verdict_for`: `MUST PLAY` / `EXCELLENT` / `RECOMMENDED` / `PROMISING` /
`MIXED` / `NOT RECOMMENDED`). A dedicated `ReviewRevealTest` exists.

### Existing systems that can be reused
`ReviewSimulator.critic_scores`, the entire reveal/verdict/color
infrastructure in `ReleaseResultsScreen`, `PublishingScreen`,
`PostmortemScreen`.

### Missing functionality
Per `docs/ASSET_UI_PLAN.md` Batch 3 (still unchecked): "Animated critic
cards, release banner and celebration effects." Concretely: no written
pull-quotes or per-outlet personality/flavor text (only a numeric score +
generic verdict word), no confetti/particle celebration on a strong
release, no shareable release-day summary. Also unchecked in the same
batch: "Publisher marks, contract-client badges and engine-feature icons"
(icon assets, not logic).

### Required data/model changes
If written quotes are added: a small `data/review_quotes.json` keyed by
verdict band (a handful of quote templates per band, e.g. 4–6 phrasings for
`EXCELLENT`), picked pseudo-randomly per outlet per release — avoids
hardcoding prose in GDScript and keeps the door open for later localization
(README already flags name-pool data-driving as prep for "a different
locale later" — same rationale applies here).

### Required simulation changes
None — quote selection is presentation, not simulation; it can be a pure
function in `ReviewSimulator` or a UI-layer helper, whichever keeps
simulation free of display strings (lean toward UI-layer, since quote text
is not something any other system needs to read back).

### Required UI
Pull-quote rendering on the existing critic cards; a celebration effect
(particles or a simple animated banner) gated on `verdict_for` returning
`EXCELLENT`/`MUST PLAY`; the icon assets from Batch 2/3.

### Save migration requirements
None — quotes are generated at display time, not persisted (persisting
which quote was shown isn't necessary unless the Records screen is meant to
recall it verbatim later; if so, add a field to `GameProject.critic_reviews`
entries and migrate).

### Tests required
Extend `ReviewRevealTest` to assert a quote is always non-empty and
band-appropriate; no new suite needed.

### Acceptance criteria
A release above `EXCELLENT` visibly celebrates; every critic card carries
readable flavor text, not just a number.

### Dependencies on other sections
PA.8 (a celebration moment wants a sound sting); PA.9 (the studio floor
already reacts to releases via `_celebrate`/`_on_game_released` in
`OfficeFloorView.gd` — keep the two celebration moments in sync rather than
building this one independently).

---

## PA.8 — Audio & Feedback

### Current repository state
`autoload/AudioManager.gd` (71 lines) crossfades a single music loop
(`assets/audio/music/studio_day_loop.wav`) and a single ambience loop
(`assets/audio/ambience/office_room_loop.wav`) based on which scene is
active (`scene_uses_ambience`). `Settings.gd` has `music_volume` and
`ambience_volume` sliders, persisted. **`assets/audio/` contains exactly
these two files** — there is no UI SFX of any kind (no click, hire,
release, sale-milestone, level-up, bankruptcy-warning, or error sound).

### Existing systems that can be reused
`AudioManager`'s player-pooling and fade infrastructure
(`_looping_player`, `FADE_PER_SECOND`) already solves looping/crossfading;
one-shot SFX is a smaller, additive problem (a pooled `AudioStreamPlayer`
for fire-and-forget clips) that should live in the same manager rather than
a new one. `EventBus`'s existing signal set (`employee_hired`,
`game_released`, `game_hit_sales_milestone`, `company_bankruptcy_warning`,
`employee_skill_level_up`, `experience_level_up`, ...) is already exactly
the trigger list a one-shot-SFX layer would subscribe to — no new signals
needed to wire this up, only new listeners.

### Missing functionality
Everything except the two loops: one-shot SFX for UI interaction and
milestone events, a `sfx_volume` setting, and (per
`docs/ASSET_UI_PLAN.md` Batch 4) "original music" beyond the single loop —
whether that means more tracks or dynamic layering by era/mood is a scope
decision to make explicitly before sourcing/producing audio.

### Required data/model changes
`Settings.gd` gains `sfx_volume: float` alongside the existing two volume
fields, persisted the same way (`save_settings`/`load_settings` already
round-trip a small dictionary — extend it, no new mechanism).

### Required simulation changes
None.

### Required UI
A volume slider for SFX in `SettingsScreen` next to the existing two.

### Save migration requirements
None — `Settings` persists to its own file outside the versioned save
system (confirm this before assuming no migration is needed — if it turns
out `Settings` shares the save-version path, treat it identically to a
`GameState` field).

### Tests required
`AudioTest.gd` already exists (check its current scope before extending);
add coverage that a one-shot SFX request doesn't disrupt the looping
music/ambience players (the two systems must coexist, not fight over the
same player).

### Acceptance criteria
Every major milestone event (hire, release, sale milestone, level-up,
bankruptcy warning) has an audible cue; SFX volume is independently
adjustable and persists across sessions.

### Dependencies on other sections
PA.7 (celebration sting), PA.9 (office floor already has visual reactions —
SFX should accompany them), PA.13 (a distinct crisis/warning cue).

This section is **asset-bound**: the engineering (a one-shot SFX pool +
settings slider + EventBus listeners) is small; sourcing or producing
enough distinct, era-appropriate, licensable sound assets is the actual
cost driver and should be scoped/budgeted separately from the code work.

---

## PA.9 — Studio Visual Feedback

### Current repository state
This is the most mature system on the list, and it was under active,
tested development in this repository's immediate git history (see the
"Baseline" section above regarding uncommitted work-in-progress on
`OfficeFloorView.gd`/`OfficeLayout.gd` right now). `scripts/ui/
OfficeFloorView.gd` (880+ lines) simulates a real physical office: employees
walk from a desk anchor through an open-floor hub on an A*-routed path
(`OfficeLayout.route`, `AStarGrid2D`), take breaks, collaborate at a
coworker's desk when sharing a project, emit role-colored "work bubbles"
(`_spawn_work_bubble`, `output_kind` mapping role→code/design/art/story/
audio/qa/plan/polish), and show condition reactions (happy/stress/worry)
read straight off morale/stress. `StudioRoomRenderer.gd` draws the room
itself (floor, walls, depth-sorted furniture/actor compositing).
`OfficeLayout.gd` generates a capacity-scaled grid layout per office tier
with desks, social spots, props and a normalized entrance/hub for every
office in `data/offices.json`.

### Existing systems that can be reused
All of the above — this section is about extending an already-rich system,
not building one.

### Missing functionality
Two specific unchecked items from `docs/ASSET_UI_PLAN.md` Batch 3:
- **"Floating discipline and bug feedback in the physical office."**
  Partially covered already — work bubbles already show discipline-colored
  output (code/art/design/etc.) per `WORK_OUTPUT_COLORS`. What's actually
  missing is *bug* feedback specifically: nothing visualizes QA finding or
  fixing bugs in the room the way ordinary work output is visualized.
- **"Phase-specific pre-production, production and polish treatment."**
  The room currently looks the same regardless of whether a team is in
  pre-production, production or polish — no visual distinction between
  phases (e.g., whiteboards/sketches during pre-production vs. debugging
  poses during polish).

### Required data/model changes
None — phase and bug-fix events are already readable off `GameProject`
(`current_phase()`, `bugs`/`known_bugs`) and `QASimulator` already tracks
bug discovery/fixing; this is a rendering-layer addition, not a new data
model.

### Required simulation changes
None — `OfficeFloorView` already listens to enough `EventBus` signals
(`preproduction_completed`, etc.) and reads project state directly; a
"qa" work-bubble variant for bug-fix events and a phase check in the
room-drawing code are additive to existing code paths, not new systems.

### Required UI
A bug-fix-specific work-bubble variant (reuse `_spawn_work_bparticle`-style
existing bubble infrastructure with a new `kind`); phase-conditional prop/
pose selection in `StudioRoomRenderer`/`OfficeFloorView`'s draw pass.

### Save migration requirements
None.

### Tests required
Extend `OfficeFloorTest.gd` (already the largest suite at 234 checks in the
baseline run) with assertions for the new bubble kind and phase-conditional
rendering, following its existing pattern exactly (see its
`_work_output_matches_the_phase_and_role` section for the precedent to
extend).

### Acceptance criteria
A QA bug-fix week is visually distinguishable from an ordinary work week in
the room; a pre-production week looks different from a polish week without
reading any text.

### Dependencies on other sections
PA.8 (visual reactions currently have no matching sound); the uncommitted
in-flight change noted in Baseline should land (or be reverted) before this
section's work begins, to avoid working on top of an unreviewed diff.

---

## PA.10 — Sequels & Franchises

### Current repository state
**Does not exist beyond intent.** `GameProject.gd`'s class doc says a game
is "identified by a stable id, never by title, so sequels and remasters can
reference each other later" — but no field actually links one `GameProject`
to another; there is no `series_id`/`parent_game_id`, no "make a sequel"
action anywhere in the UI, and no franchise-level fan tracking (fans are a
single company-wide `GameState.fans` counter, not per-series).

### Existing systems that can be reused
This should **not** be a parallel system. Reuse:
- `ExperienceManager`'s `genre_experience`/`theme_experience`/
  `combo_knowledge`/`platform_genre_knowledge` as the *familiarity* signal a
  sequel draws on — a studio that's shipped three games in the same
  theme/genre combo already has a measurable, tested advantage mechanism
  (`KnowledgeSimulator.true_compatibility`). A sequel bonus should be
  expressed through this existing channel (e.g., a same-series shipment
  counts extra toward `combo_knowledge`) rather than a new franchise-XP
  system duplicating it.
- `CompanyStats`/`GameDetailScreen` for the "make a sequel" entry point —
  the natural place is a button on a shipped game's own detail page, not a
  new top-level screen.
- `GameState.fans` for franchise pull, at least initially — a genuinely
  separate per-series fan pool is a larger design decision (does a
  franchise's fans carry over if the studio never ships that series again?)
  that should be made explicitly, not defaulted into by accident.

### Missing functionality
Everything: series identity, a sequel-creation flow, and whatever
mechanical benefit a sequel carries (reduced effort from reused assets/
engine, a quality or word-of-mouth bonus from established fans, or both).

### Required data/model changes
`GameProject.series_id: String` (empty = standalone) and
`GameProject.sequel_number: int` (1 = original). Follow the existing
numeric/string field-list pattern at `GameProject.gd:142-150` exactly so
save serialization picks the new fields up without a separate code path.
`GameState` needs no new top-level field if series membership is derived by
scanning `released_games` for matching `series_id` at read time (prefer
this — avoids a second source of truth to keep in sync).

### Required simulation changes
A pure function (new, in `SalesSimulator` or a small new
`FranchiseSimulator` if the logic grows past what belongs in
`SalesSimulator`) computing a sequel's starting demand/quality bonus from
prior same-series performance — measured with BalanceProbe before landing,
same discipline as every other multiplier in `SalesSimulator`. This is a
genuine new economic lever and needs the same "measured, not argued"
treatment `QUALITY_EXPONENT` got.

### Required UI
"Make a Sequel" action on `GameDetailScreen` for a released game,
pre-filling genre/theme/platform on `NewGameScreen` and passing
`series_id` through; a franchise indicator (numbering, a small series badge)
on `GamesScreen` list entries belonging to the same series.

### Save migration requirements
Version bump; new `GameProject` fields default to empty/1 for existing
saves (no existing game is retroactively part of a series — this is
correct and requires no backfill logic, unlike the employee career-history
backfill the README describes for an earlier field).

### Tests required
A `SequelTest`: starting a sequel from a shipped game correctly pre-fills
and links `series_id`; the sequel's demand/quality bonus applies and is
measurable; a save/reload round-trips series membership; an
`EconomyPlateauTest`-style check that franchise bonuses don't compound
without bound across a long series (this is exactly the kind of runaway
`docs/LATE_GAME_ECONOMY_2026-09-08.md` already had to guard against once,
for a different mechanic — same failure mode to watch for here).

### Acceptance criteria
A player can start a sequel from a shipped game's detail page; the sequel
visibly benefits from the original's success; BalanceProbe shows the bonus
does not produce runaway compounding across a long-running series (measure
a scripted 5-game series the way `EconomyPlateauTest` measures the whole
career).

### Dependencies on other sections
PA.15 (mandatory re-measurement — this is the single highest-leverage new
economic lever on this entire list, higher than PA.1's pricing question,
because it compounds release-over-release rather than acting once per
game); PA.12 (a franchise view naturally wants its own chart/breakdown).

---

## PA.11 — Awards

### Current repository state
`Employee.gd:120-124` carries an `awards: Array` field
(`{award_id, name, project_id, year}`) with an explicit comment: **"Nothing
awards these yet."** No `data/awards.json`, no ceremony trigger, no
`GameState`-level company awards list, no UI. `PostmortemSimulator.
_award_and_describe` and `ExperienceManager.award()` both use "award" to
mean *grant XP*, an unrelated meaning — name whatever new system is built
here carefully (e.g. `AwardsManager`/`AwardsSimulator`) to avoid reading as
the same concept in code review or in-repo search.

### Existing systems that can be reused
`Employee.awards` (the field already exists — populate it, don't
duplicate it); `NewsManager` for ceremony announcements (the README already
lists "breakout hits" and "commercial failures" as existing news
categories — an award win is the same shape of story); `World.gd`'s ordered
weekly-tick list as the place a yearly/periodic ceremony check belongs, the
same way `PlatformManager`/`UnlockManager` already hook it there rather
than a separate timer.

### Missing functionality
Everything: award categories/data, eligibility and selection logic, a
trigger cadence, a company-level award history (`GameState` has nowhere to
put "this studio has won N awards" today), and any UI.

### Required data/model changes
`data/awards.json`: category id, display name, cadence (e.g. annual),
eligibility rule (by size/genre/review-threshold — follow the same
plain-token condition grammar `studio_events.json` already established
rather than inventing a second one). `GameState.company_awards: Array` for
the studio-level record (mirrors `Employee.awards` shape); populate
`Employee.awards` for the credited employees on a winning project
(`GameProject.credited_employee_ids` already exists and is exactly the
list to award).

### Required simulation changes
A new `AwardsSimulator` (pure) selecting winners from eligible releases in
a period, called from a new `AwardsManager` (state: which awards have been
given) hooked into `World.gd`'s tick list at the appropriate cadence.
Needs its own balance pass if eligibility considers review score
thresholds — should not accidentally become a second economic lever (an
award granting a cash prize or sales bump would need the same measurement
discipline as everything else; a purely cosmetic/reputation award needs
less).

### Required UI
An award announcement (reuse `NewsManager`/`Notifications`), an awards
history view (could live on `RecordsScreen` alongside existing
`CompanyStats.records()`, or its own tab — `RecordsScreen` is currently
only 25 lines, so extending it is cheaper than a new screen), and an
awards section on the employee profile screen reading `Employee.awards`
(README already promises this: "Awards have a place in the record too,
ready for a later ceremony").

### Save migration requirements
Version bump; `GameState.company_awards` defaults to empty for existing
saves; `Employee.awards` already defaults to empty (the field exists,
unpopulated, in every current save — no migration needed for that part).

### Tests required
An `AwardsTest`: eligible releases are correctly identified; a winner is
selected deterministically given a fixed seed (avoid the RNG-flake pattern
already present in `FeatureTest` — seed the test's RNG explicitly, see
PA.15); `Employee.awards` and `GameState.company_awards` both update on a
win; save/reload round-trips awards history.

### Acceptance criteria
At least one award category triggers and is visible (news story + employee
record + a place to browse history) within a measured career length used
elsewhere in this repo's balance docs (to 1996, matching
`docs/MEDIOCRE_GAMES_2026-09-08.md`'s measurement window).

### Dependencies on other sections
PA.5 (awards content authoring follows the same JSON-grammar pattern as
studio events — sequence after that pattern is proven out); PA.12
(an awards history view is a natural statistics-screen tenant).

---

## PA.12 — Statistics & Graphs

### Current repository state
The underlying time-series data mostly already exists, unrendered:
`FinanceManager.annual_history()` returns permanent per-year income/expense/
net records; `GameProject.weekly_sales` (confirm exact field name in
`GameProject.gd` before implementing — README describes "its full sales
curve" as already tracked) holds a release's week-by-week sales; `GameState.
genre_trends`/`genre_saturation` track market movement; `ExperienceManager`
tracks per-genre/theme XP over the studio's life. `CompanyStats.gd` (143
lines) already aggregates lifetime totals and a "records" leaderboard
(best-selling, highest-rated, biggest flop, most profitable, fastest-
selling, longest-selling, largest fan gain — `RecordsScreen.gd` renders
this as text). **None of this is charted** — every existing presentation is
a number or a list, never a line/bar over time.

### Existing systems that can be reused
All of the data sources above — this section is purely "add
visualization," not "add data collection." `StudioRoomRenderer.gd`/
`OfficeFloorView.gd`'s `_draw()`-based custom canvas rendering is the
established precedent for building a chart `Control` from raw draw calls
rather than a plugin — no charting library exists in the project or on its
CDN/dependency allowlist, and none should be added for this.

### Missing functionality
Everything visual: a reusable line-chart control (cash over time, sales
curve per release), a bar-chart control (genre/platform performance
comparison), and a screen (or `FinancialsScreen` extension —
`FinancialsScreen.gd` is 97 lines today, room to grow) presenting them.

### Required data/model changes
None — this section reads existing state. If per-week granularity is
wanted for the cash chart specifically (annual_history is yearly; a
smoother curve wants weekly), that's a new lightweight rolling buffer in
`FinanceManager` (bounded size, like `ledger`'s "rolling recent detail"
already is — don't keep unbounded weekly history for a decades-long
career).

### Required simulation changes
None — charts are pure presentation over existing simulated state.

### Required UI
A `LineChart` and `BarChart` reusable `Control` (custom `_draw()`,
following the `StudioRoomRenderer` precedent), each with **a readable
textual equivalent** — `docs/ASSET_UI_PLAN.md`'s own acceptance rule
already mandates this ("Every data visualization retains a readable
textual equivalent"), which also directly serves PA.14 accessibility, so
build the text fallback as a first-class output of the chart control, not
an afterthought. Extend `FinancialsScreen` with a cash-over-time chart;
extend `GameDetailScreen` with a per-release sales curve; extend
`CompanyStats`/`RecordsScreen` or a new "Statistics" tab with genre/
platform bar comparisons.

### Save migration requirements
None, unless the weekly cash buffer above is added, in which case it's a
new bounded `GameState` array with an empty default for old saves.

### Tests required
A `ChartTest` (or fold into existing `FinancialsScreen`/`GameDetailScreen`
coverage if any exists) asserting the chart control correctly maps a known
data series to drawable points (pure-function correctness, not pixel
comparison — check the underlying point-mapping function, not rendered
output, matching how `OfficeLayout.project`/`unproject` are tested today by
value rather than by screenshot) and that the textual fallback is always
present and non-empty.

### Acceptance criteria
Cash-over-time and per-release sales curves are visible as charts, each
with a textual equivalent a screen reader could announce.

### Dependencies on other sections
PA.1 (a price-vs-demand chart, if built); PA.10 (franchise performance
view); PA.14 (the textual-equivalent requirement is shared infrastructure).

---

## PA.13 — Financial Crisis/Recovery

### Current repository state
The crisis *cliff* is built and tested: `FinanceManager.check_solvency`
tracks `GameState.overdrawn_weeks` against a difficulty-dependent
`GameState.grace_weeks()`, emits `company_bankruptcy_warning(weeks_left)`
each week the studio is overdrawn but not yet out of grace, emits
`company_recovered()` if cash returns positive within the grace window,
and `declare_bankruptcy()` (clearing active projects, ending all sales,
emitting `company_bankrupt`) if grace runs out. `GameOverScreen.gd` handles
the terminal state. `CashRunwayTest` covers this.

### Existing systems that can be reused
The **exact pattern already used for schedule crises** is the right
template here, not a new one: `DeadlineSimulator` names the real cause of a
schedule slip and offers "four real levers" (cut a feature, hire, crunch,
push the target) the moment a forecast would miss its deadline — see the
README's DEADLINE section. A financial-crisis screen should do the same
thing for cash: name the actual drag (payroll vs. rent vs. a specific
overrunning project) and offer concrete levers, rather than only showing a
countdown. `RetentionManager`/`MoraleManager` already have the layoff and
cost-reduction primitives this would call into — reuse them, don't
duplicate a "let someone go" flow that already exists on the Staff screen.

### Missing functionality
Everything past the warning itself: no guided "what to cut" screen during
`is_in_trouble()`, no emergency financing option (a loan, or an advance
against a project not yet shipped), no automatic surfacing of the specific
cost driver (today the warning is only "N weeks left," not "payroll is
$X, rent is $Y, here's what selling covers").

### Required data/model changes
If a loan is added: a new `Ledger.Kind.LOAN` (extend the existing enum,
`Ledger.gd:7-25`) and `GameState` fields for outstanding principal/interest
— this is a real, ongoing financial obligation and must be visible in
`FinancialsScreen`/the books, not a one-time cash injection (a raw cash
grant would contradict the "no cash grants" discipline already established
in `docs/M3_ACCEPTANCE.md`'s acceptance demonstration requirements).

### Required simulation changes
A pure `CrisisSimulator` (or a `FinanceManager` extension, if it stays
small) identifying the largest cost driver from current payroll/rent/
project-burn — structurally the same kind of "diagnose, then name the
single worst factor" function `BottleneckSimulator` already is for
development. If a loan is added, its interest/repayment schedule is a new,
real economic mechanic and needs BalanceProbe measurement (does an
available loan meaningfully change the bankruptcy rate measured in
`docs/MEDIOCRE_GAMES_2026-09-08.md`? that document's 25%→31% bankruptcy
figures are the baseline to compare against).

### Required UI
A crisis panel/screen surfaced the moment `FinanceManager.is_in_trouble()`
is true (mirroring how a schedule slip already pauses the clock and names
a cause), listing the actual cost breakdown and the available levers
(layoff via existing `RetentionManager`/Staff-screen flow, abandon a
project via PA.1's abandon action, downgrade office if that's ever
possible — confirm whether office downgrade exists before assuming it as a
lever, and if not, note it as a further gap rather than inventing it here).

### Save migration requirements
Version bump only if a loan mechanic is added (new `GameState` fields);
none for the diagnostic/UI-only portion.

### Tests required
Extend `CashRunwayTest` with the new diagnostic function's correctness
(largest driver correctly identified across a few synthetic cost mixes);
if a loan ships, a `CrisisLoanTest` covering origination, repayment
deduction from weekly settlement, and interaction with bankruptcy
(does taking a loan reset `overdrawn_weeks`? must be an explicit, tested
decision, not an accidental side effect).

### Acceptance criteria
The moment a studio is overdrawn, the player sees *why* (biggest cost
driver named) and *what they can do about it* (concrete, clickable levers)
without leaving the crisis panel; recovering within the grace period is
still possible through ordinary play, unaided by any cash grant.

### Dependencies on other sections
PA.1 (abandon-project lever); PA.6 (a first-time crisis is exactly the
moment onboarding should say something, not leave the player guessing);
PA.15 (any new lever, especially a loan, needs measurement).

---

## PA.14 — Difficulty & Accessibility

### Current repository state
**Difficulty is done.** `data/difficulties.json` (3 tiers: Relaxed/Normal/
Hard) drives starting cash, sales, expenses and grace-period length
(`GameState.grace_weeks()`), chosen at studio creation
(`NewCompanyScreen.gd`) and threaded through `FinanceManager`,
`SalesManager` and others already. This part needs no new work under this
plan.

**Accessibility is not started.** `Settings.gd` currently has
`compact_numbers`, `notifications_enabled`, `music_volume`,
`ambience_volume` — no colorblind-safe mode, no text scale, no reduced-
motion toggle, no screen-reader labeling. `docs/ASSET_UI_PLAN.md` Batch 4
explicitly lists "Screen-reader names and non-colour status cues" as
unchecked, and its own acceptance rules already commit to "Icons remain
legible at 18–24 px and never replace essential labels alone" and "Every
data visualization retains a readable textual equivalent" — i.e., the
design intent is documented; the implementation across screens is not.

### Existing systems that can be reused
`Settings.gd`'s existing persisted-preference pattern (add fields, extend
`save_settings`/`load_settings`, no new mechanism); `VisualTheme.gd` as the
right place for a colorblind-safe palette variant, since it's already the
single place studio/screen chrome coloring is centralized (confirm this
before assuming — check whether individual screens hardcode colors outside
`VisualTheme` before scoping the work, since that changes whether this is a
one-file change or a many-file audit).

### Missing functionality
Colorblind-safe palette option; adjustable text scale; reduced-motion
toggle (relevant specifically to PA.9's office animations and PA.7's
celebration effects, once built); screen-reader-friendia control names
across the ~30 screens under `scenes/`; non-color status cues everywhere a
status is currently color-only (e.g., `score_color` in
`ReleaseResultsScreen` conveys review quality by hue alone today — pair it
with the existing `verdict_for` text, which already exists and already
solves this for that one screen; audit for other color-only signals
elsewhere, e.g. morale/stress bars, workload bands).

### Required data/model changes
`Settings` gains `colorblind_mode: bool` (or a palette id if more than one
variant is offered), `text_scale: float`, `reduced_motion: bool` — same
persistence pattern as the four existing fields.

### Required simulation changes
None — entirely presentation.

### Required UI
New controls in `SettingsScreen`; a systematic accessibility pass across
existing screens (this is breadth, not depth — the right way to scope it
is a per-screen checklist against `docs/ASSET_UI_PLAN.md`'s own acceptance
rules, applied incrementally as other PA sections touch each screen,
rather than one giant sweep that blocks everything else).

### Save migration requirements
`Settings` persistence — confirm whether it shares `SaveManager`'s
versioned path or its own file (see PA.8's identical open question) before
deciding whether a version bump applies here too.

### Tests required
A `SettingsTest` (if none exists — confirm) covering persistence of the
new fields; no simulation test needed since nothing here touches
simulation.

### Acceptance criteria
Every screen conveys status through text or shape as well as color; text
scale and reduced-motion are respected where implemented; the settings
persist across sessions.

### Dependencies on other sections
PA.6 (design together — overlapping screen surface); PA.12 (textual chart
equivalents are an accessibility deliverable as much as a statistics one).

---

## PA.15 — Human Playtest & Balance

### Current repository state
The *automated* half of this is genuinely mature and was used twice in
this repository's immediate history: `scripts/tests/balance/BalanceProbe.gd`
plays a full scripted manager career (hiring, project selection, office
moves, retention decisions) and dumps per-release and per-year CSVs;
`scripts/tests/balance/analyse.py` aggregates multi-seed runs into review
distribution, profitability-by-review-band, market saturation and cash-
curve reports. `docs/BALANCE_PASS_2026-09-07.md`,
`docs/QUALITY_ANCHOR_2026-09-08.md`, `docs/BONUS_STACKING_2026-09-08.md`,
`docs/LATE_GAME_ECONOMY_2026-09-08.md` and
`docs/MEDIOCRE_GAMES_2026-09-08.md` are a real, working record of this
discipline in practice, including retunes measured, verified against the
regression test that would fail without them, and documented with the
actual before/after numbers.

### Existing systems that can be reused
All of the above, directly, for every PA section that touches cost, sales,
morale, culture, or event frequency (PA.1 pricing/marketing, PA.5 event
expansion, PA.10 franchise bonus, PA.13 loan mechanics).

### Missing functionality
- **No human playtest process.** `BalanceProbe` is a scripted AI manager —
  it measures whether numbers are internally consistent, not whether a real
  new player finds the game legible or fun.
  `docs/M3_ACCEPTANCE.md` already draws exactly this distinction in its
  own words: *"the existence of a manager, formula, screen or passing
  isolated test is supporting evidence, not milestone acceptance."* That
  document's structure — required player outcomes table, a connected
  demonstration script, a "fail this gate if" section — is the right
  template for a **Playable Alpha acceptance gate** document, and should
  be built the same way once enough of PA.1–PA.14 has landed to attempt a
  full connected playthrough.
- **`BalanceProbe`'s scripted manager will not exercise new PA systems** as
  they land — it won't create sequels, won't proactively research beyond
  what's cheap, won't respond to a crisis panel, won't engage with awards.
  Each PA section that adds a real decision needs a matching update to the
  probe's manager logic (`_grow`, `_work_team`, `_start_project` etc. in
  `BalanceProbe.gd`) or its measurements will silently stop covering the
  new content — exactly the trap the existing `QualityAnchorTest`/
  `EconomyPlateauTest` docstrings already warn about for constants that
  drift unnoticed.

### Required data/model changes
None.

### Required simulation changes
None directly — but every PA section above that flagged "needs
BalanceProbe re-measurement" should not be considered complete until this
section's process has actually run against it.

### Required UI
None.

### Save migration requirements
None.

### Tests required
None new — this section's job is *running* the existing tests and probe
against every other section's output, and adding probe-manager coverage
for new decisions (`BalanceProbe.gd` edits, not new `TestCase` suites).
One concrete, low-effort item surfaced by this session's own baseline run
that belongs here: **`FeatureTest` and `DevelopmentPhaseTest` are flaky on
unseeded RNG** (confirmed by rerun in this session — `FeatureTest` failed 1
of 4 identical reruns comparing random bug counts over 12 trials;
`DevelopmentPhaseTest`'s check count varies 101–103 run to run). Neither is
a regression, but flaky tests erode trust in the other 53 — seed both
suites' RNG explicitly. This is a pre-existing issue, independent of the
Playable Alpha work, and can be fixed any time before it starts causing
false alarms in CI.

### Acceptance criteria
Every PA section that changes cost/sales/morale ships with a BalanceProbe
before/after table in its own dated doc, following the existing
`docs/*_2026-*.md` naming and structure convention exactly. A
`docs/PLAYABLE_ALPHA_ACCEPTANCE.md` exists, structured like
`docs/M3_ACCEPTANCE.md`, and is signed off only after a recorded human
connected playthrough — not test output alone.

### Dependencies on other sections
All of them. This section is the closing gate on the whole plan, not a
parallel work item.

---

## Recommended implementation order

Sequenced by dependency, not by section number. Rationale after each step.
**PA.1 landed first**, ahead of this original ordering — it was the section
the brief actually asked for, and turned out to be a self-contained enough
slice (new files plus two small, well-tested existing files touched) that it
did not need to wait on PA.2's engine-data move. That move is still worth
doing before PA.4/PA.5 add more engine-adjacent content on top of the
hardcoded catalog.

1. **PA.2 data move** (engine features → JSON). Small, mechanical, and
   removes the one architectural inconsistency that later PA.4/PA.5 content
   work would otherwise have to route around or replicate.
2. **PA.5: studio-events content authoring.** Highest replayability return
   for the lowest engineering risk — the infrastructure is already built,
   tested, and idle. Also the cheapest way to start exercising the
   BalanceProbe-driven measurement loop (PA.15) on new content before
   bigger systems land.
3. **PA.9 polish** (bug-fix bubbles, phase-conditional room treatment).
   Low-risk extension of an already-mature, already-tested system; land it
   promptly so it doesn't keep sitting on top of the currently-uncommitted
   WIP diff noted in Baseline.
4. **PA.7 presentation** (quotes, celebration). Independent, low-risk,
   high visible payoff; a natural pairing with PA.9's celebration hook and
   a first target for PA.8's SFX once that exists.
5. **PA.13 crisis diagnosis (no loan yet).** Reuses `DeadlineSimulator`'s
   proven pattern; the diagnostic half carries no new economic risk, so it
   can ship before the loan mechanic is designed.
6. **PA.1: abandon-project action.** Small, and PA.13's crisis panel wants
   it as a lever immediately.
7. **PA.6 onboarding**, once there's enough surface (PA.5's events, PA.13's
   crisis panel, PA.9's polish) to actually explain. Sequenced with PA.14's
   accessibility labeling, since both sweep the same screens.
8. **PA.12 charts.** Build the reusable chart control once, then let PA.1
   (pricing), PA.10 (franchise) and PA.11 (awards) each get a view for
   free as they land.
9. **PA.11 awards.** Reuses PA.5's condition-grammar precedent directly;
   sequence after PA.5 so the pattern is already proven.
10. **PA.1: pricing/marketing decisions.** A real new economic lever —
    hold until the measurement discipline (PA.15) is warmed back up on
    smaller changes first.
11. **PA.4: engine obsolescence pressure** (platform tech-gating). Same
    reasoning — a real balance change, sequence after lower-risk levers.
12. **PA.8: SFX pass.** Mostly asset-bound; can run in parallel with
    almost anything above once the one-shot-SFX plumbing exists, but is
    listed late because it depends on which events (crisis, awards,
    celebration) are worth cueing.
13. **PA.10: sequels/franchises.** The single highest-leverage new economic
    lever on this list (compounds release over release). Deliberately
    last among the systems work — land it once PA.15's measurement
    discipline has been exercised repeatedly on smaller changes, and once
    PA.12's charting exists to make its effect visible to the player.
14. **PA.15: the acceptance gate.** Write
    `docs/PLAYABLE_ALPHA_ACCEPTANCE.md` and run the connected human
    playthrough once the above is substantially in place — this is the
    finish line, not a step to interleave earlier.

## Highest-risk architectural changes

1. **PA.10 sequels/franchises** — the only PA item that adds a new
   compounding economic multiplier (a bonus that grows with a metric the
   player directly controls the growth of, release after release). Every
   past instance of this shape in the codebase needed a dedicated
   measurement/guard pass after the fact (`docs/BONUS_STACKING_2026-09-08.md`
   capped multiplicative bonus stacking at +41% after it reached +315%
   uncapped; `docs/LATE_GAME_ECONOMY_2026-09-08.md` had to distinguish real
   runaway from simple inflation). Design the cap or diminishing-return
   curve *before* writing the multiplier, not after measuring a runaway.
2. **PA.13 loan mechanic** (if built) — the only PA item that adds a new,
   ongoing financial obligation type. Interacts directly with the
   bankruptcy cliff (`FinanceManager.declare_bankruptcy`) and must not
   create a way to indefinitely defer insolvency, which would silently
   invalidate every existing bankruptcy-adjacent test and balance
   document.
3. **PA.2's data move** is architecturally the *lowest* risk item on the
   list (pure refactor, no behavior change) but is listed here as a
   sequencing risk: doing it late, after PA.4/PA.5 have already added
   engine-adjacent content on top of the hardcoded constant, means
   redoing that content's plumbing. Do it first.
4. **PA.6/PA.14's cross-cutting screen sweep** — not risky to the
   simulation, but the only PA work that touches nearly every screen in
   `scenes/`. The risk is schedule/coordination (conflicting edits to the
   same screens as other PA sections land), not correctness — sequence it
   deliberately (see order above) rather than letting it happen
   incidentally screen-by-screen.

## What this plan deliberately does not include

Per the task brief: no M4 competitor simulation, acquisitions, console
manufacturing, global studios, or MMOs. Two places above brushed against
M4 territory and were deliberately cut off:
- PA.10's franchise fans were scoped to reuse `GameState.fans`/
  `ExperienceManager`, not a new poaching- or rival-aware system (poaching
  and `employer: competitor` are explicitly M4, per the README's own
  Employees section).
- PA.13's crisis levers stop at a loan against the studio's own future
  earnings — no acquisition offer, buyout, or external investor, all of
  which are M4/M8+ territory per the README.
