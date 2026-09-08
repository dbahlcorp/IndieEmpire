extends TestCase

## Review scoring has no size-based ceiling: a small, tightly-scoped project
## that actually clears its own quality bar can read as a 9 or a 10, same as
## a big one. What a small team cannot do is generate enough raw quality
## across enough disciplines to clear a *large* project's much higher bar --
## that is where team size earns its keep. Capacity, not ceiling.

const QUALITY_FIELDS := [
    "gameplay", "technology", "graphics", "story", "sound",
    "innovation", "polish", "performance", "narrative_quality"
]

func run() -> void:
    _no_size_has_a_ceiling_left_in_the_data()
    _the_curve_has_diminishing_returns()
    _a_solo_project_can_score_a_masterpiece()
    _equal_execution_scores_equally_regardless_of_size()
    _the_same_output_is_a_masterpiece_small_and_mediocre_large()
    _the_universal_floor_and_ceiling_still_apply()

func _the_curve_has_diminishing_returns() -> void:
    section("merit converts to score with diminishing returns, not one-for-one")
    var bar := ReviewSimulator.COMPETENT_MERIT
    check_near(ReviewSimulator.curve(bar), ReviewSimulator.COMPETENT_SCORE, 0.01,
        "competent work lands on the competent score")

    # The point of the whole exercise: each equal step of merit above the bar
    # has to buy strictly less score than the step before it, so 90+ merit
    # means "eligible for greatness" rather than "automatically a 9".
    var steps: Array[float] = []
    for i in range(4):
        var low := ReviewSimulator.curve(bar + 14.0 * i)
        var high := ReviewSimulator.curve(bar + 14.0 * (i + 1))
        steps.append(high - low)
    for i in range(steps.size() - 1):
        check_less(steps[i + 1], steps[i],
            "merit step %d buys less than step %d (%.2f < %.2f)"
                % [i + 2, i + 1, steps[i + 1], steps[i]])
    check_greater(steps[0], 8.0,
        "but the first step still pays properly (%.2f)" % steps[0])

    # Monotonic, so more merit is never worse, and the top of the practical
    # merit range still has somewhere to go: a landmark game has to be able to
    # read as one, it just has to be nearly perfect to get there.
    var previous := -INF
    for merit in range(20, 140, 5):
        var score := ReviewSimulator.curve(float(merit))
        check_greater(score, previous, "curve rises through merit %d" % merit)
        previous = score
    check_between(ReviewSimulator.curve(130.0), 95.0, 98.0,
        "a flawless release reaches the landmark band (%.1f)"
            % ReviewSimulator.curve(130.0))
    check_less(ReviewSimulator.curve(95.0), 85.0,
        "but merit well past the bar is still only an 8 (%.1f)"
            % ReviewSimulator.curve(95.0))

func _project(size_id: String, quality: float, polish: float, balance: float) -> GameProject:
    var project := GameProject.new()
    project.size_id = size_id
    project.genre_id = "fantasy"
    project.theme_id = "adventure"
    project.platform_id = "microstar_64"
    for field in QUALITY_FIELDS:
        project.set(field, quality)
    project.polish = polish
    project.balance = balance
    return project

func _average_score(build: Callable, trials: int = 40) -> float:
    ## calculate_review() adds +/-4 noise; averaging trials cancels it out so
    ## the checks are about the formula, not one unlucky roll.
    var total := 0.0
    for i in trials:
        total += ReviewSimulator.calculate_review(build.call())
    return total / float(trials)

func _bar(size_id: String) -> float:
    ## A size's expected_quality, read from the data rather than written down
    ## here. These fixtures used to carry the numbers inline, so retuning the
    ## quality bars broke the test even though the rule it checks still held.
    return maxf(float(DataManager.get_size(size_id).get("expected_quality", 100)), 1.0)

func _clearing_the_bar_by(size_id: String, margin: float, polish: float, balance: float) -> GameProject:
    ## A project of this size whose every quality field sits `margin` times its
    ## size's own bar -- so "the same relative execution" means the same number
    ## at every size, whatever the bars happen to be.
    return _project(size_id, _bar(size_id) * margin, polish, balance)

func _no_size_has_a_ceiling_left_in_the_data() -> void:
    section("the data has nothing left to cap a score by size")
    for size in DataManager.sizes:
        check(not size.has("max_score"), "%s carries no max_score" % size.get("id", "?"))

func _a_solo_project_can_score_a_masterpiece() -> void:
    section("a tightly-scoped project that clears its own bar reads as a masterpiece")
    GameState.consumer_reputation = 0.0
    # Comfortably past small's own bar -- the ratio clamps at 1.6, so this is
    # as good as the quality component alone can score.
    var average := _average_score(func(): return _clearing_the_bar_by("small", 1.83, 55.0, 70.0))
    check_greater(average, 8.5,
        "a well-executed small project reads as a genuine 9 (%.2f)" % average)

func _equal_execution_scores_equally_regardless_of_size() -> void:
    section("the same relative execution scores the same at any size")
    GameState.consumer_reputation = 0.0
    # Each comfortably clears its own size's expected_quality by the same
    # margin, so the quality component -- and so the final score -- should
    # land in the same place either way.
    var small := _average_score(func(): return _clearing_the_bar_by("small", 1.83, 55.0, 70.0))
    var large := _average_score(func(): return _clearing_the_bar_by("large", 1.83, 711.0, 800.0))
    # Averaged over 40 noisy trials, so these land near each other rather than
    # on each other. This used to be check_approx() and passed only because
    # both sides pinned the old 9.8 ceiling exactly -- float equality was
    # measuring the clamp, not the rule. See TestCase.check_near().
    check_near(small, large, 0.15,
        "small at %.2f, large at %.2f -- no size-shaped ceiling between them" % [small, large])

func _the_same_output_is_a_masterpiece_small_and_mediocre_large() -> void:
    section("what a small team can actually produce: brilliant when scoped to fit, mediocre when not")
    GameState.consumer_reputation = 0.0
    # A fixed amount of raw quality -- what a small team can plausibly turn
    # out -- clears a small project's bar with room to spare, and falls well
    # short of a large one's.
    var raw_quality := 100.0
    var scoped_right := _average_score(func(): return _project("small", raw_quality, 60.0, 60.0))
    var overreached := _average_score(func(): return _project("large", raw_quality, 60.0, 60.0))

    check_greater(scoped_right, 8.0,
        "scoped to what the team can deliver, it is a hit (%.2f)" % scoped_right)
    check_less(overreached, 5.0,
        "the identical output, attempted at a scale the team cannot fill, is not (%.2f)" % overreached)
    check_greater(scoped_right - overreached, 3.0,
        "the gap is the whole point: capacity, not a hand-me-down score")

func _the_universal_floor_and_ceiling_still_apply() -> void:
    section("a floor and a ceiling still exist -- they just do not depend on size")
    GameState.consumer_reputation = 0.0
    var project := _project("aaa", 5000.0, 5000.0, 5000.0)
    project.bugs = 0
    var maxed := _average_score(func(): return project)
    check_less(maxed, 9.9, "even an absurd input cannot clear the universal ceiling")

    var wreck := _project("small", 0.0, 0.0, 0.0)
    wreck.bugs = 200
    var floored := _average_score(func(): return wreck)
    check_greater(floored, 1.5, "and nothing can score below the universal floor")
