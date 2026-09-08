extends Control

## The final review before a project becomes real: everything chosen on
## NewGameScreen, plus a real estimate built from the same simulation the
## project will actually run on (ProjectEstimateSimulator), so greenlighting
## a project is a genuine decision rather than a formality after picking a
## few dropdowns.

@onready var title_label: Label = $Margin/Scroll/VBox/TitleLabel
@onready var identity_container: VBoxContainer = $Margin/Scroll/VBox/IdentityContainer
@onready var features_container: VBoxContainer = $Margin/Scroll/VBox/FeaturesContainer
@onready var team_container: VBoxContainer = $Margin/Scroll/VBox/TeamContainer
@onready var priorities_container: VBoxContainer = $Margin/Scroll/VBox/PrioritiesContainer
@onready var estimate_container: VBoxContainer = $Margin/Scroll/VBox/EstimateContainer
@onready var error_label: Label = $Margin/Scroll/VBox/ErrorLabel
@onready var greenlight_button: Button = $Margin/Scroll/VBox/GreenlightButton
@onready var edit_button: Button = $Margin/Scroll/VBox/EditButton

var _draft: Dictionary = {}
var _estimate: Dictionary = {}

func _ready() -> void:
    GameClock.enter_menu()
    _draft = ScreenRouter.draft_project

    # Reached with nothing to review -- a direct navigation, a stale link
    # after a reload, or the draft was already spent. Nothing here can be
    # shown without it, so send the player back to build one rather than
    # rendering an empty confirmation screen.
    if _draft.is_empty():
        get_tree().change_scene_to_file.call_deferred("res://scenes/development/NewGameScreen.tscn")
        return

    _estimate = ProjectEstimateSimulator.full_estimate(
        str(_draft.get("genre_id", "")), str(_draft.get("theme_id", "")),
        str(_draft.get("platform_id", "")), str(_draft.get("size_id", "")),
        str(_draft.get("team_id", "")), _draft.get("assignments", {}),
        str(_draft.get("engine_id", "")), _draft.get("feature_ids", [])
    )

    greenlight_button.pressed.connect(_on_greenlight_pressed)
    edit_button.pressed.connect(_on_edit_pressed)

    _render()

func _render() -> void:
    title_label.text = str(_draft.get("title", "")).to_upper()
    _render_identity()
    _render_features()
    _render_team()
    _render_priorities()
    _render_estimate()

    var schedule: Dictionary = _estimate.get("schedule", {})
    greenlight_button.disabled = schedule.is_empty()

func _render_identity() -> void:
    UiBuilder.clear(identity_container)
    var genre_id := str(_draft.get("genre_id", ""))
    var theme_id := str(_draft.get("theme_id", ""))
    var platform_id := str(_draft.get("platform_id", ""))
    var size_id := str(_draft.get("size_id", ""))
    var engine_id := str(_draft.get("engine_id", ""))

    identity_container.add_child(UiBuilder.label("Genre: %s" % DataManager.display_name(DataManager.genres, genre_id), 15))
    identity_container.add_child(UiBuilder.label("Theme: %s" % DataManager.display_name(DataManager.themes, theme_id), 15))
    identity_container.add_child(UiBuilder.label("Platform: %s" % DataManager.display_name(DataManager.platforms, platform_id), 15))
    identity_container.add_child(UiBuilder.label(
        "Scope: %s" % str(DataManager.get_size(size_id).get("name", "")), 15))
    identity_container.add_child(UiBuilder.label(
        "Engine: %s" % (EngineManager.engine_name(engine_id) if not engine_id.is_empty() else "No custom engine"), 15))

func _render_features() -> void:
    UiBuilder.clear(features_container)
    features_container.add_child(UiBuilder.heading("FEATURES"))
    var feature_ids: Array = _draft.get("feature_ids", [])
    if feature_ids.is_empty():
        features_container.add_child(UiBuilder.label("No features chosen.", 14))
        return
    for id in feature_ids:
        var feature := DataManager.get_game_feature(str(id))
        features_container.add_child(UiBuilder.label(
            "• %s" % str(feature.get("name", str(id))), 14))

func _render_team() -> void:
    UiBuilder.clear(team_container)
    team_container.add_child(UiBuilder.heading("TEAM"))
    var assignments: Dictionary = _draft.get("assignments", {})
    var headcount := 0
    for value in assignments.values():
        if not str(value).is_empty():
            headcount += 1
    # Named roles only count who is actually doing something on this
    # project -- the same headcount the setup screen's own preview shows.
    team_container.add_child(UiBuilder.label(
        "%d employee%s" % [headcount, "" if headcount == 1 else "s"], 15))

func _render_priorities() -> void:
    UiBuilder.clear(priorities_container)
    priorities_container.add_child(UiBuilder.heading("PROJECT PRIORITIES"))
    var choices: Dictionary = _draft.get("priority_choices", {})
    for line in ProjectPrioritySimulator.summary_lines(choices):
        priorities_container.add_child(UiBuilder.label(line, 14))

func _render_estimate() -> void:
    UiBuilder.clear(estimate_container)
    estimate_container.add_child(UiBuilder.heading("ESTIMATE"))

    var schedule: Dictionary = _estimate.get("schedule", {})
    var market: Dictionary = _estimate.get("market", {})
    var experience: Dictionary = _estimate.get("experience", {})
    var risk: Dictionary = _estimate.get("risk", {})

    if schedule.is_empty():
        estimate_container.add_child(UiBuilder.label(
            "No estimate available -- assign at least one person to this project.", 14))
        return

    var upfront := int(_estimate.get("upfront", 0)) + int(_estimate.get("platform_fee", 0))
    estimate_container.add_child(UiBuilder.label(
        "Development: %d–%d weeks" % [int(schedule["weeks_min"]), int(schedule["weeks_max"])], 15))
    estimate_container.add_child(UiBuilder.label(
        "Budget: %s–%s" % [
            Format.display(int(schedule["cost_min"])), Format.display(int(schedule["cost_max"]))], 15))
    estimate_container.add_child(UiBuilder.label(
        "Upfront cost: %s" % Format.display(upfront), 13))
    estimate_container.add_child(UiBuilder.label("Market Fit: %s" % str(market.get("label", "")), 15))
    estimate_container.add_child(UiBuilder.label("Team Experience: %s" % str(experience.get("label", "")), 15))
    estimate_container.add_child(UiBuilder.label("Risk: %s" % str(risk.get("label", "")), 15))

    var reasons: Array = risk.get("reasons", [])
    if not reasons.is_empty():
        estimate_container.add_child(UiBuilder.label(
            "%s RISK" % str(risk.get("label", "")).to_upper(), 14, false))
        for reason in reasons:
            estimate_container.add_child(UiBuilder.label("• %s" % str(reason), 13))

func _attempt_greenlight() -> GameProject:
    ## The actual state change, split out from _on_greenlight_pressed() so a
    ## test can call this directly -- the button handler goes on to navigate
    ## the scene tree, which would tear down whatever called it. Returns
    ## null and sets error_label on failure; on success the project is real,
    ## GameState.current_project is it, and the draft is spent.
    var project := DevelopmentSimulator.start_project(
        str(_draft.get("title", "")), str(_draft.get("theme_id", "")),
        str(_draft.get("genre_id", "")), str(_draft.get("platform_id", "")),
        str(_draft.get("size_id", "")), str(_draft.get("team_id", "")),
        _draft.get("assignments", {}), str(_draft.get("engine_id", "")),
        _draft.get("feature_ids", []), _draft.get("priority_choices", {})
    )
    if project == null:
        error_label.text = "You cannot afford this project."
        return null

    project.budget_target = int(_draft.get("budget_target", 0))
    ScreenRouter.clear_draft_project()
    SaveManager.autosave()
    return project

func _on_greenlight_pressed() -> void:
    if _attempt_greenlight() == null:
        return
    get_tree().change_scene_to_file("res://scenes/development/DevelopmentScreen.tscn")

func _on_edit_pressed() -> void:
    # The draft stays put -- NewGameScreen restores every choice from it. See
    # NewGameScreen._restore_draft().
    get_tree().change_scene_to_file("res://scenes/development/NewGameScreen.tscn")
