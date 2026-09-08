# M3 test report — September 7, 2026

**Result: M3 does not pass the completion gate.** The workforce simulation has
substantial working coverage, but the Studio dashboard hides critical controls,
the career test fails two balance assertions, and the complete earned-growth UI
journey remains unverified.

## Execution

Ran the installed Godot 4.7.2 stable engine, imported the project, launched the
actual desktop game, and played through company creation, development,
self-publication, reviews and sales. Test processes used isolated `APPDATA`
directories under `artifacts/m3-validation-2026-09-07/`; a preliminary engine
probe confirmed that `user://` resolved there. Existing player saves were not
used or overwritten.

Ran 21 existing suites: **19 passed, two failed; 1,092 of 1,096 checks passed.**

| Coverage | Result |
| --- | --- |
| M3EmployeeSmokeTest, ContributionTest, PayrollForecastTest, CashRunwayTest | Pass |
| MoraleTest, BurnoutTest, TrainingTest, RetentionTest | Pass |
| EmployeeHistoryTest, LeadershipTest | Pass |
| ScopeTest, FeatureTest, BottleneckTest, DeadlineTest | Pass |
| EquipmentTest, OfficeFloorTest | Pass |
| Phase B: reload and continuation | 40 checks passed |
| Phase C: bankruptcy | 14 checks passed |
| Phase D: real-time clock and screen instantiation | 66 checks passed |
| Phase A: career simulation | Two failures out of 55 checks |
| DelayTest | Two failures out of 29 checks, reproduced on a second run |

No script/parse errors appeared in these logs. Sandboxed engine runs printed
`Failed to read the root certificate store`; the interactive desktop run did
not. This environment message did not prevent the tests from running.

## Confirmed UI blocker: Studio dashboard overflows

Observed during normal UI play: the Studio dashboard's clock and bottom
navigation are off screen. The development button can be partly visible or
pushed below the window as more content appears. Office screens display their
clock and navigation correctly, so this is not simply the desktop window size.

A supplemental runtime probe measured the ten-person Studio screen at the
configured 430 × 932 viewport:

| Control | Vertical position | Height | Problem |
| --- | ---: | ---: | --- |
| ClockBar | -101.5 | 48 | Entirely above viewport |
| DevelopButton | 913.5 | 62 | Partly below viewport |
| NavBar | 985.5 | 58 | Entirely below viewport |

`scenes/studio/StudioScreen.tscn` puts the dashboard, expanded runway label,
office card and action buttons in one non-scrolling VBox with the clock and
navigation. Its combined content exceeds the available height. Screen
instantiation tests do not detect this; the added bounds probe does.

This prevents reliable access to core management controls and is a milestone
blocker. Put the dashboard content in a scrollable region while keeping the
clock and navigation reachable, then verify both solo and staffed states.

## Career balance: failed assertions, not yet a definitive diagnosis

Phase A played 528 weeks to January 1996 and finished with:

- 12 staff in the largest office;
- $174,650 monthly payroll and $93,691,604 cash;
- 47 released games, none unprofitable;
- average review 9.0787, above the test's 9.0 upper bound;
- 31 granted staff requests, zero departures and zero preventive rest actions.

The failures were the absence of an unprofitable game and the high average
review. This randomized manager-driven run uses forced hiring acceptance and
publisher deals. It demonstrates growth and solvency in that scenario, but does
not establish balanced payroll pressure or an M3-only, two-team growth path.
Do not change economic tuning solely to make one randomized run pass; reproduce
with controlled careers and compare ordinary player decisions first.

## DelayTest: incorrect assumption in the test fixture

The test forces a two-week slip before advancing the world. During that tick,
development improves the completion forecast by a week. At the actual warning
check, only a one-week slip remains, below the two-week threshold.

Instrumented diagnostic:

- Before tick: forecast 95300, baseline 95298.
- After tick: forecast 95299, baseline 95298; no warning, correctly under threshold.
- A separate diagnostic with a larger forced slip emitted the signal, paused
  the clock and passed all 29 checks.

The original suite remains failing. Evidence supports repairing its supposedly
guaranteed-slip setup; it does not support reporting a broken gameplay warning.
Diagnostic copies are saved with the test artifacts; production code and the
original test have not been changed.

## Supplemental ten-person integration probe

A deterministic fixture created ten people including the founder, moved through
all office tiers, equipped Standard workstations, split into two five-person
teams and started two separate projects. It advanced 24 weeks without releases
and saved/reloaded both projects.

All **51 simulation and persistence checks passed**. Six monthly payroll entries
were recorded at $30,200/month; cash fell $241,644 including development and
overhead. Both projects progressed and retained distinct team ownership after
reload. Three additional screen-bounds checks failed as described above.

The fixture supplied $2 million and forced successful offers. It proves that
the systems operate together; it does not prove the player can afford this
studio from normal earnings or that managing it feels sufficiently different.

## Manual play evidence and limits

Created `M3 Playtest` on Normal with founder Alex, Generalist background and
Perfectionist trait. Verified one-person bedroom, $10,000 cash, zero salaries
and $140 monthly overhead. Created `Bedroom Launch`, a Tiny Space/Action game
for MicroStar 64, with the founder assigned programming and design at 95% load.
The setup exposed effort, cost estimates and staffing. Development exposed
individual contribution and an unstaffed-art bottleneck recommending an artist.

Shipped after ten development weeks without polishing: $7,510 development cost,
15 known bugs, a 5.4 review and 50 first-week copies worth $750. Sales subsequently
ended. Letting the idle company continue incurred overhead and eventually raised
a financial-trouble warning and paused the clock. The isolated playtest is left
open in that paused state on the Offices screen.

This run demonstrated a weak first release and financial consequences. It did
not earn the first office, hire through the UI, or complete the junior-to-veteran
and ten-person journeys. Those outcomes remain pending; automated coverage is
not substituted for them.

Logs, diagnostic scenes and isolated saves are in
[`artifacts/m3-validation-2026-09-07/`](../artifacts/m3-validation-2026-09-07/).
No gameplay fixes or balance changes were made during this test pass.
