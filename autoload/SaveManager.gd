extends Node

## Autosave plus three manual slots under user://saves/. Autosave runs after
## anything the player would hate to repeat, because a phone can kill the app at
## any moment.

signal game_loaded()
signal game_saved(slot: String)

const SAVE_DIR := "user://saves"
const AUTOSAVE := "autosave"
const MANUAL_SLOTS := ["save_1", "save_2", "save_3"]
const SAVE_VERSION := 20
const MIN_SUPPORTED_VERSION := 5

var has_active_company: bool = false

func _ready() -> void:
    _ensure_directory()
    if has_save(AUTOSAVE):
        load_game(AUTOSAVE)

func _ensure_directory() -> void:
    if not DirAccess.dir_exists_absolute(SAVE_DIR):
        var error := DirAccess.make_dir_recursive_absolute(SAVE_DIR)
        if error != OK:
            push_error("Could not create %s (error %d)" % [SAVE_DIR, error])

func slot_path(slot: String) -> String:
    return "%s/%s.json" % [SAVE_DIR, slot]

func has_save(slot: String) -> bool:
    return FileAccess.file_exists(slot_path(slot))

func has_any_save() -> bool:
    if has_save(AUTOSAVE):
        return true
    for slot in MANUAL_SLOTS:
        if has_save(slot):
            return true
    return false

func slot_summary(slot: String) -> Dictionary:
    ## Enough detail to label a load button without loading the whole game.
    if not has_save(slot):
        return {}

    var file := FileAccess.open(slot_path(slot), FileAccess.READ)
    if file == null:
        return {}

    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if not (parsed is Dictionary):
        return {}

    var data: Dictionary = parsed
    var company: Dictionary = data.get("company", {})
    var date: Dictionary = data.get("date", {})
    return {
        "company": str(company.get("name", "?")),
        "cash": int(company.get("cash", 0)),
        "games": int(data.get("released_count", 0)),
        "date": TimeManager.format_date(
            int(date.get("year", 1985)), int(date.get("month", 1)), int(date.get("week", 1))
        ),
        "version": int(data.get("version", 0))
    }

func autosave() -> bool:
    if not has_active_company:
        return false
    return save_game(AUTOSAVE)

func save_game(slot: String = AUTOSAVE) -> bool:
    _ensure_directory()

    var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
    if file == null:
        push_error("Could not write save %s (error %d)" % [slot, FileAccess.get_open_error()])
        return false

    file.store_string(JSON.stringify(_collect_save_data(), "\t"))
    file.close()
    game_saved.emit(slot)
    return true

func load_game(slot: String = AUTOSAVE) -> bool:
    if not has_save(slot):
        return false

    var file := FileAccess.open(slot_path(slot), FileAccess.READ)
    if file == null:
        push_error("Could not read save %s (error %d)" % [slot, FileAccess.get_open_error()])
        return false

    var parsed = JSON.parse_string(file.get_as_text())
    file.close()

    if not (parsed is Dictionary):
        push_error("Save file is corrupt; ignoring it.")
        return false

    var data: Dictionary = parsed
    var version := int(data.get("version", 0))
    if version < MIN_SUPPORTED_VERSION or version > SAVE_VERSION:
        push_warning("Save file is from an incompatible version; ignoring it.")
        return false

    _apply_save_data(data)
    has_active_company = true
    World.sync_year()
    game_loaded.emit()
    return true

func delete_save(slot: String) -> void:
    if not has_save(slot):
        return
    var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(slot)))
    if error != OK:
        push_error("Could not delete save %s (error %d)" % [slot, error])

func _collect_save_data() -> Dictionary:
    var released: Array = []
    for game in GameState.released_games:
        released.append(game.to_dict())

    return {
        "version": SAVE_VERSION,
        "released_count": released.size(),
        "company": {
            "name": GameState.company_name,
            "founder": GameState.founder_name,
            "founder_pronouns": GameState.founder_pronoun_id,
            "founder_background": GameState.founder_background_id,
            "founder_trait": GameState.founder_trait_id,
            "difficulty": GameState.difficulty_id,
            "cash": GameState.cash,
            "fans": GameState.fans,
            "consumer_reputation": GameState.consumer_reputation,
            "employer_reputation": GameState.employer_reputation,
            "founded_year": GameState.founded_year,
            "founded_month": GameState.founded_month,
            "founded_week": GameState.founded_week,
            "next_id": GameState.next_id,
            "overdrawn_weeks": GameState.overdrawn_weeks,
            "bankrupt": GameState.bankrupt
        },
        "date": {
            "year": TimeManager.current_year,
            "month": TimeManager.current_month,
            "week": TimeManager.current_week
        },
        "knowledge": {
            "genre_experience": GameState.genre_experience,
            "theme_experience": GameState.theme_experience,
            "platform_experience": GameState.platform_experience,
            "combo_knowledge": GameState.combo_knowledge,
            "platform_genre_knowledge": GameState.platform_genre_knowledge,
            "feature_knowledge": GameState.feature_knowledge
        },
        "technology": {
            "completed_technologies": GameState.completed_technologies,
            "active_research": GameState.active_research,
            "research_points": GameState.research_points,
            "experimented_feature_ids": GameState.experimented_feature_ids,
            "engines": GameState.custom_engines,
            "next_number": GameState.next_engine_number
        },
        "market": {
            "genre_trends": GameState.genre_trends,
            "genre_saturation": GameState.genre_saturation,
            "weeks_until_trend_shift": GameState.weeks_until_trend_shift
        },
        "unlocks": {
            "genres": GameState.unlocked_genres,
            "themes": GameState.unlocked_themes,
            "sizes": GameState.unlocked_sizes,
            "platforms": GameState.known_platforms
        },
        "books": {
            "ledger": GameState.ledger,
            "annual_finance": GameState.annual_finance,
            "news": GameState.news,
            "milestones": GameState.milestones,
            "culture": GameState.culture
        },
        "workforce": {
            "next_employee_number": GameState.next_employee_number,
            "employees": GameState.employees.map(func(employee: Employee): return employee.to_dict()),
            "candidates": GameState.labor_candidates.map(func(employee: Employee): return employee.to_dict()),
            "market_weeks_left": GameState.labor_market_weeks_left,
            "market_generation": GameState.labor_market_generation,
            "office_quality": GameState.office_quality,
            "office_id": GameState.office_id,
            "owned_office_customizations": GameState.owned_office_customizations,
            "equipped_office_customization": GameState.equipped_office_customization,
            "office_remodel": GameState.office_remodel,
            "crunch_teams": GameState.crunch_teams,
            "staff_requests": GameState.staff_requests.map(func(r: StaffRequest): return r.to_dict()),
            "departed": GameState.departed_employees.map(func(e: Employee): return e.to_dict()),
            "recent_layoffs": GameState.recent_layoffs,
            "pending_studio_event": GameState.pending_studio_event,
            "studio_event_cooldowns": GameState.studio_event_cooldowns,
            "studio_event_effects": GameState.studio_event_effects,
            "next_request_number": GameState.next_request_number,
            "teams": GameState.teams.map(func(team: StudioTeam): return team.to_dict())
        },
        "contracts": {
            "offers": GameState.contract_offers.map(func(c: Contract): return c.to_dict()),
            "active": GameState.active_contract.to_dict() if GameState.active_contract != null else null,
            "completed": GameState.completed_contracts.map(func(c: Contract): return c.to_dict()),
            "offer_weeks_left": GameState.contract_offer_weeks_left,
            "next_number": GameState.next_contract_number
        },
        "current_project": GameState.current_project.to_dict() if GameState.current_project != null else null,
        "active_projects": GameState.active_projects.map(func(project: GameProject): return project.to_dict()),
        "selected_project_id": GameState.selected_project_id,
        "released_games": released
    }

func _apply_save_data(data: Dictionary) -> void:
    var company: Dictionary = data.get("company", {})
    GameState.company_name = str(company.get("name", "Indie Empire"))
    GameState.founder_name = str(company.get("founder", "You"))
    var founder_pronouns := str(company.get("founder_pronouns", Pronouns.DEFAULT))
    GameState.founder_pronoun_id = founder_pronouns if Pronouns.is_known(founder_pronouns) else Pronouns.DEFAULT
    var founder_background := str(company.get("founder_background", "generalist"))
    GameState.founder_background_id = (
        founder_background if not DataManager.get_founder_background(founder_background).is_empty()
        else "generalist")
    var founder_trait := str(company.get("founder_trait", "perfectionist"))
    GameState.founder_trait_id = (
        founder_trait if not DataManager.get_employee_trait(founder_trait).is_empty()
        else "perfectionist")
    GameState.difficulty_id = str(company.get("difficulty", "normal"))
    GameState.cash = int(company.get("cash", 10_000))
    GameState.fans = int(company.get("fans", 0))
    # Pre-v18 saves have one "reputation" field, which was consumer-facing;
    # employer reputation did not exist yet, so it starts neutral like a new company.
    GameState.consumer_reputation = float(
        company.get("consumer_reputation", company.get("reputation", 0.0)))
    GameState.employer_reputation = float(company.get("employer_reputation", 50.0))
    GameState.founded_year = int(company.get("founded_year", 1985))
    GameState.founded_month = int(company.get("founded_month", 1))
    GameState.founded_week = int(company.get("founded_week", 1))
    GameState.next_id = int(company.get("next_id", 1))
    GameState.overdrawn_weeks = int(company.get("overdrawn_weeks", 0))
    GameState.bankrupt = bool(company.get("bankrupt", false))

    var date: Dictionary = data.get("date", {})
    TimeManager.set_date(
        int(date.get("year", 1985)),
        int(date.get("month", 1)),
        int(date.get("week", 1))
    )

    var knowledge: Dictionary = data.get("knowledge", {})
    GameState.genre_experience = _int_dictionary(knowledge.get("genre_experience", {}))
    GameState.theme_experience = _int_dictionary(knowledge.get("theme_experience", {}))
    GameState.platform_experience = _int_dictionary(knowledge.get("platform_experience", {}))
    GameState.combo_knowledge = _int_dictionary(knowledge.get("combo_knowledge", {}))
    GameState.platform_genre_knowledge = _int_dictionary(knowledge.get("platform_genre_knowledge", {}))
    GameState.feature_knowledge = _int_dictionary(knowledge.get("feature_knowledge", {}))

    var technology: Dictionary = data.get("technology", {})
    # v20 renamed researched_features -> completed_technologies and made
    # research a timed project. Pre-v20 saves keep every id they had (the
    # technology ids are unchanged) and simply have no in-flight research.
    GameState.completed_technologies = _string_array(
        technology.get("completed_technologies",
            technology.get("researched_features", ResearchManager.starter_ids())))
    for starter_id in ResearchManager.starter_ids():
        if not GameState.completed_technologies.has(starter_id):
            GameState.completed_technologies.append(starter_id)
    GameState.research_points = float(technology.get("research_points", 0.0))
    GameState.experimented_feature_ids = _string_array(
        technology.get("experimented_feature_ids", []))
    GameState.active_research = []
    for entry in technology.get("active_research", []):
        if not (entry is Dictionary):
            continue
        var tech_id := str(entry.get("tech_id", ""))
        if DataManager.get_technology(tech_id).is_empty() or GameState.completed_technologies.has(tech_id):
            continue
        GameState.active_research.append({
            "tech_id": tech_id,
            "progress": maxf(float(entry.get("progress", 0.0)), 0.0),
            "researcher_ids": _string_array(entry.get("researcher_ids", []))
        })
    GameState.custom_engines.clear()
    for entry in technology.get("engines", []):
        if entry is Dictionary:
            var engine: Dictionary = entry.duplicate(true)
            engine["id"] = str(engine.get("id", ""))
            engine["name"] = str(engine.get("name", "Custom Engine"))
            engine["feature_ids"] = _string_array(engine.get("feature_ids", []))
            GameState.custom_engines.append(engine)
    GameState.next_engine_number = int(technology.get("next_number", GameState.custom_engines.size() + 1))

    var market: Dictionary = data.get("market", {})
    GameState.genre_trends = _float_dictionary(market.get("genre_trends", {}))
    GameState.genre_saturation = _float_dictionary(market.get("genre_saturation", {}))
    GameState.weeks_until_trend_shift = int(market.get("weeks_until_trend_shift", 12))
    if GameState.genre_trends.is_empty():
        MarketManager.seed_trends()

    var unlocks: Dictionary = data.get("unlocks", {})
    GameState.unlocked_genres = _string_array(unlocks.get("genres", []))
    GameState.unlocked_themes = _string_array(unlocks.get("themes", []))
    GameState.unlocked_sizes = _string_array(unlocks.get("sizes", []))
    GameState.known_platforms = _string_array(unlocks.get("platforms", []))

    var books: Dictionary = data.get("books", {})
    GameState.ledger = _entry_array(books.get("ledger", []))
    GameState.annual_finance = _annual(books.get("annual_finance", {}))
    GameState.news = _entry_array(books.get("news", []))
    GameState.milestones = _string_array(books.get("milestones", []))
    # Saves before v13 have no culture: those studios start from neutral.
    CultureManager.seed_culture()
    var culture: Dictionary = books.get("culture", {})
    for id in CultureSimulator.IDS:
        if culture.has(id):
            GameState.culture[id] = float(culture[id])

    var workforce: Dictionary = data.get("workforce", {})
    GameState.next_employee_number = int(workforce.get("next_employee_number", 1))
    GameState.employees.clear()
    for entry in workforce.get("employees", []):
        if entry is Dictionary:
            GameState.employees.append(Employee.from_dict(entry))
    # Version 5 predates employees. Loading one promotes its named founder into
    # the workforce instead of throwing away the player's M2 company.
    EmployeeManager.ensure_founder()
    GameState.teams.clear()
    for entry in workforce.get("teams", []):
        if entry is Dictionary:
            GameState.teams.append(StudioTeam.from_dict(entry))
    TeamManager.ensure_teams()
    var contracts: Dictionary = data.get("contracts", {})
    GameState.contract_offers.clear()
    for entry in contracts.get("offers", []):
        if entry is Dictionary:
            GameState.contract_offers.append(Contract.from_dict(entry))
    GameState.completed_contracts.clear()
    for entry in contracts.get("completed", []):
        if entry is Dictionary:
            GameState.completed_contracts.append(Contract.from_dict(entry))
    var active = contracts.get("active", null)
    GameState.active_contract = Contract.from_dict(active) if active is Dictionary else null
    GameState.contract_offer_weeks_left = int(contracts.get("offer_weeks_left", 0))
    GameState.next_contract_number = int(contracts.get("next_number", 1))

    GameState.labor_candidates.clear()
    for entry in workforce.get("candidates", []):
        if entry is Dictionary:
            GameState.labor_candidates.append(Employee.from_dict(entry))
    GameState.labor_market_weeks_left = int(workforce.get("market_weeks_left", 0))
    GameState.labor_market_generation = int(workforce.get("market_generation", 0))
    GameState.office_quality = int(workforce.get("office_quality", 0))
    GameState.office_id = str(workforce.get("office_id", "bedroom"))
    GameState.owned_office_customizations.assign(_string_array(
        workforce.get("owned_office_customizations", ["classic"])))
    if "classic" not in GameState.owned_office_customizations:
        GameState.owned_office_customizations.push_front("classic")
    GameState.equipped_office_customization = str(
        workforce.get("equipped_office_customization", "classic"))
    if GameState.equipped_office_customization not in GameState.owned_office_customizations:
        GameState.equipped_office_customization = "classic"
    GameState.office_remodel = workforce.get("office_remodel", {}).duplicate(true)
    OfficeCustomizationManager.validate_remodel()
    GameState.crunch_teams = _string_array(workforce.get("crunch_teams", []))
    GameState.staff_requests.clear()
    for entry in workforce.get("staff_requests", []):
        if entry is Dictionary:
            GameState.staff_requests.append(StaffRequest.from_dict(entry))
    GameState.departed_employees.clear()
    for entry in workforce.get("departed", []):
        if entry is Dictionary:
            GameState.departed_employees.append(Employee.from_dict(entry))
    GameState.recent_layoffs.clear()
    for week in workforce.get("recent_layoffs", []):
        GameState.recent_layoffs.append(int(week))

    var pending_event = workforce.get("pending_studio_event", {})
    if pending_event is Dictionary and not pending_event.is_empty():
        GameState.pending_studio_event = {
            "event_id": str(pending_event.get("event_id", "")),
            "employee_id": str(pending_event.get("employee_id", "")),
            "weeks_left": int(pending_event.get("weeks_left", 4))
        }
    else:
        GameState.pending_studio_event = {}
    GameState.studio_event_cooldowns.clear()
    var cooldowns = workforce.get("studio_event_cooldowns", {})
    if cooldowns is Dictionary:
        for key in cooldowns:
            GameState.studio_event_cooldowns[str(key)] = int(cooldowns[key])
    GameState.studio_event_effects.clear()
    for effect in workforce.get("studio_event_effects", []):
        if effect is Dictionary:
            GameState.studio_event_effects.append({
                "kind": str(effect.get("kind", "")),
                "amount": float(effect.get("amount", 0.0)),
                "weeks_left": int(effect.get("weeks_left", 0))
            })

    GameState.next_request_number = int(workforce.get("next_request_number", 1))
    # Early M3 development saves used these temporary office ids.
    if GameState.office_id == "small_studio":
        GameState.office_id = "small_office"
    elif GameState.office_id == "downtown_studio":
        GameState.office_id = "large_studio_floor"
    OfficeManager.sync_office_quality()
    if GameState.labor_candidates.is_empty() and GameState.labor_market_weeks_left <= 0:
        LaborMarketManager.refresh_market(false)

    GameState.released_games.clear()
    for entry in data.get("released_games", []):
        if entry is Dictionary:
            GameState.released_games.append(GameProject.from_dict(entry))

    # v15 adds a per-employee career history. It cannot be fully reconstructed,
    # but the games a studio has already shipped are on record, so credit their
    # veterans -- current and departed -- for those rather than starting blank.
    if int(data.get("version", 0)) < 15:
        for game in GameState.released_games:
            EmployeeManager.record_shipped_project(game)

    GameState.active_projects.clear()
    for entry in data.get("active_projects", []):
        if entry is Dictionary:
            GameState.active_projects.append(GameProject.from_dict(entry))

    # Versions 5-8 stored a single current project.
    var project_data = data.get("current_project", null)
    if GameState.active_projects.is_empty() and project_data is Dictionary:
        GameState.active_projects.append(GameProject.from_dict(project_data))

    for project in GameState.active_projects:
        if project.team_id.is_empty():
            project.team_id = "team_a"
        if project.role_assignments.is_empty():
            project.role_assignments = TeamManager.default_assignments(project.team_id)
        var team := TeamManager.find_team(project.team_id)
        if team != null:
            team.project_id = project.id

    GameState.selected_project_id = str(data.get("selected_project_id", ""))
    var selected := GameState.find_active_project(GameState.selected_project_id)
    if selected == null and not GameState.active_projects.is_empty():
        selected = GameState.active_projects[0]
    GameState.select_project(selected)

    UnlockManager.refresh(false)

func _int_dictionary(source) -> Dictionary:
    # JSON returns every number as a float; counters must stay integers.
    var result: Dictionary = {}
    if source is Dictionary:
        for key in source:
            result[str(key)] = int(source[key])
    return result

func _float_dictionary(source) -> Dictionary:
    var result: Dictionary = {}
    if source is Dictionary:
        for key in source:
            result[str(key)] = float(source[key])
    return result

func _string_array(source) -> Array:
    var result: Array = []
    if source is Array:
        for value in source:
            result.append(str(value))
    return result

func _annual(source) -> Dictionary:
    var result: Dictionary = {}
    if source is Dictionary:
        for key in source:
            var row = source[key]
            if row is Dictionary:
                result[str(key)] = {
                    "income": int(row.get("income", 0)),
                    "expenses": int(row.get("expenses", 0))
                }
    return result

func _entry_array(source) -> Array:
    var result: Array = []
    if source is Array:
        for value in source:
            if value is Dictionary:
                result.append(value)
    return result
