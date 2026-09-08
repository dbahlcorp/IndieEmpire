# Bounded bonus stacking — September 8, 2026

The studio has a lot of independent positive systems. Each was small and
reasonable on its own. They all multiplied into the same number, and a product
of small reasonable things is not a small reasonable thing.

Measured by `artifacts/bonus-stack-2026-09-08/StackProbe.gd`:

    founder, bedroom, no XP, no engine     x0.93    (-7.5%)
    mid-career studio                      x2.07   (+107%)
    maxed studio, every system at once     x4.15   (+315%)

That is on top of headcount, which separately multiplies output by up to 5.2x.

## What changed

**`BonusStack` (new).** Bonuses are sorted into five categories, each capped;
the categories add rather than multiply; the sum is capped again.

| Category | Cap | Holds |
|---|---|---|
| `knowledge` | +8% | genre, theme and platform experience |
| `team` | +10% | chemistry, coordination, morale, traits, culture |
| `facilities` | +8% | office comfort, workstations |
| `strategy` | +10% | engine features, the pre-production plan |
| `meta` | +5% | reputation and standing |
| **total** | **+41%** | the sum of the caps, so investing everywhere still pays |

Four things deliberately stay outside it:

- **Capacity.** Team size is how much work a studio can take on, not a bonus on
  top of it. Twelve people should out-produce one by several times.
- **Core competence.** Skill, attributes and accumulated experience are what the
  player invests in most directly; capping those would make senior hires
  pointless.
- **Penalties.** Overload, understaffing, crowding, bad condition, studio
  events. Only the upside is bounded — a studio doing everything wrong should
  feel all of it.
- **Trade-offs.** Compatibility, development focus and crunch give with one hand
  and take with the other, so they are not stacking bonuses.

**Everything bearing on pace resolves through one cap.** The first attempt
capped the team's pace in `ProjectStaffSimulator` and the studio's pace
(culture, engine, plan) in `DevelopmentSimulator`, which just multiplied two
capped stacks together. `staff_effects()` now hands its studio-level parts down
so a single stack resolves them all.

## The coupling this uncovered

Capping the pace bonuses made reviews go **up**, from a mean of 7.29 to 7.61.

Quality accrued per elapsed week while the finish line stayed fixed at 100%
progress. Total quality therefore came out proportional to `work / pace` — so a
*slower* team banked more quality for the same project, the team's own craft
largely cancelled out of the result, and every pace bonus quietly made the game
worse. Slowing development from 6 weeks to 7 raised median medium-project
quality from 171 to 190.

Production quality now accrues **per unit of work completed**, the same rule
`FeatureSimulator.apply_quality_potential()` already used for chosen features;
the core stats simply were not on it. Speed now means throughput — more games
per year — rather than worse games, and a better team makes a better game.

This is the larger of the two changes. It required re-deriving
`expected_quality` for every size, because those bars were authored against the
old model:

| Size | work | was | now |
|---|---|---|---|
| Tiny | 90 | 30 | 28 |
| Small | 540 | 166 | 983 |
| Medium | 3500 | 1300 | 8387 |
| Large | 7000 | 2550 | 17500 |

Measured quality ratios afterwards: 1.05 / 0.98 / 1.04 — a competent team lands
on its size's bar at every size, which is what the bars are for.

## Knock-on retuning

**The review curve is a logistic now, not an exponential.** With craft no longer
cancelling out, a weak team produces a genuinely weak game instead of one
flattered by taking a long time, and the merit spread roughly doubled. The
exponential only bent at the top, so it put 12.3% of releases on the 2.5 floor.
A curve with two shoulders keeps a bad game bad without making it a catastrophe.

**`OVER_DELIVERY_CAP` (new, 1.35).** A veteran studio pointing a full team at a
tiny project clears that project's bar by over 2x — measured p90 for Tiny is
2.30 — and that was a free 9. Credit for over-delivery now saturates.

**`QUALITY_ANCHOR` moved 9.3 → 11.0.** Sales go as the fourth power of it, and
it is the single lever on how rich the economy is. The changes above pushed a
measured career's final cash to $123M; 11.0 brings it back to $57M, against the
$45M the September 7 pass had targeted.

> Re-measured after the Tiny-bar pass that followed this one: $120M at 9.3 and
> $38M at 11.0. The choice was validated in full and the constant pinned by a
> regression test — see `docs/QUALITY_ANCHOR_2026-09-08.md`.

## Result

    before  mean 7.84  median 8.00  stdev 1.37   9+: 24.3%   6.9% on the ceiling
    mid     mean 7.29  median 7.40  stdev 0.96   9+:  2.7%   0.0% on the ceiling
    after   mean 7.13  median 7.30  stdev 1.16   9+:  3.0%   0.0% on the ceiling

| Score | Meaning | Wanted | After |
|-------|---------|--------|-------|
| 3–4.9 | Disaster | Rare | 6.2% |
| 5–5.9 | Weak | Occasional | 8.2% |
| 6–6.9 | Okay | Common | 22.0% |
| 7–7.9 | Good | Most successful releases | 39.7% |
| 8–8.9 | Excellent | Uncommon | 20.9% |
| 9–9.5 | Exceptional | Rare | 2.7% |
| 9.6+ | Landmark | Extremely rare | 0.3% |

Career average review is flat at about 7.1 from 1988 onward — it no longer
drifts upward as the studio compounds, which was the runaway.

## Known rough edge

Tiny projects still show a quality ratio well above 1.0, because a mature
studio's small projects clear a bar authored for a founder in a bedroom.
`OVER_DELIVERY_CAP` clips the review consequence, so it does not read as a free
9, but the underlying ratio is not meaningful for that size.

**Followed up in `docs/TINY_PROJECT_BAR_2026-09-08.md`.** The cause turned out
to be `team_output` (1.0 for one person, 1.8 for two), not the bar drifting; the
bar is correct at 28 and the early game depends on it.
