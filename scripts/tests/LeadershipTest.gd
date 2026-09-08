extends TestCase

## Somebody runs the project. Not necessarily whoever is best at the work.

func run() -> void:
    _picks_the_highest_leadership()
    _ties_are_stable()
    _empty_team_has_no_lead()
    _a_star_is_not_automatically_the_lead()
    _refreshed_every_week()
    _coordination()
    _chemistry()
    _schedule_consistency_narrows_the_swing()
    _schedule_consistency_leaves_the_average_alone()
    _stress()
    _persistence()

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(400_000, Ledger.Kind.OTHER, "seed")
    OfficeManager.move_to("shared_workspace")

func _hire(role: String = "programmer", seniority: String = "mid") -> Employee:
    var candidate := EmployeeManager.generate_candidate(role, seniority)
    GameState.labor_candidates.append(candidate)
    LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)
    return candidate

func _picks_the_highest_leadership() -> void:
    section("pick_lead")
    var quiet := Employee.new()
    quiet.id = "quiet"
    quiet.leadership = 30
    var loud := Employee.new()
    loud.id = "loud"
    loud.leadership = 85
    var middling := Employee.new()
    middling.id = "middling"
    middling.leadership = 60

    var lead := LeadershipSimulator.pick_lead([quiet, loud, middling])
    check_equal(lead.id, "loud", "the highest leadership on the team leads")

func _ties_are_stable() -> void:
    section("a tie does not flicker")
    var a := Employee.new()
    a.id = "employee_b"
    a.leadership = 70
    var b := Employee.new()
    b.id = "employee_a"
    b.leadership = 70

    var first := LeadershipSimulator.pick_lead([a, b])
    var second := LeadershipSimulator.pick_lead([b, a])
    check_equal(first.id, second.id, "the same person wins regardless of list order")
    check_equal(first.id, "employee_a", "resolved by id, not by chance")

func _empty_team_has_no_lead() -> void:
    section("no team, no lead")
    check_null(LeadershipSimulator.pick_lead([]), "an empty roster leads to nobody")

func _a_star_is_not_automatically_the_lead() -> void:
    section("a brilliant programmer is not necessarily a brilliant leader")
    _company()
    var star := _hire("programmer", "senior")
    star.programming = 98
    star.leadership = 8
    var steady := _hire("producer", "mid")
    steady.programming = 20
    steady.leadership = 92

    var project := DevelopmentSimulator.start_project(
        "Depth", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return

    check_equal(str(project.role_assignments.get("lead_programmer", "")), star.id,
        "the star still does the programming")
    check_equal(project.lead_employee_id, steady.id,
        "but leadership goes to whoever actually has it")
    check_not_equal(project.lead_employee_id, star.id,
        "and it is not automatically the most skilled person in the room")

func _refreshed_every_week() -> void:
    section("the lead is kept current, not decided once")
    _company()
    var first_lead := _hire("designer", "mid")
    first_lead.leadership = 80
    var project := DevelopmentSimulator.start_project(
        "Refresh", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return
    TimeManager.advance_week()
    check_equal(project.lead_employee_id, first_lead.id, "starts with whoever has the leadership")

    var challenger := _hire("artist", "senior")
    challenger.leadership = 95
    TimeManager.advance_week()
    check_equal(project.lead_employee_id, challenger.id,
        "and hands over once somebody with more leadership joins the team")

func _coordination() -> void:
    section("coordination")
    var worker := Employee.new()
    worker.id = "worker"
    worker.programming = 60

    var weak_lead := Employee.new()
    weak_lead.id = "weak_lead"
    weak_lead.leadership = 5
    var strong_lead := Employee.new()
    strong_lead.id = "strong_lead"
    strong_lead.leadership = 95

    var assignments := {"lead_programmer": worker.id}
    var weak := ProjectStaffSimulator.effects(
        assignments, [worker, weak_lead], {worker.id: 50}, 0)
    var strong := ProjectStaffSimulator.effects(
        assignments, [worker, strong_lead], {worker.id: 50}, 0)

    check_equal(str(weak["lead_employee_id"]), "weak_lead", "the weak leader is identified")
    check_equal(str(strong["lead_employee_id"]), "strong_lead", "so is the strong one")
    check_greater(float(strong["leadership_coordination"]), float(weak["leadership_coordination"]),
        "a strong lead coordinates the team better")
    check_greater(float(strong["progress"]), float(weak["progress"]),
        "which shows up in how fast the project actually moves")

func _chemistry() -> void:
    section("team chemistry")
    var a := Employee.new()
    a.id = "a"
    a.teamwork = 60
    a.morale = 70
    var b := Employee.new()
    b.id = "b"
    b.teamwork = 60
    b.morale = 70

    var team := StudioTeam.new()
    team.weeks_together = 10
    team.recent_result = 50

    b.leadership = 10
    var low := TeamManager.chemistry_target(team, [a, b])
    b.leadership = 95
    var high := TeamManager.chemistry_target(team, [a, b])
    check_greater(high, low, "a strong leader on the team lifts its chemistry")

func _schedule_consistency_narrows_the_swing() -> void:
    section("schedule consistency")
    var weak := LeadershipSimulator.schedule_half_width(5.0)
    var neutral := LeadershipSimulator.schedule_half_width(50.0)
    var strong := LeadershipSimulator.schedule_half_width(95.0)
    check_greater(weak, neutral, "a poor lead makes the week less predictable")
    check_greater(neutral, strong, "a strong one keeps it steady")
    check_approx(neutral, 3.0, "and an unremarkable lead matches the old flat range exactly")

func _schedule_consistency_leaves_the_average_alone() -> void:
    section("consistency changes the swing, not the average")
    var weak_total := 0.0
    var strong_total := 0.0
    const SAMPLES := 400
    for i in SAMPLES:
        var weak_width := LeadershipSimulator.schedule_half_width(5.0)
        weak_total += randf_range(11.0 - weak_width, 11.0 + weak_width)
        var strong_width := LeadershipSimulator.schedule_half_width(95.0)
        strong_total += randf_range(11.0 - strong_width, 11.0 + strong_width)
    var weak_avg := weak_total / float(SAMPLES)
    var strong_avg := strong_total / float(SAMPLES)
    check_between(weak_avg, 10.5, 11.5, "a weakly-led average still centres on the same pace")
    check_between(strong_avg, 10.5, 11.5, "so does a strongly-led one")

func _stress() -> void:
    section("stress")
    var poorly_led := LeadershipSimulator.stress_influence(10.0)
    var well_led := LeadershipSimulator.stress_influence(90.0)
    var ordinary := LeadershipSimulator.stress_influence(50.0)

    check_greater(float(poorly_led.get("stress", 0)), 0.0, "a poorly-led project adds stress")
    check_less(float(well_led.get("stress", 0)), 0.0, "a well-led one eases it")
    check(ordinary.is_empty(), "and an unremarkable one says nothing either way")

func _persistence() -> void:
    section("the lead survives a save")
    _company()
    var lead := _hire("designer", "senior")
    lead.leadership = 88
    var project := DevelopmentSimulator.start_project(
        "Saved", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return
    TimeManager.advance_week()
    var expected_lead := project.lead_employee_id
    check_not_empty(expected_lead, "somebody is leading before the save")

    check(SaveManager.save_game("save_leadership"), "saved")
    GameState.reset_company()
    check(SaveManager.load_game("save_leadership"), "loaded")

    var restored := GameState.find_active_project(project.id)
    if check_not_null(restored, "the project came back"):
        check_equal(restored.lead_employee_id, expected_lead, "with the same project lead")
    SaveManager.delete_save("save_leadership")
