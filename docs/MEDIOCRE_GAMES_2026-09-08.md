# Making mediocre games economically mediocre — September 8, 2026

## The problem

Reviews had been normalised, but sales had not been retightened against them.
A 6.8 was a comfortably profitable game, and effectively nothing a staffed
studio shipped ever lost money.

Sixteen seeds to 1996 on the balance probe, median revenue over total cost
(wages included) by review band:

| review | median rev/cost | releases that lost money |
|--------|----------------:|-------------------------:|
| 5.x    |            1.2x |                      38% |
| 6.0–6.5|            4.0x |                      10% |
| 6.5–7.0|            5.9x |                       4% |
| 7.x    |            8.2x |                       4% |
| 8.x    |           11.5x |                       0% |
| 9.x    |           36.6x |                       0% |

Overall, 12.9% of releases lost money — and only 4.0% of the releases built by
paid staff. Development cost had stopped being a meaningful number next to
expected sales: the median release returned 6.4x what it cost, so a studio
could carry a twenty-person team on a slate of 6.x games indefinitely.

## The lever

`SalesSimulator.QUALITY_EXPONENT`, 4.0 → 5.5.

It is the only lever that could do this. `QUALITY_ANCHOR` multiplies every
score's demand by the same factor (`QualityAnchorTest` pins that property
deliberately), so it sets how rich the economy is and cannot move *which* score
breaks even. The exponent is the shape.

Raising it lowers the whole curve as well as steepening it, and that is wanted
here rather than compensated for: the brief was that development cost should
matter more relative to expected sales, and both halves of that follow from the
same change.

## Measured result

Sixteen seeds to 1996, same seeds and same probe manager as the baseline above.

| review  | rev/cost 4.0 | rev/cost 5.5 | lost money 5.5 | intent                      |
|---------|-------------:|-------------:|---------------:|-----------------------------|
| 5.x     |         1.2x |         0.5x |            84% | likely loss                 |
| 6.0–6.5 |         4.0x |         0.9x |            58% | break-even to small profit  |
| 6.5–7.0 |         5.9x |         2.3x |            16% | break-even to small profit  |
| 7.x     |         8.2x |         4.5x |             3% | healthy profit              |
| 8.x     |        11.5x |        15.4x |             2% | strong success              |
| 9.x     |        36.6x |        63.0x |             0% | major hit                   |

The bands are the general shape, not a guarantee — trend, platform size and how
crowded the studio's own slate is still move an individual release either side
of its band. 42% of 6.0–6.5 releases still turn a profit and 2.5% of 7.x
releases still lose money.

## What it costs

|                                | 4.0   | 5.5    |
|--------------------------------|------:|-------:|
| releases that lost money       | 12.9% |  33.4% |
| of those built by paid staff   |  4.0% |   8.2% |
| median rev/cost                |  6.4x |   2.7x |
| median final cash, 1996        |  $48M |  $8.6M |
| bankrupt careers (of 16 seeds) |   25% |    31% |

Two things to be aware of.

**The 1996 cash target is superseded.** `docs/QUALITY_ANCHOR_2026-09-08.md`
tuned the anchor against a ~$45M figure at 1996. That target assumed a median
release returning 6.4x its cost, which is the thing this pass removed, so the
$8.6M here is not a regression against it — but the anchor should not be
re-tuned back toward $45M without re-reading this document first.

**Bankruptcy is up slightly, and later.** 25% → 31% over sixteen seeds. The
baseline's failures are all the known April 1986 cash cliff; the added ones are
studios that expanded on mediocre releases and could no longer carry payroll in
1988–1990, which is the intended consequence rather than a separate fault. The
probe's manager never reacts to a worse economy — it hires on the same schedule
whatever its games earn — so this is an upper bound on what a player would see.

## Regression protection

`QualityAnchorTest._mediocre_games_are_economically_mediocre` pins the property
rather than the constant: the gaps between 6.8, 7.5 and 8.5, and that each
point of review is worth more than the point below it. Those checks fail at the
old 4.0. The pinned steepness figures in the same suite moved with the retune
(8.0 vs 7.0: 1.71x → 2.08x; 7.0 vs 6.0: 1.85x → 2.33x), as did
`COMPETENT_STRENGTH` (0.194 → 0.105).
