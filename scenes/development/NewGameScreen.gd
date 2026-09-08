extends Control

@onready var title_input: LineEdit = $Margin/Scroll/VBox/TitleInput
@onready var theme_option: OptionButton = $Margin/Scroll/VBox/ThemeOption
@onready var genre_option: OptionButton = $Margin/Scroll/VBox/GenreOption
@onready var platform_option: OptionButton = $Margin/Scroll/VBox/PlatformOption
@onready var size_option: OptionButton = $Margin/Scroll/VBox/SizeOption
@onready var engine_option: OptionButton = $Margin/Scroll/VBox/EngineOption
@onready var team_option: OptionButton = $Margin/Scroll/VBox/TeamOption
@onready var roles_container: VBoxContainer = $Margin/Scroll/VBox/RoleAssignments
@onready var feature_list: VBoxContainer = $Margin/Scroll/VBox/FeatureList
@onready var knowledge_label: Label = $Margin/Scroll/VBox/KnowledgeLabel
@onready var cost_label: Label = $Margin/Scroll/VBox/CostLabel
@onready var budget_container: VBoxContainer = $Margin/Scroll/VBox/BudgetContainer
@onready var start_button: Button = $Margin/Scroll/VBox/StartButton
@onready var back_button: Button = $Margin/Scroll/VBox/BackButton
@onready var error_label: Label = $Margin/Scroll/VBox/ErrorLabel

const BUDGET_STEP := 5000

var _role_options: Dictionary = {}
var _selected_feature_ids: Array[String] = []
## Optional. 0 means the player has not chosen to set one at all.
var _budget_target: int = 0
var _cover_preview: GameCoverArt

func _ready() -> void:
    GameClock.enter_menu()
    _cover_preview = GameCoverArt.new()
    _cover_preview.custom_minimum_size = Vector2(104, 136)
    var preview_center := CenterContainer.new()
    preview_center.add_child(_cover_preview)
    $Margin/Scroll/VBox.add_child(preview_center)
    $Margin/Scroll/VBox.move_child(preview_center, 1)
    _populate_options()

    title_input.text_changed.connect(_on_title_changed)
    theme_option.item_selected.connect(_on_choice_changed)
    genre_option.item_selected.connect(_on_choice_changed)
    platform_option.item_selected.connect(_on_choice_changed)
    size_option.item_selected.connect(_on_choice_changed)
    engine_option.item_selected.connect(_on_choice_changed)
    team_option.item_selected.connect(_on_team_changed)
    start_button.pressed.connect(_on_start_pressed)
    back_button.pressed.connect(_on_back_pressed)

    _refresh()

func _populate_options() -> void:
    _fill(theme_option, MarketManager.unlocked_themes(), "theme")
    _fill(genre_option, MarketManager.unlocked_genres(), "genre")
    _fill(size_option, MarketManager.unlocked_sizes(), "size")

    engine_option.clear()
    engine_option.add_item("No custom engine")
    engine_option.set_item_metadata(0, "")
    for engine in GameState.custom_engines:
        engine_option.add_item(str(engine.get("name", "Custom Engine")))
        engine_option.set_item_metadata(engine_option.item_count - 1, engine.get("id", ""))

    team_option.clear()
    for team in TeamManager.available_for_project():
        team_option.add_item(team.name)
        team_option.set_item_metadata(team_option.item_count - 1, team.id)
        if team.id == ScreenRouter.selected_team_id:
            team_option.select(team_option.item_count - 1)

    platform_option.clear()
    for platform in PlatformManager.available_platforms():
        platform_option.add_item("%s (%s)" % [
            platform.get("name", "Unknown"), PlatformManager.stage(platform)
        ])
        platform_option.set_item_metadata(platform_option.item_count - 1, platform.get("id", ""))
        platform_option.set_item_icon(platform_option.item_count - 1, IdentityArtwork.platform_texture(str(platform.get("id", ""))))
    _populate_roles(_selected_id(team_option))
    _populate_features()

func _populate_roles(team_id: String) -> void:
    UiBuilder.clear(roles_container)
    _role_options.clear()
    var defaults := TeamManager.default_assignments(team_id)
    var members := TeamManager.working_members(team_id)
    for role in TeamManager.PROJECT_ROLES:
        var row := HBoxContainer.new()
        var label := UiBuilder.label(str(role["name"]), 13)
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        row.add_child(label)
        var option := OptionButton.new()
        option.custom_minimum_size = Vector2(165, UiBuilder.TAP_HEIGHT)
        option.add_item("Unassigned")
        option.set_item_metadata(0, "")
        for employee in members:
            option.add_item(employee.display_name())
            option.set_item_metadata(option.item_count - 1, employee.id)
            if str(defaults.get(role["id"], "")) == employee.id:
                option.select(option.item_count - 1)
        row.add_child(option)
        roles_container.add_child(row)
        _role_options[str(role["id"])] = option

func _populate_features() -> void:
    UiBuilder.clear(feature_list)
    _selected_feature_ids = _selected_feature_ids.filter(func(id): return _feature_selectable(id))

    for feature in DataManager.game_features:
        var id := str(feature.get("id", ""))
        if int(feature.get("unlock_year", 1985)) > TimeManager.current_year:
            continue
        feature_list.add_child(_feature_row(feature, id))

func _feature_selectable(id: String) -> bool:
    var feature := DataManager.get_game_feature(id)
    return not feature.is_empty() and FeatureSimulator.is_available(
        feature, TimeManager.current_year, GameState.researched_engine_features)

func _feature_row(feature: Dictionary, id: String) -> Control:
    var panel := PanelContainer.new()
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 4)

    var missing := FeatureSimulator.missing_tech(feature, GameState.researched_engine_features)
    var locked := not missing.is_empty()

    var toggle := UiBuilder.toggle(str(feature.get("name", id)), id in _selected_feature_ids)
    toggle.disabled = locked
    toggle.toggled.connect(_on_feature_toggled.bind(id))
    stack.add_child(toggle)

    var bonuses: Array = []
    for field in feature.get("quality_potential", {}).keys():
        bonuses.append("+%d %s" % [
            int(feature["quality_potential"][field]), str(field).capitalize()])
    var detail := "Effort +%d    Bug risk +%d%%\n%s" % [
        int(feature.get("effort", 0)), int(round(float(feature.get("bug_risk", 0.0)) * 100.0)),
        ", ".join(bonuses)
    ]
    if locked:
        detail += "\nRequires: %s" % ", ".join(missing)
    stack.add_child(UiBuilder.label(detail, 12))

    panel.add_child(stack)
    return panel

func _on_feature_toggled(pressed: bool, id: String) -> void:
    if pressed and id not in _selected_feature_ids:
        _selected_feature_ids.append(id)
    elif not pressed:
        _selected_feature_ids.erase(id)
    _refresh()

func _fill(option: OptionButton, items: Array, artwork_kind: String = "") -> void:
    option.clear()
    for item in items:
        option.add_item(str(item.get("name", "Unknown")))
        var index := option.item_count - 1
        var id := str(item.get("id", ""))
        option.set_item_metadata(index, id)
        if artwork_kind == "theme":
            option.set_item_icon(index, IdentityArtwork.theme_texture(id))
        elif artwork_kind == "genre":
            option.set_item_icon(index, IdentityArtwork.genre_texture(id))
        elif artwork_kind == "size":
            option.set_item_icon(index, IdentityArtwork.size_texture(id))

func _selected_id(option: OptionButton) -> String:
    if option.item_count == 0 or option.selected < 0:
        return ""
    return str(option.get_item_metadata(option.selected))

func _refresh() -> void:
    var theme_id := _selected_id(theme_option)
    var genre_id := _selected_id(genre_option)
    var platform_id := _selected_id(platform_option)
    var size_id := _selected_id(size_option)
    var engine_id := _selected_id(engine_option)

    if _cover_preview != null:
        _cover_preview.configure_preview(title_input.text, theme_id, genre_id, platform_id)

    _refresh_knowledge(theme_id, genre_id, platform_id)

    var upfront := DevelopmentSimulator.get_upfront_cost(platform_id, size_id)
    var fee := DevelopmentSimulator.get_platform_fee(platform_id)
    var size := DataManager.get_size(size_id)
    var ideal_min := int(size.get("ideal_team_min", 1))
    var ideal_max := int(size.get("max_useful_staff", 1))
    var team_id := _selected_id(team_option)
    var headcount := TeamManager.working_members(team_id).size()

    var cost_text := "Scope\n%s (ideal team %s)\nRequired Effort %d\n\nAssigned Team\n%d employee%s\n\n" % [
        str(size.get("name", "")), ScopeSimulator.team_size_label(ideal_min, ideal_max),
        int(DevelopmentSimulator.required_effort(size_id, _selected_feature_ids)),
        headcount, "" if headcount == 1 else "s"
    ]

    var estimate := _estimate_schedule(size_id, platform_id, team_id, upfront + fee, _selected_feature_ids)
    if estimate.is_empty():
        cost_text += "Estimated Development\n%d–%d weeks\n\nEstimated Cost\nUnknown until a team is picked" % [
            int(size.get("dev_weeks_min", 4)), int(size.get("dev_weeks_max", 10))
        ]
    else:
        cost_text += "Estimated Development\n%d–%d weeks\n\nEstimated Cost\n%s–%s" % [
            int(estimate["weeks_min"]), int(estimate["weeks_max"]),
            Format.money(int(estimate["cost_min"])), Format.money(int(estimate["cost_max"]))
        ]
    cost_text += "\n\nCurrent Cash\n%s" % Format.money(GameState.cash)

    if fee > 0:
        cost_text += "\n\nUpfront cost $%s + $%s licence" % [Format.exact(upfront), Format.exact(fee)]
    else:
        cost_text += "\n\nUpfront cost $%s" % Format.exact(upfront)
    if not engine_id.is_empty():
        cost_text += "\nUsing %s" % EngineManager.engine_name(engine_id)

    if not team_id.is_empty() and ScopeSimulator.is_understaffed(headcount, ideal_min):
        var speed := ScopeSimulator.speed_multiplier(headcount, ideal_min)
        var stress := ScopeSimulator.stress_delta(headcount, ideal_min)
        cost_text += "\n\nUNDERSTAFFED\nDevelopment speed %d%%\nStress +%d" % [
            int(round((speed - 1.0) * 100.0)), stress
        ]
    elif not team_id.is_empty() and ScopeSimulator.is_overstaffed(headcount, ideal_max):
        cost_text += "\n\nOVERSTAFFED\nCoordination overhead %s\nDevelopment cost %s" % [
            ScopeSimulator.coordination_overhead_label(headcount, ideal_max),
            ScopeSimulator.cost_overhead_label(headcount, ideal_max)
        ]
    cost_label.text = cost_text
    _build_budget_section(estimate)

    start_button.disabled = (
        not FinanceManager.can_afford(upfront + fee)
        or team_option.item_count == 0
    )
    _refresh_title_warning()

func _build_budget_section(estimate: Dictionary) -> void:
    ## Optional. Nothing in the simulation enforces it -- it exists purely so
    ## the player can hold themselves to a number, tycoon-style.
    UiBuilder.clear(budget_container)

    if _budget_target <= 0:
        var enable := UiBuilder.button("SET A BUDGET TARGET (OPTIONAL)")
        enable.pressed.connect(func():
            # A sensible starting point: the middle of the estimate, rounded
            # to a step the player can nudge from.
            var mid := BUDGET_STEP * 2
            if not estimate.is_empty():
                mid = (int(estimate.get("cost_min", 0)) + int(estimate.get("cost_max", 0))) / 2
            _budget_target = maxi(int(round(float(mid) / float(BUDGET_STEP))) * BUDGET_STEP, BUDGET_STEP)
            _refresh())
        budget_container.add_child(enable)
        return

    budget_container.add_child(UiBuilder.heading("PROJECT BUDGET"))
    budget_container.add_child(UiBuilder.label("Target\n%s" % Format.money_exact(_budget_target), 16, true))

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    var minus := UiBuilder.button("-")
    minus.custom_minimum_size.x = 58
    minus.disabled = _budget_target <= BUDGET_STEP
    minus.pressed.connect(func():
        _budget_target = maxi(_budget_target - BUDGET_STEP, BUDGET_STEP)
        _refresh())
    row.add_child(minus)
    var plus := UiBuilder.button("+")
    plus.custom_minimum_size.x = 58
    plus.pressed.connect(func():
        _budget_target += BUDGET_STEP
        _refresh())
    row.add_child(plus)
    var clear := UiBuilder.button("CLEAR")
    clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    clear.pressed.connect(func():
        _budget_target = 0
        _refresh())
    row.add_child(clear)
    budget_container.add_child(row)

    if not estimate.is_empty():
        var over := int(estimate.get("cost_max", 0)) - _budget_target
        if over > 0:
            budget_container.add_child(UiBuilder.label(
                "BUDGET WARNING\nAt this pace the project is likely to exceed its target by up to %s." % [
                    Format.money_exact(over)], 13, true))

func _estimate_schedule(
    size_id: String, platform_id: String, team_id: String, upfront: int,
    feature_ids: Array = []
) -> Dictionary:
    ## A real forecast, not a generic per-scope range: built from exactly the
    ## staff and roles currently chosen, the same way the actual project
    ## would be. So the player can financially plan before committing, not
    ## just after.
    var size := DataManager.get_size(size_id)
    if size.is_empty() or team_id.is_empty():
        return {}
    var employees := TeamManager.working_members(team_id)
    if employees.is_empty():
        return {}

    var assignments := _current_assignments()
    var workloads := _preview_workloads(assignments)
    var office_productivity := OfficeManager.productivity()
    var team := TeamManager.find_team(team_id)
    var chemistry := team.chemistry if team != null else 50.0
    var ideal_max := int(size.get("max_useful_staff", 99))
    var ideal_min := int(size.get("ideal_team_min", 1))

    var effects := ProjectStaffSimulator.effects(
        assignments, employees, workloads, office_productivity, chemistry, ideal_max, ideal_min)

    var lead := LeadershipSimulator.pick_lead(employees)
    var leadership := float(lead.leadership) if lead != null else LeadershipSimulator.BASELINE
    var half_width := LeadershipSimulator.schedule_half_width(leadership)
    var culture_progress := CultureSimulator.progress_multiplier(CultureManager.value("efficiency"))

    # Pre-production, fast and slow ends of the same weekly roll production
    # itself uses.
    var preprod_work := float(DevelopmentSimulator.PREPRODUCTION_WORK.get(size_id, 45.0))
    var preprod_scale := 100.0 / maxf(preprod_work, 1.0)
    var preprod_staff := float(effects.get("preproduction_progress", 1.0))
    var preprod_fast := 100.0 / maxf(
        (12.0 + half_width) * preprod_scale * preprod_staff * culture_progress, 0.01)
    var preprod_slow := 100.0 / maxf(
        maxf(12.0 - half_width, 1.0) * preprod_scale * preprod_staff * culture_progress, 0.01)

    # Production. The plan-efficiency swing from pre-production is not known
    # yet, so this assumes an unremarkable plan -- neither a bonus nor a
    # penalty.
    var work := DevelopmentSimulator.required_effort(size_id, feature_ids)
    var progress_scale := 100.0 / work
    var prod_staff := float(effects.get("progress", 1.0))
    var prod_fast := 100.0 / maxf(
        (11.0 + half_width) * progress_scale * prod_staff * culture_progress, 0.01)
    var prod_slow := 100.0 / maxf(
        maxf(11.0 - half_width, 1.0) * progress_scale * prod_staff * culture_progress, 0.01)

    var weeks_min := maxi(int(ceil(preprod_fast + prod_fast)), 1)
    var weeks_max := maxi(int(ceil(preprod_slow + prod_slow)), weeks_min)

    var headcount := employees.size()
    var multiplier := (
        float(size.get("cost_multiplier", 1.0)) * DevelopmentSimulator.platform_cost_multiplier(platform_id)
        * ScopeSimulator.cost_overhead_multiplier(headcount, ideal_max)
    )

    return {
        "weeks_min": weeks_min,
        "weeks_max": weeks_max,
        "cost_min": upfront + _estimated_dev_cost(int(ceil(preprod_fast)), int(ceil(prod_fast)), multiplier),
        "cost_max": upfront + _estimated_dev_cost(int(ceil(preprod_slow)), int(ceil(prod_slow)), multiplier)
    }

func _estimated_dev_cost(preprod_weeks: int, prod_weeks: int, multiplier: float) -> int:
    var cost := 0
    # Pre-production never ramps -- total_weeks() stays at zero throughout,
    # exactly matching how the real weekly cost is actually calculated.
    var preprod_base := DevelopmentSimulator.BASE_WEEKLY_COST + 15
    for i in preprod_weeks:
        cost += FinanceManager.expense(int(round(
            float(preprod_base) * multiplier * DevelopmentSimulator.PREPRODUCTION_COST_SHARE)))
    # Production ramps with each week actually spent building.
    for week_index in range(1, prod_weeks + 1):
        var base := DevelopmentSimulator.BASE_WEEKLY_COST + week_index * 15
        cost += FinanceManager.expense(int(round(float(base) * multiplier)))
    return cost

func _current_assignments() -> Dictionary:
    var assignments: Dictionary = {}
    for role_id in _role_options:
        var option: OptionButton = _role_options[role_id]
        assignments[role_id] = _selected_id(option)
    return assignments

func _preview_workloads(assignments: Dictionary) -> Dictionary:
    var workloads: Dictionary = {}
    for role in TeamManager.PROJECT_ROLES:
        var employee_id := str(assignments.get(role["id"], ""))
        if employee_id.is_empty():
            continue
        workloads[employee_id] = int(workloads.get(employee_id, 0)) + int(role["workload"])
    return workloads

func _refresh_knowledge(theme_id: String, genre_id: String, platform_id: String) -> void:
    if theme_id.is_empty() or genre_id.is_empty():
        knowledge_label.text = ""
        return

    var theme_name := DataManager.display_name(DataManager.themes, theme_id)
    var genre_name := DataManager.display_name(DataManager.genres, genre_id)

    var text := "%s + %s\nCompatibility: %s" % [
        theme_name, genre_name,
        ExperienceManager.compatibility_label(theme_id, genre_id)
    ]

    var confidence := ExperienceManager.confidence_label(theme_id, genre_id)
    if confidence != "None":
        text += "   Confidence: %s" % confidence

    if not platform_id.is_empty():
        text += "\n%s fit: %s" % [
            DataManager.display_name(DataManager.platforms, platform_id),
            ExperienceManager.platform_fit_label(platform_id, genre_id)
        ]

    var level := ExperienceManager.level_of(GameState.genre_experience, genre_id)
    if level > 0:
        text += "\nStudio experience: %s %s" % [
            KnowledgeSimulator.stars_label(level), KnowledgeSimulator.level_name(level)
        ]

    text += "\n%s market: %s" % [genre_name, MarketManager.trend_label(genre_id)]
    var saturation := MarketManager.saturation_label(genre_id)
    if not saturation.is_empty():
        text += " (%s)" % saturation

    knowledge_label.text = text

func _refresh_title_warning() -> void:
    var title := title_input.text.strip_edges()
    if not title.is_empty() and GameState.has_title(title):
        error_label.text = "You have already released a game named \"%s\"." % title
    elif error_label.text.begins_with("You have already released"):
        error_label.text = ""

func _on_title_changed(_text: String) -> void:
    _refresh_title_warning()
    _refresh()

func _on_choice_changed(_index: int) -> void:
    _refresh()

func _on_team_changed(_index: int) -> void:
    _populate_roles(_selected_id(team_option))
    _refresh()

func _on_start_pressed() -> void:
    var title := title_input.text.strip_edges()
    if title.is_empty():
        error_label.text = "Give your game a title."
        return

    var theme_id := _selected_id(theme_option)
    var genre_id := _selected_id(genre_option)
    var platform_id := _selected_id(platform_option)
    var size_id := _selected_id(size_option)
    var team_id := _selected_id(team_option)
    var engine_id := _selected_id(engine_option)

    if theme_id.is_empty() or genre_id.is_empty() or platform_id.is_empty() or size_id.is_empty() or team_id.is_empty():
        error_label.text = "No valid options available right now."
        return


    var assignments := _current_assignments()
    if not assignments.values().any(func(value): return not str(value).is_empty()):
        error_label.text = "Assign at least one person to the project."
        return

    var project := DevelopmentSimulator.start_project(
        title, theme_id, genre_id, platform_id, size_id, team_id, assignments, engine_id,
        _selected_feature_ids
    )
    if project == null:
        error_label.text = "You cannot afford this project."
        return
    project.budget_target = _budget_target

    SaveManager.autosave()
    get_tree().change_scene_to_file("res://scenes/development/DevelopmentScreen.tscn")

func _on_back_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/studio/TeamsScreen.tscn")
