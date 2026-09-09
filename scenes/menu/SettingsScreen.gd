extends Control

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var back_button: Button = $Margin/VBox/BackButton

func _ready() -> void:
    GameClock.enter_menu()
    back_button.pressed.connect(_on_back)
    _build()

func _build() -> void:
    UiBuilder.clear(list)

    list.add_child(UiBuilder.heading("AUDIO"))
    _volume_control("Master", Settings.master_volume,
        func(value): Settings.set_master_volume(value))
    _volume_control("Music", Settings.music_volume,
        func(value): Settings.set_music_volume(value))
    _volume_control("Sound effects", Settings.sfx_volume,
        func(value): Settings.set_sfx_volume(value))
    _volume_control("Office ambience", Settings.ambience_volume,
        func(value): Settings.set_ambience_volume(value))
    var haptics := UiBuilder.toggle("Subtle haptics on iOS", Settings.haptics_enabled)
    haptics.toggled.connect(func(value): Settings.set_haptics_enabled(value))
    list.add_child(haptics)
    list.add_child(UiBuilder.label(
        "Music continues across navigation. Office ambience scales with the workspace.", 13))

    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("DISPLAY"))
    var numbers := UiBuilder.toggle("Compact numbers (12.4K)", Settings.compact_numbers)
    numbers.toggled.connect(_on_numbers_toggled)
    list.add_child(numbers)
    list.add_child(UiBuilder.label(
        "Dashboards show shortened numbers. Financial pages always show exact amounts.", 13))

    var motion := UiBuilder.toggle("Reduce motion", Settings.reduced_motion)
    motion.toggled.connect(func(value): Settings.set_reduced_motion(value))
    list.add_child(motion)
    list.add_child(UiBuilder.label(
        "Release reveals, count-ups and charts appear instantly instead of animating.", 13))

    _option_row("Text size", Settings.TEXT_SCALE_LABELS, Settings.text_scale_index(),
        func(index): Settings.set_text_scale(Settings.TEXT_SCALES[index]); _rebuild())
    list.add_child(UiBuilder.label(
        "Enlarges interface text. Larger sizes trade on-screen space for readability.", 13))

    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("GAMEPLAY"))
    _option_row("Starting game speed", GameClock.SPEED_LABELS, Settings.default_game_speed,
        func(index): Settings.set_default_game_speed(index))
    list.add_child(UiBuilder.label(
        "The clock speed a company begins and resumes at.", 13))

    var autosave := UiBuilder.toggle("Autosave", Settings.autosave_enabled)
    autosave.toggled.connect(func(value): Settings.set_autosave_enabled(value))
    list.add_child(autosave)
    list.add_child(UiBuilder.label(
        "Saves automatically as you play. The game still saves when it is closed or interrupted.", 13))

    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("NOTIFICATIONS"))
    var toasts := UiBuilder.toggle("Show notifications", Settings.notifications_enabled)
    toasts.toggled.connect(_on_toasts_toggled)
    list.add_child(toasts)

    var onboarding := UiBuilder.toggle("Tutorials", Settings.onboarding_enabled)
    onboarding.toggled.connect(func(value): Settings.set_onboarding_enabled(value))
    list.add_child(onboarding)
    list.add_child(UiBuilder.label(
        "Turn this off to skip first-hour guidance and reveal every management area.", 13))

    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("SAVE DATA"))
    var wipe := UiBuilder.button("DELETE ALL SAVES")
    wipe.pressed.connect(_on_delete_saves)
    list.add_child(wipe)

func _volume_control(label_text: String, value: float, setter: Callable) -> void:
    var heading := UiBuilder.label("%s   %d%%" % [label_text, int(round(value * 100.0))], 14)
    list.add_child(heading)
    var slider := HSlider.new()
    slider.min_value = 0.0
    slider.max_value = 100.0
    slider.step = 5.0
    slider.value = value * 100.0
    slider.custom_minimum_size = Vector2(0, 44)
    slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    slider.value_changed.connect(func(percent: float):
        heading.text = "%s   %d%%" % [label_text, int(round(percent))]
        setter.call(percent / 100.0))
    list.add_child(slider)

func _option_row(label_text: String, options: Array, selected: int, on_pick: Callable) -> void:
    list.add_child(UiBuilder.label(label_text, 14))
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    var buttons: Array[Button] = []
    for index in options.size():
        var choice := UiBuilder.button(str(options[index]))
        choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        choice.toggle_mode = true
        choice.button_pressed = index == selected
        choice.theme_type_variation = &"PrimaryButton" if index == selected else &"SecondaryButton"
        var this_index := index
        choice.pressed.connect(func():
            for other in buttons.size():
                buttons[other].button_pressed = other == this_index
                buttons[other].theme_type_variation = (
                    &"PrimaryButton" if other == this_index else &"SecondaryButton")
            on_pick.call(this_index))
        buttons.append(choice)
        row.add_child(choice)
    list.add_child(row)

func _rebuild() -> void:
    _build()

func _on_numbers_toggled(value: bool) -> void:
    Settings.set_compact_numbers(value)

func _on_toasts_toggled(value: bool) -> void:
    Settings.set_notifications_enabled(value)
    if value:
        EventBus.notify("NOTIFICATIONS", "You will see updates like this")

func _on_delete_saves() -> void:
    var confirm := ConfirmationDialog.new()
    confirm.title = "Delete all saves?"
    confirm.dialog_text = "Every company, including the autosave, will be erased."
    confirm.ok_button_text = "DELETE"
    confirm.confirmed.connect(_do_delete_saves)
    add_child(confirm)
    confirm.popup_centered()

func _do_delete_saves() -> void:
    SaveManager.delete_save(SaveManager.AUTOSAVE)
    for slot in SaveManager.MANUAL_SLOTS:
        SaveManager.delete_save(slot)
    SaveManager.has_active_company = false
    EventBus.notify("SAVES DELETED", "All companies erased", true)
    get_tree().change_scene_to_file("res://scenes/menu/MainMenuScreen.tscn")

func _on_back() -> void:
    get_tree().change_scene_to_file(ScreenRouter.return_scene)
