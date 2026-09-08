# The late-game economy — September 8, 2026

Asked to fix the late-game runaway I had attributed to `MAX_ATTACH_RATE`.

**There is no late-game runaway to fix.** The $1.2B a 65-year career ends on is
a nominal figure; in 1985 dollars the same career is flat from about 2020, and
in runway it plateaus near fifty years at the same point. `MAX_ATTACH_RATE` is
involved, but as the mechanism holding the economy flat rather than the one
running it away — I had that backwards.

This records the measurement, because the same misreading has now been made
twice by two different passes looking at the same misleading column.

## `MAX_ATTACH_RATE` is what *stops* the runaway, not what causes it

The claim was that the runaway "lives in `MAX_ATTACH_RATE` and how the attach
ceiling interacts with platform install bases growing across the timeline". The
attach ceiling does govern late-game sales — but it is the brake, not the
accelerator.

It is worth being precise about how it binds, because the obvious diagnostic
says the opposite. The share of releases *pinned* at the 8% cap is 4% in the
late eighties, 20% in the late nineties, and **0% in every era from 2000 on**.
Read on its own that looks like a cap doing nothing.

It is doing everything. `remaining_audience()` bounds each week's units to
`SATURATION_RATE` (32%) of the headroom left up to
`install_base * max_attach_for(install_base)`, so a game strong enough to
saturate *approaches* its ceiling asymptotically across 52 weeks and never
arrives. Late-game releases therefore land at 4-5% attach having been ceiling-
bound the whole way, and never trip a "pinned at 7.99%" test.

The proof is that the two `QUALITY_ANCHOR` settings converge exactly where this
takes over. The anchor is a pure scale factor on demand — 1.96x between 9.3 and
11.0 — and in the eighties that is what the data shows: $979,520 against
$174,520 of median revenue per release. From 2000 the two are indistinguishable:

    era        attach 9.3   attach 11.0    units 9.3    units 11.0
    1985-89         1.90%         0.36%      200,444        41,213
    2000-04         4.89%         4.89%    1,170,987     1,170,703
    2005-09         4.19%         4.18%    2,457,375     2,495,578

Demand stopped setting sales; the ceiling did. Attach also *falls* across the
timeline — 7.09% in 1995-99 down to 1.85% by 2045-49 — because
`CROWDING_EXPONENT` shrinks that ceiling as install bases grow, which is exactly
what its comment says it is for.

## And there is no runaway

A 65-year career ends on about $1.2 billion, which is what both this claim and
the September 7 pass's "a 66-year career still ends on roughly a billion
dollars" were reacting to. That figure is nominal, and nominal is close to
meaningless over this timeline: costs inflate 5.3x by 2050, so a balance that
stopped growing decades earlier still prints a larger number every year.

Two inflation-neutral measures, both medianed across seeds:

| year | cash (nominal) | cash (1985 $) | runway |
|-----:|---------------:|--------------:|-------:|
| 1995 | $51.4M | $38.1M | 11y |
| 2005 | $119.8M | $65.7M | 16y |
| 2015 | $376.2M | $153.6M | 44y |
| 2020 | $553.5M | $197.7M | 48y |
| 2030 | $698.3M | $196.7M | 47y |
| 2040 | $908.6M | $206.5M | 56y |
| 2050 | $1,142.6M | $215.6M | 58y |

Real cash plateaus around 2020-2025 and is flat for the remaining thirty years:
+0.4%/yr, and *negative* across 2025-2035. Runway — cash over monthly overhead,
which needs no deflating because inflation cancels out of it — plateaus at the
same time and holds near fifty years.

The pattern is identical at `QUALITY_ANCHOR` 9.3 and 11.0, so it is not an
artefact of that tuning either.

**The September 7 sink work succeeded.** Its own summary said the goal was that
"a maximally-expanded studio's income and costs finally meet, so it stops
compounding". That is exactly what the data shows. The doc then measured its own
success in nominal dollars and concluded it had failed.

## What actually happens across a career

    1985-1990   bedroom to a staffed studio; real cash to ~$17M
    1990-2020   the growth phase; real cash to ~$198M, runway 11y to 48y
    2020-2050   flat; real cash +9% over thirty years, runway flat near 50y

Income and costs meet once the studio tops out at 20 seats, because overhead
keeps inflating while capacity cannot grow. That is the intended shape.

## What changed

No balance change. Nothing measured here warrants one. What changed is the
tooling and the guard, so this cannot be misdiagnosed a third time.

**`analyse.py` now reports cash in 1985 dollars and as runway**, beside the
nominal figure, and ends the cash curve with an explicit verdict:

    real growth 2019-2051: +0.4%/yr  FLAT -- income and costs have met

Nominal-only reporting is the actual root cause here. Both passes looked at the
right data and read the one column that cannot answer the question.

**`EconomyPlateauTest` plays a full 1985-2050 career and asserts the plateau.**
It is slow — about 100 seconds — and earns it, because whether income and costs
meet is a property of the whole simulation that no test on a constant can see.
It asserts in both directions: the late game must neither compound (real growth
under 1.5%/yr, under 1.5x across the back half, runway not growing) nor collapse
into a treadmill, which the September 7 pass rightly identified as the opposite
failure. It also checks the career it measures is a *successful* one, since
every growth assertion would otherwise pass on a studio that went bankrupt in
1986.

Verified against an induced runaway: setting `CROWDING_EXPONENT` to 0 so market
growth passes through undamped produces +1.78%/yr and 1.82x, and the test fails
all three compounding checks by name.

## What is genuinely still open

The studio ends with roughly $215M in 1985 dollars and nothing to spend it on —
about fifty years of runway banked, against a real annual profit near zero. That
is not a runaway; it is an **endgame with no decisions left**. Money stops being
a constraint around 2020 and never becomes one again.

The September 7 pass identified this and set it aside as a design decision
rather than a tuning one, which is right. `expansion_slots` is still authored on
every office (1-5 by tier) and still read by exactly one description string —
the hook for facilities with a capital cost and an ongoing upkeep, which would
give money a destination and the late game a decision.

Worth noting for whoever picks it up: the bonus caps added earlier today mean
facilities cannot pay out as another stacking bonus without being worth almost
nothing. Whatever they give would need to be something the caps do not govern —
capacity, unlocks, or cost reductions.
