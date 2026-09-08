extends HBoxContainer

## Date, time controls, and the compact news-feed entry point. Present on every
## management screen so News does not need to consume a primary nav tab.

var _pause_button: Button
var _date_label: Label
var _speed_button: Button
var _news_button: Button

func _ready() -> void:
    add_theme_constant_override("separation", 8)

    _pause_button = Button.new()
    _pause_button.custom_minimum_size = Vector2(58, 48)
    _pause_button.expand_icon = true
    _pause_button.add_theme_constant_override("icon_max_width", 22)
    _pause_button.add_theme_font_size_override("font_size", 16)
    _pause_button.pressed.connect(_on_pause_pressed)
    add_child(_pause_button)

    _date_label = Label.new()
    _date_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _date_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _date_label.add_theme_font_size_override("font_size", 15)
    add_child(_date_label)

    _speed_button = Button.new()
    _speed_button.custom_minimum_size = Vector2(58, 48)
    _speed_button.add_theme_font_size_override("font_size", 15)
    _speed_button.pressed.connect(_on_speed_pressed)
    add_child(_speed_button)

    _news_button = Button.new()
    _news_button.custom_minimum_size = Vector2(48, 48)
    _news_button.icon = UiIcons.texture("news")
    _news_button.expand_icon = true
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
    _refresh()

func _on_week(_year: int, _month: int, _week: int) -> void:
    _refresh()

func _refresh() -> void:
    _pause_button.text = ""
    _pause_button.icon = UiIcons.texture("play" if GameClock.paused else "pause")
    _pause_button.tooltip_text = "Resume" if GameClock.paused else "Pause"
    _speed_button.text = GameClock.speed_label()
    _date_label.text = TimeManager.get_date_label()
    if GameClock.paused:
        _date_label.text += "  (paused)"

func _on_pause_pressed() -> void:
    GameClock.toggle_pause()

func _on_speed_pressed() -> void:
    GameClock.cycle_speed()

func _on_news_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/market/NewsScreen.tscn")
