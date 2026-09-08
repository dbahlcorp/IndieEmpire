class_name ReviewSimulator
extends RefCounted

## Reviewers judge a game against what its size promised, not against raw
## numbers, so a long project has to earn its extra development time.

const QUALITY_PER_WORK := 0.40
## The printed score can never leave this range, whatever the merit behind it.
## The floor is above zero because even a disaster is a game somebody finished;
## the ceiling is below 100 because a perfect game is not a thing.
##
## Other systems calibrate against the top of this range -- notably
## SalesSimulator.QUALITY_ANCHOR, which is meant to sit above it. Named so they
## can read it rather than each carrying their own copy of 9.8.
const MIN_SCORE := 25.0
const MAX_SCORE := 98.0

static func best_possible_score() -> float:
    ## The highest review a release can print, on the 0-10 scale players see.
    return MAX_SCORE / 10.0
## How much a spotless reputation raises the bar a game is measured against.
## Deliberately smaller than the goodwill it buys, so standing is still worth
## having -- it just stops being a free 1.7 points forever.
const EXPECTATION_FROM_STANDING := 0.11
## How far past its own size's quality bar a release can be credited for going.
##
## Tiny is the size this binds on, and it binds by design. Its bar is calibrated
## for the founder alone in a bedroom, because the opening of a career depends
## on those first games clearing it -- raising the bar to suit a properly
## staffed two-person team was measured, and it put solo releases at 3.9 and
## the studio never got off the ground. So a Tiny project built by two people
## over-delivers by construction, and this is what stops that reading as a 9.
##
## It no longer flattens them, though, which was the real complaint. It used to
## do the whole job alone: 70% of late Tiny releases pinned it and scored an
## identical 8.5. With scope absorption compressing the range at the source
## first, the ratio still clips but the rest of the merit -- bugs, polish,
## balance, compatibility -- still separates them: 41 late Tiny releases now
## land on 19 distinct scores between 5.6 and 9.0.
const OVER_DELIVERY_CAP := 1.30

static func calculate_review(project: GameProject) -> float:
    var size := DataManager.get_size(project.size_id)
    var work := maxf(float(size.get("work", 100)), 1.0)

    # What a competent team is expected to deliver at this size. Authored per
    # size because output multipliers do not scale evenly with work, and a flat
    # rule quietly under-scored every large project.
    var expected_quality := maxf(
        float(size.get("expected_quality", work * QUALITY_PER_WORK)), 1.0)

    # A studio is judged against its own reputation. Every goodwill bonus below
    # pins at its cap once consumer_reputation reaches 100 and never comes back
    # down, so without this the identical execution scored 1.7 higher for a
    # famous studio than an unknown one, permanently -- a measured career drifted
    # from 7.3 in its first decade to 9.1 and stayed there. Standing buys the
    # benefit of the doubt; it also raises what people expect for the money.
    expected_quality *= 1.0 + clampf(
        GameState.consumer_reputation, 0.0, 100.0) / 100.0 * EXPECTATION_FROM_STANDING

    var quality_ratio := project.average_quality() / expected_quality
    # Clearing your own size's bar by a third is already excellent; past that
    # the reviewers stop counting. See OVER_DELIVERY_CAP.
    var quality := clampf(quality_ratio, 0.0, OVER_DELIVERY_CAP) * 62.0

    var compatibility := _compatibility_bonus(project)
    var bug_penalty := minf(float(project.bugs) * 0.65, 18.0)
    var polish_bonus := minf(project.polish * 0.15 / float(size.get("quality_weight", 1.0)), 8.0)
    # A well-tuned game reads well regardless of how much raw content it has.
    var balance_bonus := minf(project.balance * 0.12 / float(size.get("quality_weight", 1.0)), 6.0)
    var experience_bonus := minf(GameState.consumer_reputation * 0.05, 3.0)
    # A famous name on the credits buys the benefit of the doubt too.
    var fame_bonus := minf(float(_credited_reputation(project)) * 0.04, 2.5)

    # Raw merit: what the project actually delivered, on an open-ended scale
    # where a competent studio lands near COMPETENT_MERIT and only a flawless
    # one approaches 130. This is *not* the review score -- see curve().
    var merit := (
        quality + compatibility + polish_bonus + balance_bonus + experience_bonus + fame_bonus
        - bug_penalty
    )
    # No size-based ceiling here on purpose: a tightly-scoped solo project that
    # actually hits its own quality bar deserves to read as a 9 or a 10, the
    # same as a big one does. What a small team cannot do is generate enough
    # raw quality across enough disciplines to clear a large project's much
    # higher bar in the first place -- that is expected_quality's job, and
    # team size earns capacity to reach it, not a higher score for the same
    # execution. See average_quality() and ProjectStaffSimulator.effects().
    var score_100 := curve(merit)
    # Critical reception is fickle. Applied *after* the curve so the spread
    # stays a real +/-0.4 review points instead of being flattened along with
    # everything else above the competent bar.
    score_100 += randf_range(-4.0, 4.0)
    score_100 = clampf(score_100, MIN_SCORE, MAX_SCORE)

    project.review_score = snappedf(score_100 / 10.0, 0.1)
    return project.review_score

## Raw merit a competent studio reliably delivers -- the measured median across
## an eight-seed career. Maps to COMPETENT_SCORE, so the middle of the
## distribution sits where "good, not remarkable" should.
const COMPETENT_MERIT := 75.0
const COMPETENT_SCORE := 72.0
## Where the curve is steepest, and the floor and span it runs between. Neither
## end is reachable: merit would have to be infinite. The floor sits above zero
## because even a disaster is a game somebody finished.
const CURVE_MIDPOINT := 64.0
const CURVE_FLOOR := 20.0
const CURVE_SPAN := 85.0
## How sharply the curve rises through its midpoint.
const CURVE_STEEPNESS := 0.041

static func curve(merit: float) -> float:
    ## Convert raw merit to a 0-100 review score with diminishing returns at
    ## both ends.
    ##
    ## Merit is open-ended. The old mapping read it straight off as the score,
    ## so a quarter of all releases scored 9+ and 7% pinned the ceiling exactly.
    ##
    ## A logistic bends it instead. Through the middle a point of merit is worth
    ## most of a point of score, so ordinary improvement pays properly. Above
    ## the competent bar the return decays, so the last stretch costs far more
    ## than the first: +14 merit over the bar buys about +10 score, the next +14
    ## buys +8, then +6, then +4. Reaching 9.6 takes roughly 125 merit -- every
    ## component at once, not one good project.
    ##
    ## It compresses the *bottom* too, and that matters as much. Once quality
    ## started accruing per unit of work completed rather than per week (see
    ## DevelopmentSimulator.QUALITY_PER_WORK_UNIT) a weak team produced a
    ## genuinely weak game instead of one flattered by taking a long time, and
    ## the merit spread roughly doubled. An exponential, which only bends at the
    ## top, turned that into 12% of releases sitting on the 2.5 floor. A curve
    ## with two shoulders keeps a bad game bad without making it a catastrophe.
    return CURVE_FLOOR + CURVE_SPAN / (
        1.0 + exp(-(merit - CURVE_MIDPOINT) * CURVE_STEEPNESS))

static func _credited_reputation(project: GameProject) -> int:
    ## The most famous name attached to this release, if any.
    var best := 0
    for employee_id in project.role_assignments.values():
        var employee := EmployeeManager.find_employee(str(employee_id))
        if employee != null:
            best = maxi(best, employee.reputation)
    return best

static func critic_scores(project: GameProject) -> Array[Dictionary]:
    var outlets := [
        "Pixel Monthly",
        "GameWorld",
        "Joystick Weekly",
        "Computer Player"
    ]

    var scores: Array[Dictionary] = []
    for outlet in outlets:
        scores.append({
            "outlet": outlet,
            "score": clampf(snappedf(project.review_score + randf_range(-0.7, 0.7), 0.1), 1.0, 10.0)
        })
    return scores

static func _compatibility_bonus(project: GameProject) -> float:
    var platform := DataManager.get_platform(project.platform_id)
    var audience: Dictionary = platform.get("audience", {})

    var theme_affinity := KnowledgeSimulator.true_compatibility(project.theme_id, project.genre_id)
    var platform_affinity := float(audience.get(project.genre_id, 1.0))
    var combined := (theme_affinity + platform_affinity) / 2.0

    return (combined - 1.0) * 30.0
