# Review scale normalisation — September 8, 2026

Reviews were inflated. A competent studio averaged 7.8 and drifted upward over
a career; a quarter of all releases scored 9 or better and 6.9% sat exactly on
the 9.8 ceiling. A 9 is supposed to mean something.

## How this was measured

The same eight-seed `BalanceProbe` career the September 7 pass used, so the
before and after numbers are directly comparable:

    godot --headless --path . res://scripts/tests/balance/BalanceProbe.tscn -- --seed=1
    python scripts/tests/balance/analyse.py "<user-dir>/balance" AFTER

Raw CSV and both reports are under `artifacts/review-scale-2026-09-08/`.

## Target distribution

| Score | Meaning | Wanted | Before | After |
|-------|---------|--------|--------|-------|
| 3–4.9 | Disaster | Rare | 5.4% | 1.8% |
| 5–5.9 | Weak | Occasional | 6.0% | 7.9% |
| 6–6.9 | Okay | Common | 10.5% | 21.9% |
| 7–7.9 | Good | Most successful releases | 27.0% | 44.9% |
| 8–8.9 | Excellent | Uncommon | 26.7% | 20.7% |
| 9–9.5 | Exceptional | Rare | 15.0% | 2.1% |
| 9.6+ | Landmark | Extremely rare | 9.3% | 0.6% |

    before   mean 7.84  median 8.00  stdev 1.37   6.9% pinned at the ceiling
    after    mean 7.29  median 7.40  stdev 0.96   0.0% pinned at the ceiling

## What changed

**`ReviewSimulator` no longer reads quality straight off as a score.** The
scoring components now add up to an open-ended *merit* figure, which
`curve()` converts with diminishing returns:

    score = UNREACHABLE - head * exp(-(merit - COMPETENT_MERIT) * RETURN / head)

A competent studio delivers about 77 merit, which maps to 72 — a 7.2. Around
that bar a point of merit is worth 0.85 of a point of score, so climbing out of
the 5s and 6s still pays properly. Past it the return decays: the first +14
merit over the bar buys about +7 score, the next +14 buys +4, the next only +2.
Reaching 9.6 takes roughly 120 merit — every component at once.

The problem it fixes is that merit clusters. Everything from "solid" to
"landmark" sat between 85 and 125, and the old mapping read that band off
directly as 8.5 to 9.8. Bending the curve spreads it back out.

An exponential rather than a straight knee because the measured merit spread
needs the return to keep falling all the way up: a single knee either flattens
the 8s (too steep) or leaves the 9s free (too shallow).

**Noise moved after the curve.** The ±4 critical-reception roll used to be
added to merit and then flattened along with everything else. Applied to the
score instead, it stays a real ±0.4 review points.

**`SalesSimulator.QUALITY_ANCHOR` (new, 9.3).** `review_multiplier()` was
`pow(score / 10.0, 4.0)`, which quietly assumed the old inflated scale. With
the same exponent against the new scale every release read as a third weaker
than before, and the economy collapsed on its own — 30.5% of releases stopped
breaking even and median revenue-to-cost fell to 1.6x. Anchoring the curve at
9.3 keeps commercial expectations calibrated to what the scale now means: sell
at full strength only for a genuinely exceptional game, not a merely competent
one.

The economy is still meaningfully tighter than before, which is the point —
9.9% of releases lost money before, 16.8% do now, and median revenue-to-cost
went from 30.9x to 3.4x. The old figure was the runaway the September 7 pass
had already flagged, not a target.

## What this did not change

Nothing about *what* earns merit. `expected_quality` per size, the polish and
balance bonuses, the bug penalty, the reputation expectation and the
compatibility bonus are all untouched — only the conversion from merit to a
printed score, and the sales curve's anchor on that score.

Reputation gain (`reputation_change`) was deliberately left alone. It reads
`(score - 5.5) * 1.4`, so lower scores mean slower reputation growth — which
works against the pinned-at-100 reputation the September 7 pass flagged rather
than for it.

## Tests

`ReviewTest` gained a section asserting the curve's properties directly:
monotonic, each equal step of merit above the bar buying strictly less than the
one before, a flawless release still able to reach the landmark band, and merit
well past the bar still only reading as an 8.

`ReviewTest` also had a latent bug. `_equal_execution_scores_equally_regardless_of_size`
compared two 40-trial averages with `check_approx()`, which demands float
equality — it passed only because both sides pinned the 9.8 ceiling exactly, so
it was measuring the clamp rather than the rule. It now uses a new
`TestCase.check_near()` with a real tolerance.
