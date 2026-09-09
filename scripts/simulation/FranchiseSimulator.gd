class_name FranchiseSimulator
extends RefCounted

## Entry kinds within a franchise. "original" and "sequel" are the two the
## simulation actually distinguishes today; the rest are reserved so a save and
## the model already carry the vocabulary when PA-later builds their mechanics.
const ENTRY_KINDS := ["original", "sequel", "remake", "remaster", "spinoff", "expansion"]

## Pure maths for sequels and franchises (PA.10). Holds no state; every function
## takes a Franchise (or plain numbers) and returns a number, a label or a
## short string. FranchiseManager owns the state and decides when to call.
##
## The design brief this is tuned to: a sequel to a successful series should
## feel worth making, but must never be an automatic money printer. So the
## benefits are mostly demand-side and small on the craft side, while the review
## bar the entry is judged against genuinely rises with the franchise's
## standing -- and against SalesSimulator.QUALITY_EXPONENT (5.5) a higher bar is
## a real cost. On top of that, shipping entries close together accumulates
## fatigue that eventually drags a rushed series' launch demand *below* what a
## brand-new IP would have opened to. A patient series keeps a modest tailwind;
## a milked one does not. FranchiseEconomyTest pins the no-runaway property, the
## same way EconomyPlateauTest does for the career as a whole.

# --- Sequel benefits -------------------------------------------------------

## Most a fully-hyped franchise adds to a sequel's launch demand. Large enough
## that a timely, well-made sequel to a loved series clearly out-opens a fresh
## idea -- but see FATIGUE_DEMAND_PENALTY, which can reach further, so a milked
## series ends up the worse bet.
const FAN_INTEREST_DEMAND_REACH := 0.45
## Most the reused design knowledge of a long-running series lifts a sequel's
## production quality. Tiny -- the series bar rises faster than this (see
## expectation_multiplier), which is the point.
const DESIGN_KNOWLEDGE_QUALITY_MAX := 0.05
## Most a team's familiarity with a series' own systems speeds its production.
const TEAM_FAMILIARITY_SPEED_MAX := 0.05
## Entries of prior work at which the two bonuses above saturate.
const KNOWLEDGE_SATURATION_ENTRIES := 3.0

# --- Sequel risks --------------------------------------------------------

## Most a spotless franchise reputation raises the quality bar its next entry is
## measured against. Applied on top of ReviewSimulator's own standing-based
## expectation bump, multiplicative with expected_quality, and -- against
## SalesSimulator's steep quality curve -- a real cost. Scaled by how long the
## series has run (see expectation_multiplier): a one-hit series is barely held
## to a standard yet; a long-running institution is held to a high one.
const EXPECTATION_RAISE_MAX := 0.12
## Entries of history at which the expectation bar is fully raised.
const EXPECTATION_MATURITY_ENTRIES := 3.0
## Most accumulated fatigue takes off a sequel's launch demand.
const FATIGUE_DEMAND_PENALTY := 0.45
## Innovation multiplier for a sequel that follows its predecessor immediately.
## A series that never changes gets stale; three years apart it is fully novel
## again.
const NOVELTY_FLOOR := 0.72
const NOVELTY_FULL_WEEKS := 156.0
## A disappointing sequel is also compared unfavourably to what came before.
## Worst-case word-of-mouth multiplier for an entry well below its series'
## standing.
const COMPARISON_WOM_FLOOR := 0.90

# --- Fatigue dynamics --------------------------------------------------

## Fatigue a same-year follow-up adds before innovation relief. Sized so that a
## series shipped roughly annually accumulates fatigue faster than the gap
## clears it, but a three-to-four-year cadence stays rested -- see
## FranchiseEconomyTest, which measures exactly that.
const FATIGUE_PER_FAST_RELEASE := 55.0
## Gap at which a new entry adds essentially no fatigue -- the audience has had
## a proper rest from the series (five years).
const FATIGUE_GAP_RELIEF_WEEKS := 260.0
## How much fatigue bleeds off per week of no new entry (~4.8 years to clear a
## fully exhausted franchise).
const FATIGUE_DECAY_PER_WEEK := 0.40
## How much a genuinely innovative entry (innovation well above its size's bar)
## can cut the fatigue it would otherwise add.
const FATIGUE_INNOVATION_RELIEF := 0.5

# --- Fan interest dynamics -------------------------------------------

const FAN_INTEREST_DECAY_PER_WEEK := 0.22
## Fan interest never falls below this share of the franchise's reputation --
## a beloved series keeps real pull even after a long silence, which is what
## makes reviving a dormant IP worthwhile.
const FAN_INTEREST_REPUTATION_FLOOR := 0.28

# =====================================================================
# Launch demand
# =====================================================================

static func launch_demand_multiplier(franchise: Franchise) -> float:
    ## The net franchise effect on a sequel's opening demand. Can be above 1
    ## (a rested, anticipated series) or below it (a fatigued, over-milked one).
    if franchise == null:
        return 1.0
    var interest := clampf(franchise.fan_interest, 0.0, 100.0) / 100.0
    var fat := clampf(franchise.fatigue, 0.0, 100.0) / 100.0
    var net := 1.0 + FAN_INTEREST_DEMAND_REACH * interest - FATIGUE_DEMAND_PENALTY * fat
    return clampf(net, 1.0 - FATIGUE_DEMAND_PENALTY, 1.0 + FAN_INTEREST_DEMAND_REACH)

# =====================================================================
# Review expectations
# =====================================================================

static func expectation_multiplier(franchise: Franchise) -> float:
    ## What a sequel's quality bar is multiplied by, on top of the studio-wide
    ## standing bump ReviewSimulator already applies. 1.0 for a standalone game
    ## or a franchise with no track record yet.
    if franchise == null or franchise.entry_count() < 1:
        return 1.0
    var maturity := clampf(
        float(franchise.entry_count()) / EXPECTATION_MATURITY_ENTRIES, 0.0, 1.0)
    return 1.0 + EXPECTATION_RAISE_MAX * clampf(
        franchise.reputation, 0.0, 100.0) / 100.0 * maturity

# =====================================================================
# Production bonuses
# =====================================================================

static func _knowledge_scale(prior_entries: int) -> float:
    return clampf(float(prior_entries) / KNOWLEDGE_SATURATION_ENTRIES, 0.0, 1.0)

static func design_knowledge_quality_bonus(franchise: Franchise) -> float:
    ## Additive multiplier on every quality stat earned during production.
    if franchise == null:
        return 0.0
    var prior := franchise.entry_count()
    if prior < 1:
        return 0.0
    var reputation_scale := clampf(franchise.reputation / 70.0, 0.0, 1.0)
    return DESIGN_KNOWLEDGE_QUALITY_MAX * _knowledge_scale(prior) * reputation_scale

static func team_familiarity_speed_bonus(franchise: Franchise) -> float:
    ## Additive multiplier on weekly production progress.
    if franchise == null or franchise.entry_count() < 1:
        return 0.0
    return TEAM_FAMILIARITY_SPEED_MAX * _knowledge_scale(franchise.entry_count())

static func novelty_multiplier(weeks_since_last: int) -> float:
    ## Innovation earned by a sequel, scaled down when it follows its
    ## predecessor too quickly.
    if weeks_since_last <= 0:
        return NOVELTY_FLOOR
    return clampf(
        NOVELTY_FLOOR + (1.0 - NOVELTY_FLOOR) * (float(weeks_since_last) / NOVELTY_FULL_WEEKS),
        NOVELTY_FLOOR, 1.0)

# =====================================================================
# Word of mouth -- comparison against previous entries
# =====================================================================

static func word_of_mouth_multiplier(review_score: float, franchise: Franchise) -> float:
    ## A sequel that reviews below its series' established standing is talked
    ## about worse than its raw score alone would suggest. Above the bar, no
    ## bonus -- a franchise does not get to coast.
    if franchise == null or franchise.entry_count() < 1:
        return 1.0
    var bar := clampf(franchise.reputation, 0.0, 100.0) / 10.0
    if review_score >= bar:
        return 1.0
    var shortfall := clampf((bar - review_score) / 2.5, 0.0, 1.0)
    return lerpf(1.0, COMPARISON_WOM_FLOOR, shortfall)

# =====================================================================
# State transitions on release
# =====================================================================

static func fatigue_from_release(
        current_fatigue: float, weeks_since_last: int, innovation_ratio: float) -> float:
    ## New fatigue level after shipping an entry. innovation_ratio is the
    ## entry's innovation over its size's expected bar (1.0 == on the bar).
    var gap_factor := clampf(
        1.0 - float(weeks_since_last) / FATIGUE_GAP_RELIEF_WEEKS, 0.0, 1.0)
    var added := FATIGUE_PER_FAST_RELEASE * gap_factor
    var relief := clampf(innovation_ratio - 1.0, 0.0, 1.0) * FATIGUE_INNOVATION_RELIEF
    added *= 1.0 - relief
    return clampf(current_fatigue + added, 0.0, 100.0)

static func fatigue_after_week(current_fatigue: float) -> float:
    return maxf(current_fatigue - FATIGUE_DECAY_PER_WEEK, 0.0)

static func fan_interest_from_release(
        current: float, review_score: float, franchise_average_before: float,
        prior_entries: int) -> float:
    ## Anticipation after an entry ships. A strong game builds it; a weak one
    ## burns it. From the second entry on, how it compares to the series so far
    ## matters as much as its absolute score.
    var delta := (review_score - 6.0) * 12.0
    if prior_entries > 0:
        delta += (review_score - franchise_average_before) * 8.0
    return clampf(current + delta, 0.0, 100.0)

static func fan_interest_after_week(current: float, reputation: float) -> float:
    var floor_value := clampf(reputation, 0.0, 100.0) * FAN_INTEREST_REPUTATION_FLOOR
    return maxf(current - FAN_INTEREST_DECAY_PER_WEEK, floor_value)

static func reputation_from_release(
        current: float, review_score: float, prior_entries: int) -> float:
    var target := clampf(review_score * 10.0, 0.0, 100.0)
    if prior_entries <= 0:
        return target
    return clampf(lerpf(current, target, 0.45), 0.0, 100.0)

# =====================================================================
# Labels and player-facing copy
# =====================================================================

static func fan_interest_label(value: float) -> String:
    if value >= 75.0:
        return "Feverish"
    if value >= 50.0:
        return "High"
    if value >= 25.0:
        return "Warm"
    if value >= 8.0:
        return "Cooling"
    return "Faded"

static func fatigue_label(value: float) -> String:
    if value >= 70.0:
        return "Exhausted"
    if value >= 45.0:
        return "Strained"
    if value >= 22.0:
        return "Noticeable"
    if value >= 8.0:
        return "Slight"
    return "Rested"

static func reputation_label(value: float) -> String:
    if value >= 85.0:
        return "Legendary"
    if value >= 70.0:
        return "Beloved"
    if value >= 55.0:
        return "Respected"
    if value >= 40.0:
        return "Established"
    if value >= 25.0:
        return "Shaky"
    return "Troubled"

static func sequel_outlook(franchise: Franchise) -> Array:
    ## Short "what a sequel would inherit" bullets for the greenlight screen.
    ## Only meaningful once the franchise has a released entry.
    var out: Array = []
    if franchise == null or franchise.entry_count() < 1:
        return out
    var demand := launch_demand_multiplier(franchise)
    var demand_pct := int(round((demand - 1.0) * 100.0))
    if demand_pct > 0:
        out.append("Established audience: launch demand about %+d%%" % demand_pct)
    elif demand_pct < 0:
        out.append("Franchise fatigue: launch demand about %d%%" % demand_pct)
    var expectation := int(round((expectation_multiplier(franchise) - 1.0) * 100.0))
    if expectation > 0:
        out.append("Higher expectations: reviewers judge it about %d%% harder" % expectation)
    var quality := int(round(design_knowledge_quality_bonus(franchise) * 100.0))
    if quality > 0:
        out.append("Reused design knowledge: +%d%% production quality" % quality)
    var speed := int(round(team_familiarity_speed_bonus(franchise) * 100.0))
    if speed > 0:
        out.append("Team familiarity: +%d%% production speed" % speed)
    var gap := franchise.weeks_since_last_release()
    var novelty := int(round((1.0 - novelty_multiplier(gap)) * 100.0))
    if novelty > 0:
        out.append("Coming soon after the last entry: -%d%% innovation" % novelty)
    return out

static func postmortem_note(project: GameProject, franchise: Franchise) -> String:
    ## One short paragraph explaining how the sequel's franchise standing
    ## shaped its performance. Assumes project.sequel_number > 1.
    if franchise == null:
        return ""
    var lines: Array[String] = []
    lines.append("%s is entry %d in the %s series." % [
        project.title, project.sequel_number, franchise.name])

    var demand := launch_demand_multiplier(franchise)
    if demand >= 1.03:
        lines.append("An established, anticipated audience gave it a stronger launch than a new game would have opened to.")
    elif demand <= 0.97:
        lines.append("Franchise fatigue held its launch back -- the series has been shipping too often for the audience to stay hungry for it.")
    else:
        lines.append("The franchise neither carried nor hurt its launch much either way.")

    var bar := clampf(franchise.reputation, 0.0, 100.0) / 10.0
    if project.review_score + 0.05 < bar:
        lines.append("Reviewers measured it against the series' own standard (about %.1f) and found it wanting." % bar)
    elif project.review_score > bar + 0.3:
        lines.append("It cleared the bar the earlier entries set, which is what a sequel has to do to be worth making.")

    if franchise.fatigue >= 45.0:
        lines.append("The series is badly overworked -- time away from it is the only thing that brings the audience back.")
    return "\n".join(lines)
