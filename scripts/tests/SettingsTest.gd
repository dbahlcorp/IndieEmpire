extends TestCase

## PA.14 -- player settings live in user://settings.json, separate from any
## company save, and survive a new company or a bankruptcy. This covers the
## fields added for the playable alpha (game speed, autosave, text scale) and
## that each one still does what it says.

var _snapshot: Dictionary = {}

func run() -> void:
    _take_snapshot()
    _all_fields_round_trip()
    _values_are_clamped()
    _text_scale_reaches_the_ui()
    _default_speed_starts_the_clock()
    _autosave_toggle_gates_routine_saves()
    await _settings_screen_survives_the_largest_text()
    _restore_snapshot()

func _take_snapshot() -> void:
    _snapshot = {
        "compact_numbers": Settings.compact_numbers,
        "notifications_enabled": Settings.notifications_enabled,
        "master_volume": Settings.master_volume,
        "music_volume": Settings.music_volume,
        "sfx_volume": Settings.sfx_volume,
        "ambience_volume": Settings.ambience_volume,
        "haptics_enabled": Settings.haptics_enabled,
        "onboarding_enabled": Settings.onboarding_enabled,
        "reduced_motion": Settings.reduced_motion,
        "default_game_speed": Settings.default_game_speed,
        "autosave_enabled": Settings.autosave_enabled,
        "text_scale": Settings.text_scale,
    }

func _restore_snapshot() -> void:
    for key in _snapshot:
        Settings.set(key, _snapshot[key])
    Settings.save_settings()
    VisualTheme.apply_text_scale()

func _all_fields_round_trip() -> void:
    section("every preference persists through a save/load cycle")
    Settings.compact_numbers = false
    Settings.reduced_motion = true
    Settings.onboarding_enabled = false
    Settings.default_game_speed = 2
    Settings.autosave_enabled = false
    Settings.text_scale = 1.15
    Settings.music_volume = 0.33
    Settings.sfx_volume = 0.44
    Settings.save_settings()

    # Scramble in memory, then reload from disk.
    Settings.compact_numbers = true
    Settings.reduced_motion = false
    Settings.onboarding_enabled = true
    Settings.default_game_speed = 0
    Settings.autosave_enabled = true
    Settings.text_scale = 1.0
    Settings.music_volume = 1.0
    Settings.sfx_volume = 1.0
    Settings.load_settings()

    check_equal(Settings.compact_numbers, false, "compact numbers persists")
    check_equal(Settings.reduced_motion, true, "reduced motion persists")
    check_equal(Settings.onboarding_enabled, false, "tutorials preference persists")
    check_equal(Settings.default_game_speed, 2, "starting game speed persists")
    check_equal(Settings.autosave_enabled, false, "autosave preference persists")
    check_approx(Settings.text_scale, 1.15, "text scale persists")
    check_approx(Settings.music_volume, 0.33, "music volume persists")
    check_approx(Settings.sfx_volume, 0.44, "sfx volume persists")

func _values_are_clamped() -> void:
    section("out-of-range inputs are snapped to a valid choice")
    Settings.set_text_scale(9.0)
    check_approx(Settings.text_scale, Settings.TEXT_SCALES.back(), "huge text scale snaps to the largest step")
    Settings.set_text_scale(0.1)
    check_approx(Settings.text_scale, Settings.TEXT_SCALES[0], "tiny text scale snaps to standard")
    Settings.set_text_scale(1.14)
    check_approx(Settings.text_scale, 1.15, "a near value snaps to the nearest step")
    check_equal(Settings.text_scale_index(), 1, "text_scale_index round-trips the choice")

    Settings.set_default_game_speed(99)
    check_equal(Settings.default_game_speed, GameClock.SPEEDS.size() - 1, "game speed clamps to the fastest")
    Settings.set_default_game_speed(-5)
    check_equal(Settings.default_game_speed, 0, "game speed clamps to the slowest")

func _text_scale_reaches_the_ui() -> void:
    section("text scale drives the code-built UI and the theme")
    Settings.set_text_scale(1.0)
    check_equal(UiBuilder.scaled_font(15), 15, "standard scale is identity")
    check_equal(VisualTheme.game_theme.default_font_size, 15, "theme base size at standard scale")

    Settings.set_text_scale(1.3)
    check_equal(UiBuilder.scaled_font(15), 20, "larger scale enlarges a 15px label to 20px")
    check_greater(float(VisualTheme.game_theme.default_font_size), 15.0, "theme base size grew")
    var big_button := UiBuilder.button("OK")
    check_greater(big_button.custom_minimum_size.y, float(UiBuilder.TAP_HEIGHT) - 0.1,
        "tap targets never shrink below the mobile minimum")
    big_button.free()

    Settings.set_text_scale(1.0)

func _default_speed_starts_the_clock() -> void:
    section("a company begins at the preferred speed")
    var restore_company := SaveManager.has_active_company
    GameState.start_company("Clock Co", "Rae", "normal")
    SaveManager.has_active_company = true

    Settings.default_game_speed = 2
    GameClock.apply_default_speed()
    check_equal(GameClock.speed_index, 2, "apply_default_speed adopts the setting")

    Settings.default_game_speed = 0
    GameClock.apply_default_speed()
    check_equal(GameClock.speed_index, 0, "changing the setting changes the start speed")

    SaveManager.has_active_company = restore_company

func _autosave_toggle_gates_routine_saves() -> void:
    section("autosave off stops routine saves but never the safety save")
    GameState.start_company("Save Co", "Nour", "normal")
    SaveManager.has_active_company = true
    SaveManager.delete_save(SaveManager.AUTOSAVE)

    Settings.autosave_enabled = false
    check_equal(SaveManager.autosave(), false, "routine autosave is skipped when disabled")
    check_equal(SaveManager.has_save(SaveManager.AUTOSAVE), false, "nothing was written")

    check_equal(SaveManager.safety_save(), true, "the safety save ignores the preference")
    check_equal(SaveManager.has_save(SaveManager.AUTOSAVE), true, "a save exists after backgrounding")

    Settings.autosave_enabled = true
    check_equal(SaveManager.autosave(), true, "routine autosave resumes when re-enabled")

    SaveManager.delete_save(SaveManager.AUTOSAVE)

func _settings_screen_survives_the_largest_text() -> void:
    section("the settings screen stays usable at the largest text size")
    Settings.set_text_scale(Settings.TEXT_SCALES.back())

    var viewport := SubViewport.new()
    viewport.size = Vector2i(430, 932)
    viewport.disable_3d = true
    add_child(viewport)
    var screen := load("res://scenes/menu/SettingsScreen.tscn").instantiate() as Control
    viewport.add_child(screen)
    VisualTheme._style_scene(screen)
    for _i in range(6):
        await get_tree().process_frame

    var list := screen.get_node("Margin/VBox/Scroll/List") as VBoxContainer
    check_greater(list.get_child_count(), 6.0, "the list built its rows")
    var viewport_width := 430.0
    for row in list.get_children():
        if row is Control:
            check((row as Control).get_global_rect().end.x <= viewport_width + 1.0,
                "row '%s' does not run off the right edge at 1.3x text" % row.name)
        if row is Button:
            check((row as Button).size.y >= 44.0,
                "button '%s' stays thumb-sized at 1.3x text (%.0f)" % [row.name, (row as Button).size.y])

    screen.queue_free()
    viewport.queue_free()
    await get_tree().process_frame
    Settings.set_text_scale(1.0)
