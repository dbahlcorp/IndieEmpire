extends TestCase

## Guards SalesSimulator.QUALITY_ANCHOR against silent drift.
##
## This constant is the single lever on how rich the whole economy is -- sales
## go as the fourth power of it -- and it is calibrated by measurement, not by
## reasoning. It has already been wrong twice: it was a bare 10.0 assuming the
## old inflated review scale, and it was briefly reported as having regressed to
## 9.3. Nothing in the code stopped either, because a number in a constant looks
## as plausible as any other number.
##
## So this pins the value *and* the properties the tuning depends on, and says
## what to do about a failure rather than just that one happened. See
## docs/QUALITY_ANCHOR_2026-09-08.md.

## The measured tuning this suite is pinned to. Changing the constant without
## re-running the balance probe is the failure mode this exists to catch.
const DOCUMENTED_ANCHOR := 11.0
## Median review across an eight-seed measured career.
const COMPETENT_REVIEW := 7.3
## What that competent release sells at, as a share of full strength.
const COMPETENT_STRENGTH := 0.194

func run() -> void:
    _the_anchor_is_a_scale_not_a_target()
    _a_competent_release_sells_at_the_measured_strength()
    _the_anchor_scales_everything_equally()
    _steepness_belongs_to_the_exponent()
    _the_value_matches_the_documented_balance()

func _the_anchor_is_a_scale_not_a_target() -> void:
    section("the anchor sits above any score a release can actually print")
    # The invariant, and not an arbitrary one: the anchor is the score at which
    # a game would sell at full strength, and the design is that nothing ever
    # does. If it drops below the printable ceiling, the best releases start
    # selling at *over* full strength and the fourth-power curve runs away
    # exactly where it is least affordable.
    #
    # This is the check that catches the two values it has actually been wrong
    # at: 10.0 (the original) and 9.3, both under the 9.8 ceiling.
    var ceiling := ReviewSimulator.best_possible_score()
    check_greater(SalesSimulator.QUALITY_ANCHOR, ceiling,
        "anchor %.2f is above the best printable review %.2f"
            % [SalesSimulator.QUALITY_ANCHOR, ceiling])
    check_less(SalesSimulator.review_multiplier(ceiling), 1.0,
        "so even a perfect release sells under full strength (%.3f)"
            % SalesSimulator.review_multiplier(ceiling))

func _a_competent_release_sells_at_the_measured_strength() -> void:
    section("a competent release sells at the strength the economy is tuned for")
    # The economic calibration in one number. It moves if the anchor moves, if
    # the exponent moves, or if the review scale is renormalised again -- all
    # three of which require re-measuring the economy, and all three of which
    # this catches.
    var strength := SalesSimulator.review_multiplier(COMPETENT_REVIEW)
    check_near(strength, COMPETENT_STRENGTH, 0.01,
        "a %.1f release sells at %.3f of full strength" % [COMPETENT_REVIEW, strength])

func _the_anchor_scales_everything_equally() -> void:
    section("the anchor is a pure scale factor")
    # It shifts every score's multiplier by the same factor and changes no
    # relative outcome. Worth pinning because it is what makes the constant safe
    # to retune at all: it is the economy's volume knob, and nothing else.
    var baseline := SalesSimulator.QUALITY_ANCHOR
    var alternative := 9.3
    var scale := pow(baseline / alternative, SalesSimulator.QUALITY_EXPONENT)
    for score in [5.0, 6.5, 7.3, 8.0, 9.0]:
        var here := SalesSimulator.review_multiplier(score)
        var there := pow(score / alternative, SalesSimulator.QUALITY_EXPONENT)
        check_near(there / here, scale, 0.001,
            "score %.1f scales by the same factor as every other" % score)

func _steepness_belongs_to_the_exponent() -> void:
    section("how sharply quality drives sales is the exponent's job, not the anchor's")
    # A weak game must not quietly break even on a big platform. That gap is
    # owned by QUALITY_EXPONENT and is anchor-independent, so it is pinned
    # separately -- otherwise retuning the economy's richness could flatten the
    # incentive to make good games without anything noticing.
    var seven := SalesSimulator.review_multiplier(7.0)
    var eight := SalesSimulator.review_multiplier(8.0)
    var six := SalesSimulator.review_multiplier(6.0)
    check_near(eight / seven, 1.71, 0.02,
        "an 8.0 outsells a 7.0 by %.2fx" % (eight / seven))
    check_near(seven / six, 1.85, 0.02,
        "a 7.0 outsells a 6.0 by %.2fx" % (seven / six))
    check_greater(SalesSimulator.review_multiplier(9.0) / SalesSimulator.review_multiplier(5.0), 8.0,
        "and the span from a bad game to a great one is worth chasing")

func _the_value_matches_the_documented_balance() -> void:
    section("the value still matches the balance it was measured against")
    # Deliberately last, and deliberately blunt. The checks above cover the
    # properties; this one covers the number, because the properties alone
    # cannot tell 11.0 from 12.5 and the difference between those is roughly
    # double the studio's cash by 1996.
    check_near(SalesSimulator.QUALITY_ANCHOR, DOCUMENTED_ANCHOR, 0.001,
        "QUALITY_ANCHOR is %.2f, the value measured in "
        % SalesSimulator.QUALITY_ANCHOR
        + "docs/QUALITY_ANCHOR_2026-09-08.md. If this is a deliberate retune, "
        + "re-run the balance probe (8 seeds) and update the documented figures "
        + "and this test together -- final cash at 1996 was $120M at 9.3 and "
        + "$38M at 11.0, against a $45M target")
