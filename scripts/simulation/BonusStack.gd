class_name BonusStack
extends RefCounted

## Bounded, additive stacking for the project modifiers.
##
## The studio has a lot of independent positive systems -- genre, theme and
## platform knowledge, team chemistry, morale, traits, equipment, office
## comfort, producer and lead coordination, engine features, culture, the
## pre-production plan. Each is small and reasonable on its own. They used to
## multiply into the same number, and a product of small reasonable things is
## not a small reasonable thing:
##
##     founder, bedroom, no XP        x0.93   (-7.5%)
##     mid-career studio              x2.07  (+107%)
##     maxed studio, every system     x4.15  (+315%)
##
## measured by artifacts/bonus-stack-2026-09-08/StackProbe.gd. That is the
## runaway: nothing was individually wrong, and the total was absurd.
##
## So bonuses are sorted into categories, each category is capped, the
## categories are added rather than multiplied, and the sum is capped again.
## A studio that has invested in everything is meaningfully better than one
## that has not -- about +40% rather than +315%.
##
## What deliberately does NOT come through here:
##
## - **Capacity.** Team size (`team_output_multiplier`) is how much work the
##   studio can take on, not a bonus on top of it. Twelve people really should
##   out-produce one by several times.
## - **Core competence.** An employee's skill, attributes and accumulated
##   experience are the thing the player invests in most directly. Capping
##   those at a few percent would make senior hires pointless.
## - **Penalties.** Overload, understaffing, crowding, bad condition and a
##   crowded release slate stay multiplicative and uncapped. Only the upside
##   is bounded -- a studio doing everything wrong should feel all of it.
## - **Trade-offs.** Theme/genre compatibility and the development focus give
##   with one hand and take with the other, so they are not stacking bonuses
##   and are applied directly.

const KNOWLEDGE := "knowledge"
const TEAM := "team"
const FACILITIES := "facilities"
const STRATEGY := "strategy"
const META := "meta"

## Per-category ceilings. Within a category the parts add, so two knowledge
## sources at +8% each come to +8% total, not +16.6%.
const CATEGORY_CAP := {
    KNOWLEDGE: 0.08,
    TEAM: 0.10,
    FACILITIES: 0.08,
    STRATEGY: 0.10,
    META: 0.05
}

## Ceiling on everything at once. Set at the sum of the category caps, so a
## studio that has genuinely maxed every category reaches it and nothing beyond
## it. Normal development lands around +25% to +30%.
const TOTAL_CAP := 0.41
## Floor on everything at once, so a run of bad luck cannot invert output.
const TOTAL_FLOOR := -0.60

static func combine(parts: Dictionary) -> float:
    ## `parts` maps a category to an array of plain multipliers (1.08 for +8%).
    ## Returns a single multiplier to apply in their place.
    var total := 0.0
    for category in parts:
        var amount := 0.0
        for multiplier in parts[category]:
            amount += float(multiplier) - 1.0
        total += cap_for(str(category), amount)
    return 1.0 + clampf(total, TOTAL_FLOOR, TOTAL_CAP)

static func cap_for(category: String, amount: float) -> float:
    ## Penalties are not capped. A category that has gone negative -- no
    ## workstations, miserable staff, a room too small for the team -- passes
    ## through at full weight; only the upside is bounded.
    if amount <= 0.0:
        return amount
    return minf(amount, float(CATEGORY_CAP.get(category, TOTAL_CAP)))
