extends Control

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var back_button: Button = $Margin/VBox/BackButton

func _ready() -> void:
    GameClock.enter_menu()
    back_button.pressed.connect(_on_back)
    _build()

func _build() -> void:
    UiBuilder.clear(list)

    var records := CompanyStats.records()
    if records.is_empty():
        list.add_child(UiBuilder.label("Release a game to start setting records.", 16, true))
        return

    for record in records:
        list.add_child(UiBuilder.label(str(record["label"]).to_upper(), 13))
        list.add_child(UiBuilder.label("%s\n%s" % [record["title"], record["value"]], 16))
        list.add_child(UiBuilder.divider())

func _on_back() -> void:
    get_tree().change_scene_to_file("res://scenes/company/CompanyScreen.tscn")
