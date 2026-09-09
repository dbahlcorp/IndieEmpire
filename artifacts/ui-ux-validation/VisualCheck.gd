extends Node

const OUTPUT := "res://artifacts/ui-ux-validation/"
const SIZES := [
    Vector2i(1280, 720), Vector2i(1600, 900),
    Vector2i(1920, 1080), Vector2i(2560, 1440)
]

func _ready() -> void:
    GameState.start_company("Bright Anvil Games", "Alex", "normal")
    SaveManager.has_active_company = true
    Settings.onboarding_enabled = false
    GameClock.set_paused(true)
    for resolution in SIZES:
        get_window().size = resolution
        await _settle()
        await _capture_scene(
            "res://scenes/studio/StudioScreen.tscn",
            "studio-%dx%d.png" % [resolution.x, resolution.y])
    get_window().size = Vector2i(1600, 900)
    await _capture_scene("res://scenes/studio/GamesScreen.tscn", "games-1600x900.png")
    await _capture_scene("res://scenes/studio/TeamsScreen.tscn", "teams-1600x900.png")
    await _capture_scene("res://scenes/company/ResearchScreen.tscn", "research-1600x900.png")
    await _capture_scene("res://scenes/development/NewGameScreen.tscn", "create-game-1600x900.png")
    get_tree().quit()

func _capture_scene(path: String, filename: String) -> void:
    var screen := load(path).instantiate() as Control
    add_child(screen)
    VisualTheme._style_scene(screen)
    await _settle()
    await RenderingServer.frame_post_draw
    var error := get_viewport().get_texture().get_image().save_png(OUTPUT + filename)
    assert(error == OK, "Could not save " + filename)
    screen.queue_free()
    await _settle()

func _settle() -> void:
    for index in 18:
        await get_tree().process_frame
