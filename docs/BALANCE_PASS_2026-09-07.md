# Balance pass — September 7, 2026

A measured pass over the released-game economy: review scoring, the sales
ceiling, and the studio's cash curve from 1985 to 1996.

## How this was measured

Reviews and sales are randomised, so a single career says very little — the
September 7 M3 report saw one run finish on a 9.08 average review and another
pass the same assertions. This pass added a probe that plays the same
randomised manager career the Phase A acceptance run plays, but records every
release and a yearly snapshot of the books as CSV instead of asserting:

    godot --headless --path . res://scripts/tests/balance/BalanceProbe.tscn -- --seed=1
    python scripts/tests/balance/analyse.py "<user-dir>/balance" BASELINE

Six to eight seeds per configuration, ~280 releases per configuration. Raw CSV
and run logs are under `artifacts/balance-2026-09-07/`.

## What was wrong

**Reviews were saturated.** 34.6% of all releases scored 9.5 or better and
28.7% sat exactly on the 9.8 ceiling. The cause was `expected_quality` in
`data/game_sizes.json`: the bar for a Medium project was 444 against an actual
delivered quality of about 1,330, so every Medium game cleared its bar by 3x,
clamped the quality ratio and scored 9.8 automatically. Tiny was off in the
same direction by a smaller margin. Small was correctly calibrated.

**The sales ceiling was a wall, not a ceiling.** `MAX_ATTACH_RATE` was applied
as a hard remaining-audience clamp, so a strong release sold flat out until it
hit exactly 8% of the platform's install base and stopped. 16.8% of releases
pinned that cap, and unrelated hits finished on identical round numbers —
across 286 releases there were only 109 distinct lifetime unit totals. Five
different 1989 games each sold exactly 960,000 copies. Above a certain quality,
quality stopped mattering at all.

**The economy ran away in year three.** Median cash went $39,230 (1986) to
$6,177,696 (1987) — a 157x jump in one year — and finished at $92M against
about $2M/year of running costs, with consumer reputation pinned at its 100
maximum from 1989 onward. Average review *fell* over a career (9.08 down to
8.73) because the studio peaked almost immediately.

## What changed

| File | Change | Why |
| --- | --- | --- |
| `data/game_sizes.json` | `large` expected_quality 444 → 1300 | Measured delivered quality was 3.0x the bar |
| `data/game_sizes.json` | `small` expected_quality 30 → 38 | Measured 1.35x the bar |
| `data/game_sizes.json` | `aaa` expected_quality 870 → 2550 | Unreachable placeholder, kept proportional to `large` |
| `scripts/simulation/SalesSimulator.gd` | `remaining_audience()` now returns a `SATURATION_RATE` (0.32) share of the untouched audience instead of all of it | The attach ceiling is approached over ~8 weeks rather than hit and stopped against |
| `data/publishers.json` | `atlas` developer_share 0.19 → 0.18 | Atlas and Northgate were exactly tied on reach x share, making Atlas a strict upgrade rather than a different bargain |
| `scripts/tests/ReviewTest.gd` | Fixtures derive quality from each size's `expected_quality` instead of hardcoding it | The fixture broke on retuning even though the rule it checks still held |

Production scoring code in `ReviewSimulator.gd` was **not** changed. An earlier
attempt to trim the review formula's weights and bonus caps alongside the data
is recorded below as a rejected experiment.

## Result

Eight seeds before and after, ~300 releases each.

| | Before | After |
| --- | ---: | ---: |
| Mean review | 8.75 | 7.84 |
| Median review | 8.90 | 8.00 |
| Review spread (stdev) | 1.00 | 1.37 |
| Lowest review seen | 5.6 | 3.9 |
| Releases at the 9.8 ceiling | 28.7% | 6.9% |
| Releases pinned at the 8% attach cap | 16.8% | 1.5% |
| Distinct lifetime unit totals | 109 of 286 | 332 of 333 |
| Quality ratio, Tiny / Small / Medium | 1.38 / 1.05 / 3.00 | 0.94 / 1.04 / 1.06 |
| Releases that lost money | 3.1% | 9.9% |
| Median revenue against stated dev cost | 126x | 31x |
| Final cash, median across seeds | $91,978,756 | $45,615,186 |
| Final cash, range across seeds | $79M – $97M | $25M – $76M |

The growth curve is the part worth reading. Before, a studio went from $39,230
to $6,177,696 in a single year and hired twelve people in 1987. After:

| Year | Cash (median) | Staff | Avg review to date |
| --- | ---: | ---: | ---: |
| 1986 | $4,050 | 1 | 5.13 |
| 1987 | $39,627 | 1 | 5.68 |
| 1988 | $251,183 | 4.5 | 6.29 |
| 1989 | $1,596,955 | 12 | 6.75 |
| 1990 | $11,431,813 | 12 | 7.05 |
| 1992 | $32,020,625 | 12 | 7.58 |
| 1996 | $45,615,186 | 12 | 7.84 |

The studio now stays a bedroom operation for three years, and its average
review climbs across a career (5.13 to 7.84) instead of peaking at 9.08 in
year three and drifting down. Seed-to-seed variance is real again — the
baseline's careers all landed within $18M of each other.

## Rejected experiments

**Trimming the review formula (reverted).** Lowering the quality weight
62 → 52, the ratio clamp 1.6 → 1.5, the compatibility bonus 30 → 22 and the
polish/balance/reputation/fame caps, *on top of* the `expected_quality`
recalibration, collapsed the game: average review 5.17, median cash $395k, and
one seed in six bankrupt by 1986. Sales scale with review to the fourth power,
so the review change compounds through fans and reputation into the next
project. The `expected_quality` correction alone was the fix; the formula
constants were not the problem.

**Raising self-publishing reach 0.35 → 0.45 (reverted).** Self-publishing is
strictly the worst deal in the game at every point — reach x share of 0.350,
below even Thrift's 0.380 — so "who publishes this" is never a real decision.
Raising its reach to make it competitive flipped the AI manager into
self-publishing and *halved* the endgame economy ($49M to $16M), because reach
does not only convert to revenue: it converts to units, which convert to fans
and reputation, which compound into every later release. Reach x share
understates what a publisher is worth. Left as authored — see below.

## Findings not acted on

These are real, were measured, and are design calls rather than tuning:

1. **Self-publishing is never the right choice.** See above. Making it a genuine
   option needs the fan and reputation paths to reward keeping your own
   audience, not just a bigger `reach` number.
2. ~~**A project's profit excludes payroll.**~~ **Fixed** — see the follow-up
   section below.
3. **Money has nowhere to go after 1990.** Headcount is capped at 12 by the
   largest office, so a studio accumulates tens of millions with nothing to
   spend it on and no growth pressure. This is a content gap, not a tuning
   one; no amount of revenue tuning makes the late game a decision.
4. **Tiny games score systematically below larger ones** (mean 6.8 against
   8.4) even at the same quality ratio, because polish and balance accumulate
   in smaller absolute amounts and `quality_weight` divides rather than
   compensates. Worth a look if Tiny projects are meant to stay viable late.

## Verification

All 27 unit suites and the four acceptance phases were re-run after the change.

- **26 of 27 unit suites pass**, including every suite that touches scoring,
  sales, publishing, scope and finance.
- **All four acceptance phases pass** — PhaseA 55 checks, PhaseB 40, PhaseC 14,
  PhaseD 66. PhaseA is the randomised career smoke test, and it passes with its
  average-review and "some games lost money" assertions intact, which is the
  pair the September 7 M3 report saw fail.
- **`DelayTest` remains failing** (2 of 29 checks). This is the pre-existing
  stale-fixture failure diagnosed in the September 7 M3 report — its forced
  two-week slip is partly recovered by development during the same tick — and
  it fails identically before and after this pass. Not addressed here.
- `ReviewTest` failed on its hardcoded quality fixtures, which were calibrated
  to the old bars; the fixtures now read each size's bar from the data and it
  passes.
- PhaseD failed once on a wall-clock check ("weeks passed with no input") while
  eight other Godot processes were running, and passes on its own. Timing
  flake, not a regression.

The probe and its analysis script are checked in at
`scripts/tests/balance/` so this pass can be repeated rather than re-derived.

---

# Follow-up: wages in a game's books

A game's cost was development spend plus platform fee only. The salaries that
actually built it were booked as company overhead and never reached the
project, so a release only had to out-earn its equipment budget — median
revenue was 31x a game's stated cost, and effectively nothing a staffed studio
shipped could lose money.

## The change

`GameProject.labour_cost` accrues that project team's wages once per
development week, in pre-production, production and polish alike. Everyone on
the team counts, including anyone away on a course — they are still paid, and
they are still the project's cost.

This is **attribution, not a second charge**. Payroll still leaves the bank
monthly exactly as before; nothing about the cash economy changes. Measured
across eight seeds, final cash was within noise of the previous run.

The cost split now has two names:

- `cash_cost()` — development spend plus platform fee. What came out of this
  project's own budget. The player's budget target and a publisher's advance
  are both about this.
- `total_cost()` — `cash_cost()` plus wages. What the game actually cost, and
  what `profit()` and `is_profitable()` are measured against.

Publisher advances deliberately stayed on `cash_cost()`. An unrecouped advance
is money a failed game keeps, so scaling advances to wages as well would have
cushioned exactly the failures this was meant to expose.

Wages turn out to be **79% of a typical game's cost** (median), which is the
size of the hole this was leaving in the books.

## Result

Profitability is now a clean function of how good the game was:

| Review | Lost money — before | Lost money — after |
| --- | ---: | ---: |
| below 5.0 | 100% | 100% |
| 5.0 – 6.0 | 65% | 75% |
| 6.0 – 7.0 | 6% | 22% |
| 7.0 – 8.0 | 0% | 4% |
| 8.0 and up | 0% | 0% |

| | Before | After |
| --- | ---: | ---: |
| Releases that lost money | 9.9% | 13.5% |
| Median revenue against a game's cost | 31x | 6.1x |
| Median profit per release | $934,596 | $642,848 |
| Wages as a share of a game's cost | not counted | 79% |

The aggregate moves less than the per-band figures because the probe's manager
is a competent player — it picks high-demand genres, good theme combinations
and the best publisher available, so most of what it ships reviews at 7 or
better. The change is visible exactly where it should be: a mediocre game now
fails commercially about a fifth of the time instead of almost never, and a
merely-decent one can now fail at all.

Solo founder releases are unaffected, because the founder draws no salary —
their games genuinely cost only what was spent on them. 49% of those lose
money, against 6% of releases built by paid staff.

## Where it shows up

- **Publishing screen** and **Financials** already read `total_cost()`, so they
  now show the loaded figure.
- **`FinanceManager.profit_breakdown()`** gained a Wages row — without it the
  rows no longer summed to the profit printed underneath them.
- **Development screen** shows "Wages So Far" beside the budget meter, so the
  player does not first meet this number in the postmortem. It sits outside the
  budget target on purpose: the target is a cash-spend tool.
- `labour_cost` is in `INT_FIELDS`, so it round-trips through saves. Older
  saves load with zero and simply report what they always did.

Knock-on effects, both intended: a flop now moves team morale (`MoraleManager`
reads `is_profitable()`), and `EmployeeReputationSimulator.hit_score()` judges a
release against its real cost, so "major hits" are rarer.

## Verification

Every unit suite re-run: **32 of 33 pass**, `DelayTest` failing on the same two
pre-existing stale-fixture checks as before this work started. All four
acceptance phases pass, including PhaseB's reload of a save written with the
new field.

---

# Follow-up: the late-game money sink

Finding 3 was that money had nowhere to go after 1990. Headcount was capped at
12 by the largest office, so a studio banked tens of millions with nothing to
spend it on and no growth pressure.

## The gap that was already there

The code supported two teams (`TeamManager.MAX_TEAMS = 2`) and a Medium project
could use ten people. Two full teams is twenty. The office ladder stopped at
twelve, so the second team was never actually staffable. The fix was to finish
the ladder rather than invent a new system.

| Office | Tier | Seats | Rent | Move-in | Rent per desk |
| --- | ---: | ---: | ---: | ---: | ---: |
| Large Studio Floor | 4 | 12 | $7,800 | $42,000 | $650 |
| **Studio Building** | 5 | 16 | $38,000 | $850,000 | $2,375 |
| **Studio Campus** | 6 | 20 | $110,000 | $3,200,000 | $5,500 |

Rent per desk climbs steeply on purpose: scaling up has to cost more per person
than staying small, or the top of the ladder is a free upgrade. Twenty seats is
not arbitrary -- it is exactly AAA's `max_useful_staff`, and exactly two full
Medium teams. The ladder ends where the systems do.

## The third inflation bug

Rent drifts with the era. Salaries drift with the era. **Move-in costs did
not** -- so a 2050 studio bought a campus at 1985 prices while paying 2050
wages inside it, and the largest offices stopped being a decision late on.
This is the same class of bug as development costs (see the payroll follow-up),
found in a third place. All callers now go through `OfficeManager.move_in_cost()`
so the Offices screen, the simulation and the probe quote the same number.

Its effect alone: seed 1's 1996 cash went **$21.7M to $8.5M**.

## Expansion is a bet, and the game lets you lose it

`can_move_to()` checks only the move-in cost. The rent afterwards is the half
that closes studios, and the player is deliberately allowed to find that out.
`OfficeExpansionTest` pins this rather than leaving it to drift: the same move
into the same office is **fatal within a year at $1.2M cash and survivable at
$30M**.

This is not theoretical. While measuring, the probe's own manager -- which only
checked the move-in cost -- signed for a campus with sixteen staff and went
bankrupt in 1991. It now checks it can carry a year of rent first, which is
what a competent player does.

## Result

Eight seeds, 1985-1996, against the original baseline:

| | Baseline | Now |
| --- | ---: | ---: |
| Peak headcount | 12 | 20 |
| Teams running in parallel | 1 | 2 |
| Games shipped | 45 | 39 - 84 |
| Releases that lost money | 3.1% | 19.2% |
| Median revenue against a game's cost | 126x | 5.5x |
| Final cash, median | $92.0M | $60.7M |
| Final cash, range | $79M - $97M | $5.5M - $103M |

The number that matters is not the median, it is the **shape of the curve**.
Baseline cash was still climbing at the end ($89.6M in 1994 to $92.0M in 1996).
It now peaks and turns over:

| Year | 1993 | 1994 | 1995 | 1996 |
| --- | ---: | ---: | ---: | ---: |
| Cash (median) | $51.4M | $61.9M | $62.6M | **$60.7M** |

A maximally-expanded studio's income and costs finally meet. It stops
compounding, which is what the sink was for.

The spread also widened enormously -- $5.5M to $103M, against a baseline where
every career landed within $18M of every other. Expansion is now a decision
with outcomes, not a formality.

## What this does not fix, honestly

**A 66-year career still ends on roughly a billion dollars.** The sink flattens
the growth curve, but the pile that accumulated on the way up stays, and sixty
years of even modest annual profit integrates to a large number. Removing that
would mean driving steady-state profit to about zero, which turns the late game
into a treadmill with no reward -- so it is a design decision rather than a
tuning one, and it is not mine to make. The levers that would actually do it:

1. **Market saturation.** Nothing stops a studio flooding the market with 190
   games; each one sells as if it were the first. Audience fatigue, or
   self-cannibalisation between a studio's own concurrent releases, is the
   missing mechanism the whole runaway-economy thread keeps pointing at.
2. **Something to buy that is not headcount.** `expansion_slots` is authored on
   every office (1-5 by tier) and read by exactly one description string.
   Facilities with a capital cost and ongoing upkeep would give money a second
   destination once the ladder tops out.

Both were offered and set aside when this work was scoped; they remain the
next lever if the billion bothers you.

---

# Follow-up: market saturation

Finding 1 of the sink write-up proposed market saturation as the lever that
would stop a studio flooding the market. Investigating it corrected two of my
own claims, so both are recorded here.

## Correction: genre saturation already existed

`MarketSimulator` has always modelled it -- 30% per release scaled by project
size, capped at 75%, decaying over roughly a year. The earlier claim that
"nothing stops a studio flooding the market" was wrong about the genre axis.
Instrumented, it bites: about half of all releases launch into a genre the
studio itself had already crowded.

What it does not cover is a studio with two teams simply **rotating genres**.
That dodges genre saturation entirely while the studio's own back catalogue is
still on the shelf, competing for the same buyers.

## The new axis: catalogue crowding

`SalesSimulator.catalogue_crowding` applies a penalty for each of the studio's
own releases still on sale, counted at launch because that is what shapes the
curve that follows.

| Games on sale | 1 | 2 | 3 | 4 | 5+ |
| --- | ---: | ---: | ---: | ---: | ---: |
| Demand multiplier | 100% | 80% | 60% | 40% | 30% |

`MIN_CATALOGUE_FACTOR` is the term that decides how hard this bites, not the
per-release rate. At the first tuning (13% and a 50% floor) a slate of five was
already on the floor, so the rate did nothing past that point and the net effect
on a career was inside the seed-to-seed noise. Lowering the floor to 30% is what
made it register.

`SaturationTest` covers both axes, including the check that matters: the same
game, built twice, differs by exactly the crowding factor when the shelf is
crowded. Career runs are far too noisy to establish that.

## Result

Eight seeds, 1985-1996:

| | No crowding | 13% / 50% floor | 20% / 30% floor |
| --- | ---: | ---: | ---: |
| Median final cash | $60.7M | $70.9M | **$50.3M** |
| Lowest seed | $5.5M | $15.9M | **$3.5M** |
| Highest seed | $102.9M | $90.1M | **$88.9M** |
| Games shipped (median) | 74 | 74 | **68** |

## Correction: who actually pays it

An earlier reading of this data claimed crowding punishes high-volume shipping
and leaves quality studios alone. The per-seed numbers say the opposite:

| Seed | Average review | Median slate | Final cash |
| --- | ---: | ---: | ---: |
| 3 | 7.91 | 5 | $83.4M |
| 4 | 7.90 | 5 | $88.9M |
| 7 | 7.92 | 4 | $72.7M |
| 1 | 6.60 | 2 | $6.1M |
| 2 | 6.04 | 2 | $3.5M |

A large slate is a **consequence** of success -- good games sell for longer and
stay on the shelf -- so the successful studios carry the most crowding and pay
the most for it. The causation ran the other way from what was claimed.

## Why this cannot cap the top end

Crowding is a flat multiplier, and the top studios' advantage is quality, which
feeds demand to the fourth power: a 7.9 against a 6.0 is roughly 3x before
anything else applies. Scaling everyone by 0.4 lowers the whole distribution
without compressing it. The measurements show exactly that -- across the crank
the low end fell from $15.9M to $3.5M while the high end moved $90.1M to
$88.9M.

**So market saturation lowers the economy but structurally cannot cap its
ceiling**, and cranking it further bankrupts weak studios long before it
touches strong ones. Capping the ceiling needs a lever that scales *with*
success rather than multiplying it -- diminishing returns on reputation and
fans, or costs that grow with studio scale. That changes what success feels
like, so it is left as a design decision rather than taken unilaterally.

---

# Follow-up: diminishing returns on reputation and fans

The saturation write-up concluded that crowding could lower the economy but not
cap its ceiling, and named this as the lever that could. It is.

## The two straight lines

Measured across a career, both terms that carry a studio's success paid out
linearly:

- **Consumer reputation** reaches its hard cap of 100 around 1992 and then
  hands over a flat 1.5x demand multiplier for the remaining sixty years.
- **Fans** grow without bound -- a million by 1996 and still climbing -- and
  every one was worth exactly as much as the first. Worse, fans were won in
  proportion to units sold, so units bought fans bought units with nothing
  damping the loop.

## The curves

| Reputation | 0 | 25 | 50 | 75 | 100 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Before | 1.00 | 1.13 | 1.25 | 1.38 | 1.50 |
| After | 1.00 | 1.16 | 1.23 | 1.28 | **1.32** |

A square root to a lower ceiling. Note it **crosses over around 35**: an
obscure studio is slightly better off than before, a famous one meaningfully
worse. That crossover is the point -- it compresses the field rather than
scaling everyone down, which is exactly what catalogue crowding could not do.

| Fans | 10,000 | 100,000 | 1,000,000 |
| --- | ---: | ---: | ---: |
| Head-start units, before | 800 | 8,000 | 80,000 |
| Head-start units, after | 800 | 4,499 | **25,298** |

Anchored so a small following is untouched. And `fan_gain_multiplier` damps
acquisition -- half rate once a studio holds 900,000 -- which is the brake on
the units/fans loop itself. Losing followers is deliberately *not* damped: a
bad game sheds them at full rate.

## Result

Eight seeds, 1985-1996:

| | Crowding only | + diminishing returns |
| --- | ---: | ---: |
| Median final cash | $50.3M | **$21.9M** |
| Highest seed | $88.9M | **$60.8M** |
| Lowest seed | $3.5M | **$1,404** (survived) |
| Seeds bankrupt | 1 of 8 | **0 of 8** |

Per seed, the compression is the story:

| Seed | Average review | Crowding only | + diminishing returns |
| --- | ---: | ---: | ---: |
| 4 | ~7.9 | $88.9M | $60.8M |
| 3 | ~7.8 | $83.4M | $53.7M |
| 1 | ~6.9 | $6.1M | $11.0M |
| 2 | ~6.5 | $3.5M | $17.7M |
| 5 | ~4.7 | bankrupt | survived, 14 games |

The top fell by about a third and the bottom rose. The seed that went bankrupt
under crowding alone now trades.

## Against the original baseline

| | Baseline | Now |
| --- | ---: | ---: |
| Mean review | 8.75 | **7.43** |
| Releases at the 9.8 ceiling | 28.7% | **0.2%** |
| Releases scoring 9.5+ | 34.6% | **1.2%** |
| Median final cash | $92.0M | **$21.9M** |
| Range across seeds | $79M - $97M | **$1.4k - $60.8M** |
| Cash curve at the end | still climbing | roughly flat |

The review ceiling has essentially stopped being reachable by accident -- one
release in five hundred -- while the distribution keeps a full range from 3.4
to 9.8.
