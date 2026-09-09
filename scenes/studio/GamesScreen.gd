extends Control

## The studio portfolio. Active work and shipped games share one visual
## language, while every action still routes through the existing project APIs.

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List

func _ready() -> void:
    GameClock.enter_gameplay(false)
    EventBus.week_ticked.connect(func(_y, _m, _w): _refresh())
    resized.connect(_refresh)
    _refresh()

func _refresh() -> void:
    UiBuilder.clear(list)
    _portfolio_summary()
    _active_projects()
    _released_games()

func _portfolio_summary() -> void:
    var revenue := 0
    for game in GameState.released_games:
        revenue += game.lifetime_revenue
    list.add_child(UiBuilder.stat_grid([
        {"icon": "games", "label": "Released", "value": str(GameState.released_games.size())},
        {"icon": "sales", "label": "On market", "value": str(GameState.games_on_market().size())},
        {"icon": "cash", "label": "Lifetime revenue", "value": Format.money(revenue)}
    ], 3 if get_viewport_rect().size.x >= 720 else 1))

func _active_projects() -> void:
    if GameState.active_projects.is_empty():
        return
    list.add_child(UiBuilder.section_header(
        "IN DEVELOPMENT", "Open a project to direct the team or prepare its release."))
    var grid := _grid()
    for project in GameState.active_projects:
        grid.add_child(_active_card(project))
    list.add_child(grid)

func _released_games() -> void:
    list.add_child(UiBuilder.section_header(
        "RELEASED GAMES", "Review reception, sales, profit and each game's full lifecycle."))
    if GameState.released_games.is_empty():
        var empty := UiBuilder.empty_state(
            "No games released yet",
            "Create your first game to begin building the studio's catalogue.")
        var action := UiBuilder.major_button("CREATE GAME")
        action.pressed.connect(_create_game)
        (empty["panel"] as PanelContainer).get_child(0).add_child(action)
        list.add_child(empty["panel"])
        return

    var grid := _grid()
    var ordered := GameState.released_games.duplicate()
    ordered.reverse()
    for game in ordered:
        grid.add_child(_released_card(game))
    list.add_child(grid)

func _grid() -> GridContainer:
    var grid := GridContainer.new()
    var width := get_viewport_rect().size.x
    grid.columns = 3 if width >= 1180 else (2 if width >= 720 else 1)
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return grid

func _active_card(project: GameProject) -> PanelContainer:
    var card := PanelContainer.new()
    card.theme_type_variation = &"ElevatedPanel"
    card.custom_minimum_size = Vector2(280, 190)
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var stack := VBoxContainer.new()
    stack.add_child(UiBuilder.label(project.title.to_upper(), 19))
    stack.add_child(UiBuilder.status_chip(project.phase_label(), "info"))
    var progress := project.preproduction_progress
    if project.current_phase() == "production":
        progress = project.development_progress
    elif project.current_phase() == "polish":
        progress = DevelopmentSimulator.polish_percent(project)
    var bar := ProgressBar.new()
    bar.value = progress
    bar.custom_minimum_size.y = 18
    stack.add_child(bar)
    var team := TeamManager.find_team(project.team_id)
    stack.add_child(UiBuilder.label("%d%% complete  ·  %s\nBugs %d  ·  Cost %s" % [
        int(round(progress)), team.name if team != null else "Unassigned",
        project.bugs, Format.money(project.development_cost)], 13))
    var open := UiBuilder.button("OPEN PROJECT")
    open.pressed.connect(_open_active.bind(project))
    stack.add_child(open)
    card.add_child(stack)
    return card

func _released_card(game: GameProject) -> PanelContainer:
    var card := PanelContainer.new()
    card.theme_type_variation = &"ElevatedPanel"
    card.custom_minimum_size = Vector2(280, 228)
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    var cover := GameCoverArt.new().configure(game)
    cover.custom_minimum_size = Vector2(84, 116)
    row.add_child(cover)
    var stack := VBoxContainer.new()
    stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var title := UiBuilder.label(game.title.to_upper(), 18)
    title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    stack.add_child(title)
    var status := _sales_status(game)
    stack.add_child(UiBuilder.status_chip(status[0], status[1]))
    stack.add_child(UiBuilder.label("%s · %s\n%s\nReleased %s" % [
        DataManager.display_name(DataManager.themes, game.theme_id),
        DataManager.display_name(DataManager.genres, game.genre_id),
        DataManager.display_name(DataManager.platforms, game.platform_id),
        game.release_date_label()], 13))
    var score := UiBuilder.label("%.1f  REVIEW SCORE" % game.review_score, 18)
    score.theme_type_variation = &"HeroValue"
    stack.add_child(score)
    stack.add_child(UiBuilder.label("%s sold  ·  %s revenue" % [
        Format.count(game.lifetime_sales), Format.money(game.lifetime_revenue)], 13))
    var open := UiBuilder.button("VIEW DETAILS")
    open.pressed.connect(_open.bind(game.id))
    stack.add_child(open)
    row.add_child(stack)
    card.add_child(row)
    return card

func _sales_status(game: GameProject) -> Array[String]:
    if not game.sales_active:
        return ["OFF MARKET", "info"]
    if game.weekly_sales.size() < 2:
        return ["LAUNCHING", "positive"]
    var latest := float(game.weekly_sales[game.weekly_sales.size() - 1])
    var previous := maxf(float(game.weekly_sales[game.weekly_sales.size() - 2]), 1.0)
    if latest > previous * 1.1:
        return ["TRENDING ↑", "positive"]
    if latest < previous * 0.85:
        return ["DECLINING ↓", "warning"]
    return ["STABLE →", "info"]

func _create_game() -> void:
    var teams := TeamManager.available_for_project()
    if teams.is_empty():
        get_tree().change_scene_to_file("res://scenes/studio/TeamsScreen.tscn")
        return
    ScreenRouter.selected_team_id = teams[0].id
    get_tree().change_scene_to_file("res://scenes/development/NewGameScreen.tscn")

func _open_active(project: GameProject) -> void:
    ScreenRouter.open_project(project)
    get_tree().change_scene_to_file("res://scenes/development/DevelopmentScreen.tscn")

func _open(id: String) -> void:
    ScreenRouter.open_game(id, "res://scenes/studio/GamesScreen.tscn")
    get_tree().change_scene_to_file("res://scenes/studio/GameDetailScreen.tscn")
