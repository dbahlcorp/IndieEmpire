extends Node

## Owns the small rotating pool of available talent and converts accepted
## applicants into persistent employees.

const MARKET_SIZE := 3
const ROTATION_WEEKS := 4

func process_week() -> void:
    GameState.labor_market_weeks_left -= 1
    if GameState.labor_market_weeks_left <= 0:
        refresh_market()

func refresh_market(notify: bool = true) -> void:
    GameState.labor_candidates.clear()
    GameState.labor_market_generation += 1
    GameState.labor_market_weeks_left = ROTATION_WEEKS

    var attraction := company_attractiveness()
    var seniority_weights := RecruitmentSimulator.seniority_weights(attraction)
    var role_weights := RecruitmentSimulator.role_weights(attraction)
    var rarity_weights := _rarity_weights()

    for index in MARKET_SIZE:
        var seed_value := absi(hash("%s|%d|%d" % [
            GameState.company_name, GameState.labor_market_generation, index
        ]))
        var rng := RandomNumberGenerator.new()
        rng.seed = seed_value
        var seniority := _weighted_pick(rng, seniority_weights)
        var role := _weighted_pick(rng, role_weights)
        var rarity := _weighted_pick(rng, rarity_weights)
        var candidate := EmployeeManager.generate_candidate(
            role, seniority, "", seed_value + 17, rarity)
        if candidate != null:
            GameState.labor_candidates.append(candidate)

    if notify:
        EventBus.labor_market_refreshed.emit()
        EventBus.notify("AVAILABLE TALENT", "New candidates are looking for work")

func make_offer(candidate: Employee, offered_salary: int, forced_roll: float = -1.0) -> Dictionary:
    if candidate == null or not GameState.labor_candidates.has(candidate):
        return {"status": "invalid", "chance": 0.0}
    if not OfficeManager.has_capacity():
        return {"status": "office_full", "chance": 0.0}
    if not FinanceManager.can_afford(candidate.hiring_fee):
        return {"status": "unaffordable", "chance": 0.0}

    offered_salary = maxi(offered_salary, 0)
    var chance := RecruitmentSimulator.acceptance_probability(
        candidate.salary, offered_salary, company_attractiveness()
    )
    var roll := randf() if forced_roll < 0.0 else forced_roll
    if roll > chance:
        GameState.labor_candidates.erase(candidate)
        EventBus.notify("OFFER DECLINED", "%s declined your offer" % candidate.display_name(), true)
        SaveManager.autosave()
        return {"status": "declined", "chance": chance}

    candidate.salary = offered_salary
    _complete_hire(candidate)
    return {"status": "accepted", "chance": chance}

func _complete_hire(candidate: Employee) -> void:
    FinanceManager.spend(
        candidate.hiring_fee, Ledger.Kind.HIRING,
        "%s hiring fee" % candidate.display_name()
    )

    candidate.id = GameState.next_employee_id()
    candidate.status = "active"
    candidate.employer = "player"
    candidate.hire_year = TimeManager.current_year
    candidate.hire_month = TimeManager.current_month
    candidate.hire_week = TimeManager.current_week
    GameState.labor_candidates.erase(candidate)
    GameState.employees.append(candidate)
    EmployeeManager.record_hire(candidate)

    # Put them on a team immediately. A hire who is paid but assigned to
    # nothing contributes nothing, which reads as a bug rather than a choice.
    TeamManager.assign_employee(candidate, TeamManager.team_for_new_hire())

    EventBus.employee_hired.emit(candidate)
    EventBus.notify("WELCOME ABOARD", "%s joined as %s" % [
        candidate.display_name(), EmployeeManager.job_title(candidate)
    ], true)
    SaveManager.autosave()

func company_attractiveness() -> float:
    var best := CompanyStats.highest_rated()
    var highest_review := best.review_score if best != null else 0.0
    # Word gets round about who is worth working for.
    var loyalty_bonus := CultureSimulator.recruitment_bonus(
        CultureManager.value("employee_loyalty"))
    # A famous name on the roster draws applicants of its own.
    var fame_bonus := float(EmployeeManager.highest_reputation()) * 0.10
    var score := RecruitmentSimulator.attractiveness(
        GameState.employer_reputation,
        EmployeeManager.active_employees().size(),
        highest_review,
        salary_competitiveness(),
        OfficeManager.recruiting_quality(),
        profitability_score(),
        crunch_culture_score(),
        EmployeeManager.average_morale(),
        RetentionManager.recent_layoff_count()
    )
    return clampf(score + loyalty_bonus + fame_bonus, 0.0, 100.0)

func crunch_culture_score() -> float:
    ## How the studio's work-life balance reads to an outsider. The standing
    ## culture value, dragged down further while a team is actually crunching
    ## right now -- that is the loudest possible signal about the place.
    var score := CultureManager.value("work_life_balance")
    if not GameState.crunch_teams.is_empty():
        score -= 18.0
    return clampf(score, 0.0, 100.0)

func employer_reputation() -> Dictionary:
    ## The star rating the hiring screen shows: {score, stars, label, display}.
    return RecruitmentSimulator.employer_reputation(company_attractiveness())

func salary_competitiveness() -> float:
    var actual := 0.0
    var expected := 0.0
    for employee in EmployeeManager.active_employees():
        if employee.is_founder():
            continue
        var role_data := DataManager.get_employee_role(employee.role)
        var band: Dictionary = EmployeeManager.SENIORITY.get(employee.seniority, {})
        if role_data.is_empty() or band.is_empty():
            continue
        actual += employee.salary
        expected += float(role_data.get("base_salary", 2300)) * float(band.get("salary", 1.0))
    return actual / expected if expected > 0.0 else 0.85

func profitability_score() -> float:
    var row: Dictionary = GameState.annual_finance.get(str(TimeManager.current_year), {})
    if row.is_empty():
        return 40.0
    var income := float(row.get("income", 0))
    var expenses := float(row.get("expenses", 0))
    var scale := maxf(expenses, 1000.0)
    var margin := clampf((income - expenses) / scale, -1.0, 1.0)
    return 50.0 + margin * 50.0

func _rarity_weights() -> Dictionary:
    ## Flat, not attraction-scaled -- how good a studio is to work for changes
    ## who is willing to work there, not how rare genuine talent is.
    var weights := {}
    for rarity in DataManager.candidate_rarities:
        weights[str(rarity.get("id", ""))] = int(rarity.get("weight", 0))
    return weights if not weights.is_empty() else {"common": 1}

func _weighted_pick(rng: RandomNumberGenerator, weights: Dictionary) -> String:
    var total := 0
    for weight in weights.values():
        total += maxi(int(weight), 0)
    if total <= 0:
        return str(weights.keys()[0])
    var roll := rng.randi_range(1, total)
    var running := 0
    for key in weights:
        running += maxi(int(weights[key]), 0)
        if roll <= running:
            return str(key)
    return str(weights.keys()[-1])
