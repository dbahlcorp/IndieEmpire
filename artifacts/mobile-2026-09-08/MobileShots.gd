extends TestCase

## Renders the studio surface at the logical viewport sizes real phones produce,
## so the layout can be looked at rather than only asserted about. Needs a real
## display driver -- under --headless the captures are skipped and only the
## geometry checks run.

const SHOTS := [
    {"name": "iphone-se", "logical": Vector2i(523, 932)},
    {"name": "pixel-8", "logical": Vector2i(430, 955)},
    {"name": "ipad-portrait", "logical": Vector2i(699, 932)},
]

func run() -> void:
    GameState.start_company("Indie Empire", "Alex", "normal")
    SaveManager.has_active_company = true
    GameClock.set_paused(true)
    for shot in SHOTS:
        await _capture(shot)

func settle() -> void:
    for i in range(6):
        await get_tree().process_frame

func _capture(shot: Dictionary) -> void:
    var logical: Vector2i = shot["logical"]
    section("%s (%d x %d logical)" % [shot["name"], logical.x, logical.y])
    var viewport := SubViewport.new()
    viewport.size = logical
    viewport.disable_3d = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child(viewport)

    var screen := load("res://scenes/studio/StudioScreen.tscn").instantiate() as Control
    viewport.add_child(screen)
    VisualTheme._style_scene(screen)
    await settle()

    var hud := screen.get_node("%CompanyHUD") as Control
    var cards := screen.get_node("%Projects") as Control
    check(not hud.get_global_rect().intersects(cards.get_global_rect()),
        "HUD %s clears the project cards %s" % [hud.get_global_rect(), cards.get_global_rect()])

    if DisplayServer.get_name() != "headless":
        await RenderingServer.frame_post_draw
        var path := "res://artifacts/mobile-2026-09-08/%s.png" % shot["name"]
        check_equal(viewport.get_texture().get_image().save_png(path), OK, "captured " + path)

    screen.queue_free()
    viewport.queue_free()
    await settle()
