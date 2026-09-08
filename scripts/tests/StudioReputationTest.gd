extends TestCase

## Consumer reputation (how the market sees the studio's games) and employer
## reputation (how the industry sees it as a place to work) are tracked
## separately: a studio can ship acclaimed games while treating people badly,
## or vice versa. See GameState.consumer_reputation / employer_reputation and
## RecruitmentSimulator.attractiveness().

func run() -> void:
    _fresh_company_defaults()
    _sales_move_consumer_not_employer()
    _layoffs_move_employer_not_consumer()
    _attractiveness_reads_employer_not_consumer()
    _persistence()

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(400_000, Ledger.Kind.OTHER, "seed")
    OfficeManager.move_to("shared_workspace")

func _bigger_office() -> void:
    for tier in ["small_office", "professional_studio", "large_studio_floor"]:
        OfficeManager.move_to(tier)

func _hire(role: String = "programmer", seniority: String = "mid") -> Employee:
    var candidate := EmployeeManager.generate_candidate(role, seniority)
    GameState.labor_candidates.append(candidate)
    LaborMarketManager.make_offer(candidate, candidate.salary, 0.0)
    return candidate

func _fresh_company_defaults() -> void:
    section("a fresh company")
    _company()
    check_equal(GameState.consumer_reputation, 0.0, "has no reputation with players yet")
    check_approx(GameState.employer_reputation, 50.0,
        "and starts neutral as an employer, unproven either way")

func _sales_move_consumer_not_employer() -> void:
    section("a release moves consumer reputation, not employer reputation")
    _company()
    var before_employer := GameState.employer_reputation
    GameState.add_consumer_reputation(20.0)
    check_equal(GameState.consumer_reputation, 20.0, "consumer reputation rose")
    check_equal(GameState.employer_reputation, before_employer,
        "shipping a good game does not by itself make the studio a better employer")

func _layoffs_move_employer_not_consumer() -> void:
    section("a round of layoffs costs employer reputation, not consumer reputation")
    _company()
    _bigger_office()
    GameState.consumer_reputation = 70.0
    GameState.employer_reputation = 60.0

    var people: Array[Employee] = []
    for i in 5:
        people.append(_hire())
    for i in 3:
        RetentionManager.lay_off(people[i])

    check_less(GameState.employer_reputation, 60.0, "the round of cuts costs standing as an employer")
    check_equal(GameState.consumer_reputation, 70.0,
        "but players buying the studio's games never hear about it")

func _attractiveness_reads_employer_not_consumer() -> void:
    section("hiring appeal follows employer reputation, not consumer reputation")
    _company()
    GameState.consumer_reputation = 0.0
    GameState.employer_reputation = 0.0
    var before := LaborMarketManager.company_attractiveness()

    # A blockbuster release would once have inflated hiring appeal too --
    # exactly the coupling this split removes.
    GameState.consumer_reputation = 100.0
    check_equal(LaborMarketManager.company_attractiveness(), before,
        "a legendary catalogue does not by itself make the studio easier to hire for")

    GameState.consumer_reputation = 0.0
    GameState.employer_reputation = 100.0
    check_greater(LaborMarketManager.company_attractiveness(), before,
        "but a strong employer reputation does")

func _persistence() -> void:
    section("both reputations survive a save")
    _company()
    GameState.consumer_reputation = 42.0
    GameState.employer_reputation = 68.0

    check(SaveManager.save_game("save_studio_reputation"), "saved")
    GameState.reset_company()
    check(SaveManager.load_game("save_studio_reputation"), "loaded")

    check_equal(GameState.consumer_reputation, 42.0, "consumer reputation came back")
    check_equal(GameState.employer_reputation, 68.0, "and employer reputation came back")
    SaveManager.delete_save("save_studio_reputation")
