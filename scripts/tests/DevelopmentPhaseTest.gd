extends TestCase

## Pre-Production -> Production -> Polish. Different disciplines carry each
## one, and nothing in a later phase starts before the one before it finishes.

func run() -> void:
    _starts_in_preproduction()
    _production_waits_its_turn()
    _preproduction_then_production()
    _different_people_matter_in_each_phase()
    _good_planning_pays_off()
    _efficiency_modifier_bounds()
    _poor_preproduction_penalizes_production()
    _strong_preproduction_helps_production()
    _flaw_is_announced()
    _an_ordinary_plan_is_not_news()
    _polish_percent_is_a_display_target_not_a_gate()
    _polish_improves_its_four_named_outcomes()
    _polish_contributors_are_qa_programmers_artists_designers()
    _balance_is_a_bonus_not_a_dilution()
    _preproduction_costs_less_than_a_full_production_week()
    _phase_labels()
    _focus_choices_have_real_tradeoffs()
    _focus_choices_persist()
    _persistence()
    _balance_persists()
    _old_saves_are_not_sent_back_to_preproduction()

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(400_000, Ledger.Kind.OTHER, "seed")
    OfficeManager.move_to("shared_workspace")

func _hire(role: String, seniority: String = "senior") -> Employee:
    var candidate := EmployeeManager.generate_candidate(role, seniority)
    GameState.labor_candidates.append(candidate)
    LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)
    return candidate

func _starts_in_preproduction() -> void:
    section("a new project starts in pre-production")
    _company()
    var project := DevelopmentSimulator.start_project(
        "New", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return
    check_equal(project.current_phase(), "pre_production", "it begins in pre-production")
    check_equal(project.phase_label(), "PRE-PRODUCTION", "and reads that way")
    check_equal(project.preproduction_progress, 0.0, "with nothing done yet")
    check_equal(project.development_progress, 0.0, "and production has not started")

func _production_waits_its_turn() -> void:
    section("production does not start early")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Waits", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return

    var guard := 0
    while project.preproduction_progress < 100.0 and guard < 40:
        guard += 1
        TimeManager.advance_week()
        check_equal(project.development_progress, 0.0,
            "production stays at zero while pre-production runs (week %d)" % guard)
        check_equal(project.bugs_created, 0, "and nothing has been built yet to have bugs")
    check(project.preproduction_progress >= 100.0, "pre-production actually finished (%d weeks)" % guard)

func _preproduction_then_production() -> void:
    section("then production takes over")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Handoff", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return

    var guard := 0
    while project.current_phase() == "pre_production" and guard < 40:
        guard += 1
        TimeManager.advance_week()
    check_equal(project.current_phase(), "production", "the phase changes on its own")

    TimeManager.advance_week()
    check_greater(project.development_progress, 0.0, "and production actually moves now")

func _different_people_matter_in_each_phase() -> void:
    section("different employees matter more in each phase")

    # Art and audio carry production -- one of its five named contributors
    # each -- but neither has any term in pre-production's formula at all.
    var weak_artist := Employee.new()
    weak_artist.id = "artist"
    weak_artist.art = 10
    var strong_artist := Employee.new()
    strong_artist.id = "artist"
    strong_artist.art = 95
    var with_weak_artist := ProjectStaffSimulator.effects(
        {"artist": weak_artist.id}, [weak_artist], {weak_artist.id: 45}, 0)
    var with_strong_artist := ProjectStaffSimulator.effects(
        {"artist": strong_artist.id}, [strong_artist], {strong_artist.id: 45}, 0)

    check_greater(
        float(with_strong_artist["progress"]), float(with_weak_artist["progress"]),
        "a stronger artist speeds up production")
    check_approx(
        float(with_strong_artist["preproduction_progress"]), float(with_weak_artist["preproduction_progress"]),
        "but makes no difference to pre-production -- there is nothing to draw yet")

    var weak_audio := Employee.new()
    weak_audio.id = "audio"
    weak_audio.audio = 10
    var strong_audio := Employee.new()
    strong_audio.id = "audio"
    strong_audio.audio = 95
    var with_weak_audio := ProjectStaffSimulator.effects(
        {"audio_designer": weak_audio.id}, [weak_audio], {weak_audio.id: 30}, 0)
    var with_strong_audio := ProjectStaffSimulator.effects(
        {"audio_designer": strong_audio.id}, [strong_audio], {strong_audio.id: 30}, 0)

    check_greater(
        float(with_strong_audio["progress"]), float(with_weak_audio["progress"]),
        "an audio designer speeds up production too")
    check_approx(
        float(with_strong_audio["preproduction_progress"]), float(with_weak_audio["preproduction_progress"]),
        "and also makes no difference to pre-production")

    # The reverse: a producer's own output is a direct term in pre-production,
    # but not in production -- there it only reaches the bar indirectly,
    # through coordination, and far more faintly.
    var weak_producer := Employee.new()
    weak_producer.id = "producer"
    weak_producer.production = 10
    var strong_producer := Employee.new()
    strong_producer.id = "producer"
    strong_producer.production = 95
    var with_weak_producer := ProjectStaffSimulator.effects(
        {"producer": weak_producer.id}, [weak_producer], {weak_producer.id: 40}, 0)
    var with_strong_producer := ProjectStaffSimulator.effects(
        {"producer": strong_producer.id}, [strong_producer], {strong_producer.id: 40}, 0)

    var preprod_delta := (
        float(with_strong_producer["preproduction_progress"]) - float(with_weak_producer["preproduction_progress"]))
    var progress_delta := (
        float(with_strong_producer["progress"]) - float(with_weak_producer["progress"]))
    check_greater(preprod_delta, 0.0, "a stronger producer speeds up pre-production")
    check_greater(preprod_delta, progress_delta,
        "and matters far more there than in production, where the role is coordination, not output")

    # Programmers now carry both phases -- an early read on feasibility in
    # pre-production, the same programming once there is code to write.
    var weak_coder := Employee.new()
    weak_coder.id = "coder"
    weak_coder.programming = 10
    var strong_coder := Employee.new()
    strong_coder.id = "coder"
    strong_coder.programming = 95
    var with_weak_coder := ProjectStaffSimulator.effects(
        {"lead_programmer": weak_coder.id}, [weak_coder], {weak_coder.id: 50}, 0)
    var with_strong_coder := ProjectStaffSimulator.effects(
        {"lead_programmer": strong_coder.id}, [strong_coder], {strong_coder.id: 50}, 0)

    check_greater(
        float(with_strong_coder["progress"]), float(with_weak_coder["progress"]),
        "a stronger programmer speeds up production")
    check_greater(
        float(with_strong_coder["preproduction_progress"]), float(with_weak_coder["preproduction_progress"]),
        "and pre-production too, on an equal underlying weighting")

func _good_planning_pays_off() -> void:
    section("a strong pre-production leaves a mark on the game")
    _company()
    var star := _hire("designer", "senior")
    star.design = 95
    star.writing = 90
    star.production = 70

    var project := DevelopmentSimulator.start_project(
        "Planned Well", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return
    project.role_assignments["game_designer"] = star.id

    var innovation_before := project.innovation
    var narrative_before := project.narrative_quality
    var gameplay_before := project.gameplay

    var guard := 0
    while project.current_phase() == "pre_production" and guard < 40:
        guard += 1
        project.role_assignments["game_designer"] = star.id
        TimeManager.advance_week()

    check_greater(project.innovation, innovation_before,
        "innovation gets a head start from strong planning")
    check_greater(project.narrative_quality, narrative_before,
        "so does narrative quality")
    check_equal(project.gameplay, gameplay_before,
        "but gameplay itself is untouched -- nothing has actually been built yet")

func _efficiency_modifier_bounds() -> void:
    section("what a plan is worth")
    check_approx(
        PreproductionSimulator.production_efficiency_modifier(PreproductionSimulator.BASELINE_EFFECTIVENESS),
        0.0, "an ordinary team leaves production exactly as fast as it would have been")
    check_approx(
        PreproductionSimulator.production_efficiency_modifier(0.20), PreproductionSimulator.MAX_PENALTY,
        "the worst realistic pre-production hits the floor penalty (as in the example, -12%)")
    check_greater(PreproductionSimulator.production_efficiency_modifier(3.0), 0.0,
        "a strong pre-production is a real bonus")
    check_approx(
        PreproductionSimulator.production_efficiency_modifier(3.0), PreproductionSimulator.MAX_BONUS,
        "capped at the ceiling")

    check_equal(PreproductionSimulator.label(-0.10), "UNCLEAR DESIGN", "a bad plan is named plainly")
    check_equal(PreproductionSimulator.label(0.10), "CLEAR VISION", "so is a great one")
    check_equal(PreproductionSimulator.label(0.0), "", "an ordinary plan gets no label at all")
    check_not_empty(PreproductionSimulator.description("UNCLEAR DESIGN"),
        "and the flaw explains itself in plain language")

func _poor_preproduction_penalizes_production() -> void:
    section("poor pre-production creates a penalty later, exactly as advertised")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Muddled", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return

    project.preproduction_progress = 100.0
    project.production_efficiency_modifier = PreproductionSimulator.MAX_PENALTY
    var penalized_gain := _one_week_of_progress(project)

    project.development_progress = 0.0
    project.production_efficiency_modifier = 0.0
    var neutral_gain := _one_week_of_progress(project)

    check_less(penalized_gain, neutral_gain,
        "an unclear plan measurably slows every week of production that follows (%.2f vs %.2f)" % [
            penalized_gain, neutral_gain])

func _strong_preproduction_helps_production() -> void:
    section("a clear plan pays that back")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Clear-Eyed", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return

    project.preproduction_progress = 100.0
    project.production_efficiency_modifier = 0.0
    var neutral_gain := _one_week_of_progress(project)

    project.development_progress = 0.0
    project.production_efficiency_modifier = PreproductionSimulator.MAX_BONUS
    var bonus_gain := _one_week_of_progress(project)

    check_greater(bonus_gain, neutral_gain,
        "a clear plan measurably speeds production up (%.2f vs %.2f)" % [bonus_gain, neutral_gain])

func _one_week_of_progress(project: GameProject) -> float:
    ## Isolates the modifier's effect from the week's random roll by sampling
    ## many weeks and averaging, resetting progress each time so it never
    ## actually completes production mid-sample.
    # A +-12% shift needs a decent sample before it reliably clears the
    # noise of the week's own random roll.
    var total := 0.0
    const SAMPLES := 80
    for i in SAMPLES:
        project.development_progress = 0.0
        DevelopmentSimulator.advance_project(project)
        total += project.development_progress
    return total / float(SAMPLES)

func _flaw_is_announced() -> void:
    section("a named flaw or strength is announced")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Announced", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return

    var caught: Array = []
    var catcher := func(_p, modifier, flaw): caught.append([modifier, flaw])
    EventBus.preproduction_completed.connect(catcher)

    var guard := 0
    while project.current_phase() == "pre_production" and guard < 40:
        guard += 1
        TimeManager.advance_week()
    EventBus.preproduction_completed.disconnect(catcher)

    if not check_not_empty(caught, "completion was announced exactly once"):
        return
    check_equal(str(caught[0][1]), project.preproduction_flaw_label(),
        "with the same label the project itself now reports")

    if not project.preproduction_flaw_label().is_empty():
        var in_news := false
        for item in GameState.news:
            if str(item.get("headline", "")).contains(project.preproduction_flaw_label()):
                in_news = true
        check(in_news, "and a notable one reaches the news feed")

func _an_ordinary_plan_is_not_news() -> void:
    section("an unremarkable plan is not a headline")
    # A single founder, staffing several roles adequately but nobody
    # dedicated to any one of them, is exactly the ordinary case this should
    # not flag either way.
    check_equal(PreproductionSimulator.label(
        PreproductionSimulator.production_efficiency_modifier(0.75)), "",
        "the anchor point itself earns no flaw or strength label")

    _company()
    var project := DevelopmentSimulator.start_project(
        "Unremarkable", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return

    var before_news := GameState.news.size()
    var guard := 0
    while project.current_phase() == "pre_production" and guard < 40:
        guard += 1
        TimeManager.advance_week()

    if project.preproduction_flaw_label().is_empty():
        check_equal(GameState.news.size(), before_news,
            "an unremarkable solo-founder plan is not treated as news")
    else:
        # Rare, but honest: a lone founder can occasionally land outside the
        # neutral band too, and that is exactly when it should be reported.
        check_greater(float(GameState.news.size()), float(before_news),
            "and on the rare run where it is notable, it is reported")

func _polish_percent_is_a_display_target_not_a_gate() -> void:
    section("polish has a target, not a hard stop")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Polishing", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return

    check_equal(DevelopmentSimulator.polish_percent(project), 0.0, "nothing polished yet reads 0%")
    project.polish = DevelopmentSimulator.polish_target("small")
    check_equal(DevelopmentSimulator.polish_percent(project), 100.0, "hitting the target reads 100%")
    project.polish = DevelopmentSimulator.polish_target("small") * 4.0
    check_equal(DevelopmentSimulator.polish_percent(project), 100.0,
        "and polishing well past it never reads more than 100%")

func _polish_improves_its_four_named_outcomes() -> void:
    section("polish improves bugs, polish, performance and balance")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Polishing Up", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return
    project.development_progress = 100.0
    project.bugs = 12
    project.known_bugs = 10
    var polish_before := project.polish
    var performance_before := project.performance
    var balance_before := project.balance

    DevelopmentSimulator.polish_week(project)

    check_less(project.bugs, 12, "bugs go down")
    check_greater(project.polish, polish_before, "polish goes up")
    check_greater(project.performance, performance_before, "performance goes up")
    check_greater(project.balance, balance_before, "and so does balance")

func _one_polish_week(project: GameProject) -> Dictionary:
    ## Isolates one week's gains from the random roll by sampling and
    ## resetting the relevant stats each time.
    var polish_total := 0.0
    var performance_total := 0.0
    var balance_total := 0.0
    const SAMPLES := 40
    for i in SAMPLES:
        project.polish = 0.0
        project.performance = 0.0
        project.balance = 0.0
        project.known_bugs = 20
        project.bugs = 20
        DevelopmentSimulator.polish_week(project)
        polish_total += project.polish
        performance_total += project.performance
        balance_total += project.balance
    return {
        "polish": polish_total / float(SAMPLES),
        "performance": performance_total / float(SAMPLES),
        "balance": balance_total / float(SAMPLES)
    }

func _polish_contributors_are_qa_programmers_artists_designers() -> void:
    section("polish's contributors")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Contributors", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return
    project.development_progress = 100.0

    var weak_designer := _hire("designer", "junior")
    project.role_assignments["game_designer"] = weak_designer.id
    weak_designer.design = 10
    var weak_avg := _one_polish_week(project)

    weak_designer.design = 95
    var strong_avg := _one_polish_week(project)

    check_greater(strong_avg["polish"], weak_avg["polish"],
        "a stronger designer raises the polish stat")
    check_greater(strong_avg["balance"], weak_avg["balance"],
        "and balance, which is mostly their call")

    var programmer := _hire("programmer", "junior")
    project.role_assignments["lead_programmer"] = programmer.id
    programmer.programming = 10
    var weak_prog := _one_polish_week(project)
    programmer.programming = 95
    var strong_prog := _one_polish_week(project)

    check_greater(strong_prog["performance"], weak_prog["performance"],
        "a stronger programmer raises performance")

func _balance_is_a_bonus_not_a_dilution() -> void:
    section("balance adds to a review, it does not dilute one")
    var project := GameProject.new()
    project.size_id = "small"
    project.genre_id = "fantasy"
    project.theme_id = "adventure"
    project.platform_id = "microstar_64"
    for field in ["gameplay", "technology", "graphics", "story", "sound",
            "innovation", "polish", "performance", "narrative_quality"]:
        project.set(field, 40.0)

    var quality_with_no_balance := project.average_quality()
    project.balance = 90.0
    check_approx(project.average_quality(), quality_with_no_balance,
        "balance never changes the core quality average, however high it is")

    # calculate_review() carries a +/-4 reception roll, which is +/-0.4 review
    # points -- larger than the effect being measured here. Comparing one roll
    # against one other roll failed about one run in three. Averaging cancels
    # the noise so this measures the rule rather than the dice.
    var low_balance_score := _average_review(project, 0.0)
    var high_balance_score := _average_review(project, 90.0)
    check_greater(high_balance_score, low_balance_score,
        "but a well-tuned game never reviews worse for it (%.2f vs %.2f)" % [
            high_balance_score, low_balance_score])

func _average_review(project: GameProject, balance: float, trials: int = 40) -> float:
    project.balance = balance
    var total := 0.0
    for i in trials:
        total += ReviewSimulator.calculate_review(project)
    return total / float(trials)

func _preproduction_costs_less_than_a_full_production_week() -> void:
    section("pre-production costs less than a full production week")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Cheaper Planning", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return

    var full_cost := DevelopmentSimulator.get_weekly_cost(project)
    var result := DevelopmentSimulator.advance_preproduction(project)
    var charged := int(result.get("weekly_cost", -1))

    check_less(float(charged), float(full_cost),
        "a planning-only week costs less than a full production one (%d vs %d)" % [
            charged, full_cost])
    check_approx(float(charged),
        float(int(round(float(full_cost) * DevelopmentSimulator.PREPRODUCTION_COST_SHARE))),
        "by exactly the documented share")

func _phase_labels() -> void:
    section("phase labels")
    var project := GameProject.new()
    check_equal(project.phase_label(), "PRE-PRODUCTION", "fresh project")
    project.preproduction_progress = 100.0
    check_equal(project.phase_label(), "PRODUCTION", "pre-production done")
    project.development_progress = 100.0
    check_equal(project.phase_label(), "POLISH", "production done")
    project.released = true
    check_equal(project.phase_label(), "RELEASED", "and shipped")

func _focus_choices_have_real_tradeoffs() -> void:
    section("hands-on phase focus choices have real tradeoffs")
    var project := GameProject.new()
    check_equal(project.focus_id("pre_production"), "balanced",
        "new and old projects default safely to a balanced plan")
    check(not project.set_focus("production", "made_up"),
        "an unknown focus cannot enter project state")

    check(project.set_focus("pre_production", "lock_scope"),
        "scope can be locked during planning")
    check_greater(DevelopmentFocusSimulator.multiplier(
        project, "pre_production", "progress"), 1.0,
        "locking scope speeds planning up")
    check_less(DevelopmentFocusSimulator.quality_multiplier(
        project, "pre_production", "innovation"), 1.0,
        "and gives up some ambition for that schedule")

    check(project.set_focus("production", "technology"),
        "the build can be directed toward technology")
    check_greater(DevelopmentFocusSimulator.quality_multiplier(
        project, "production", "technology"), 1.0,
        "which improves technology output")
    check_less(DevelopmentFocusSimulator.quality_multiplier(
        project, "production", "story"), 1.0,
        "while story receives less of the team's attention")
    check_greater(DevelopmentFocusSimulator.multiplier(
        project, "production", "cost"), 1.0,
        "and the technical push costs more per week")

    check(project.set_focus("polish", "stability"),
        "the finishing pass can prioritise stability")
    check_greater(DevelopmentFocusSimulator.multiplier(
        project, "polish", "bug_fix"), 1.0,
        "which increases bug-fixing throughput")
    check_less(DevelopmentFocusSimulator.quality_multiplier(
        project, "polish", "polish"), 1.0,
        "in exchange for less visible refinement")

func _focus_choices_persist() -> void:
    section("phase decisions survive serialization")
    var project := GameProject.new()
    project.set_focus("pre_production", "prototype")
    project.set_focus("production", "game_systems")
    project.set_focus("polish", "tuning")
    var restored := GameProject.from_dict(project.to_dict())
    check_equal(restored.focus_id("pre_production"), "prototype", "planning focus returns")
    check_equal(restored.focus_id("production"), "game_systems", "build focus returns")
    check_equal(restored.focus_id("polish"), "tuning", "finishing focus returns")

    var old_data := project.to_dict()
    old_data.erase("focus_choices")
    var migrated := GameProject.from_dict(old_data)
    check_equal(migrated.focus_id("production"), "balanced",
        "older projects migrate to balanced choices")

func _persistence() -> void:
    section("phase progress survives a save")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Saved Phase", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return
    TimeManager.advance_week()
    TimeManager.advance_week()
    var expected := project.preproduction_progress
    if not check_greater(expected, 0.0, "some pre-production progress was made"):
        return

    check(SaveManager.save_game("save_phase"), "saved")
    GameState.reset_company()
    check(SaveManager.load_game("save_phase"), "loaded")

    var restored := GameState.find_active_project(project.id)
    if check_not_null(restored, "the project came back"):
        check_approx(restored.preproduction_progress, expected, "with the same pre-production progress")
        check_equal(restored.current_phase(), "pre_production", "still in the same phase")
    SaveManager.delete_save("save_phase")

func _balance_persists() -> void:
    section("balance survives a save")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Saved Balance", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return
    project.balance = 47.0

    check(SaveManager.save_game("save_balance"), "saved")
    GameState.reset_company()
    check(SaveManager.load_game("save_balance"), "loaded")

    var restored := GameState.find_active_project(project.id)
    if check_not_null(restored, "the project came back"):
        check_approx(restored.balance, 47.0, "with balance intact")
    SaveManager.delete_save("save_balance")

func _old_saves_are_not_sent_back_to_preproduction() -> void:
    section("a save from before phases existed is not punished for it")
    var underway := GameProject.new().to_dict()
    underway.erase("preproduction_progress")
    underway["development_progress"] = 42.0
    var restored_underway := GameProject.from_dict(underway)
    check_equal(restored_underway.preproduction_progress, 100.0,
        "a project already mid-production is treated as past pre-production")
    check_equal(restored_underway.current_phase(), "production",
        "so it resumes in production, not pre-production")

    var fresh := GameProject.new().to_dict()
    fresh.erase("preproduction_progress")
    var restored_fresh := GameProject.from_dict(fresh)
    check_equal(restored_fresh.preproduction_progress, 0.0,
        "a project that never actually started still begins at the start")
