class_name QASimulator
extends RefCounted

## What the studio actually knows about its own bugs. A project's true bug
## count is never shown directly -- only what QA has found, and how much that
## can be trusted. Skipping QA is legal. It is just a gamble the player takes
## with their eyes open, or should.

## Discovery -----------------------------------------------------------

static func discovery_rate(testing_effectiveness: float, polishing: bool = false) -> float:
    ## Fraction of the still-hidden gap QA turns up this week. Even a great
    ## tester never sees everything in one pass; even nobody assigned still
    ## stumbles onto something eventually.
    var rate := 0.10 + testing_effectiveness * 0.28
    if polishing:
        # Dedicated testing time, not testing squeezed in around everything
        # else.
        rate += 0.15
    return clampf(rate, 0.08, 0.85)

static func discovered_this_week(gap: int, rate: float) -> int:
    if gap <= 0:
        return 0
    var found := int(round(float(gap) * rate * randf_range(0.75, 1.25)))
    return clampi(found, 0, gap)

static func confidence_label(rate: float) -> String:
    ## How much the known count can be trusted -- not the count itself.
    if rate >= 0.55:
        return "High"
    if rate >= 0.32:
        return "Medium"
    if rate >= 0.15:
        return "Low"
    return "Very Low"

## Fixing and regressions ------------------------------------------------

static func regression_rate(testing_effectiveness: float) -> float:
    ## The chance any one fix quietly breaks something else. Never zero --
    ## nothing is ever perfectly safe -- but a strong tester keeps it small.
    return clampf(0.22 - testing_effectiveness * 0.09, 0.02, 0.22)

static func roll_regressions(fixed: int, rate: float) -> int:
    var regressions := 0
    for i in fixed:
        if randf() < rate:
            regressions += 1
    return regressions

## What the player is told --------------------------------------------

static func launch_stability_label(known_bugs: int, rate: float) -> String:
    ## Not the truth. Just how much to trust the number on screen.
    var risk := float(known_bugs)
    match confidence_label(rate):
        "Very Low":
            risk += 6.0
        "Low":
            risk += 3.0
        "Medium":
            risk += 1.0

    if risk <= 2.0:
        return "Looking Solid"
    if risk <= 5.0:
        return "Reasonable"
    if risk <= 9.0:
        return "Risky"
    return "At Risk"
