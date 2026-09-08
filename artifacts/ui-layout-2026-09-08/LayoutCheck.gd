extends TestCase

func run() -> void:
    GameState.start_company("Indie Empire", "Alex", "normal")
    GameClock.set_paused(true)
    await inspect_studio("bedroom")
    check(SaveManager.load_game("ten_person_probe"), "load ten-person test fixture")
    GameClock.set_paused(true)
    await inspect_studio("ten-person")
    GameState.select_project(GameState.active_projects[0])
    var development := load("res://scenes/development/DevelopmentScreen.tscn").instantiate() as Control
    add_child(development)
    VisualTheme._style_scene(development)
    GameClock.set_paused(true)
    await settle()
    var viewport := get_viewport().get_visible_rect()
    for path in ["Margin/Shell/ClockBar", "Margin/Shell/ReleaseButton", "Margin/Shell/NavBar"]:
        check(viewport.encloses(development.get_node(path).get_global_rect()), path + " on screen")
    await capture("development")
    development.queue_free()
    await settle()

func settle() -> void:
    for i in range(4):
        await get_tree().process_frame

func capture(label: String) -> void:
    if DisplayServer.get_name() == "headless":
        return
    await RenderingServer.frame_post_draw
    var error := get_viewport().get_texture().get_image().save_png("res://artifacts/ui-layout-2026-09-08/" + label + ".png")
    check_equal(error, OK, "capture " + label)

func inspect_studio(label: String) -> void:
    var screen := load("res://scenes/studio/StudioScreen.tscn").instantiate() as Control
    add_child(screen)
    VisualTheme._style_scene(screen)
    await settle()
    var viewport := get_viewport().get_visible_rect()
    for path in ["Margin/VBox/ClockBar", "Margin/VBox/DevelopButton", "Margin/VBox/NavBar"]:
        check(viewport.encloses(screen.get_node(path).get_global_rect()), label + " " + path + " on screen")
    for active in GameState.active_projects:
        var card: Button = screen._cards[active.id]["button"]
        var connections := card.pressed.get_connections()
        check_equal(connections.size(), 1, "one project action")
        var action: Callable = connections[0]["callable"]
        check_equal(action.get_bound_arguments()[0].id, active.id, "card opens its own project")
        card.grab_focus()
        screen._refresh()
        check(card.has_focus(), "weekly refresh retains project focus")
    var scroll := screen.get_node("Margin/VBox/Scroll") as ScrollContainer
    var art := screen.get_node("%OfficeArt") as Control
    check(scroll.get_global_rect().encloses(art.get_global_rect()), label + " room fully visible on entry")
    await capture(label)
    scroll.scroll_vertical = 10000
    await settle()
    var finances := screen.get_node("%RunwayLabel") as Label
    check(scroll.get_global_rect().encloses(finances.get_global_rect()), label + " lower content reachable")
    await capture(label + "-scrolled")
    screen.queue_free()
    await settle()

