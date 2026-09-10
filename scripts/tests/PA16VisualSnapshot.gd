extends Node

## Deterministic real-screen fixture for PA.16 art direction review. It captures
## actual application scenes at the portrait reference viewport rather than a
## separate mockup. Run with a renderer (not --headless) for meaningful PNGs.

const DEFAULT_OUTPUT_DIR := "res://artifacts/pa16-visual-validation"
const SCREENS := [
    {"name": "01-main-menu", "scene": "res://scenes/menu/MainMenuScreen.tscn"},
    {"name": "02-new-company-1985", "scene": "res://scenes/company/NewCompanyScreen.tscn"},
    {"name": "03-bedroom-founder-1985", "scene": "res://scenes/studio/StudioScreen.tscn", "office": "bedroom", "year": 1985},
    {"name": "04-shared-studio-1995", "scene": "res://scenes/studio/StudioScreen.tscn", "office": "shared_workspace", "year": 1995},
    {"name": "05-five-person-studio-2005", "scene": "res://scenes/studio/StudioScreen.tscn", "office": "small_office", "year": 2005},
    {"name": "06-professional-studio-2015", "scene": "res://scenes/studio/StudioScreen.tscn", "office": "professional_studio", "year": 2015},
    {"name": "07-ten-person-studio-2025", "scene": "res://scenes/studio/StudioScreen.tscn", "office": "large_studio_floor", "year": 2025},
    {"name": "08-new-project", "scene": "res://scenes/development/NewGameScreen.tscn"},
    {"name": "09-greenlight", "scene": "res://scenes/development/GreenlightScreen.tscn", "draft": true},
    {"name": "10-research", "scene": "res://scenes/company/ResearchScreen.tscn"},
    {"name": "11-engine-lab", "scene": "res://scenes/company/EngineLabScreen.tscn"},
    {"name": "12-hiring", "scene": "res://scenes/company/HiringScreen.tscn"},
    {"name": "13-employee-detail", "scene": "res://scenes/company/EmployeeScreen.tscn"},
    {"name": "14-game-detail", "scene": "res://scenes/studio/GameDetailScreen.tscn"},
    {"name": "15-franchise", "scene": "res://scenes/studio/FranchiseDetailScreen.tscn"},
    {"name": "16-release-review", "scene": "res://scenes/release/ReleaseResultsScreen.tscn"},
    {"name": "17-market", "scene": "res://scenes/market/MarketScreen.tscn"},
    {"name": "18-awards", "scene": "res://scenes/company/AwardsCeremonyScreen.tscn"},
    {"name": "19-statistics", "scene": "res://scenes/company/RecordsScreen.tscn"},
    {"name": "20-financial-crisis", "scene": "res://scenes/company/CrisisScreen.tscn", "crisis": true},
    {"name": "21-company", "scene": "res://scenes/company/CompanyScreen.tscn"},
    {"name": "22-game-over", "scene": "res://scenes/company/GameOverScreen.tscn"},
]

var _output_dir := DEFAULT_OUTPUT_DIR
var _bottom_output_dir := DEFAULT_OUTPUT_DIR + "/bottom-scroll"
var _capture_errors := 0

func _ready() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--output="):
            _output_dir = argument.trim_prefix("--output=").trim_suffix("/")
    _bottom_output_dir = _output_dir + "/bottom-scroll"
    _seed_fixture()
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_dir))
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_bottom_output_dir))
    for fixture in SCREENS:
        _prepare_fixture(fixture)
        await _capture(str(fixture["scene"]), "%s.png" % str(fixture["name"]))
    print("PA.16 visual snapshots written to %s (%d errors)" % [
        ProjectSettings.globalize_path(_output_dir), _capture_errors])
    get_tree().quit(_capture_errors)

func _seed_fixture() -> void:
    GameState.start_company("Lantern Byte", "Alex Rivera", "normal")
    SaveManager.has_active_company = true
    for index in 9:
        var employee := EmployeeManager.generate_candidate(
            ["programmer", "designer", "artist", "writer", "qa_tester"][index % 5],
            ["junior", "mid", "senior"][index % 3], "Fixture Staff %02d" % (index + 1), 16000 + index)
        employee.id = GameState.next_employee_id()
        employee.status = "active"
        GameState.employees.append(employee)
        TeamManager.assign_employee(employee, "team_a")
    TimeManager.current_year = 2025
    GameState.office_id = "large_studio_floor"
    var game := GameProject.new()
    game.id = "pa16_fixture_game"
    game.title = "Signal Beyond the Last Horizon"
    game.genre_id = "adventure"
    game.theme_id = "space"
    game.platform_id = "nexus_hd"
    game.series_id = "pa16_signal_series"
    game.start_year = 2006
    game.release_year = 2008
    game.release_month = 9
    game.release_week = 2
    game.released = true
    game.review_score = 8.7
    game.lifetime_sales = 148000
    game.lifetime_revenue = 3100000
    game.weekly_sales = [48000, 39000, 31000, 18000, 12000]
    game.weekly_revenue = [1000000, 820000, 650000, 380000, 250000]
    GameState.released_games.append(game)
    ScreenRouter.selected_game_id = game.id
    var franchise := Franchise.new()
    franchise.id = game.series_id
    franchise.name = "Signal Beyond"
    franchise.original_game_id = game.id
    franchise.game_ids.append(game.id)
    franchise.founded_year = game.release_year
    franchise.fan_interest = 76.0
    franchise.reputation = 87.0
    GameState.franchises.append(franchise)
    ScreenRouter.selected_franchise_id = franchise.id
    var founder := EmployeeManager.founder()
    if founder != null:
        ScreenRouter.selected_employee_id = founder.id
    var ceremony := {"year": 2008, "categories": [{
        "award_id": "goty", "name": "Game of the Year", "winner_id": game.id,
        "nominees": [{"game_id": game.id, "title": game.title}]
    }], "rewards": {"wins": 1, "nominations": 1, "reputation": 2.0, "fans": 1200}}
    GameState.award_ceremonies.append(ceremony)
    ScreenRouter.selected_ceremony_year = 2008
    GameClock.set_paused(true)

func _prepare_fixture(fixture: Dictionary) -> void:
    # Layout review needs the settled frame. Motion behavior has its own test
    # coverage and snapshot; capturing five frames into a reveal made otherwise
    # identical screens look randomly dimmed.
    Settings.reduced_motion = true
    var active_staff := 10
    match str(fixture.get("office", "")):
        "bedroom": active_staff = 1
        "shared_workspace": active_staff = 3
        "small_office": active_staff = 5
        "professional_studio": active_staff = 8
        "large_studio_floor": active_staff = 10
    for index in GameState.employees.size():
        GameState.employees[index].status = "active" if index < active_staff else "departed"
    if fixture.has("year"):
        TimeManager.current_year = int(fixture["year"])
    if fixture.has("office"):
        GameState.office_id = str(fixture["office"])
    GameState.cash = 420000
    GameState.overdrawn_weeks = 0
    if bool(fixture.get("crisis", false)):
        GameState.cash = -2500
        GameState.overdrawn_weeks = 4
    if bool(fixture.get("draft", false)):
        ScreenRouter.draft_project = {
            "title": "Signal Beyond the Last Horizon II: Afterlight",
            "genre_id": "adventure", "theme_id": "space", "platform_id": "nexus_hd",
            "size_id": "small", "team_id": "team_a",
            "assignments": TeamManager.default_assignments("team_a"),
            "engine_id": "", "feature_ids": ["save_system", "dialogue_trees"],
            "priority_choices": {}, "series_id": "pa16_signal_series",
        }
    else:
        ScreenRouter.draft_project = {}

func _capture(scene_path: String, filename: String) -> void:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(430, 932)
    viewport.disable_3d = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child(viewport)
    var screen := load(scene_path).instantiate() as Control
    viewport.add_child(screen)
    # These screens are embedded directly rather than entered through
    # SceneTree.change_scene_to_file(), so VisualTheme's scene_changed hook does
    # not run. Apply the same runtime styling explicitly or the fixture captures
    # Godot's default white labels/buttons instead of the shipped presentation.
    VisualTheme._style_scene(screen)
    await get_tree().process_frame
    if scene_path.ends_with("ReleaseResultsScreen.tscn"):
        screen.call("_skip_to_end")
    for frame in 5:
        await get_tree().process_frame
    var image := viewport.get_texture().get_image()
    var output := ProjectSettings.globalize_path("%s/%s" % [_output_dir, filename])
    var error := image.save_png(output)
    print("snapshot %s (%s)" % [output, error_string(error)])
    if error != OK:
        _capture_errors += 1
        push_error("Could not save visual snapshot %s: %s" % [output, error_string(error)])
    await _capture_bottom(screen, filename, viewport)
    viewport.queue_free()
    await get_tree().process_frame

func _capture_bottom(screen: Control, filename: String, viewport: SubViewport) -> void:
    var scrolls := screen.find_children("*", "ScrollContainer", true, false)
    var primary: ScrollContainer = null
    var largest_area := 0.0
    for candidate in scrolls:
        var scroll := candidate as ScrollContainer
        if scroll == null or not scroll.is_visible_in_tree():
            continue
        var bar := scroll.get_v_scroll_bar()
        if bar.max_value <= bar.page + 1.0:
            continue
        var area := scroll.size.x * scroll.size.y
        if area > largest_area:
            largest_area = area
            primary = scroll
    if primary == null:
        return
    primary.scroll_vertical = int(primary.get_v_scroll_bar().max_value)
    await get_tree().process_frame
    await get_tree().process_frame
    var image := viewport.get_texture().get_image()
    var output := ProjectSettings.globalize_path("%s/%s" % [_bottom_output_dir, filename])
    var error := image.save_png(output)
    print("bottom snapshot %s (%s)" % [output, error_string(error)])
    if error != OK:
        _capture_errors += 1
        push_error("Could not save bottom visual snapshot %s: %s" % [output, error_string(error)])
