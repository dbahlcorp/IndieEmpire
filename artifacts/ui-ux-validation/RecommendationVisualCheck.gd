extends Node

const OUTPUT := "res://artifacts/ui-ux-validation/"
const RESOLUTION := Vector2i(1600, 900)

func _ready() -> void:
    GameState.start_company("Bright Anvil Games", "Alex", "normal")
    SaveManager.has_active_company = true
    Settings.onboarding_enabled = false
    Settings.reduced_motion = true
    GameClock.set_paused(true)
    FinanceManager.earn(750_000, Ledger.Kind.OTHER, "Seed investment")
    OfficeManager.move_to("shared_workspace")
    FinanceManager.force_spend(18_500, Ledger.Kind.SOFTWARE, "Production software")
    LaborMarketManager.refresh_market(false)
    ContractManager.refresh_offers(false)
    get_window().size = RESOLUTION
    await _settle()
    await _capture_scene("res://scenes/company/FinancialsScreen.tscn", "recommendation-financials-1600x900.png")
    await _capture_scene("res://scenes/company/HiringScreen.tscn", "recommendation-hiring-1600x900.png")
    await _capture_scene("res://scenes/company/ContractsScreen.tscn", "recommendation-contracts-1600x900.png")
    await _capture_scene("res://scenes/studio/OfficeScreen.tscn", "recommendation-office-1600x900.png")
    await _capture_scene("res://scenes/studio/OfficeScreen.tscn",
        "recommendation-office-customization-1600x900.png", true)
    get_tree().quit()

func _capture_scene(path: String, filename: String, scroll_to_bottom: bool = false) -> void:
    var screen := load(path).instantiate() as Control
    add_child(screen)
    VisualTheme._style_scene(screen)
    await _settle()
    if scroll_to_bottom:
        var scroll := screen.get_node_or_null("Margin/VBox/Scroll") as ScrollContainer
        if scroll != null:
            scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
            await _settle()
    await RenderingServer.frame_post_draw
    var error := get_viewport().get_texture().get_image().save_png(OUTPUT + filename)
    assert(error == OK, "Could not save " + filename)
    screen.queue_free()
    await _settle()

func _settle() -> void:
    for _index in 18:
        await get_tree().process_frame
