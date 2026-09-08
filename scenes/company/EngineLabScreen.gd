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
    _research()
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

func _research() -> void:
    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("TECHNOLOGY"))
    for item in EngineManager.available_features():
        var id := str(item["id"])
        var researched := GameState.researched_engine_features.has(id)
        var row := VBoxContainer.new()
        row.add_child(UiBuilder.label("%s%s\n%s" % [
            str(item["name"]), "  RESEARCHED" if researched else "",
            str(item["description"])
        ], 14))
        if not researched:
            var cost := FinanceManager.expense(int(item["cost"]))
            var button := UiBuilder.button("RESEARCH — %s" % Format.money_exact(cost))
            button.disabled = not FinanceManager.can_afford(cost)
            button.pressed.connect(_research_feature.bind(id))
            row.add_child(button)
        list.add_child(row)

    var future: Array[String] = []
    for item in EngineManager.FEATURES:
        if int(item["year"]) > TimeManager.current_year:
            future.append("%d  %s" % [int(item["year"]), str(item["name"])])
    if not future.is_empty():
        list.add_child(UiBuilder.label("COMING TECHNOLOGY\n" + "\n".join(future.slice(0, 3)), 13, true))

func _builder(message: String) -> void:
    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("BUILD AN ENGINE"))
    _name_input = LineEdit.new()
    _name_input.custom_minimum_size = Vector2(0, UiBuilder.TAP_HEIGHT)
    _name_input.placeholder_text = "Engine name"
    _name_input.text_changed.connect(func(_value): _update_build_state())
    list.add_child(_name_input)

    for item in EngineManager.FEATURES:
        var id := str(item["id"])
        if not GameState.researched_engine_features.has(id):
            continue
        var check := CheckBox.new()
        check.custom_minimum_size = Vector2(0, UiBuilder.TAP_HEIGHT)
        check.text = str(item["name"])
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

func _research_feature(id: String) -> void:
    if EngineManager.research(id):
        SaveManager.autosave()
        _refresh("Research complete. This feature can now be used in every future engine.")

func _build_engine() -> void:
    var engine := EngineManager.build(_name_input.text, _selected_features())
    if not engine.is_empty():
        SaveManager.autosave()
        _refresh("%s is ready for your next game." % engine["name"])

func _back() -> void:
    get_tree().change_scene_to_file("res://scenes/company/CompanyScreen.tscn")
