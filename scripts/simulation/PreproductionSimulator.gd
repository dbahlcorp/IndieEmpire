class_name PreproductionSimulator
extends RefCounted

## What planning actually buys, or costs. A designer, a writer, a producer and
## a lead programmer are the main contributors -- vision and design quality
## from the first two, scope clarity from the last two, all of it feeding one
## verdict on how clear the plan really was.

## Where a perfectly ordinary team lands -- a solo founder covering design
## and programming with nobody dedicated to writing or production. Anchoring
## here means a normal early studio is judged as normal, not as failing.
const BASELINE_EFFECTIVENESS := 0.75

const MAX_PENALTY := -0.12
const MAX_BONUS := 0.12
const SLOPE := 0.22

## How much of the one-time quality it earns for production to inherit.
const QUALITY_FLOOR := 0.25
const QUALITY_CEILING := 3.0

static func production_efficiency_modifier(effectiveness: float) -> float:
    ## What a plan this clear (or unclear) does to every week of production
    ## that follows. Neutral for an unremarkable team; only a genuinely thin
    ## pre-production, or a genuinely strong one, moves this at all.
    return clampf((effectiveness - BASELINE_EFFECTIVENESS) * SLOPE, MAX_PENALTY, MAX_BONUS)

static func quality_bonus(effectiveness: float) -> float:
    return clampf(effectiveness, QUALITY_FLOOR, QUALITY_CEILING)

static func label(modifier: float) -> String:
    ## Named only at the extremes -- most projects plan adequately and
    ## deserve no comment either way.
    if modifier <= -0.06:
        return "UNCLEAR DESIGN"
    if modifier >= 0.06:
        return "CLEAR VISION"
    return ""

static func description(label_text: String) -> String:
    match label_text:
        "UNCLEAR DESIGN":
            return "Nobody nailed down what this game actually was before production started."
        "CLEAR VISION":
            return "The plan was clear before a line of it was built."
        _:
            return ""
