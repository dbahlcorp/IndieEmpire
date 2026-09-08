extends TestCase

## Not an M3 mechanic -- there are no competitor studios yet -- but every
## employment transition already records who currently employs a person
## (unemployed/player/competitor), so poaching has somewhere to record a move
## once M4/M5 adds rivals to move between. See Employee.employer.

func run() -> void:
    _a_generated_candidate_is_unemployed()
    _the_founder_belongs_to_the_player()
    _hiring_makes_them_the_players()
    _a_layoff_returns_them_to_unemployed()
    _a_resignation_returns_them_to_unemployed()
    _an_unknown_value_falls_back_on_load()
    _survives_a_save()

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(400_000, Ledger.Kind.OTHER, "seed")
    OfficeManager.move_to("shared_workspace")

func _hire(role: String = "programmer", seniority: String = "mid") -> Employee:
    var candidate := EmployeeManager.generate_candidate(role, seniority)
    GameState.labor_candidates.append(candidate)
    LaborMarketManager.make_offer(candidate, candidate.salary, 0.0)
    return candidate

func _a_generated_candidate_is_unemployed() -> void:
    section("a fresh candidate on the market belongs to nobody yet")
    var candidate := EmployeeManager.generate_candidate("designer", "junior")
    check_equal(candidate.employer, "unemployed", "not yet anyone's employee")

func _the_founder_belongs_to_the_player() -> void:
    section("the founder is the player's from the start")
    _company()
    var founder := EmployeeManager.founder()
    if check_not_null(founder, "the founder exists"):
        check_equal(founder.employer, "player", "and belongs to the studio immediately")

func _hiring_makes_them_the_players() -> void:
    section("accepting an offer changes who employs them")
    _company()
    var hire := _hire()
    check_equal(hire.status, "active", "hired and active")
    check_equal(hire.employer, "player", "now belongs to the studio")

func _a_layoff_returns_them_to_unemployed() -> void:
    section("a layoff sends them back to unemployed, not to a rival")
    _company()
    var hire := _hire()
    RetentionManager.lay_off(hire)
    check_equal(hire.status, "laid_off", "the status reflects the layoff")
    check_equal(hire.employer, "unemployed",
        "and ownership reverts -- there is nowhere else for them to go yet")

func _a_resignation_returns_them_to_unemployed() -> void:
    section("leaving on their own also returns them to unemployed")
    _company()
    var hire := _hire()
    hire.notice_weeks = 1
    RetentionManager.process_week()
    check_equal(hire.status, "departed", "they actually left")
    check_equal(hire.employer, "unemployed", "and ownership reverts the same way")

func _an_unknown_value_falls_back_on_load() -> void:
    section("a stale or hand-edited value is not trusted")
    var data := {"employer": "some_removed_state"}
    var restored := Employee.from_dict(data)
    check_equal(restored.employer, "unemployed", "an unrecognised value falls back safely")

func _survives_a_save() -> void:
    section("ownership survives a save")
    _company()
    var hire := _hire()
    check_equal(hire.employer, "player", "hired, so belongs to the player")

    check(SaveManager.save_game("save_ownership"), "saved")
    GameState.reset_company()
    check(SaveManager.load_game("save_ownership"), "loaded")

    var restored := EmployeeManager.find_employee(hire.id)
    if check_not_null(restored, "the employee came back"):
        check_equal(restored.employer, "player", "still recorded as the player's")
    SaveManager.delete_save("save_ownership")
