extends Node

## Owns employee creation and workforce queries. Weekly condition, payroll,
## hiring and teams will join here in later M3 slices.

const SKILL_FIELDS := [
    "programming", "design", "art", "writing", "audio", "production",
    "testing", "research"
]
const MAX_SKILL_LEVEL := 10
const SKILL_POINTS_PER_LEVEL := 5
const SENIORITY := {
    "intern": {
        "primary": Vector2i(30, 49), "secondary": Vector2i(18, 35),
        "other": Vector2i(3, 22), "generalist": Vector2i(18, 38),
        "attribute": Vector2i(30, 54), "salary": 0.55, "age": Vector2i(18, 23)
    },
    "junior": {
        "primary": Vector2i(48, 66), "secondary": Vector2i(24, 44),
        "other": Vector2i(5, 28), "generalist": Vector2i(24, 48),
        "attribute": Vector2i(35, 58), "salary": 0.72, "age": Vector2i(19, 27)
    },
    "mid": {
        "primary": Vector2i(65, 82), "secondary": Vector2i(32, 54),
        "other": Vector2i(8, 34), "generalist": Vector2i(36, 61),
        "attribute": Vector2i(44, 67), "salary": 1.0, "age": Vector2i(24, 38)
    },
    "senior": {
        "primary": Vector2i(82, 96), "secondary": Vector2i(40, 64),
        "other": Vector2i(7, 32), "generalist": Vector2i(48, 72),
        "attribute": Vector2i(54, 78), "salary": 1.55, "age": Vector2i(29, 52)
    },
    # Promote-only: candidate generation never asks for this band, but pricing
    # a promotion to Lead reads its salary multiplier like any other rung.
    "lead": {
        "primary": Vector2i(88, 99), "secondary": Vector2i(46, 70),
        "other": Vector2i(8, 34), "generalist": Vector2i(54, 78),
        "attribute": Vector2i(60, 84), "salary": 2.05, "age": Vector2i(33, 55)
    }
}

func _ready() -> void:
    EventBus.game_sales_ended.connect(award_reputation)
    EventBus.game_released.connect(record_shipped_project)
    EventBus.project_abandoned.connect(record_abandoned_project)

func generate_candidate(
    role_id: String,
    seniority_id: String = "junior",
    full_name: String = "",
    generation_seed: int = 0,
    rarity_id: String = "common"
) -> Employee:
    ## Produces an applicant, not an active employee. The hiring system can
    ## assign the stable id and hire date only when an offer is accepted.
    var role_data := DataManager.get_employee_role(role_id)
    if role_data.is_empty():
        push_error("Unknown employee role: %s" % role_id)
        return null
    if not SENIORITY.has(seniority_id):
        push_error("Unknown employee seniority: %s" % seniority_id)
        return null

    var rng := RandomNumberGenerator.new()
    if generation_seed == 0:
        rng.randomize()
    else:
        rng.seed = generation_seed

    var employee := Employee.new()
    var candidate_name := full_name.strip_edges()
    if candidate_name.is_empty():
        candidate_name = _generated_name(rng)
    var names := _split_name(candidate_name)
    employee.first_name = names[0]
    employee.last_name = names[1]
    employee.pronoun_id = pronouns_for(names[0], rng)
    employee.portrait_seed = rng.randi_range(1, 2_147_483_647)
    employee.role = role_id
    employee.seniority = seniority_id
    employee.status = "candidate"
    employee.employer = "unemployed"

    var band: Dictionary = SENIORITY[seniority_id]
    employee.age = _roll_range(rng, band["age"])
    employee.reputation = _rolled_reputation(rng, seniority_id)

    var primary := str(role_data.get("primary_skill", ""))
    var secondary := str(role_data.get("secondary_skill", ""))
    for skill in SKILL_FIELDS:
        var bounds: Vector2i
        if role_id == "generalist":
            bounds = band["generalist"]
        elif skill == primary:
            bounds = band["primary"]
        elif skill == secondary:
            bounds = band["secondary"]
        else:
            bounds = band["other"]
        employee.set(skill, _roll_range(rng, bounds))

    var attribute_range: Vector2i = band["attribute"]
    for attribute in ["creativity", "speed", "quality", "teamwork", "adaptability", "leadership"]:
        employee.set(attribute, _roll_range(rng, attribute_range))

    # These adjustments give non-production roles recognizable working styles
    # while their eight skills remain the main source of specialization.
    if role_id in ["designer", "artist", "writer", "audio_designer"]:
        employee.creativity = mini(employee.creativity + 12, 100)
    if role_id == "qa_tester":
        employee.quality = mini(employee.quality + 12, 100)
    if role_id == "producer":
        employee.leadership = mini(employee.leadership + 18, 100)
        employee.teamwork = mini(employee.teamwork + 10, 100)
    if role_id == "generalist":
        employee.adaptability = mini(employee.adaptability + 15, 100)
    employee.trait_ids = _personality_traits(rng)

    # A rare find is rare because they are genuinely better at the job, not
    # just because the market says so -- the stat bonus comes first, and the
    # salary premium below is on top of what those better stats already buy.
    employee.rarity_id = rarity_id
    var rarity := DataManager.get_candidate_rarity(rarity_id)
    var stat_bonus := int(rarity.get("stat_bonus", 0))
    if stat_bonus > 0:
        if not primary.is_empty():
            employee.set(primary, mini(int(employee.get(primary)) + stat_bonus, 100))
        if not secondary.is_empty():
            employee.set(secondary, mini(
                int(employee.get(secondary)) + int(round(stat_bonus * 0.5)), 100))

    # What they ask for follows from what they now are: skills, seniority,
    # traits, reputation and experience, priced the same way as everybody
    # already on the payroll -- plus a rarity premium on top, since a rare
    # find knows their own worth.
    var rarity_salary_multiplier := float(rarity.get("salary_multiplier", 1.0))
    var market_noise := rng.randf_range(0.94, 1.06)
    employee.salary = int(round(
        float(EmployeeValueSimulator.market_value(employee))
        * market_noise * rarity_salary_multiplier / 25.0)) * 25
    employee.hiring_fee = int(round(float(employee.salary) * 0.45 / 50.0)) * 50
    return employee

func _rolled_reputation(rng: RandomNumberGenerator, seniority_id: String) -> int:
    ## Most candidates are unknowns. A little more often at senior level, the
    ## market turns up somebody with a name already -- a known quantity who
    ## will cost accordingly and bring some shine to the roster.
    const CHANCE := {"intern": 0.0, "junior": 0.02, "mid": 0.06, "senior": 0.14}
    if rng.randf() >= float(CHANCE.get(seniority_id, 0.03)):
        return 0
    return rng.randi_range(28, 70)

func role_name(role_id: String) -> String:
    if role_id == "founder":
        return "Founder"
    var role_data := DataManager.get_employee_role(role_id)
    return str(role_data.get("name", role_id.capitalize()))

func job_title(employee: Employee) -> String:
    var name := role_name(employee.role)
    if employee.role in ["founder", "generalist"]:
        return name
    if employee.seniority == "lead":
        return "Lead %s" % name
    if employee.seniority == "senior":
        return "Senior %s" % name
    if employee.seniority == "junior":
        return "Junior %s" % name
    if employee.seniority == "intern":
        return "%s Intern" % name
    return name

func create_founder(full_name: String) -> Employee:
    var employee := Employee.new()
    var names := _split_name(full_name)
    employee.id = GameState.next_employee_id()
    employee.first_name = names[0]
    employee.last_name = names[1]
    employee.age = 24
    employee.hire_year = TimeManager.current_year
    employee.hire_month = TimeManager.current_month
    employee.hire_week = TimeManager.current_week
    employee.role = "founder"
    employee.seniority = "founder"
    employee.pronoun_id = GameState.founder_pronoun_id
    employee.salary = 0
    employee.employer = "player"

    # A local seeded generator makes each founder distinct and reproducible
    # without consuming randomness used by development and sales.
    var rng := RandomNumberGenerator.new()
    rng.seed = absi(hash("%s|%s" % [GameState.company_name, full_name]))
    employee.portrait_seed = rng.randi_range(1, 2_147_483_647)

    employee.programming = rng.randi_range(48, 64)
    employee.design = rng.randi_range(46, 62)
    employee.art = rng.randi_range(12, 32)
    employee.writing = rng.randi_range(28, 50)
    employee.audio = rng.randi_range(5, 22)
    employee.production = rng.randi_range(24, 43)
    employee.testing = rng.randi_range(30, 52)
    employee.research = rng.randi_range(34, 54)
    _apply_background(employee, GameState.founder_background_id)

    employee.creativity = rng.randi_range(55, 70)
    employee.speed = rng.randi_range(48, 64)
    employee.quality = rng.randi_range(52, 68)
    employee.teamwork = rng.randi_range(42, 62)
    employee.adaptability = rng.randi_range(55, 72)
    employee.leadership = rng.randi_range(30, 50)
    # A deliberate choice, not the random 1-2 traits everybody else rolls --
    # see GameState.founder_trait_id and data/employee_traits.json.
    var trait_id := GameState.founder_trait_id
    if not DataManager.get_employee_trait(trait_id).is_empty():
        var chosen: Array[String] = [trait_id]
        employee.trait_ids = chosen
    else:
        employee.trait_ids = _personality_traits(rng)
    return employee

func _apply_background(employee: Employee, background_id: String) -> void:
    ## A one-time tilt to the founder's rolled starting skills -- replayability,
    ## not a promotion or a specialization. See data/founder_backgrounds.json.
    var background := DataManager.get_founder_background(background_id)
    if background.is_empty():
        return
    var modifiers: Dictionary = background.get("skill_modifiers", {})
    for skill in modifiers:
        if skill not in SKILL_FIELDS:
            continue
        employee.set(skill, clampi(int(employee.get(skill)) + int(modifiers[skill]), 0, 100))

func seed_founder() -> Employee:
    GameState.employees.clear()
    GameState.next_employee_number = 1
    var founder := create_founder(GameState.founder_name)
    GameState.employees.append(founder)
    return founder

func ensure_founder() -> Employee:
    var existing := founder()
    if existing != null:
        return existing
    var created := create_founder(GameState.founder_name)
    GameState.employees.push_front(created)
    return created

func founder() -> Employee:
    for employee in GameState.employees:
        if employee.is_founder():
            return employee
    return null

func find_employee(employee_id: String) -> Employee:
    for employee in GameState.employees:
        if employee.id == employee_id:
            return employee
    return null

func find_any_employee(employee_id: String) -> Employee:
    ## Also checks people who have since left, for history that outlives them.
    var found := find_employee(employee_id)
    if found != null:
        return found
    for employee in GameState.departed_employees:
        if employee.id == employee_id:
            return employee
    return null

func trait_name(trait_id: String) -> String:
    var trait_data := DataManager.get_employee_trait(trait_id)
    return str(trait_data.get("name", trait_id.capitalize()))

func trait_description(trait_id: String) -> String:
    return str(DataManager.get_employee_trait(trait_id).get("description", ""))

func skill_level(employee: Employee, skill: String) -> int:
    return maxi(int(employee.skill_levels.get(skill, 1)), 1)

func skill_xp_progress(employee: Employee, skill: String) -> float:
    var level := skill_level(employee, skill)
    if level >= MAX_SKILL_LEVEL:
        return 1.0
    var xp := int(employee.skill_experience.get(skill, 0))
    var floor_xp := _skill_level_threshold(level)
    var ceiling_xp := _skill_level_threshold(level + 1)
    return clampf(float(xp - floor_xp) / float(ceiling_xp - floor_xp), 0.0, 1.0)

func award_skill_experience(employee: Employee, skill: String, amount: int) -> void:
    if employee == null or skill not in SKILL_FIELDS or amount <= 0:
        return
    if "fast_learner" in employee.trait_ids:
        amount = int(round(float(amount) * 1.25))
    employee.skill_experience[skill] = int(employee.skill_experience.get(skill, 0)) + amount
    employee.experience += amount
    var old_overall_level := employee.level
    employee.level = maxi(1 + int(employee.experience / 300), 1)
    if employee.level > old_overall_level:
        employee.training_points += employee.level - old_overall_level

    var level := skill_level(employee, skill)
    while level < MAX_SKILL_LEVEL and int(employee.skill_experience[skill]) >= _skill_level_threshold(level + 1):
        level += 1
        employee.skill_levels[skill] = level
        employee.set(skill, mini(int(employee.get(skill)) + SKILL_POINTS_PER_LEVEL, 100))
        EventBus.employee_skill_level_up.emit(employee, skill, level)
        EventBus.notify("SKILL IMPROVED", "%s reached %s level %d" % [
            employee.display_name(), skill.capitalize(), level
        ])

func award_project_experience(project: GameProject) -> void:
    var assigned: Array[String] = []
    for role in TeamManager.PROJECT_ROLES:
        var employee_id := str(project.role_assignments.get(role["id"], ""))
        var employee := find_employee(employee_id)
        if employee == null:
            continue
        award_skill_experience(employee, str(role["skill"]), 10)
        if employee_id not in assigned:
            assigned.append(employee_id)

    # Non-lead team members learn more slowly in their employment specialty.
    var credited := assigned.duplicate()
    for employee in TeamManager.working_members(project.team_id):
        if employee.id not in credited:
            credited.append(employee.id)
        if employee.id in assigned:
            continue
        var role := DataManager.get_employee_role(employee.role)
        var specialty := str(role.get("primary_skill", ""))
        if specialty.is_empty():
            specialty = _strongest_skill(employee)
        award_skill_experience(employee, specialty, 4)

    # Kept fresh every week, so by the time this game's sales run ends -- long
    # after the team has moved on to something else -- reputation still finds
    # the people who actually built it.
    project.credited_employee_ids = credited

func active_employees() -> Array[Employee]:
    var result: Array[Employee] = []
    for employee in GameState.employees:
        if employee.is_active():
            result.append(employee)
    return result

func monthly_payroll() -> int:
    var total := 0
    for employee in active_employees():
        total += employee.salary
    return total

func monthly_expenses() -> Dictionary:
    var office := DataManager.get_office(GameState.office_id)
    if office.is_empty():
        office = DataManager.get_office("bedroom")
    var salaries := monthly_payroll()
    var rent := OfficeManager.monthly_rent(office)
    var utilities := FinanceManager.expense(int(office.get("utilities", 0)))
    var software := FinanceManager.expense(
        int(office.get("software_per_employee", 0)) * active_employees().size()
    )
    return {
        "salaries": salaries,
        "rent": rent,
        "utilities": utilities,
        "software": software,
        "total": salaries + rent + utilities + software
    }

func forecast_monthly_expenses(extra_salary: int) -> Dictionary:
    ## What the books would look like with one more employee on payroll --
    ## for weighing an offer before it is made. Rent and utilities are fixed
    ## per office, but software licences scale with headcount, so a would-be
    ## hire is added to both before totalling.
    var office := DataManager.get_office(GameState.office_id)
    if office.is_empty():
        office = DataManager.get_office("bedroom")
    var salaries := monthly_payroll() + maxi(extra_salary, 0)
    var rent := OfficeManager.monthly_rent(office)
    var utilities := FinanceManager.expense(int(office.get("utilities", 0)))
    var software := FinanceManager.expense(
        int(office.get("software_per_employee", 0)) * (active_employees().size() + 1)
    )
    return {
        "salaries": salaries,
        "rent": rent,
        "utilities": utilities,
        "software": software,
        "total": salaries + rent + utilities + software
    }

func process_week() -> void:
    # Morale, stress and energy are MoraleManager's business now.
    if TimeManager.current_week != 1:
        return
    var costs := monthly_expenses()
    if int(costs["salaries"]) > 0:
        FinanceManager.force_spend(int(costs["salaries"]), Ledger.Kind.PAYROLL, "Employee salaries")
    if int(costs["rent"]) > 0:
        FinanceManager.force_spend(int(costs["rent"]), Ledger.Kind.OFFICE, "Office rent")
    if int(costs["utilities"]) > 0:
        FinanceManager.force_spend(int(costs["utilities"]), Ledger.Kind.UTILITIES, "Utilities")
    if int(costs["software"]) > 0:
        FinanceManager.force_spend(int(costs["software"]), Ledger.Kind.SOFTWARE, "Software licences")

func _split_name(full_name: String) -> Array[String]:
    var clean := full_name.strip_edges()
    if clean.is_empty():
        return ["You", ""]
    var space := clean.find(" ")
    if space < 0:
        return [clean, ""]
    return [clean.left(space), clean.substr(space + 1).strip_edges()]

func _roll_range(rng: RandomNumberGenerator, bounds: Vector2i) -> int:
    return rng.randi_range(bounds.x, bounds.y)

## First names that usually go with a particular set. Anything not listed
## here — including a name the player typed — gets whichever set the roll
## lands on, because a name does not tell you somebody's pronouns.
const NAME_PRONOUNS := {
    "Maya": "she", "Priya": "she", "Ines": "she", "Nadia": "she", "Clara": "she",
    "Hana": "she", "Rosa": "she", "Freya": "she",
    "Marcus": "he", "Dev": "he", "Tomas": "he", "Ivan": "he", "Omar": "he",
    "Leo": "he", "Hugo": "he", "Malik": "he"
}

func pronouns_for(first_name: String, rng: RandomNumberGenerator) -> String:
    if NAME_PRONOUNS.has(first_name):
        return str(NAME_PRONOUNS[first_name])
    return Pronouns.random(rng)

func _generated_name(rng: RandomNumberGenerator) -> String:
    ## Pools live in data/first_names.json and data/last_names.json (see
    ## DataManager), not here, so new names -- or a future locale -- are a
    ## data change, not a code change.
    var first_names := DataManager.first_names if not DataManager.first_names.is_empty() else ["Alex"]
    var last_names := DataManager.last_names if not DataManager.last_names.is_empty() else ["Morgan"]
    return "%s %s" % [first_names[rng.randi_range(0, first_names.size() - 1)],
        last_names[rng.randi_range(0, last_names.size() - 1)]]

func _personality_traits(rng: RandomNumberGenerator) -> Array[String]:
    const PERSONALITIES := [
        "perfectionist", "workhorse", "team_player", "lone_wolf",
        "visionary", "bug_hunter", "fast_learner", "people_person", "technical_genius"
    ]
    var result: Array[String] = [PERSONALITIES[rng.randi_range(0, PERSONALITIES.size() - 1)]]
    if rng.randf() < 0.30:
        var second: String = PERSONALITIES[rng.randi_range(0, PERSONALITIES.size() - 1)]
        if second not in result:
            result.append(second)
    return result

func _skill_level_threshold(level: int) -> int:
    var completed := maxi(level - 1, 0)
    return int(75 * completed * (completed + 1) / 2)

func _strongest_skill(employee: Employee) -> String:
    var best := "programming"
    for skill in SKILL_FIELDS:
        if int(employee.get(skill)) > int(employee.get(best)):
            best = skill
    return best

# --- Personal reputation -------------------------------------------------

func award_reputation(project: GameProject) -> void:
    ## A game's whole run is over; judge it once, with the final numbers, and
    ## credit whoever actually built it.
    if project == null or not EmployeeReputationSimulator.is_major_hit(project):
        return
    var leads := {}
    for employee_id in project.role_assignments.values():
        leads[str(employee_id)] = true

    for employee_id in project.credited_employee_ids:
        var employee := find_employee(str(employee_id))
        if employee == null:
            continue
        var gain := EmployeeReputationSimulator.reputation_gain(project, leads.has(employee.id))
        if gain > 0:
            _grant_reputation(employee, gain, project)

func _grant_reputation(employee: Employee, gain: int, project: GameProject) -> void:
    ## Every system tells its story through NewsManager, not here -- this only
    ## announces what changed.
    var before := employee.reputation
    employee.reputation = clampi(before + gain, 0, 100)
    if employee.reputation == before:
        return
    EventBus.employee_reputation_gained.emit(employee, project, employee.reputation - before)

    var was := EmployeeReputationSimulator.tier_label(before, employee.role)
    var now := EmployeeReputationSimulator.tier_label(employee.reputation, employee.role)
    if now != was and not now.is_empty():
        EventBus.employee_tier_up.emit(employee, now)

func highest_reputation() -> int:
    ## The most famous name currently on the payroll. Candidates look at this
    ## roster the same way a player does.
    var best := 0
    for employee in active_employees():
        best = maxi(best, employee.reputation)
    return best

func average_morale() -> float:
    ## How the people already here feel, on the whole -- word of that is part
    ## of what the studio is worth working for. The founder counts: a
    ## one-person studio is judged on how its founder is doing. 50 when empty.
    var people := active_employees()
    if people.is_empty():
        return 50.0
    var total := 0.0
    for employee in people:
        total += float(employee.morale)
    return total / float(people.size())

func reputation_tier(employee: Employee) -> String:
    if employee == null:
        return ""
    return EmployeeReputationSimulator.tier_label(employee.reputation, employee.role)

# --- Career history ----------------------------------------------------
## Each person keeps a running record -- pay, promotions, courses and the
## games they shipped -- that outlives their employment. The HR systems call
## in here as those things happen; game releases arrive on the event bus.

func record_hire(employee: Employee) -> void:
    ## Their first salary line is the offer they accepted.
    if employee != null and employee.salary_history.is_empty():
        _append_salary(employee, employee.salary, "Starting salary")

func record_salary_change(employee: Employee, amount: int, reason: String) -> void:
    _append_salary(employee, amount, reason)

func record_promotion(employee: Employee, from_seniority: String, to_seniority: String) -> void:
    ## Call after the new seniority and salary are already on the employee.
    if employee == null:
        return
    employee.promotion_history.append({
        "from": from_seniority, "to": to_seniority, "salary": employee.salary,
        "year": TimeManager.current_year,
        "month": TimeManager.current_month,
        "week": TimeManager.current_week
    })
    _append_salary(employee, employee.salary, "Promotion to %s" % to_seniority.capitalize())

func record_training(
    employee: Employee, course_id: String, course_name: String, skill: String, gain: int
) -> void:
    if employee == null:
        return
    employee.training_history.append({
        "course_id": course_id, "course_name": course_name,
        "skill": skill, "gain": gain,
        "year": TimeManager.current_year,
        "month": TimeManager.current_month,
        "week": TimeManager.current_week
    })

func record_shipped_project(project: GameProject) -> void:
    _record_project(project, true)

func record_abandoned_project(project: GameProject) -> void:
    _record_project(project, false)

func _append_salary(employee: Employee, amount: int, reason: String) -> void:
    if employee == null:
        return
    employee.salary_history.append({
        "amount": amount, "reason": reason,
        "year": TimeManager.current_year,
        "month": TimeManager.current_month,
        "week": TimeManager.current_week
    })

func _record_project(project: GameProject, shipped: bool) -> void:
    ## Credit everybody who actually worked on it -- the refreshed contributor
    ## list, plus anyone still holding a named role -- and note the role they
    ## held. Works for people who have since left, so the record is complete.
    if project == null:
        return

    var role_by_id := {}
    for role_id in project.role_assignments:
        role_by_id[str(project.role_assignments[role_id])] = str(role_id)

    var contributors: Array = project.credited_employee_ids.duplicate()
    for assigned_id in project.role_assignments.values():
        var person_id := str(assigned_id)
        if not person_id.is_empty() and person_id not in contributors:
            contributors.append(person_id)

    var year := project.release_year if shipped else TimeManager.current_year
    var month := project.release_month if shipped else TimeManager.current_month
    var week := project.release_week if shipped else TimeManager.current_week

    for employee_id in contributors:
        var employee := find_any_employee(str(employee_id))
        if employee == null or _has_project_entry(employee, project.id):
            continue
        employee.project_history.append({
            "project_id": project.id,
            "title": project.title,
            "role": str(role_by_id.get(employee.id, "support")),
            "seniority": employee.seniority,
            "review_score": project.review_score if shipped else 0.0,
            "shipped": shipped,
            "year": year, "month": month, "week": week
        })

func _has_project_entry(employee: Employee, project_id: String) -> bool:
    for entry in employee.project_history:
        if str(entry.get("project_id", "")) == project_id:
            return true
    return false
