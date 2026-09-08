extends TestCase

## Data-driven studio events: the condition grammar, what makes one eligible,
## raising it, the choices, the default when it is ignored, and that all of it
## survives a save.

func run() -> void:
    _condition_grammar()
    _variables()
    _eligibility()
    _raising_and_answering()
    _coworker_conflict()
    _the_default_when_ignored()
    _cannot_afford_a_choice()
    _equipment_penalty_ages_off()
    _persistence()

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(300_000, Ledger.Kind.OTHER, "seed")
    OfficeManager.move_to("shared_workspace")

func _hire(role: String = "artist", seniority: String = "mid") -> Employee:
    var candidate := EmployeeManager.generate_candidate(role, seniority)
    GameState.labor_candidates.append(candidate)
    LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)
    return candidate

func _condition_grammar() -> void:
    section("a condition is three tokens a designer can write")
    var person := Employee.new()
    person.art = 60
    person.morale = 40

    check(StudioEventSimulator.conditions_met(["employee_art > 50"], person),
        "greater-than passes when it should")
    check(not StudioEventSimulator.conditions_met(["employee_art > 70"], person),
        "and fails when it should")
    check(StudioEventSimulator.conditions_met(["employee_art >= 60"], person), "greater-or-equal")
    check(StudioEventSimulator.conditions_met(["employee_morale <= 40"], person), "less-or-equal")
    check(StudioEventSimulator.conditions_met(["employee_art == 60"], person), "equality")
    check(StudioEventSimulator.conditions_met(["employee_morale != 40.0"], person) == false,
        "inequality")
    check(StudioEventSimulator.conditions_met(
        ["employee_art > 50", "employee_morale < 50"], person),
        "every clause has to pass")
    check(not StudioEventSimulator.conditions_met(
        ["employee_art > 50", "employee_morale > 50"], person),
        "one failing clause fails the set")

func _variables() -> void:
    section("what a condition can look at")
    _company()
    GameState.cash = 12_345
    check_equal(int(StudioEventSimulator.resolve_var("company_cash", null)), 12_345,
        "company cash")
    check_equal(StudioEventSimulator.resolve_var("has_active_project", null), 0.0,
        "no project in development")
    GameState.active_projects.append(GameProject.new())
    check_equal(StudioEventSimulator.resolve_var("has_active_project", null), 1.0,
        "a project in development")
    GameState.active_projects.clear()

    var person := _hire("artist", "mid")
    person.hire_year = TimeManager.current_year - 2
    check_greater(StudioEventSimulator.resolve_var("employee_tenure_weeks", person), 90.0,
        "two years of tenure reads as ~96 weeks")
    check_equal(StudioEventSimulator.resolve_var("employee_art", person), float(person.art),
        "an employee skill")

func _eligibility() -> void:
    section("what makes an event eligible to fire")
    _company()
    GameState.cash = 20_000
    var artist := _hire("artist", "mid")
    artist.art = 65

    var subjects := StudioEventManager.eligible_subjects(DataManager.get_studio_event("art_conference"))
    var ids: Array = subjects.map(func(e: Employee): return e.id)
    check(artist.id in ids, "an artist over the skill bar is a candidate for the conference event")

    var coder := _hire("programmer", "mid")
    coder.art = 90
    subjects = StudioEventManager.eligible_subjects(DataManager.get_studio_event("art_conference"))
    ids = subjects.map(func(e: Employee): return e.id)
    check(coder.id not in ids, "but a programmer is not, however good their art -- the event names roles")

    GameState.studio_event_cooldowns["art_conference"] = TimeManager.absolute_week()
    var eligible_ids: Array = []
    for event in StudioEventManager._eligible_events():
        eligible_ids.append(str(event["id"]))
    check("art_conference" not in eligible_ids, "a recent event is on cooldown and will not recur")
    GameState.studio_event_cooldowns.clear()

func _raising_and_answering() -> void:
    section("raising an event and approving it")
    _company()
    GameState.cash = 20_000
    GameClock.enter_gameplay(true)
    var artist := _hire("artist", "mid")
    artist.art = 60
    artist.morale = 80
    var xp_before := int(artist.skill_experience.get("art", 0))
    var morale_before := artist.morale

    check(StudioEventManager.raise_event("art_conference", artist), "the event is raised")
    check(StudioEventManager.has_pending(), "and is now waiting on the player")
    check(GameClock.paused, "the clock stopped for it")
    check_equal(str(StudioEventManager.pending_event().get("id", "")), "art_conference",
        "the right event is pending")
    check_equal(StudioEventManager.pending_employee(), artist, "about the right person")
    check(not StudioEventManager.raise_event("workstation_failure"),
        "only one event is ever pending at a time")

    var cash_before := GameState.cash
    var result := StudioEventManager.resolve(0)
    check(bool(result.get("ok")), "APPROVE goes through")
    check_equal(GameState.cash, cash_before - 1200, "the conference fee was paid")
    check_greater(int(artist.skill_experience.get("art", 0)), xp_before,
        "the artist came back with more art experience")
    check_greater(artist.morale, morale_before, "and in better spirits")
    check(not StudioEventManager.has_pending(), "the decision is closed")
    check(StudioEventManager.pending().is_empty(), "nothing is queued")

    var in_news := false
    for item in GameState.news:
        if str(item.get("body", "")).contains(artist.first_name):
            in_news = true
    check(in_news, "and the outcome reached the news feed")

func _coworker_conflict() -> void:
    section("a coworker conflict plays out on the team")
    _company()
    var a := _hire("programmer", "mid")
    var b := _hire("designer", "mid")
    TeamManager.assign_employee(a, "team_a")
    TeamManager.assign_employee(b, "team_a")
    a.morale = 60
    b.morale = 65

    check_greater(StudioEventSimulator.resolve_var("employee_team_size", a), 1.0,
        "the subject shares a team with other people")
    var subjects := StudioEventManager.eligible_subjects(
        DataManager.get_studio_event("coworker_conflict"))
    var ids: Array = subjects.map(func(e: Employee): return e.id)
    check(a.id in ids, "an unhappy teammate is a candidate for the conflict event")
    check(b.id in ids, "so is the other one -- either can be the flashpoint")

    var team := TeamManager.find_team("team_a")
    team.chemistry = 60.0
    check(StudioEventManager.raise_event("coworker_conflict", a), "the conflict is raised")

    var chem_before := team.chemistry
    var b_morale := b.morale
    check(bool(StudioEventManager.resolve(1).get("ok")), "STAY OUT OF IT is chosen")
    check_less(team.chemistry, chem_before, "team chemistry drops when nobody steps in")
    check_less(b.morale, b_morale, "and the sour mood spreads across the team")

    check(StudioEventManager.raise_event("coworker_conflict", a),
        "the same friction can come up again later")
    var chem_mediated := team.chemistry
    check(bool(StudioEventManager.resolve(0).get("ok")), "this time you MEDIATE")
    check_greater(team.chemistry, chem_mediated, "sitting them down repairs some chemistry")

func _the_default_when_ignored() -> void:
    section("ignoring an event is answered for you")
    _company()
    GameState.cash = 20_000
    var artist := _hire("artist", "mid")
    artist.art = 60
    artist.morale = 70

    check(StudioEventManager.raise_event("art_conference", artist), "raised")
    var cash_before := GameState.cash
    GameState.pending_studio_event["weeks_left"] = 1
    StudioEventManager.process_week()

    check(not StudioEventManager.has_pending(), "a week later, it has lapsed")
    check_equal(GameState.cash, cash_before, "the default choice (DECLINE) costs nothing")
    check_less(artist.morale, 70, "but being turned down still stings a little")

func _cannot_afford_a_choice() -> void:
    section("a choice you cannot pay for is offered but refused")
    _company()
    var artist := _hire("artist", "mid")
    artist.art = 60
    check(StudioEventManager.raise_event("art_conference", artist), "raised")

    GameState.cash = 500
    check(not StudioEventManager.can_afford_choice(0), "APPROVE is out of reach")
    var result := StudioEventManager.resolve(0)
    check(not bool(result.get("ok")), "and the studio cannot pretend otherwise")
    check_equal(str(result.get("reason", "")), "unaffordable", "with a reason the screen can show")
    check(StudioEventManager.has_pending(), "the event is still on the table")

func _equipment_penalty_ages_off() -> void:
    section("a workstation failure drags on development, then passes")
    _company()
    GameState.cash = 20_000
    GameState.active_projects.append(GameProject.new())

    check(StudioEventManager.raise_event("workstation_failure"), "the failure is raised")
    check_null(StudioEventManager.pending_employee(), "it is about the studio, not a person")
    check_approx(StudioEventManager.development_efficiency_multiplier(), 1.0,
        "no penalty until a choice is made")

    var result := StudioEventManager.resolve(1)
    check(bool(result.get("ok")), "MAKE DO is chosen")
    check_less(StudioEventManager.development_efficiency_multiplier(), 1.0,
        "development slows while the team shares machines")
    check_approx(StudioEventManager.development_efficiency_multiplier(), 0.92,
        "by the authored 8%")

    for week in 3:
        StudioEventManager.process_week()
    check_approx(StudioEventManager.development_efficiency_multiplier(), 1.0,
        "three weeks on, the trouble is behind them")

func _persistence() -> void:
    section("a pending event and its aftermath survive a save")
    _company()
    GameState.cash = 20_000
    GameState.active_projects.append(GameProject.new())
    StudioEventManager.raise_event("workstation_failure")
    StudioEventManager.resolve(1)   # leaves a dev-efficiency penalty running

    var artist := _hire("artist", "mid")
    artist.art = 60
    StudioEventManager.raise_event("art_conference", artist)

    check(SaveManager.save_game("save_events"), "saved")
    GameState.reset_company()
    check(SaveManager.load_game("save_events"), "loaded")

    check(StudioEventManager.has_pending(), "the pending event came back")
    check_equal(str(StudioEventManager.pending_event().get("id", "")), "art_conference",
        "as the same event")
    check_less(StudioEventManager.development_efficiency_multiplier(), 1.0,
        "and the equipment penalty is still running")
    check(StudioEventManager._on_cooldown("workstation_failure"),
        "the resolved event is still on cooldown")
    SaveManager.delete_save("save_events")
