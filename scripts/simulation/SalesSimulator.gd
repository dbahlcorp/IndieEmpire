class_name SalesSimulator
extends RefCounted

## Pure sales maths. Holds no state and calls no manager:
##
##   Sales = Base Demand
##         x Review Multiplier
##         x Trend Multiplier
##         x Platform Multiplier
##         x Reputation Multiplier
##         x Word of Mouth
##         x Age Decay

const MAX_WEEKS_ON_MARKET := 52
const MIN_WEEKLY_UNITS := 40
## Share of a platform's install base a flawless game reaches in its launch week.
## Trimmed from 0.0009 alongside the attach-rate cap below -- that alone
## halved late-game cash but releases were still routinely maxing out rather
## than genuinely varying.
const MARKET_REACH := 0.0007
## The install base MARKET_REACH is authored against -- roughly what a healthy
## eighties platform held, so the early game is untouched by the crowding rule
## below.
const REFERENCE_INSTALL_BASE := 12_000_000
## A bigger market is a more crowded one. Without this, base demand was a flat
## share of the install base, so a 2050 platform with 260 million owners paid
## fourteen times what a 1990 one did for the same game and the late-game
## economy ran to billions. Reach now falls as the audience grows, so units
## still rise with the market -- just as install_base^0.65 rather than
## proportionally.
const CROWDING_EXPONENT := 0.35

## How sharply review score drives demand. Steep on purpose: a weak game should
## not quietly break even on a big platform.
const QUALITY_EXPONENT := 4.0
## The review score this steep curve is anchored on. Was a bare 10.0, which
## quietly assumed the old, inflated scale where a competent studio averaged
## 7.8 and hits ran 9+; against the normalised scale the same exponent read
## every release as a third weaker and a third of them stopped breaking even.
##
## Deliberately above the highest score a release can actually reach, so no
## game ever sells at "full strength" -- it is a scale constant, not a target.
## It is the single lever on how rich the whole economy is, because sales go as
## the fourth power of it: at 9.3 a measured career finished on $123M, at 11.0
## on $57M. Retune it with the balance probe, never by eye.
const QUALITY_ANCHOR := 11.0
## The most of a platform's owners a single runaway hit can ever reach. Real
## attach rates rarely clear the low teens; this was 0.22 and, combined with
## how easily the multipliers below stacked, meant a good late-game release
## routinely maxed out rather than approaching a real ceiling.
const MAX_ATTACH_RATE := 0.08

static func max_attach_for(install_base: int) -> float:
    ## The same crowding applies to the ceiling, and it has to: for any game
    ## strong enough to approach it, the ceiling -- not base demand -- is what
    ## sets lifetime sales. Damping demand alone barely moved a 2050 career's
    ## takings, because its hits were converging on 8% of a 260-million-owner
    ## platform either way.
    if install_base <= REFERENCE_INSTALL_BASE:
        return MAX_ATTACH_RATE
    return MAX_ATTACH_RATE * pow(
        float(REFERENCE_INSTALL_BASE) / float(install_base), CROWDING_EXPONENT)

static func market_reach_for(install_base: int) -> float:
    if install_base <= REFERENCE_INSTALL_BASE:
        return MARKET_REACH
    return MARKET_REACH * pow(
        float(REFERENCE_INSTALL_BASE) / float(install_base), CROWDING_EXPONENT)

static func review_multiplier(score: float) -> float:
    return pow(score / QUALITY_ANCHOR, QUALITY_EXPONENT)

static func reputation_change(score: float, size_id: String = "") -> float:
    ## Standing moves with what you shipped, not just how it reviewed. A well
    ## received Tiny game is a nice thing to have made; it is not the same event
    ## in a studio's life as a well received Medium one, and it used to move
    ## reputation by exactly as much.
    ##
    ## That was the loop worth closing. Fans already scale with units sold, so a
    ## small game's following looks after itself -- but reputation was flat in
    ## size, which made cheap, fast, safe Tiny projects the most efficient way to
    ## buy standing in the game. See `reputation_weight` in data/game_sizes.json.
    return (score - 5.5) * 1.4 * reputation_weight(size_id)

static func reputation_weight(size_id: String) -> float:
    if size_id.is_empty():
        return 1.0
    return float(DataManager.get_size(size_id).get("reputation_weight", 1.0))

static func word_of_mouth(project: GameProject, reputation: float) -> float:
    ## Players talk about games that are good, novel and not broken.
    var size := DataManager.get_size(project.size_id)
    var expected := maxf(float(size.get("work", 100)) * 0.40, 1.0)

    var review_part := (project.review_score - 6.5) * 0.09
    var gameplay_part := ((project.gameplay / expected) - 1.0) * 0.10
    var innovation_part := ((project.innovation / expected) - 1.0) * 0.08
    var bug_part := -minf(float(project.bugs) * 0.012, 0.25)
    var reputation_part := reputation * 0.0015

    return clampf(
        1.0 + review_part + gameplay_part + innovation_part + bug_part + reputation_part,
        0.55, 1.45)

## How much each of a studio's own releases takes off the others when they are
## on sale together. MarketSimulator already stops a studio flooding a single
## genre -- but a studio with two teams simply rotates genres, and a measured
## 66-year career shipped 190 games with every one selling as though it were
## the only thing the studio had ever put out. Its own back catalogue is still
## on the shelf, competing for the same buyers and the same attention.
const CATALOGUE_CROWDING := 0.20
## However crowded its own slate, a studio never loses more than this much: the
## floor is what a release would still find on its own merits. This is the term
## that actually decides how hard crowding bites -- at the previous 0.50 a slate
## of five was already on the floor, so raising the per-release rate alone did
## nothing past that point.
const MIN_CATALOGUE_FACTOR := 0.30

## Diminishing returns on standing.
##
## Both of these used to pay out in a straight line, which is what let a
## successful studio compound: reputation reached its 100 cap around 1992 and
## then handed over a flat 1.5x for the rest of the game, and every new fan was
## worth exactly as much as the first. Success should still be worth having --
## it is just worth progressively less at the top, which is what stops the gap
## between a good studio and a great one widening forever.

## What a spotless reputation is worth at most. Reached on a square-root curve,
## so the first quarter of a studio's standing buys more than the last.
const REPUTATION_REACH := 0.32
## Anchored so a studio with ten thousand fans sees what it always did; past
## that the curve bends. A million fans used to be worth 80,000 head-start
## units and is now worth about 25,000.
const FAN_REACH := 0.8
const FAN_EXPONENT := 0.75
## An audience is finite: the more of it a studio already has, the harder the
## next slice is to win. This is the damper on the units -> fans -> units loop.
const FAN_SATURATION := 900_000.0

static func reputation_reach(reputation: float) -> float:
    ## 1.0 for an unknown studio, REPUTATION_REACH above that at full standing.
    var standing := clampf(reputation, 0.0, 100.0) / 100.0
    return 1.0 + REPUTATION_REACH * sqrt(standing)

static func fan_reach(fans: int) -> float:
    ## How many buyers a studio's following is actually worth to a new release.
    if fans <= 0:
        return 0.0
    return FAN_REACH * pow(float(fans), FAN_EXPONENT)

static func fan_gain_multiplier(fans: int) -> float:
    ## How readily a release still wins new followers, given how many the studio
    ## already has.
    return 1.0 / (1.0 + float(maxi(fans, 0)) / FAN_SATURATION)

## How many releases a studio can have on sale before they start taking from
## each other. A bedroom studio with its first few games out is not crowding
## anything -- and charging it as though it were killed a quarter of measured
## careers in their first year, before the studio had the cash to absorb a
## single bad month. Crowding is the price of running a real slate, not of
## shipping at all: a two-team studio carries five to seven and still pays.
const CROWDING_FREE_SLOTS := 3

static func catalogue_crowding(concurrent_releases: int) -> float:
    ## `concurrent_releases` counts this game too, so a studio with nothing else
    ## on sale is untouched.
    var others := maxi(concurrent_releases - CROWDING_FREE_SLOTS, 0)
    return maxf(1.0 - CATALOGUE_CROWDING * float(others), MIN_CATALOGUE_FACTOR)

static func base_demand(
        project: GameProject, platform: Dictionary, size: Dictionary,
        install_base: int, trend_demand: float, reputation: float,
        fans: int, difficulty_multiplier: float,
        concurrent_releases: int = 1) -> float:

    var audience: Dictionary = platform.get("audience", {})
    var review := review_multiplier(project.review_score)
    var platform_multiplier := float(audience.get(project.genre_id, 1.0))
    # Was a straight 1 + reputation/200, so a studio that had reached the 100
    # cap collected a flat 1.5x forever. See reputation_reach().
    var reputation_multiplier := reputation_reach(reputation)
    var combo := KnowledgeSimulator.true_compatibility(project.theme_id, project.genre_id)
    var size_multiplier := float(size.get("sales_multiplier", 1.0))
    # A studio selling its own game reaches who it can reach; a publisher opens
    # the market. This is what a publisher is actually being paid for.
    var reach := project.publisher_reach if project.publisher_reach > 0.0 else 1.0

    # Fans give a game a head start, but they are not a captive audience: a bad
    # game burns their goodwill instead of selling to all of them, they can
    # never amount to more than the machines actually out there, and each new
    # one is worth less than the last. See fan_reach().
    var fan_bonus := minf(fan_reach(fans), float(install_base) * 0.004) * review

    # Fans are the one part of this a crowded slate does not dilute -- they
    # follow the studio, so they turn up for whichever game it just put out.
    var crowding := catalogue_crowding(concurrent_releases)

    var demand := float(install_base) * market_reach_for(install_base) * review * trend_demand * platform_multiplier
    demand *= reputation_multiplier * combo * size_multiplier * difficulty_multiplier * reach
    return demand * crowding + fan_bonus

static func units_for_week(
        project: GameProject, platform_popularity: float, trend_demand: float,
        install_base: int = 0) -> int:
    var week := project.weeks_on_market
    var units := 0

    if week == 0:
        units = maxi(int(project.current_demand * randf_range(0.9, 1.1)), 50)
    else:
        var previous := float(project.last_week_units())
        var factor := age_decay(week) * word_of_mouth_factor(project.word_of_mouth, week)
        factor *= living_market_factor(platform_popularity, trend_demand)
        units = maxi(int(previous * factor * randf_range(0.92, 1.08)), 0)

    return mini(units, remaining_audience(project, install_base))

## How much of the still-untouched audience a game can reach in any one week.
## The ceiling used to be a wall: a strong release sold flat out, hit exactly
## MAX_ATTACH_RATE and stopped, so unrelated hits finished on identical round
## numbers and quality stopped separating them at the top of the range.
const SATURATION_RATE := 0.32

static func remaining_audience(project: GameProject, install_base: int) -> int:
    ## How many machine owners are still realistically reachable this week. The
    ## last of an audience is the hardest to sell to, so a game approaches its
    ## ceiling rather than arriving at it.
    if install_base <= 0:
        return units_without_limit()
    var ceiling := float(install_base) * max_attach_for(install_base)
    var headroom := maxf(ceiling - float(project.lifetime_sales), 0.0)
    return maxi(int(headroom * SATURATION_RATE), 0)

static func units_without_limit() -> int:
    return 1 << 30

static func age_decay(week: int) -> float:
    ## Interest in any release fades; the drop is steepest early.
    return clampf(0.86 - float(week) * 0.012, 0.55, 0.86)

static func word_of_mouth_factor(wom: float, week: int) -> float:
    if wom >= 1.0:
        # Strong word of mouth can outrun decay for the first weeks.
        var fading := maxf(1.0 - float(week) * 0.14, 0.0)
        return 1.0 + (wom - 1.0) * (1.0 + 1.6 * fading)

    # Bad word of mouth compounds instead.
    return wom

static func living_market_factor(platform_popularity: float, trend_demand: float) -> float:
    ## The world keeps moving while a game is on sale.
    return clampf(0.75 + platform_popularity * 0.15 + trend_demand * 0.15, 0.75, 1.10)

static func should_leave_market(project: GameProject, units: int) -> bool:
    if project.weeks_on_market >= MAX_WEEKS_ON_MARKET:
        return true
    var launch := project.weekly_sales[0] if not project.weekly_sales.is_empty() else 0
    return units <= maxi(MIN_WEEKLY_UNITS, int(launch * 0.02))

static func net_revenue(units: int, price: int, royalty: float) -> int:
    return int(units * price * (1.0 - royalty))

static func fans_from_week(units: int, score: float, existing_fans: int = 0) -> int:
    ## Winning over the next slice of an audience gets harder the more of it a
    ## studio already holds -- otherwise units buy fans buy units, without end.
    ## A studio losing followers sheds them at full rate; only the winning is
    ## made harder.
    var raw := float(units) * (score - 5.0) * 0.02
    if raw <= 0.0:
        return int(raw)
    return int(raw * fan_gain_multiplier(existing_fans))
