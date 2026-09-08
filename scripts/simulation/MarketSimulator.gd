class_name MarketSimulator
extends RefCounted

## Pure demand maths: how trend and saturation combine, and how flooding a genre
## with your own releases wears the audience down.

## Saturation has to fade slower than the player can ship, or flooding one
## genre costs nothing. A release is felt for roughly a year.
const SATURATION_DECAY := 0.985
const SATURATION_PER_RELEASE := 0.30
const SATURATION_MAX := 0.75
const MIN_DEMAND := 0.12

static func demand(trend: float, saturation: float) -> float:
    ## What the market is actually willing to absorb right now.
    return maxf(trend * (1.0 - saturation), MIN_DEMAND)

static func add_saturation(current: float, size_weight: float = 1.0) -> float:
    ## A bigger release floods the genre harder.
    return minf(current + SATURATION_PER_RELEASE * size_weight, SATURATION_MAX)

static func decay_saturation(current: float) -> float:
    return current * SATURATION_DECAY

static func saturation_label(saturation: float) -> String:
    if saturation >= 0.50:
        return "Heavily saturated"
    if saturation >= 0.28:
        return "Saturated"
    if saturation >= 0.10:
        return "Slightly crowded"
    return ""
