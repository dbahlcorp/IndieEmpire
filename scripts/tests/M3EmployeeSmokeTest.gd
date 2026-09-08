extends TestCase

## Run with:
## godot --headless --path . res://scripts/tests/M3EmployeeSmokeTest.tscn
##
## Covers the M3 workforce: the founder, candidate generation, recruitment,
## offices, payroll, teams, workload, staffing effects, traits, skill growth,
## weekly condition, and that all of it survives serialisation.

var founder: Employee
var hire: Employee
var team_a: StudioTeam
var team_b: StudioTeam
var project_a: GameProject
var project_b: GameProject
var weak: Employee
var strong: Employee
var programmer: Employee
var producer: Employee

func run() -> void:
    _founder()
    _serialisation()
    _roles_and_candidates()
    _recruitment_maths()
    _hiring()
    _payroll()
    _offices()
    _teams_and_workload()
    _staffing_effects()
    _traits()
    _skill_progression()
    _weekly_condition()
    _persistence()

func _founder() -> void:
    section("founder")
    GameState.company_name = "Test Works"
    GameState.founder_name = "Ada Lovelace"
    TimeManager.set_date(1985, 1, 1)
    EmployeeManager.seed_founder()

    if not check_equal(GameState.employees.size(), 1, "the studio starts with one person"):
        return
    founder = GameState.employees[0]
    check_equal(founder.id, "employee_000001", "founder id")
    check_equal(founder.display_name(), "Ada Lovelace", "founder name")
    check(founder.is_founder(), "is flagged as the founder")
    check_equal(founder.salary, 0, "the founder draws no salary")
    check_equal(EmployeeManager.monthly_payroll(), 0, "payroll starts at zero")

func _serialisation() -> void:
    section("employee serialisation")
    if founder == null:
        return
    var restored := Employee.from_dict(founder.to_dict())
    check_equal(restored.display_name(), founder.display_name(), "name survives a round trip")
    check_equal(restored.programming, founder.programming, "skills survive a round trip")
    check_equal(restored.portrait_seed, founder.portrait_seed, "portrait seed survives a round trip")

    # An M2 v5 save has no workforce section at all; loading one must promote
    # the named founder into a real employee.
    GameState.employees.clear()
    GameState.next_employee_number = 1
    var migrated := EmployeeManager.ensure_founder()
    check(migrated.is_founder(), "a v5 save is migrated into a founder")
    check_equal(GameState.employees.size(), 1, "migration produces exactly one employee")
    check_equal(GameState.next_employee_number, 2, "the id counter moves on")
    founder = EmployeeManager.founder()

func _roles_and_candidates() -> void:
    section("roles and candidates")
    var expected_roles := [
        "programmer", "designer", "artist", "writer", "audio_designer",
        "qa_tester", "producer", "generalist"
    ]
    check_equal(DataManager.employee_roles.size(), expected_roles.size(), "every role is authored")
    for role_id in expected_roles:
        check_not_empty(DataManager.get_employee_role(role_id), "role data for %s" % role_id)

    var generalist := EmployeeManager.generate_candidate("generalist", "junior", "Alex Morgan", 101)
    if not check_not_null(generalist, "a generalist candidate is produced"):
        return
    check_equal(generalist.status, "candidate", "candidates are not employees yet")
    check_empty(generalist.id, "a candidate has no id until hired")
    for skill in EmployeeManager.SKILL_FIELDS:
        check_between(float(generalist.get(skill)), 24.0, 48.0,
            "junior generalist %s is in band" % skill)

    var specialist := EmployeeManager.generate_candidate("programmer", "senior", "Maya Chen", 202)
    if not check_not_null(specialist, "a senior specialist is produced"):
        return
    check_between(float(specialist.programming), 82.0, 96.0, "senior programmer skill is in band")
    check(specialist.art <= 32, "a programmer is not also an artist (art %d)" % specialist.art)
    check_equal(EmployeeManager.job_title(specialist), "Senior Programmer", "job title")
    check_greater(float(specialist.salary), float(generalist.salary), "seniority costs more")

func _recruitment_maths() -> void:
    section("recruitment maths")
    var unknown := RecruitmentSimulator.seniority_weights(10.0)
    var famous := RecruitmentSimulator.seniority_weights(90.0)
    check_equal(int(unknown["intern"]) + int(unknown["junior"]), 90,
        "an unknown studio mostly attracts juniors")
    check_greater(float(famous["senior"]), float(unknown["senior"]),
        "a famous studio attracts seniors")
    check_greater(
        RecruitmentSimulator.attractiveness(90, 12, 9.5, 1.2, 90, 90),
        RecruitmentSimulator.attractiveness(0, 1, 0, 0.85, 0, 40),
        "a successful studio is more attractive")

    # Crunch culture and staff morale are part of the recruiting score.
    var humane := RecruitmentSimulator.attractiveness(60, 6, 8.0, 1.0, 50, 55, 85.0, 88.0)
    var grim := RecruitmentSimulator.attractiveness(60, 6, 8.0, 1.0, 50, 55, 15.0, 25.0)
    check_greater(humane, grim,
        "the same studio is worth more to work for when people are happy (%.1f vs %.1f)" % [
            humane, grim])

    # The score reads out as an employer reputation the player can see.
    var top := RecruitmentSimulator.employer_reputation(92.0)
    var bottom := RecruitmentSimulator.employer_reputation(8.0)
    check_equal(str(top["label"]), "Exceptional", "a great employer reads as exceptional")
    check_equal(str(top["display"]), "★★★★★", "with five stars")
    check_equal(str(bottom["label"]), "Notorious", "a terrible one is notorious")
    check_greater(float(top["stars"]), float(bottom["stars"]), "and has more stars")
    check_equal(str(RecruitmentSimulator.employer_reputation(70.0)["display"]), "★★★★☆",
        "the four-star band renders as in the mock-up")
    check_equal(str(RecruitmentSimulator.employer_reputation(80.0)["display"]), "★★★★½",
        "and a half star shows when earned")

    GameState.crunch_teams = []
    var calm := LaborMarketManager.crunch_culture_score()
    GameState.crunch_teams = ["team_a"]
    check_less(LaborMarketManager.crunch_culture_score(), calm,
        "an active crunch visibly hurts the studio's standing as an employer")
    GameState.crunch_teams = []

func _hiring() -> void:
    section("hiring")
    SaveManager.has_active_company = false
    GameState.cash = 20_000
    GameState.consumer_reputation = 0.0
    GameState.employer_reputation = 0.0
    GameState.office_quality = 0
    GameState.office_id = "bedroom"
    GameState.annual_finance.clear()
    GameState.released_games.clear()
    # An autosave left by another test can carry an in-progress project whose
    # staffed roles clash with the ids this section hands out.
    GameState.active_projects.clear()
    GameState.current_project = null

    LaborMarketManager.refresh_market(false)
    check_equal(GameState.labor_candidates.size(), LaborMarketManager.MARKET_SIZE,
        "the market is stocked")
    check_equal(GameState.labor_market_weeks_left, LaborMarketManager.ROTATION_WEEKS,
        "the rotation clock is set")
    if GameState.labor_candidates.is_empty():
        return

    hire = GameState.labor_candidates[0]
    var fee := hire.hiring_fee
    var before_employees := GameState.employees.size()

    OfficeManager.sync_office_quality()
    check_equal(OfficeManager.capacity(), 1, "the bedroom holds one person")
    check(not OfficeManager.has_capacity(), "and has no room for a hire")
    check_equal(str(LaborMarketManager.make_offer(hire, hire.salary, 0.0)["status"]),
        "office_full", "an offer is refused with no desk to put them at")

    GameState.office_id = "shared_workspace"
    OfficeManager.sync_office_quality()
    check_equal(OfficeManager.capacity(), 3, "a shared workspace holds three")
    check(OfficeManager.has_capacity(), "and has room")

    var asking := hire.salary
    var low := RecruitmentSimulator.acceptance_probability(asking, int(asking * 0.7), 10)
    var high := RecruitmentSimulator.acceptance_probability(asking, int(asking * 1.2), 90)
    check_less(low, high, "a better offer from a better studio is likelier to land")
    check_in(RecruitmentSimulator.acceptance_label(low), ["Very Low", "Low"], "low offer label")
    check_equal(RecruitmentSimulator.acceptance_label(high), "Very High", "high offer label")

    check_equal(str(LaborMarketManager.make_offer(hire, asking, 0.0)["status"]), "accepted",
        "a fair offer is accepted")
    check_equal(GameState.employees.size(), before_employees + 1, "the studio grew by one")
    check_equal(hire.status, "active", "the new person is active")
    check_not_empty(hire.id, "and has been given an id")
    check_equal(GameState.cash, 20_000 - fee, "the hiring fee was paid")

    # A hire who is paid but assigned to nothing would contribute nothing.
    check_not_empty(hire.assigned_team, "the hire was placed on a team")
    check(TeamManager.unassigned_employees().is_empty(), "nobody is left unassigned")

func _payroll() -> void:
    section("payroll and running costs")
    if hire == null:
        return
    var before := GameState.cash
    TimeManager.set_date(1985, 2, 1)
    var monthly := EmployeeManager.monthly_expenses()
    EmployeeManager.process_week()

    check_equal(int(monthly["salaries"]), hire.salary, "salaries are the sum of wages")
    check_greater(float(monthly["utilities"]), 0.0, "utilities are charged")
    check_greater(float(monthly["software"]), 0.0, "software is charged per head")
    check_equal(GameState.cash, before - int(monthly["total"]), "the full amount left the account")

func _offices() -> void:
    section("offices")
    GameState.cash = 100_000
    check(not OfficeManager.can_move_to("large_studio_floor"), "you cannot skip office tiers")
    check(OfficeManager.can_move_to("small_office"), "the next tier up is available")
    check(OfficeManager.move_to("small_office"), "moving to a small office")
    check(OfficeManager.can_move_to("professional_studio"), "then the tier above that")
    check(OfficeManager.move_to("professional_studio"), "moving again")
    check(OfficeManager.can_move_to("large_studio_floor"), "and again")
    check(OfficeManager.move_to("large_studio_floor"), "reaching the largest floor")

    check_equal(GameState.office_id, "large_studio_floor", "the studio is in the new office")
    check_equal(OfficeManager.capacity(), 12, "capacity matches the office")
    check_equal(GameState.office_quality, 75, "office quality matches the office")
    var expected_cash := (100_000
        - FinanceManager.expense(8_000)
        - FinanceManager.expense(18_000)
        - FinanceManager.expense(42_000))
    check_equal(GameState.cash, expected_cash, "every move-in cost was paid")

func _teams_and_workload() -> void:
    section("teams and workload")
    GameState.active_projects.clear()
    TeamManager.seed_teams()

    team_a = TeamManager.find_team("team_a")
    if not check_not_null(team_a, "the first team exists"):
        return
    check(founder.id in team_a.employee_ids, "the founder is on it")

    team_b = TeamManager.create_second_team()
    check_not_null(team_b, "a second team can be created")
    check_null(TeamManager.create_second_team(), "but not a third")
    check(TeamManager.assign_employee(hire, "team_b"), "an employee can be moved between teams")
    check_equal(hire.assigned_team, "team_b", "and remembers where they went")

    project_a = GameProject.new()
    project_a.id = "team_test_a"
    project_a.title = "Starfall II"
    project_a.team_id = "team_a"
    project_a.role_assignments = {
        "lead_programmer": founder.id,
        "game_designer": founder.id,
        "writer": founder.id
    }
    project_b = GameProject.new()
    project_b.id = "team_test_b"
    project_b.title = "Dark Horizon"
    project_b.team_id = "team_b"
    project_b.role_assignments = {"artist": hire.id}
    GameState.active_projects.assign([project_a, project_b])
    team_a.project_id = project_a.id
    team_b.project_id = project_b.id

    check_equal(TeamManager.workload_percent(founder.id), 130, "three roles is an overload")
    check_equal(TeamManager.workload_label(130), "OVERLOADED", "and is labelled as one")
    check_equal(TeamManager.workload_percent(hire.id), 45, "one role is a normal load")
    check_equal(TeamManager.workload_label(45), "Healthy", "and is labelled healthy")
    check(not TeamManager.assign_employee(founder, "team_b"),
        "someone with an active role cannot be moved")

    check_approx(ProjectStaffSimulator.workload_multiplier(80), 1.0, "under full load is no penalty")
    check_less(ProjectStaffSimulator.workload_multiplier(130),
        ProjectStaffSimulator.workload_multiplier(80), "overload reduces output")

    var effects := ProjectStaffSimulator.effects(
        project_a.role_assignments, GameState.employees, {founder.id: 130, hire.id: 45}, 0)
    check_greater(float(effects["overload"]), 0.0, "overload is reported to the project")

func _staffing_effects() -> void:
    section("staffing effects")
    weak = Employee.new()
    weak.id = "weak_designer"
    weak.design = 30
    weak.creativity = 35
    weak.quality = 35
    weak.morale = 100
    weak.energy = 100

    strong = Employee.from_dict(weak.to_dict())
    strong.id = "strong_designer"
    strong.design = 85
    strong.creativity = 80
    strong.quality = 75
    strong.level = 4

    var weak_result := ProjectStaffSimulator.effects(
        {"game_designer": weak.id}, [weak], {weak.id: 45}, 0)
    var strong_result := ProjectStaffSimulator.effects(
        {"game_designer": strong.id}, [strong], {strong.id: 45}, 0)
    check_greater(float(strong_result["design"]), float(weak_result["design"]),
        "a better designer produces more")

    # Headcount alone must not raise a named role's craft multiplier.
    var extra := Employee.new()
    extra.id = "unassigned_extra"
    extra.design = 100
    extra.creativity = 100
    var with_extra := ProjectStaffSimulator.effects(
        {"game_designer": strong.id}, [strong, extra], {strong.id: 45, extra.id: 0}, 0)
    check_approx(float(with_extra["design"]), float(strong_result["design"]),
        "an unassigned bystander does not improve the design role")

    strong.morale = 20
    var low_morale := ProjectStaffSimulator.effects(
        {"game_designer": strong.id}, [strong], {strong.id: 45}, 0)
    check_less(float(low_morale["design"]), float(strong_result["design"]),
        "low morale reduces output")

    programmer = Employee.new()
    programmer.id = "overloaded_programmer"
    programmer.programming = 70
    programmer.quality = 65
    programmer.adaptability = 60
    producer = Employee.new()
    producer.id = "good_producer"
    producer.production = 90
    producer.teamwork = 85
    producer.leadership = 85

    var without := ProjectStaffSimulator.effects(
        {"lead_programmer": programmer.id}, [programmer], {programmer.id: 130}, 0)
    var with_producer := ProjectStaffSimulator.effects(
        {"lead_programmer": programmer.id, "producer": producer.id},
        [programmer, producer], {programmer.id: 130, producer.id: 40}, 0)
    check_greater(
        float(with_producer["role_contributions"]["lead_programmer"]["workload_efficiency"]),
        float(without["role_contributions"]["lead_programmer"]["workload_efficiency"]),
        "a good producer softens an overload")

    for pair in [[1, 1.0], [2, 1.8], [3, 2.5], [4, 3.1], [5, 3.6], [8, 4.5], [12, 5.2], [20, 5.2]]:
        check_approx(ProjectStaffSimulator.team_output_multiplier(int(pair[0])), float(pair[1]),
            "team output for %d people" % int(pair[0]))

    var large_team: Array[Employee] = []
    for index in 12:
        var member := Employee.new()
        member.id = "large_team_%d" % index
        large_team.append(member)
    var large := ProjectStaffSimulator.effects(
        {"game_designer": large_team[0].id}, large_team, {large_team[0].id: 45}, 0, 50)
    check_equal(int(large["contributors"]), 12, "everyone counts as a contributor")
    check_equal(int(large["named_contributors"]), 1, "but only one holds a named role")
    check_approx(float(large["effective_team_output"]), 5.2, "a twelve-person team is capped")

    check_approx(ProjectStaffSimulator.chemistry_speed_multiplier(100), 1.05, "great chemistry speeds work")
    check_approx(ProjectStaffSimulator.chemistry_speed_multiplier(0), 0.92, "poor chemistry slows it")
    check_approx(ProjectStaffSimulator.chemistry_bug_multiplier(100), 0.95, "great chemistry reduces bugs")

    var chemistry_team := StudioTeam.new()
    chemistry_team.weeks_together = 52
    chemistry_team.recent_result = 80
    for person in [weak, strong]:
        person.teamwork = 75
        person.morale = 80
    weak.leadership = 40
    strong.leadership = 80
    weak.trait_ids.assign(["team_player"])
    strong.trait_ids.assign(["team_player"])
    var harmonious := TeamManager.chemistry_target(chemistry_team, [weak, strong])
    strong.trait_ids.assign(["lone_wolf"])
    var conflicted := TeamManager.chemistry_target(chemistry_team, [weak, strong])
    check_greater(harmonious, conflicted, "clashing personalities lower chemistry")

func _traits() -> void:
    section("traits")
    programmer.trait_ids.assign([])
    var ordinary := ProjectStaffSimulator.effects(
        {"lead_programmer": programmer.id}, [programmer], {programmer.id: 50}, 0)
    programmer.trait_ids.assign(["lone_wolf"])
    var lone_wolf := ProjectStaffSimulator.effects(
        {"lead_programmer": programmer.id}, [programmer], {programmer.id: 50}, 0)
    check_greater(float(lone_wolf["programming"]), float(ordinary["programming"]),
        "a lone wolf codes better alone")

    producer.trait_ids.assign(["perfectionist"])
    var perfectionist := ProjectStaffSimulator.effects(
        {"producer": producer.id}, [producer], {producer.id: 40}, 0)
    check_greater(float(perfectionist["polish_production"]), float(perfectionist["production"]),
        "a perfectionist polishes more than they produce")
    check_less(float(perfectionist["trait_speed"]), 1.0, "and works more slowly")

    programmer.trait_ids.assign([])
    var ordinary_overload := ProjectStaffSimulator.effects(
        {"lead_programmer": programmer.id}, [programmer], {programmer.id: 140}, 0)
    programmer.trait_ids.assign(["workhorse"])
    var workhorse := ProjectStaffSimulator.effects(
        {"lead_programmer": programmer.id}, [programmer], {programmer.id: 140}, 0)
    check_greater(float(workhorse["programming"]), float(ordinary_overload["programming"]),
        "a workhorse handles overtime better")
    check_less(float(workhorse["overload"]), float(ordinary_overload["overload"]),
        "and feels the overload less")

func _skill_progression() -> void:
    section("skill progression")
    var learner := Employee.new()
    learner.id = "fast_learner"
    learner.programming = 40
    learner.trait_ids.assign(["fast_learner"])
    EmployeeManager.award_skill_experience(learner, "programming", 60)
    check_equal(int(learner.skill_experience["programming"]), 75, "a fast learner gains extra xp")
    check_equal(EmployeeManager.skill_level(learner, "programming"), 2, "which reaches level 2")
    check_equal(learner.programming, 45, "and raises the underlying skill")

    # Three years of weekly lead work turns a 42-skill junior into a veteran.
    var veteran := Employee.new()
    veteran.programming = 42
    for week in range(52 * 3):
        EmployeeManager.award_skill_experience(veteran, "programming", 10)
    check_equal(EmployeeManager.skill_level(veteran, "programming"), 6, "three years reaches level 6")
    check_equal(veteran.programming, 67, "and a much higher skill")
    check_equal(veteran.design, 0, "without teaching them anything else")

    var xp_founder := EmployeeManager.founder()
    var before := int(xp_founder.skill_experience.get("programming", 0))
    EmployeeManager.award_project_experience(project_a)
    check_greater(float(int(xp_founder.skill_experience["programming"])), float(before),
        "shipping a project teaches the people on it")

func _weekly_condition() -> void:
    section("weekly condition")
    var person := EmployeeManager.founder()
    person.stress = 0
    person.energy = 100
    person.morale = 100
    MoraleManager.process_week()
    check_greater(float(person.stress), 0.0, "a week of overload adds stress")
    check_less(float(person.energy), 100.0, "and drains energy")
    check_less(float(person.morale), 100.0, "and wears down morale")

func _persistence() -> void:
    section("teams and projects persist")
    team_b.chemistry = 78.0
    team_b.weeks_together = 20

    var restored_team := StudioTeam.from_dict(team_b.to_dict())
    check_equal(restored_team.project_id, project_b.id, "a team remembers its project")
    check_approx(restored_team.chemistry, 78.0, "and its chemistry")
    check_equal(restored_team.weeks_together, 20, "and how long it has been together")

    var restored_project := GameProject.from_dict(project_a.to_dict())
    check_equal(str(restored_project.role_assignments["writer"]), founder.id,
        "a project remembers who was assigned to it")
