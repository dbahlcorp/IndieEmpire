extends Control

## Three manual slots plus the autosave. Saving over an existing slot asks first.

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var back_button: Button = $Margin/VBox/BackButton

var _pending_slot: String = ""
var _confirm: ConfirmationDialog

func _ready() -> void:
    GameClock.enter_menu()
    back_button.pressed.connect(_on_back_pressed)

    _confirm = ConfirmationDialog.new()
    _confirm.title = "Overwrite save?"
    _confirm.dialog_text = "This slot already has a company in it."
    _confirm.ok_button_text = "OVERWRITE"
    _confirm.confirmed.connect(_on_overwrite_confirmed)
    add_child(_confirm)

    _refresh()

func _refresh() -> void:
    UiBuilder.clear(list)

    if SaveManager.has_active_company:
        list.add_child(UiBuilder.label("Autosave runs after every week, release and project.", 14, true))
        list.add_child(UiBuilder.divider())

    for slot in SaveManager.MANUAL_SLOTS:
        list.add_child(UiBuilder.label(_slot_text(slot), 15))

        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)

        if SaveManager.has_active_company:
            var save_button := UiBuilder.button("SAVE", 48)
            save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            save_button.pressed.connect(_on_save_pressed.bind(slot))
            row.add_child(save_button)

        if SaveManager.has_save(slot):
            var load_button := UiBuilder.button("LOAD", 48)
            load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            load_button.pressed.connect(_on_load_pressed.bind(slot))
            row.add_child(load_button)

        list.add_child(row)
        list.add_child(UiBuilder.divider())

    if SaveManager.has_save(SaveManager.AUTOSAVE):
        list.add_child(UiBuilder.label("AUTOSAVE\n%s" % _slot_details(SaveManager.AUTOSAVE), 15))
        var resume := UiBuilder.button("LOAD AUTOSAVE")
        resume.pressed.connect(_on_load_pressed.bind(SaveManager.AUTOSAVE))
        list.add_child(resume)

func _slot_text(slot: String) -> String:
    var index := SaveManager.MANUAL_SLOTS.find(slot) + 1
    if not SaveManager.has_save(slot):
        return "SLOT %d\nEmpty" % index
    return "SLOT %d\n%s" % [index, _slot_details(slot)]

func _slot_details(slot: String) -> String:
    var summary := SaveManager.slot_summary(slot)
    if summary.is_empty():
        return "Unreadable save"
    return "%s - %s\n$%s - %d games" % [
        str(summary.get("company", "?")),
        str(summary.get("date", "?")),
        Format.exact(int(summary.get("cash", 0))),
        int(summary.get("games", 0))
    ]

func _on_save_pressed(slot: String) -> void:
    if SaveManager.has_save(slot):
        _pending_slot = slot
        _confirm.popup_centered()
        return
    SaveManager.save_game(slot)
    _refresh()

func _on_overwrite_confirmed() -> void:
    if _pending_slot.is_empty():
        return
    SaveManager.save_game(_pending_slot)
    _pending_slot = ""
    _refresh()

func _on_load_pressed(slot: String) -> void:
    if SaveManager.load_game(slot):
        get_tree().change_scene_to_file("res://scenes/studio/StudioScreen.tscn")

func _on_back_pressed() -> void:
    if SaveManager.has_active_company:
        get_tree().change_scene_to_file("res://scenes/company/CompanyScreen.tscn")
        return
    get_tree().change_scene_to_file("res://scenes/company/NewCompanyScreen.tscn")
