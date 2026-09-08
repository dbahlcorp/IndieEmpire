class_name ReviewSimulator
extends RefCounted

## Reviewers judge a game against what its size promised, not against raw
## numbers, so a long project has to earn its extra development time.

const QUALITY_PER_WORK := 0.40
## How much a spotless reputation raises the bar a game is measured against.
## Deliberately smaller than the goodwill it buys, so standing is still worth
## having -- it just stops being a free 1.7 points forever.
const EXPECTATION_FROM_STANDING := 0.11

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
    var quality := clampf(quality_ratio, 0.0, 1.6) * 62.0

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
    score_100 = clampf(score_100, 25.0, 98.0)

    project.review_score = snappedf(score_100 / 10.0, 0.1)
    return project.review_score

## Raw merit a competent studio reliably delivers -- the measured median across
## an eight-seed career. Maps to COMPETENT_SCORE, so the middle of the
## distribution sits where "good, not remarkable" should.
const COMPETENT_MERIT := 77.0
const COMPETENT_SCORE := 72.0
## What merit asymptotically approaches but never reaches. Deliberately above
## the 98 display ceiling: if the curve levelled off at 100 the top two points
## would flatten into each other and 9.5 would read the same as a landmark.
const UNREACHABLE_SCORE := 108.0
## Conversion rate *at* the competent bar. Near the middle a point of merit is
## still worth most of a point of score, so ordinary improvement pays; the
## curve then bends away on its own.
const COMPETENT_RETURN := 0.85

static func curve(merit: float) -> float:
    ## Convert raw merit to a 0-100 review score with diminishing returns.
    ##
    ## Merit is open-ended and clusters tightly: a mature studio turning out
    ## competent work sits around 77, and everything from "solid" to "landmark"
    ## was crammed into the 85-125 band. The old mapping read merit straight off
    ## as the score, so that band became 8.5 to 9.8 -- a quarter of all releases
    ## scored 9+ and 7% pinned the ceiling exactly.
    ##
    ## This bends it instead. Around the competent bar a point of merit is worth
    ## COMPETENT_RETURN of a point, so climbing out of the 5s and 6s still pays
    ## properly. Past it the return decays smoothly towards nothing, so the last
    ## stretch costs far more than the first: +14 merit over the bar buys about
    ## +7 score, the next +14 buys about +4, and the next only +2. Reaching 9.6
    ## takes roughly 120 merit -- every component at once, not one good project.
    ##
    ## Exponential rather than a straight knee because a knee either flattens
    ## the 8s (too steep) or leaves the 9s free (too shallow); the measured
    ## merit spread needs the return to keep falling all the way up.
    var head := UNREACHABLE_SCORE - COMPETENT_SCORE
    return UNREACHABLE_SCORE - head * exp(-(merit - COMPETENT_MERIT) * COMPETENT_RETURN / head)

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
