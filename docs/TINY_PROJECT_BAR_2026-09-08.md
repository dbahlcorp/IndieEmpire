# The Tiny project bar — September 8, 2026

The rough edge left by the bonus-stacking pass. Tiny was the one size whose
quality ratio drifted over a career:

    size    1985-87  1988-90  1991-93  1994-96
    Tiny       0.96     1.87     1.94        -
    Small         -     0.95     0.98     0.99
    Medium        -        -     0.94     1.04

Two things were actually wrong, and they are not the same thing:

1. **It was free standing.** `reputation_change()` was `(score - 5.5) * 1.4`,
   flat in size. A Tiny game reviewing at 8.5 moved a studio's reputation by
   exactly as much as a Medium one at 8.5. Fans were never a problem — they
   scale with units sold, so a small game's following looks after itself — but
   reputation made cheap, fast, safe Tiny projects the most efficient way to buy
   standing in the game.
2. **It was undifferentiated.** `OVER_DELIVERY_CAP` at 1.35 was doing the whole
   job of containing it, and 70% of late Tiny releases pinned it and scored an
   identical 8.5. Every small game a veteran studio made was the same game.

## What causes the drift

Not reputation, and not over-staffing. `team_output_multiplier` returns 1.0 for
one person and 1.8 for two — and two is exactly what `max_useful_staff: 2` says
correct staffing for Tiny is. That 1.8x *is* the drift, near enough exactly.

Medium and Large never drift because they are only ever attempted by teams
already sized for them, so their `team_output` is pinned (3.6 and 5.0) and their
bars, calibrated on those teams, stay true for a whole career.

So Tiny's bar is calibrated for a founder alone in a bedroom, and a properly
staffed Tiny project beats it by 1.8x by construction.

## Two fixes that were measured and rejected

**Raise Tiny's bar to suit a two-person team** (28 → 38). This is the obvious
move and it destroys the game. The opening of a career depends on the founder's
first releases clearing their bar; at 38 they score 3.9, never sell, never fund
a hire, and the studio never gets off the ground. A measured career produced 112
releases with a mean review of 4.98, against 356 and 7.10. The bar is *correct*
at 28 — it is doing a job.

**Scale the bar by how over-resourced the scope is.** Judge a six-person team on
a two-person scope more harshly. Reasonable on its face, and it cannot work
here: the measured staffing pressure for late Tiny is 2.00 and for Medium it is
*also* 2.00, because a studio assigns everyone to two teams regardless of what
those teams are building. The term cannot tell the two cases apart, and it
dragged the whole distribution down about 0.7 of a review point before it was
backed out.

## What actually shipped

**`DevelopmentSimulator.SCOPE_ABSORPTION` (new, 0.18).** A project can only
absorb so much. Past its own size's quality bar, each further unit of craft has
progressively less to attach itself to — the quality half of what
`max_useful_staff` already does for throughput. Asymptotic, not a wall, so a
genuinely exceptional small game still pulls ahead of a merely good one. Tiny's
95th-percentile ratio falls from 2.89 to 1.96; Medium's 1.12 becomes 1.09 and
Large is untouched, because neither goes near its bar's ceiling.

**`reputation_weight` per size** (Tiny 0.60, Small 1.00, Medium 1.20, Large
1.35). Standing moves with what you shipped, not just how it reviewed. Medium
stays the 1.0 reference so the mainline career is unchanged.

**`OVER_DELIVERY_CAP` 1.35 → 1.30.** Still the thing that stops an
over-delivering Tiny project reading as a 9 — that part was always its job and
still is. What changed is that it no longer has to do it alone.

## Result

    late Tiny reviews   before: 70% pinned at 8.50
                         after: 41 releases, 19 distinct scores, 5.6 to 9.0

    ratio by era        Tiny 0.98 -> 1.41 -> 1.55   (was 0.96 -> 1.87 -> 1.94)
                      Medium 0.95 -> 0.98 -> 0.95
                       Large 0.95 -> 1.02

    distribution        mean 7.10  median 7.30  stdev 1.15  0% on the ceiling
    economy             12.6% of releases lose money, 6.5x revenue/cost,
                        final cash $52M

A veteran studio's Tiny game still reviews around 8.2. That is deliberate: a
good team making a small game *should* make a good small game. What it no longer
does is score the same 8.5 every time, or buy standing as though it were a
Medium.

## The structural alternative, not taken

Setting Tiny's `max_useful_staff` to 1 would remove the drift at its root, by
pinning its `team_output` the way every other size's is pinned. It is arguably
the more honest model — a Tiny game is a one-person project, and
`ideal_team_min` already says so. It was not taken because it makes a second
person on a Tiny project worth literally nothing, which is a larger design
statement than this pass should make on its own.
