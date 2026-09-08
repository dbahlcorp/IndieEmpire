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
@onready var review_button: Button = $Margin/Scroll/VBox/ReviewButton
@onready var back_button: Button = $Margin/Scroll/VBox/BackButton
@onready var error_label: Label = $Margin/Scroll/VBox/ErrorLabel

const BUDGET_STEP := 5000

var _role_options: Dictionary = {}
var _selected_feature_ids: Array[String] = []
## Optional. 0 means the player has not chosen to set one at all.
var _budget_target: int = 0
var _cover_preview: GameCoverArt
## The player's whole-project emphasis. See ProjectPrioritySimulator -- this
## is a different, additional choice from the per-phase FocusOption the
## development screen offers once a project is actually under way.
var _priority_choices: Dictionary = ProjectPrioritySimulator.default_choices()
var _priorities_body: VBoxContainer
var _priorities_header: Button

func _ready() -> void:
    GameClock.enter_menu()
    _cover_preview = GameCoverArt.new()
    _cover_preview.custom_minimum_size = Vector2(104, 136)
    var preview_center := CenterContainer.new()
    preview_center.add_child(_cover_preview)
    $Margin/Scroll/VBox.add_child(preview_center)
    $Margin/Scroll/VBox.move_child(preview_center, 1)
    _populate_options()
    _build_priorities_section()

    title_input.text_changed.connect(_on_title_changed)
    theme_option.item_selected.connect(_on_choice_changed)
    genre_option.item_selected.connect(_on_choice_changed)
    platform_option.item_selected.connect(_on_choice_changed)
    size_option.item_selected.connect(_on_choice_changed)
    engine_option.item_selected.connect(_on_choice_changed)
    team_option.item_selected.connect(_on_team_changed)
    review_button.pressed.connect(_on_review_pressed)
    back_button.pressed.connect(_on_back_pressed)

    _restore_draft()
    _refresh()

func _restore_draft() -> void:
    ## Coming back from the greenlight screen to change something keeps every
    ## choice already made -- editing a project should not mean rebuilding it
    ## from scratch. A draft left over from any other path (the player quit
    ## mid-flow and started a fresh session) is not something a save carries
    ## -- see ScreenRouter.draft_project -- so there is nothing stale to
    ## worry about restoring by mistake.
    var draft := ScreenRouter.draft_project
    if draft.is_empty():
        return

    title_input.text = str(draft.get("title", ""))
    _select_by_id(theme_option, str(draft.get("theme_id", "")))
    _select_by_id(genre_option, str(draft.get("genre_id", "")))
    _select_by_id(platform_option, str(draft.get("platform_id", "")))
    _select_by_id(size_option, str(draft.get("size_id", "")))
    _select_by_id(engine_option, str(draft.get("engine_id", "")))
    _select_by_id(team_option, str(draft.get("team_id", "")))
    _populate_roles(_selected_id(team_option))

    var assignments: Dictionary = draft.get("assignments", {})
    for role_id in assignments:
        if _role_options.has(role_id):
            _select_by_id(_role_options[role_id], str(assignments[role_id]))

    var feature_ids: Array = draft.get("feature_ids", [])
    _selected_feature_ids.clear()
    for id in feature_ids:
        _selected_feature_ids.append(str(id))
    _populate_features()

    _priority_choices = ProjectPrioritySimulator.sanitize(draft.get("priority_choices", {}))
    _build_priorities_section()

    _budget_target = int(draft.get("budget_target", 0))

func _select_by_id(option: OptionButton, id: String) -> void:
    if id.is_empty():
        return
    for i in option.item_count:
        if str(option.get_item_metadata(i)) == id:
            option.select(i)
            return

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
    var grouped := {}
    for feature in DataManager.game_features:
        var unlocks: Dictionary = feature.get("unlock_requirements", {})
        if int(unlocks.get("year", feature.get("unlock_year", 1985))) > TimeManager.current_year:
            continue
        var category := str(feature.get("category", "Other"))
        if not grouped.has(category):
            grouped[category] = []
        grouped[category].append(feature)
    for category in grouped:
        feature_list.add_child(UiBuilder.heading(str(category).to_upper()))
        for feature in grouped[category]:
            feature_list.add_child(_feature_row(feature, str(feature.get("id", ""))))

func _feature_selectable(id: String) -> bool:
    var feature := DataManager.get_game_feature(id)
    return not feature.is_empty() and FeatureSimulator.is_available(
        feature, TimeManager.current_year, GameState.researched_engine_features,
        FeatureSimulator.engine_features(_selected_id(engine_option)), _selected_feature_ids)

func _feature_row(feature: Dictionary, id: String) -> Control:
    var panel := PanelContainer.new()
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 4)

    var missing := FeatureSimulator.missing_requirements(
        feature, TimeManager.current_year, GameState.researched_engine_features,
        FeatureSimulator.engine_features(_selected_id(engine_option)), _selected_feature_ids)
    var locked := not missing.is_empty()

    var toggle := UiBuilder.toggle(FeatureSimulator.display_name(feature), id in _selected_feature_ids)
    toggle.disabled = locked
    toggle.toggled.connect(_on_feature_toggled.bind(id))
    stack.add_child(toggle)

    var demands: Array[String] = []
    for discipline in FeatureSimulator.DISCIPLINES:
        var amount := int(feature.get(FeatureSimulator.DEMAND_FIELDS[discipline], 0))
        if amount > 0:
            demands.append("%s %d" % [discipline.capitalize(), amount])
    var benefits: Array = feature.get("known_benefits", [])
    var detail := "Effort +%d    Complexity +%d    Bug risk: %s\nDemand: %s\nBenefits: %s" % [
        int(feature.get("development_effort", 0)), int(feature.get("complexity", 0)),
        FeatureSimulator.bug_risk_label(feature), ", ".join(demands),
        ", ".join(benefits)
    ]
    var technology: Array = feature.get("technology_requirements", [])
    if not technology.is_empty():
        var technology_names: Array[String] = []
        for tech_id in technology:
            technology_names.append(str(EngineManager.feature(str(tech_id)).get("name", tech_id)))
        detail += "\nTechnology: %s" % ", ".join(technology_names)
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
    _populate_features()
    _refresh()

func _build_priorities_section() -> void:
    ## An expandable card, not a wall of sliders: five simultaneous choices
    ## on a portrait screen need progressive disclosure as much as the
    ## feature list does. Built and inserted once, then rebuilt in place on
    ## every change -- the same pattern _cover_preview already uses to live
    ## outside the .tscn's own static nodes.
    var vbox: VBoxContainer = $Margin/Scroll/VBox
    if _priorities_body == null:
        var card := UiBuilder.collapsible_section("PROJECT PRIORITIES", false)
        vbox.add_child(card["panel"])
        vbox.move_child(card["panel"], feature_list.get_index() + 1)
        _priorities_body = card["body"]
        _priorities_header = card["header"]

    UiBuilder.clear(_priorities_body)
    _priorities_body.add_child(UiBuilder.label(
        "How this build leans. Every category starts Normal; raising one "
        + "to High only fits the budget if another drops to Low.", 13))

    for category in ProjectPrioritySimulator.CATEGORIES:
        _priorities_body.add_child(_priority_row(category))

    var used := ProjectPrioritySimulator.points_used(_priority_choices)
    var remaining := ProjectPrioritySimulator.points_remaining(_priority_choices)
    _priorities_body.add_child(UiBuilder.label(
        "Priority points: %d used, %d remaining of %d" % [
            used, remaining, ProjectPrioritySimulator.BUDGET], 12))

    var customized := 0
    for category in ProjectPrioritySimulator.CATEGORIES:
        if str(_priority_choices.get(category, "")) != ProjectPrioritySimulator.DEFAULT_LEVEL:
            customized += 1
    var suffix := " (%d set)" % customized if customized > 0 else ""
    _priorities_header.text = "%s  PROJECT PRIORITIES%s" % [
        "▾" if _priorities_body.visible else "▸", suffix]

func _priority_row(category: String) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    var label := UiBuilder.label(category.capitalize(), 14)
    label.custom_minimum_size.x = 92
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    row.add_child(label)

    var group := ButtonGroup.new()
    var current := str(_priority_choices.get(category, ProjectPrioritySimulator.DEFAULT_LEVEL))
    for level_id in ProjectPrioritySimulator.LEVEL_ORDER:
        var level_button := Button.new()
        level_button.text = ProjectPrioritySimulator.level_name(level_id)
        level_button.toggle_mode = true
        level_button.button_group = group
        level_button.custom_minimum_size = Vector2(0, UiBuilder.TAP_HEIGHT)
        level_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        level_button.add_theme_font_size_override("font_size", 13)
        var is_current: bool = (str(level_id) == current)
        level_button.button_pressed = is_current
        level_button.disabled = (
            not is_current
            and not ProjectPrioritySimulator.can_afford_level(_priority_choices, category, level_id)
        )
        level_button.toggled.connect(_on_priority_level_toggled.bind(category, level_id))
        row.add_child(level_button)
    return row

func _on_priority_level_toggled(pressed: bool, category: String, level_id: String) -> void:
    if not pressed:
        return
    if not ProjectPrioritySimulator.can_afford_level(_priority_choices, category, level_id):
        # The button that could cause this is disabled before it can be
        # tapped -- this is a defensive backstop, not the normal path.
        _build_priorities_section()
        return
    _priority_choices[category] = level_id
    _build_priorities_section()

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
    var complexity_budget := FeatureSimulator.complexity_budget(size_id, _selected_feature_ids)

    var cost_text := "PROJECT COMPLEXITY\n%d / %d recommended\n" % [
        int(complexity_budget.get("current", 0)),
        int(complexity_budget.get("recommended_max", 0))]
    if bool(complexity_budget.get("over_scoped", false)):
        cost_text += "⚠ OVER-SCOPED\nExpected consequences:\n• Longer development\n• Higher bug risk\n• Greater schedule uncertainty\n"
    cost_text += "\nScope\n%s (ideal team %s)\nRequired Effort %d\n\nAssigned Team\n%d employee%s\n\n" % [
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

    review_button.disabled = (
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
    ## just after. The maths itself lives in ProjectEstimateSimulator, shared
    ## with GreenlightScreen's own estimate, so the two screens can never
    ## quietly drift into showing different numbers for the same choices.
    if team_id.is_empty():
        return {}
    return ProjectEstimateSimulator.schedule_and_cost(
        size_id, platform_id, team_id, _current_assignments(), upfront, feature_ids)

func _current_assignments() -> Dictionary:
    var assignments: Dictionary = {}
    for role_id in _role_options:
        var option: OptionButton = _role_options[role_id]
        assignments[role_id] = _selected_id(option)
    return assignments

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
    _populate_features()
    _refresh()

func _on_team_changed(_index: int) -> void:
    _populate_roles(_selected_id(team_option))
    _refresh()

func _build_draft() -> Dictionary:
    ## Validates and assembles exactly what GreenlightScreen will need,
    ## without touching the scene tree -- kept separate from
    ## _on_review_pressed() so a test can call this directly instead of
    ## going through the button press, which navigates and would tear the
    ## calling scene down with it. Returns {} and sets error_label on any
    ## failure; never sets ScreenRouter.draft_project itself, so a failed
    ## attempt cannot clobber a previously valid draft.
    var title := title_input.text.strip_edges()
    if title.is_empty():
        error_label.text = "Give your game a title."
        return {}

    var theme_id := _selected_id(theme_option)
    var genre_id := _selected_id(genre_option)
    var platform_id := _selected_id(platform_option)
    var size_id := _selected_id(size_option)
    var team_id := _selected_id(team_option)
    var engine_id := _selected_id(engine_option)

    if theme_id.is_empty() or genre_id.is_empty() or platform_id.is_empty() or size_id.is_empty() or team_id.is_empty():
        error_label.text = "No valid options available right now."
        return {}

    var assignments := _current_assignments()
    if not assignments.values().any(func(value): return not str(value).is_empty()):
        error_label.text = "Assign at least one person to the project."
        return {}

    return {
        "title": title,
        "theme_id": theme_id,
        "genre_id": genre_id,
        "platform_id": platform_id,
        "size_id": size_id,
        "team_id": team_id,
        "engine_id": engine_id,
        "feature_ids": _selected_feature_ids.duplicate(),
        "assignments": assignments,
        "priority_choices": _priority_choices.duplicate(),
        "budget_target": _budget_target
    }

func _on_review_pressed() -> void:
    var draft := _build_draft()
    if draft.is_empty():
        return

    # Nothing is greenlit yet -- the project is only ever created by
    # GreenlightScreen pressing GREENLIGHT PROJECT, off exactly this same
    # data. ScreenRouter carries it across the scene change the same way it
    # already carries the other bits of cross-screen navigation state.
    ScreenRouter.draft_project = draft
    get_tree().change_scene_to_file("res://scenes/development/GreenlightScreen.tscn")

func _on_back_pressed() -> void:
    ScreenRouter.clear_draft_project()
    get_tree().change_scene_to_file("res://scenes/studio/TeamsScreen.tscn")
