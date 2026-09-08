extends TestCase

func run() -> void:
    GameState.start_company("Indie Empire", "Alex", "normal")
    GameClock.set_paused(true)
    await inspect_surface("bedroom")
    check(SaveManager.load_game("ten_person_probe"), "load staffed studio fixture")
    GameClock.set_paused(true)
    await inspect_surface("ten-person")
    var office := load("res://scenes/studio/OfficeScreen.tscn").instantiate() as Control
    add_child(office)
    VisualTheme._style_scene(office)
    await settle()
    var margin := office.get_node("Margin") as Control
    check(margin.size.x <= 520.1, "management screen stays compact")
    await capture("office-menu")
    office.queue_free()
    await settle()

func settle() -> void:
    for i in range(5):
        await get_tree().process_frame

func capture(label: String) -> void:
    if DisplayServer.get_name() == "headless":
        return
    await RenderingServer.frame_post_draw
    var suffix := "-wide" if get_viewport().get_visible_rect().size.x > 700 else "-portrait"
    check_equal(get_viewport().get_texture().get_image().save_png("res://artifacts/studio-surface-2026-09-08/" + label + suffix + ".png"), OK, "capture " + label)

func inspect_surface(label: String) -> void:
    var screen := load("res://scenes/studio/StudioScreen.tscn").instantiate() as Control
    add_child(screen)
    VisualTheme._style_scene(screen)
    await settle()
    var bounds := get_viewport().get_visible_rect()
    for id in ["CompanyHUD", "ClockBar", "OfficeArt", "MenuButton", "DevelopButton", "Projects", "BottomDock"]:
        check(bounds.encloses(screen.get_node("%" + id).get_global_rect()), label + " " + id + " visible")
    check(not screen.get_node("%ManagementOverlay").visible, "menus start closed")
    var room: Control = screen.get_node("%OfficeArt")
    check(room.get_parent() == screen, "room is the play surface, not scroll content")
    await capture(label)
    GameClock.set_paused(false)
    screen.get_node("%MenuButton").pressed.emit()
    await settle()
    check(GameClock.paused, "menu pauses the simulation")
    check(screen.get_node("%ManagementOverlay").visible, "studio menu opens")
    check(bounds.encloses(screen.get_node("%MenuPanel").get_global_rect()), "menu fits viewport")
    for id in ["OfficeButton", "TeamsButton", "StaffButton", "HiringButton", "FinanceButton", "ContractsButton", "GamesButton", "MarketButton", "EngineButton", "CompanyButton"]:
        var button := screen.get_node("%" + id) as Button
        check_equal(button.pressed.get_connections().size(), 1, id + " has a destination")
    await capture(label + "-menu")
    screen.get_node("%CloseMenuButton").pressed.emit()
    check(not screen.get_node("%ManagementOverlay").visible, "menu closes")
    check(not GameClock.paused, "closing restores running clock")
    GameClock.set_paused(true)
    screen._open_menu()
    screen._close_menu()
    check(GameClock.paused, "already paused clock remains paused")
    screen.queue_free()
    await settle()
