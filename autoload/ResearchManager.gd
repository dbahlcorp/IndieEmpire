extends Node

## Owns research state: the point pool, which technologies are completed, and
## which are in progress. The maths lives in ResearchSimulator.
##
## Research is a project, not a purchase. Starting one on an available
## technology assigns one or more employees who are then unavailable for game
## work (Employee.is_away(), exactly like a trainee). Each week the project
## gains progress from its researchers plus a capped draw on the point pool;
## when progress reaches the technology's cost it completes and its capability
## unlocks.

func _ready() -> void:
    EventBus.game_released.connect(_on_game_released)

func technologies() -> Array:
    return DataManager.technologies

func technology(id: String) -> Dictionary:
    return DataManager.get_technology(id)

func starter_ids() -> Array:
    var ids: Array = []
    for tech in DataManager.technologies:
        if ResearchSimulator.is_starter(tech):
            ids.append(str(tech.get("id", "")))
    return ids

func reset() -> void:
    GameState.completed_technologies = starter_ids()
    GameState.active_research = []
    GameState.research_points = 0.0
    GameState.experimented_feature_ids = []

# --- Queries ----------------------------------------------------------

func is_completed(tech_id: String) -> bool:
    return GameState.completed_technologies.has(tech_id)

func is_researching(employee_id: String) -> bool:
    for entry in GameState.active_research:
        if employee_id in Array(entry.get("researcher_ids", [])):
            return true
    return false

func active() -> Array:
    return GameState.active_research

func active_for(tech_id: String) -> Dictionary:
    return ResearchSimulator.active_entry(GameState.active_research, tech_id)

func state_of(tech_id: String) -> String:
    return ResearchSimulator.state_of(
        technology(tech_id), GameState.completed_technologies,
        GameState.active_research, TimeManager.current_year)

func has_capability(tag: String) -> bool:
    return ResearchSimulator.has_capability(tag, GameState.completed_technologies)

func researchers_for(tech_id: String) -> Array:
    var people: Array = []
    for id in active_for(tech_id).get("researcher_ids", []):
        var employee := EmployeeManager.find_employee(str(id))
        if employee != null:
            people.append(employee)
    return people

func points() -> int:
    return int(floor(GameState.research_points))

# --- Starting and managing research ----------------------------------

func can_start(tech_id: String, employee_ids: Array = []) -> Dictionary:
    ## {ok: bool, reason: String} so the screen can explain a refusal.
    var tech := technology(tech_id)
    if tech.is_empty():
        return {"ok": false, "reason": "Unknown technology."}
    if is_completed(tech_id):
        return {"ok": false, "reason": "Already researched."}
    if not active_for(tech_id).is_empty():
        return {"ok": false, "reason": "Already being researched."}

    var skill := _best_research_skill(employee_ids)
    var missing := ResearchSimulator.missing_requirements(
        tech, GameState.completed_technologies, TimeManager.current_year, skill)
    if not missing.is_empty():
        return {"ok": false, "reason": ", ".join(missing)}

    for employee_id in employee_ids:
        var employee := EmployeeManager.find_employee(str(employee_id))
        if employee == null or not employee.is_active():
            return {"ok": false, "reason": "That employee is not available."}
        if TeamManager.employee_has_active_role(employee.id):
            return {"ok": false, "reason": "%s is working on a project." % employee.display_name()}
        if employee.is_away():
            return {"ok": false, "reason": "%s is unavailable this week." % employee.display_name()}
    return {"ok": true, "reason": ""}

func start(tech_id: String, employee_ids: Array = []) -> bool:
    if not bool(can_start(tech_id, employee_ids).get("ok", false)):
        return false
    var clean_ids: Array = []
    for id in employee_ids:
        clean_ids.append(str(id))
    GameState.active_research.append({
        "tech_id": tech_id,
        "progress": 0.0,
        "researcher_ids": clean_ids
    })
    EventBus.research_started.emit(tech_id, ResearchSimulator.display_name(technology(tech_id)))
    EventBus.notify("RESEARCH STARTED", ResearchSimulator.display_name(technology(tech_id)))
    SaveManager.autosave()
    return true

func assign_researcher(tech_id: String, employee_id: String) -> bool:
    var entry := active_for(tech_id)
    if entry.is_empty():
        return false
    var employee := EmployeeManager.find_employee(employee_id)
    if employee == null or not employee.is_active() or employee.is_away():
        return false
    if TeamManager.employee_has_active_role(employee.id):
        return false
    var ids: Array = entry["researcher_ids"]
    if employee_id in ids:
        return false
    ids.append(employee_id)
    SaveManager.autosave()
    return true

func unassign_researcher(tech_id: String, employee_id: String) -> bool:
    var entry := active_for(tech_id)
    if entry.is_empty():
        return false
    var ids: Array = entry["researcher_ids"]
    if employee_id not in ids:
        return false
    ids.erase(employee_id)
    SaveManager.autosave()
    return true

func cancel(tech_id: String) -> void:
    ## Progress is lost, the same trade TrainingManager.cancel() makes.
    var entry := active_for(tech_id)
    if entry.is_empty():
        return
    GameState.active_research.erase(entry)
    SaveManager.autosave()

# --- The weekly tick -------------------------------------------------

func process_week() -> void:
    var finished: Array = []
    for entry in GameState.active_research:
        var tech := technology(str(entry.get("tech_id", "")))
        if tech.is_empty():
            finished.append(entry)
            continue
        var cost := float(ResearchSimulator.research_cost(tech))
        var remaining := cost - float(entry.get("progress", 0.0))

        var researcher_output := ResearchSimulator.weekly_researchers_output(
            _living_researchers(entry))
        var pool_draw := ResearchSimulator.weekly_pool_draw(
            maxf(remaining - researcher_output, 0.0), GameState.research_points)
        GameState.research_points = maxf(GameState.research_points - pool_draw, 0.0)

        entry["progress"] = float(entry.get("progress", 0.0)) + researcher_output + pool_draw
        if float(entry["progress"]) >= cost:
            finished.append(entry)

    for entry in finished:
        _complete(entry)

func _living_researchers(entry: Dictionary) -> Array:
    var people: Array = []
    var kept: Array = []
    for id in entry.get("researcher_ids", []):
        var employee := EmployeeManager.find_employee(str(id))
        if employee != null and employee.is_active():
            people.append(employee)
            kept.append(str(id))
    entry["researcher_ids"] = kept
    return people

func _complete(entry: Dictionary) -> void:
    GameState.active_research.erase(entry)
    var tech_id := str(entry.get("tech_id", ""))
    var tech := technology(tech_id)
    if tech.is_empty() or is_completed(tech_id):
        return
    GameState.completed_technologies.append(tech_id)
    var name := ResearchSimulator.display_name(tech)
    EventBus.research_completed.emit(tech_id, name)
    EventBus.technology_researched.emit(tech_id, name)
    EventBus.notify("TECHNOLOGY RESEARCHED", name, true)
    NewsManager.post(
        NewsManager.COMPANY, "%s RESEARCH COMPLETE" % name.to_upper(),
        "%s has finished researching %s. %s" % [
            GameState.company_name, name,
            _capability_sentence(tech)])
    SaveManager.autosave()

func _capability_sentence(tech: Dictionary) -> String:
    var tags := ResearchSimulator.unlocks(tech)
    if tags.is_empty():
        return "It strengthens future engines built with it."
    return "New capability unlocked for engines and game features."

# --- Research points ------------------------------------------------

func award_research_points(amount: float, reason: String) -> void:
    if amount <= 0.0:
        return
    GameState.research_points += amount
    EventBus.research_points_gained.emit(amount, reason)

func weekly_research_income_hint() -> String:
    ## What the studio can currently expect, for the screen header. Research
    ## points come from shipping, not from waiting.
    return "Earned by shipping games, postmortems and trying unfamiliar features."

func _best_research_skill(employee_ids: Array) -> int:
    var best := -1
    for id in employee_ids:
        var employee := EmployeeManager.find_employee(str(id))
        if employee != null:
            best = maxi(best, employee.research)
    return best

func _on_game_released(project: GameProject) -> void:
    if project == null:
        return
    var experiment_points := ResearchSimulator.points_for_experiments(
        project, GameState.experimented_feature_ids)
    for id in ResearchSimulator.new_feature_ids(project, GameState.experimented_feature_ids):
        GameState.experimented_feature_ids.append(id)

    var release_points := ResearchSimulator.points_for_release(project)
    award_research_points(release_points, "%s shipped" % project.title)
    if experiment_points > 0.0:
        award_research_points(experiment_points, "New feature experience on %s" % project.title)
