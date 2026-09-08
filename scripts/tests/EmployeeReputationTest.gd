extends TestCase

## Personal reputation: earned from major hits, read as an industry tier, and
## worth something at the hiring desk and the review desk.

func run() -> void:
    _hit_score_components()
    _major_hit_threshold()
    _reputation_gain_split()
    _tier_ladder()
    _role_flavored_tiers()
    _major_hit_grants_reputation()
    _ordinary_release_grants_nothing()
    _tier_up_makes_news()
    _wired_to_sales_ending()
    _fame_helps_recruiting()
    _fame_helps_reviews()
    _persistence()

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(400_000, Ledger.Kind.OTHER, "seed")
    OfficeManager.move_to("shared_workspace")

func _hire(role: String = "designer", seniority: String = "mid") -> Employee:
    var candidate := EmployeeManager.generate_candidate(role, seniority)
    GameState.labor_candidates.append(candidate)
    LaborMarketManager.make_offer(candidate, candidate.salary, 0.0)
    return candidate

func _strong_hit() -> GameProject:
    var project := GameProject.new()
    project.title = "Legend Quest"
    project.review_score = 9.2
    project.lifetime_sales = 600_000
    project.lifetime_revenue = 2_400_000
    project.development_cost = 300_000
    return project

func _ordinary_release() -> GameProject:
    var project := GameProject.new()
    project.title = "Fine Enough"
    project.review_score = 6.5
    project.lifetime_sales = 8_000
    project.lifetime_revenue = 40_000
    project.development_cost = 60_000
    return project

func _hit_score_components() -> void:
    section("what a hit score is made of")
    var hit := _strong_hit()
    var score := EmployeeReputationSimulator.hit_score(hit)
    check_between(score, 0.70, 0.90,
        "a genuine breakout scores high (%.3f)" % score)

    var flop := _ordinary_release()
    var flop_score := EmployeeReputationSimulator.hit_score(flop)
    check_less(flop_score, 0.20, "an unremarkable release scores low (%.3f)" % flop_score)

    check_equal(EmployeeReputationSimulator.hit_score(null), 0.0, "nothing in, nothing out")

    var lossmaker := _strong_hit()
    lossmaker.lifetime_revenue = 0
    lossmaker.development_cost = 1_000_000
    check_less(EmployeeReputationSimulator.hit_score(lossmaker), score,
        "the same reception counts for less if it never made its money back")

func _major_hit_threshold() -> void:
    section("only a real hit counts as one")
    check(EmployeeReputationSimulator.is_major_hit(_strong_hit()), "a breakout qualifies")
    check(not EmployeeReputationSimulator.is_major_hit(_ordinary_release()),
        "an average week's work does not")
    check(not EmployeeReputationSimulator.is_major_hit(null), "and neither does nothing")

func _reputation_gain_split() -> void:
    section("the credits, not just the byline")
    var project := _strong_hit()
    var lead_gain := EmployeeReputationSimulator.reputation_gain(project, true)
    var supporting_gain := EmployeeReputationSimulator.reputation_gain(project, false)
    check_greater(float(lead_gain), 0.0, "the lead is credited (%d)" % lead_gain)
    check_greater(float(supporting_gain), 0.0, "so is everyone who helped (%d)" % supporting_gain)
    check_greater(float(lead_gain), float(supporting_gain),
        "but the name on the box gains more (%d vs %d)" % [lead_gain, supporting_gain])

    var flop := _ordinary_release()
    check_equal(EmployeeReputationSimulator.reputation_gain(flop, true), 0,
        "nothing is earned from an unremarkable release, lead or not")

func _tier_ladder() -> void:
    section("the tiers")
    check_equal(EmployeeReputationSimulator.tier_label(0), "", "a total unknown has no tier yet")
    check_equal(EmployeeReputationSimulator.tier_label(24), "", "not quite there")
    check_equal(EmployeeReputationSimulator.tier_label(25), "Rising Talent", "the first rung")
    check_equal(EmployeeReputationSimulator.tier_label(44), "Rising Talent", "still rising")
    check_equal(EmployeeReputationSimulator.tier_label(45), "Industry Veteran", "the next rung")
    check_equal(EmployeeReputationSimulator.tier_label(64), "Industry Veteran", "still a veteran")

func _role_flavored_tiers() -> void:
    section("the top two rungs name the craft")
    check_equal(EmployeeReputationSimulator.tier_label(65, "designer"), "Famous Designer",
        "as in the mock-up")
    check_equal(EmployeeReputationSimulator.tier_label(85, "programmer"), "Legendary Developer",
        "as in the mock-up")
    check_equal(EmployeeReputationSimulator.tier_label(90, "artist"), "Legendary Artist",
        "and every role gets its own noun")
    check_equal(EmployeeReputationSimulator.tier_label(90, "some_unmapped_role"),
        "Legendary Developer", "an unmapped role falls back rather than breaking")

func _major_hit_grants_reputation() -> void:
    section("a major hit pays its credited staff in reputation")
    _company()
    var lead := _hire("designer", "mid")
    var support := _hire("artist", "junior")
    var project := _strong_hit()
    project.role_assignments = {"game_designer": lead.id}
    project.credited_employee_ids = [lead.id, support.id]

    var lead_before := lead.reputation
    var support_before := support.reputation
    EmployeeManager.award_reputation(project)

    check_greater(lead.reputation, lead_before, "the lead gains reputation")
    check_greater(support.reputation, support_before, "and so does the supporting artist")
    check_greater(lead.reputation - lead_before, support.reputation - support_before,
        "but the lead gains more")

func _ordinary_release_grants_nothing() -> void:
    section("an average release does not make anyone famous")
    _company()
    var person := _hire("writer", "mid")
    var project := _ordinary_release()
    project.role_assignments = {"writer": person.id}
    project.credited_employee_ids = [person.id]

    var before := person.reputation
    EmployeeManager.award_reputation(project)
    check_equal(person.reputation, before, "reputation is unchanged")

func _tier_up_makes_news() -> void:
    section("crossing a tier is announced")
    _company()
    var person := _hire("designer", "senior")
    person.reputation = 20
    var project := _strong_hit()
    project.role_assignments = {"game_designer": person.id}
    project.credited_employee_ids = [person.id]

    var crossed: Array = []
    var catcher := func(_e, tier): crossed.append(tier)
    EventBus.employee_tier_up.connect(catcher)
    EmployeeManager.award_reputation(project)
    EventBus.employee_tier_up.disconnect(catcher)

    if check_not_empty(crossed, "the tier change is signalled"):
        check_equal(crossed[0], "Rising Talent", "and named correctly")

    var in_news := false
    for item in GameState.news:
        if str(item.get("headline", "")).contains(person.display_name().to_upper()):
            in_news = true
    check(in_news, "and it reaches the news feed")

func _wired_to_sales_ending() -> void:
    section("a title's sales ending is what triggers the award")
    _company()
    var person := _hire("audio_designer", "mid")
    var project := _strong_hit()
    project.role_assignments = {"audio_designer": person.id}
    project.credited_employee_ids = [person.id]

    var before := person.reputation
    EventBus.game_sales_ended.emit(project)
    check_greater(person.reputation, before, "the signal alone is enough")

func _fame_helps_recruiting() -> void:
    section("a famous name on staff helps recruiting")
    _company()
    var star := _hire("programmer", "senior")
    star.reputation = 0
    var before := LaborMarketManager.company_attractiveness()

    star.reputation = 95
    var after := LaborMarketManager.company_attractiveness()

    check_greater(after, before,
        "the studio is more attractive with a legend on the roster (%.1f vs %.1f)" % [
            after, before])

func _fame_helps_reviews() -> void:
    section("a famous credited name helps a review a little")
    _company()
    var lead := _hire("designer", "mid")

    # A middling project, kept well clear of the score ceiling on purpose,
    # so a modest fame bonus is not lost to clipping.
    var project := GameProject.new()
    project.title = "Showcase"
    project.genre_id = "fantasy"
    project.theme_id = "adventure"
    project.platform_id = "microstar_64"
    project.size_id = "small"
    for field in ["gameplay", "technology", "graphics", "story", "sound",
            "innovation", "polish", "performance", "narrative_quality"]:
        project.set(field, 20.0)
    project.bugs = 2
    project.role_assignments = {"game_designer": lead.id}

    lead.reputation = 0
    var plain_total := 0.0
    for i in 40:
        plain_total += ReviewSimulator.calculate_review(project)
    var plain_avg := plain_total / 40.0

    lead.reputation = 90
    var famous_total := 0.0
    for i in 40:
        famous_total += ReviewSimulator.calculate_review(project)
    var famous_avg := famous_total / 40.0

    check_greater(famous_avg, plain_avg,
        "the average review nudges up with a famous designer credited (%.2f vs %.2f)" % [
            famous_avg, plain_avg])

func _persistence() -> void:
    section("reputation and credits survive a save")
    _company()
    var lead := _hire("designer", "senior")
    lead.reputation = 62
    var project := _strong_hit()
    project.id = GameState.next_project_id()
    project.role_assignments = {"game_designer": lead.id}
    project.credited_employee_ids = [lead.id]
    GameState.released_games.append(project)

    check(SaveManager.save_game("save_reputation"), "saved")
    GameState.reset_company()
    check(SaveManager.load_game("save_reputation"), "loaded")

    var restored_employee := EmployeeManager.find_employee(lead.id)
    if check_not_null(restored_employee, "the employee came back"):
        check_equal(restored_employee.reputation, 62, "with their reputation intact")

    var restored_project := GameState.find_game(project.id)
    if check_not_null(restored_project, "the credited project came back"):
        check(restored_project.credited_employee_ids.has(lead.id), "with the credit intact")
    SaveManager.delete_save("save_reputation")
