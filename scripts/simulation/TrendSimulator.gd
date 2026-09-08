class_name TrendSimulator
extends RefCounted

## How genre popularity drifts, and how a raw multiplier reads to a player.
## The player never sees the number itself.

const PERIOD_WEEKS := 12
const MIN := 0.60
const MAX := 1.60
const DRIFT := 0.28

static func starting_trend() -> float:
    return randf_range(0.85, 1.15)

static func drift(current: float) -> float:
    return clampf(current + randf_range(-DRIFT, DRIFT), MIN, MAX)

static func label(trend: float) -> String:
    if trend >= 1.32:
        return "Very Popular"
    if trend >= 1.12:
        return "Popular"
    if trend >= 0.92:
        return "Stable"
    if trend >= 0.75:
        return "Declining"
    return "Unpopular"

static func marker(trend: float) -> String:
    if trend >= 1.32:
        return "!!"
    if trend >= 1.12:
        return "^"
    if trend >= 0.92:
        return "-"
    if trend >= 0.75:
        return "v"
    return "x"
