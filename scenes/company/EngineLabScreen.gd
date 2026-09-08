extends Control

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var back_button: Button = $Margin/VBox/BackButton

var _name_input: LineEdit
var _feature_checks: Dictionary = {}
var _cost_label: Label
var _build_button: Button

func _ready() -> void:
    GameClock.enter_menu()
    back_button.pressed.connect(_back)
    _refresh()

func _refresh(message: String = "") -> void:
    UiBuilder.clear(list)
    _feature_checks.clear()
    _owned_engines()
    _builder(message)

func _owned_engines() -> void:
    list.add_child(UiBuilder.heading("YOUR ENGINES"))
    if GameState.custom_engines.is_empty():
        list.add_child(UiBuilder.label(
            "No custom engines yet. Your games currently use platform-default tools.", 14, true))
        return
    for engine in GameState.custom_engines:
        list.add_child(UiBuilder.label("%s\n%s\nBuilt %d   Cost %s" % [
            str(engine.get("name", "Custom Engine")).to_upper(),
            EngineManager.feature_names(engine.get("feature_ids", [])),
            int(engine.get("created_year", 0)),
            Format.money_exact(int(engine.get("cost", 0)))
        ], 14))

func _builder(message: String) -> void:
    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("BUILD AN ENGINE"))
    list.add_child(UiBuilder.label(
        "Research new technology in the Research screen; every engine-capable "
        + "technology you have completed can go into an engine here.", 13, true))
    _name_input = LineEdit.new()
    _name_input.custom_minimum_size = Vector2(0, UiBuilder.TAP_HEIGHT)
    _name_input.placeholder_text = "Engine name"
    _name_input.text_changed.connect(func(_value): _update_build_state())
    list.add_child(_name_input)

    var buildable := EngineManager.engine_capable_technologies()
    if buildable.is_empty():
        list.add_child(UiBuilder.label(
            "No engine-capable technology researched yet.", 14, true))
    for item in buildable:
        var id := str(item["id"])
        var check := CheckBox.new()
        check.custom_minimum_size = Vector2(0, UiBuilder.TAP_HEIGHT)
        check.text = "%s  (%s)" % [
            str(item.get("display_name", id)), str(item.get("branch", ""))]
        check.toggled.connect(func(_pressed): _update_build_state())
        list.add_child(check)
        _feature_checks[id] = check

    _cost_label = UiBuilder.label("", 14, true)
    list.add_child(_cost_label)
    _build_button = UiBuilder.button("BUILD ENGINE", 62)
    _build_button.pressed.connect(_build_engine)
    list.add_child(_build_button)
    if not message.is_empty():
        list.add_child(UiBuilder.label(message, 14, true))
    _update_build_state()

func _selected_features() -> Array:
    var selected: Array = []
    for id in _feature_checks:
        var check: CheckBox = _feature_checks[id]
        if check.button_pressed:
            selected.append(str(id))
    return selected

func _update_build_state() -> void:
    if _build_button == null:
        return
    var selected := _selected_features()
    var cost := EngineManager.build_cost(selected)
    _cost_label.text = "%d feature%s   Build cost %s" % [
        selected.size(), "" if selected.size() == 1 else "s", Format.money_exact(cost)]
    _build_button.disabled = not EngineManager.can_build(_name_input.text, selected)

func _build_engine() -> void:
    var engine := EngineManager.build(_name_input.text, _selected_features())
    if not engine.is_empty():
        SaveManager.autosave()
        _refresh("%s is ready for your next game." % engine["name"])

func _back() -> void:
    get_tree().change_scene_to_file("res://scenes/company/CompanyScreen.tscn")
