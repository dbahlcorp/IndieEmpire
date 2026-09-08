# QUALITY_ANCHOR — investigation and pinning, September 8, 2026

Raised as a suspected regression: the bonus-stacking commit documents moving
`SalesSimulator.QUALITY_ANCHOR` from 9.3 to 11.0, but the constant was reported
as reading 9.3 on main.

## There was no regression

    commit    value    subject
    b5358e3    11.0    Fix the Tiny project bar (HEAD, = origin/main)
    5d58aca    11.0    Bound the bonus stacking
    a2e92c6     9.3    Normalise the review scale   <- introduced the constant
    9c39bd3      --    initial prototype (inline `pow(score / 10.0, 4.0)`)

Local `main` and `origin/main` are the same commit and both define 11.0. There
is exactly one definition of the constant in the codebase. 9.3 was its value at
`a2e92c6`, two commits back — the commit that created it. The report appears to
have read the file at that commit rather than at HEAD.

The investigation was run anyway, because 11.0 was chosen in a single tuning
iteration and had not been validated across the dimensions below.

## Measured comparison

Eight seeds, identical, to 1996. The full dumps are under
`artifacts/quality-anchor-2026-09-08/`.

|                              |     9.3 |    11.0 |
|------------------------------|--------:|--------:|
| mean review                  |    7.24 |    7.12 |
| median review                |    7.40 |    7.30 |
| releases scoring 9+          |    0.2% |    1.1% |
| releases under 5             |    5.0% |    6.5% |
| **median final cash**        | **$120M** | **$38M** |
| min / max final cash         | $1.6k / $129M | $1.6k / $61M |
| releases that lost money     |    6.8% |   11.9% |
| median revenue / total cost  |   13.6x |    6.2x |
| **Medium releases losing money** | **0.0%** (0 of 287) | 0.5% |
| Tiny median profit           | $169,613 | $29,628 |
| Medium median profit         | $2,287,632 | $1,021,452 |
| careers ending bankrupt      |     25% |     25% |

## What the anchor does and does not control

**It does not affect review scores.** 7.24 against 7.12 — the small difference
is the studio growing faster, not games being judged differently.

**It does not affect survivability.** Bankruptcy is 25% at both, and in every
case in April 1986 — the founder's opening months, before the constant has any
leverage at all. Whether a career survives is decided by starting conditions.

**It does not affect the very late game.** Past about 1995 releases run into
`MAX_ATTACH_RATE`, and for any game strong enough to approach that ceiling it is
the ceiling, not demand, that sets sales. Revenue per release converges
completely — $7.76M against $7.76M in 2000-04, $19.2M against $19.5M in 2005-09
— and a career played to 2050 finishes on $1.276B against $1.167B, 9% apart.

**What it controls is the first decade**, which is the part of a career where
the studio is growing and the player's decisions still matter.

## Why 11.0 is right

**9.3 breaks the constant's own stated invariant.** The anchor is the score at
which a release would sell at full strength, and the design is that nothing ever
reaches it. The highest score the game can print is 9.8. At 9.3 a 9.5-scoring
release sells at 1.09x full strength and a perfect one at 1.23x — the
fourth-power curve running away exactly where it is least affordable. This is
also the shape of the original bug, when the anchor was a bare 10.0.

**9.3 removes commercial risk entirely.** Not one of 287 Medium releases lost
money, and the median release returned 13.6x its cost. At 11.0, 11.9% of
releases lose money and the median returns 6.2x — real risk, survivable.

**9.3 removes the spread between careers.** By 1990 the *minimum* cash across
surviving seeds is $42M; every career is rich, and none is ever short of money
again. At 11.0 the minimum is $5,950 in the same year, so studios are still
genuinely differentiated by how well they have played.

**11.0 matches the documented target.** The September 7 pass targeted about
$45M final cash. 11.0 measures $38M; 9.3 measures $120M.

**Recommendation: keep 11.0. No change made.**

## Pinning it

`scripts/tests/QualityAnchorTest.gd` now guards the constant. It checks the
properties, not just the number, so a failure says what is actually wrong:

1. **The anchor sits above the best printable review score.** Reads
   `ReviewSimulator.best_possible_score()` rather than carrying its own copy of
   9.8, so the two files cannot drift apart. This is the check that catches both
   values the constant has historically been wrong at — 10.0 and 9.3.
2. **A competent (7.3) release sells at 0.194 of full strength.** The economic
   calibration in one number; moves if the anchor, the exponent, or the review
   scale changes, all of which require re-measuring.
3. **The anchor is a pure scale factor** — it shifts every score's multiplier
   equally and changes no relative outcome. This is what makes it safe to retune
   at all: it is the economy's volume knob and nothing else.
4. **Steepness is pinned separately**, because it belongs to `QUALITY_EXPONENT`.
   An 8.0 outsells a 7.0 by 1.71x, a 7.0 outsells a 6.0 by 1.85x.
5. **The value itself**, with a failure message naming this document and the
   probe, and quoting both measured cash figures — so an intentional retune is a
   deliberate act with instructions rather than a number someone edited.

Verified against wrong values: 9.3 fails four checks, 10.0 fails two, 12.5 fails
two.

`ReviewSimulator` gained named `MIN_SCORE` / `MAX_SCORE` constants and
`best_possible_score()` to support check 1; those bounds were previously inline
magic numbers.

## Still open

Both anchors finish a 2050 career on roughly $1.2B against running costs of a
few million a year.

> **Corrected.** That is a nominal figure, and it is not a runaway. Measured in
> 1985 dollars the same career is flat from about 2020 (+0.4%/yr), and runway
> plateaus near fifty years at the same point. `MAX_ATTACH_RATE` is not involved
> either -- it is never pinned after 1999. See
> `docs/LATE_GAME_ECONOMY_2026-09-08.md`; `analyse.py` now reports real terms
> and runway so the nominal column cannot mislead again.
