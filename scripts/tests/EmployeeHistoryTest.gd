extends TestCase

## Career history: the running record of pay, promotions, courses and shipped
## games that every employee keeps and takes with them when they leave.

func run() -> void:
    _starting_salary_on_hire()
    _raises_and_promotions()
    _training_is_logged()
    _shipping_a_game_credits_the_team()
    _abandoned_projects_count_as_worked_on_not_shipped()
    _derived_career_numbers()
    _history_survives_serialisation()
    _history_outlives_the_employee()
    _old_saves_backfill_from_shipped_games()

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    TimeManager.set_date(1985, 1, 1)
    FinanceManager.earn(500_000, Ledger.Kind.OTHER, "seed")
    OfficeManager.move_to("shared_workspace")

func _hire(role: String = "programmer", seniority: String = "junior") -> Employee:
    var candidate := EmployeeManager.generate_candidate(role, seniority)
    GameState.labor_candidates.append(candidate)
    LaborMarketManager.make_offer(candidate, candidate.salary, 0.0)
    return candidate

func _starting_salary_on_hire() -> void:
    section("a hire's first salary line is the offer they accepted")
    _company()
    var person := _hire("programmer", "junior")
    check_equal(person.salary_history.size(), 1, "one salary entry on day one")
    check_equal(int(person.salary_history[0]["amount"]), person.salary,
        "and it is what they are paid")
    check_equal(str(person.salary_history[0]["reason"]), "Starting salary", "labelled as such")
    check_equal(person.starting_salary(), person.salary, "starting_salary() reads it back")

func _raises_and_promotions() -> void:
    section("raises and promotions are both on the record")
    _company()
    var person := _hire("designer", "junior")
    var base := person.salary

    TimeManager.set_date(1985, 6, 1)
    EmployeeManager.record_salary_change(person, base + 500, "Raise")
    person.salary = base + 500
    check_equal(person.salary_history.size(), 2, "a raise adds a salary line")
    check_equal(str(person.salary_history[1]["reason"]), "Raise", "labelled a raise")

    TimeManager.set_date(1986, 1, 1)
    person.salary = base + 1200
    EmployeeManager.record_promotion(person, "junior", "mid")
    check_equal(person.promotion_history.size(), 1, "the promotion is recorded")
    check_equal(str(person.promotion_history[0]["from"]), "junior", "from the old tier")
    check_equal(str(person.promotion_history[0]["to"]), "mid", "to the new one")
    check_equal(int(person.promotion_history[0]["salary"]), base + 1200, "at the new salary")
    check_equal(person.salary_history.size(), 3, "and it also lands a salary line")
    check_equal(str(person.salary_history[2]["reason"]), "Promotion to Mid", "named for the step up")
    check_equal(person.career_summary()["promotions"], 1, "the summary counts it")

func _training_is_logged() -> void:
    section("finishing a course is logged with what it taught")
    _company()
    var person := _hire("programmer", "junior")
    var before := person.programming

    check(TrainingManager.enrol(person, "advanced_cpp", "programming"), "enrolled")
    for week in 4:
        TrainingManager.process_week()

    check_equal(person.training_history.size(), 1, "one completed course on the record")
    var entry: Dictionary = person.training_history[0]
    check_equal(str(entry["skill"]), "programming", "it knows the skill")
    check_greater(float(entry["gain"]), 0.0, "and the gain")
    check_equal(int(entry["gain"]), person.programming - before, "matching the actual improvement")
    check_not_empty(str(entry["course_name"]), "and names the course")

func _shipping_a_game_credits_the_team() -> void:
    section("a release writes itself into every credited person's history")
    _company()
    var lead := _hire("programmer", "mid")
    var helper := _hire("artist", "junior")

    var project := GameProject.new()
    project.id = GameState.next_project_id()
    project.title = "Starfall"
    project.review_score = 8.4
    project.role_assignments = {"lead_programmer": lead.id}
    project.credited_employee_ids = [lead.id, helper.id]
    project.release_year = 1986
    project.release_month = 3
    project.release_week = 2
    GameState.released_games.append(project)

    EventBus.game_released.emit(project)

    check_equal(lead.project_history.size(), 1, "the lead has the game on record")
    var lead_entry: Dictionary = lead.project_history[0]
    check_equal(str(lead_entry["title"]), "Starfall", "with its title")
    check_equal(str(lead_entry["role"]), "lead_programmer", "and the role they held")
    check(bool(lead_entry["shipped"]), "marked shipped")
    check_approx(float(lead_entry["review_score"]), 8.4, "with the review score")
    check_equal(int(lead_entry["year"]), 1986, "dated to release")

    check_equal(helper.project_history.size(), 1, "the supporting artist has it too")
    check_equal(str(helper.project_history[0]["role"]), "support",
        "credited as support with no named role")

    EventBus.game_released.emit(project)
    check_equal(lead.project_history.size(), 1, "a repeated signal does not double it up")

func _abandoned_projects_count_as_worked_on_not_shipped() -> void:
    section("an abandoned project is worked on but never shipped")
    _company()
    var person := _hire("programmer", "mid")

    var project := GameProject.new()
    project.id = GameState.next_project_id()
    project.title = "Vaporware"
    project.role_assignments = {"lead_programmer": person.id}
    project.credited_employee_ids = [person.id]
    GameState.active_projects.append(project)
    var team := TeamManager.find_team(person.assigned_team)
    if team != null:
        team.project_id = project.id

    GameState.abandon_project(project)

    check_equal(person.project_history.size(), 1, "it is on the record")
    check(not bool(person.project_history[0]["shipped"]), "but not as a shipment")
    check_equal(person.games_shipped_count(), 0, "so nothing counts as shipped")
    check_equal(person.career_summary()["projects_worked_on"], 1, "though it counts as worked on")

func _derived_career_numbers() -> void:
    section("games shipped, average review and best game are read off the history")
    _company()
    var person := _hire("designer", "mid")

    for row in [["A", 7.0, 1986], ["B", 9.0, 1987], ["C", 5.0, 1988]]:
        var project := GameProject.new()
        project.id = GameState.next_project_id()
        project.title = str(row[0])
        project.review_score = float(row[1])
        project.release_year = int(row[2])
        project.role_assignments = {"game_designer": person.id}
        project.credited_employee_ids = [person.id]
        GameState.released_games.append(project)
        EventBus.game_released.emit(project)

    check_equal(person.games_shipped_count(), 3, "three games shipped")
    check_approx(person.average_review_score(), 7.0, "average review across them")
    check_equal(str(person.highest_rated_game()["title"]), "B", "the best-reviewed one is found")

    var summary := person.career_summary()
    check_equal(str(summary["highest_rated_game"]), "B", "the summary agrees")
    check_approx(float(summary["highest_review_score"]), 9.0, "with its score")

func _history_survives_serialisation() -> void:
    section("every history list round-trips with its types intact")
    _company()
    var person := _hire("programmer", "mid")
    EmployeeManager.record_salary_change(person, person.salary + 400, "Raise")
    person.salary += 400
    EmployeeManager.record_promotion(person, "mid", "senior")
    EmployeeManager.record_training(person, "advanced_cpp", "Advanced C++", "programming", 5)
    person.awards.append({
        "award_id": "goty_1987", "name": "Game of the Year",
        "project_id": "project_000001", "year": 1987
    })
    var project := GameProject.new()
    project.id = "project_000001"
    project.title = "Starfall"
    project.review_score = 8.4
    project.role_assignments = {"lead_programmer": person.id}
    project.credited_employee_ids = [person.id]
    GameState.released_games.append(project)
    EventBus.game_released.emit(project)

    var restored := Employee.from_dict(person.to_dict())
    check_equal(restored.salary_history.size(), person.salary_history.size(),
        "salary history count")
    check_equal(restored.promotion_history.size(), 1, "promotion history count")
    check_equal(restored.training_history.size(), 1, "training history count")
    check_equal(restored.project_history.size(), 1, "project history count")
    check_equal(restored.awards.size(), 1, "awards count")

    check(restored.salary_history[0]["amount"] is int, "a salary amount comes back an int")
    check(restored.project_history[0]["review_score"] is float, "a review score comes back a float")
    check(restored.project_history[0]["shipped"] is bool, "shipped comes back a bool")
    check_equal(int(restored.awards[0]["year"]), 1987, "an award year survives")
    check_approx(restored.average_review_score(), 8.4, "derived numbers still work after a load")

func _history_outlives_the_employee() -> void:
    section("a leaver keeps their record, and it survives a save")
    _company()
    var person := _hire("programmer", "mid")
    var project := GameProject.new()
    project.id = GameState.next_project_id()
    project.title = "Starfall"
    project.review_score = 8.0
    project.role_assignments = {"lead_programmer": person.id}
    project.credited_employee_ids = [person.id]
    GameState.released_games.append(project)
    EventBus.game_released.emit(project)

    # Send them out of the door.
    person.notice_weeks = 1
    RetentionManager.process_week()
    check(GameState.departed_employees.has(person), "they have left")
    check_equal(person.project_history.size(), 1, "and took their credit with them")

    check(SaveManager.save_game("save_history"), "saved")
    GameState.reset_company()
    check(SaveManager.load_game("save_history"), "loaded")

    var restored := EmployeeManager.find_any_employee(person.id)
    if check_not_null(restored, "the former employee is still on file"):
        check_equal(restored.project_history.size(), 1, "with their shipped game intact")
        check_approx(restored.average_review_score(), 8.0, "and their average review")
    SaveManager.delete_save("save_history")

func _old_saves_backfill_from_shipped_games() -> void:
    section("a pre-v15 save reconstructs history from games already shipped")
    _company()
    var person := _hire("programmer", "mid")
    var project := GameProject.new()
    project.id = GameState.next_project_id()
    project.title = "Legacy Hit"
    project.review_score = 9.1
    project.role_assignments = {"lead_programmer": person.id}
    project.credited_employee_ids = [person.id]
    GameState.released_games.append(project)

    check(SaveManager.save_game("save_v14"), "saved")

    # Rewrite the file as a version 14 save with no history sections at all.
    var path := SaveManager.slot_path("save_v14")
    var file := FileAccess.open(path, FileAccess.READ)
    var data: Dictionary = JSON.parse_string(file.get_as_text())
    file.close()
    data["version"] = 14
    for entry in data.get("workforce", {}).get("employees", []):
        for key in ["project_history", "salary_history", "promotion_history",
                "training_history", "awards"]:
            entry.erase(key)
    file = FileAccess.open(path, FileAccess.WRITE)
    file.store_string(JSON.stringify(data, "\t"))
    file.close()

    GameState.reset_company()
    check(SaveManager.load_game("save_v14"), "the old save still loads")
    var restored := EmployeeManager.find_employee(person.id)
    if check_not_null(restored, "the employee came back"):
        check_equal(restored.project_history.size(), 1, "with the shipped game backfilled")
        check(bool(restored.project_history[0]["shipped"]), "as a shipment")
        check_approx(restored.average_review_score(), 9.1, "at the right score")
    SaveManager.delete_save("save_v14")
