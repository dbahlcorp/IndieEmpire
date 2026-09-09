extends HBoxContainer

## Date, time controls, and the compact news-feed entry point. Present on every
## management screen so News does not need to consume a primary nav tab.

var _pause_button: Button
var _date_label: Label
var _speed_buttons: Array[Button] = []
var _news_button: Button

func _ready() -> void:
    add_theme_constant_override("separation", 4)

    _pause_button = Button.new()
    _pause_button.custom_minimum_size = Vector2(44, 46)
    _pause_button.expand_icon = true
    _pause_button.add_theme_constant_override("icon_max_width", 22)
    _pause_button.add_theme_font_size_override("font_size", 16)
    _pause_button.pressed.connect(_on_pause_pressed)
    add_child(_pause_button)

    _date_label = Label.new()
    _date_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _date_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _date_label.add_theme_font_size_override("font_size", 14)
    _date_label.tooltip_text = "Current simulation date"
    add_child(_date_label)

    for index in GameClock.SPEED_LABELS.size():
        var speed := Button.new()
        speed.text = str(GameClock.SPEED_LABELS[index])
        speed.custom_minimum_size = Vector2(38, 46)
        speed.add_theme_font_size_override("font_size", 13)
        speed.tooltip_text = "Simulation speed %s  [%d]" % [speed.text, index + 1]
        speed.pressed.connect(_on_speed_pressed.bind(index))
        _speed_buttons.append(speed)
        add_child(speed)

    _news_button = Button.new()
    _news_button.custom_minimum_size = Vector2(44, 46)
    _news_button.icon = UiIcons.texture("news")
    _news_button.expand_icon = true
    for state in ["normal", "hover", "pressed", "focus"]:
        _news_button.add_theme_color_override("icon_" + state + "_color", Color("#315f65"))
    _news_button.add_theme_constant_override("icon_max_width", 21)
    _news_button.tooltip_text = "News feed"
    _news_button.disabled = (
        get_tree().current_scene != null
        and get_tree().current_scene.scene_file_path == "res://scenes/market/NewsScreen.tscn"
    )
    _news_button.pressed.connect(_on_news_pressed)
    add_child(_news_button)

    GameClock.state_changed.connect(_refresh)
    EventBus.week_ticked.connect(_on_week)
    resized.connect(_layout_controls)
    _refresh()
    _layout_controls.call_deferred()

func _on_week(_year: int, _month: int, _week: int) -> void:
    _refresh()

func _refresh() -> void:
    _pause_button.text = ""
    _pause_button.icon = UiIcons.texture("play" if GameClock.paused else "pause")
    _pause_button.tooltip_text = "Resume" if GameClock.paused else "Pause"
    for index in _speed_buttons.size():
        var button := _speed_buttons[index]
        var active := index == GameClock.speed_index
        button.theme_type_variation = &"ClockSpeedActive" if active else &"ClockButton"
        button.set_meta("active_speed", active)
    _date_label.text = TimeManager.get_date_label()
    if GameClock.paused:
        _date_label.text += "  (paused)"

func _on_pause_pressed() -> void:
    GameClock.toggle_pause()

func _on_speed_pressed(index: int) -> void:
    GameClock.set_speed(index)
    if GameClock.paused:
        GameClock.set_paused(false)

func _on_news_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/market/NewsScreen.tscn")

func _layout_controls() -> void:
    if _news_button == null:
        return
    _news_button.visible = size.x >= 420.0

func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    var focus := get_viewport().gui_get_focus_owner()
    if focus is LineEdit or focus is TextEdit:
        return
    match event.keycode:
        KEY_SPACE:
            GameClock.toggle_pause()
        KEY_1:
            GameClock.set_speed(0)
            if GameClock.paused:
                GameClock.set_paused(false)
        KEY_2:
            GameClock.set_speed(1)
            if GameClock.paused:
                GameClock.set_paused(false)
        KEY_3:
            GameClock.set_speed(2)
            if GameClock.paused:
                GameClock.set_paused(false)
        _:
            return
    get_viewport().set_input_as_handled()

