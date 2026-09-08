extends Control

## Boot flow. Continue loads the autosave; everything else starts from here.

const VERSION := "0.2"

@onready var list: VBoxContainer = $Margin/VBox/Buttons
@onready var version_label: Label = $Margin/VBox/VersionLabel

func _ready() -> void:
    GameClock.enter_menu()
    version_label.text = "Version %s" % VERSION
    _build()

func _build() -> void:
    UiBuilder.clear(list)

    if SaveManager.has_save(SaveManager.AUTOSAVE):
        var summary := SaveManager.slot_summary(SaveManager.AUTOSAVE)
        var label := "CONTINUE"
        if not summary.is_empty():
            label = "CONTINUE\n%s - %s" % [str(summary.get("company", "?")), str(summary.get("date", ""))]
        var button := UiBuilder.major_button(label)
        button.pressed.connect(_on_continue)
        list.add_child(button)

    var new_button := UiBuilder.major_button("NEW COMPANY")
    new_button.pressed.connect(_on_new_company)
    list.add_child(new_button)

    if SaveManager.has_any_save():
        var load_button := UiBuilder.button("LOAD GAME")
        load_button.pressed.connect(_on_load)
        list.add_child(load_button)

    var settings_button := UiBuilder.button("SETTINGS")
    settings_button.pressed.connect(_on_settings)
    list.add_child(settings_button)

func _on_continue() -> void:
    if not SaveManager.load_game(SaveManager.AUTOSAVE):
        return
    if GameState.bankrupt:
        get_tree().change_scene_to_file("res://scenes/company/GameOverScreen.tscn")
        return
    get_tree().change_scene_to_file("res://scenes/studio/StudioScreen.tscn")

func _on_new_company() -> void:
    get_tree().change_scene_to_file("res://scenes/company/NewCompanyScreen.tscn")

func _on_load() -> void:
    ScreenRouter.return_scene = "res://scenes/menu/MainMenuScreen.tscn"
    get_tree().change_scene_to_file("res://scenes/company/SaveSlotScreen.tscn")

func _on_settings() -> void:
    ScreenRouter.return_scene = "res://scenes/menu/MainMenuScreen.tscn"
    get_tree().change_scene_to_file("res://scenes/menu/SettingsScreen.tscn")
