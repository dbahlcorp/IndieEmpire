extends Control

@onready var preview: EmployeeAppearancePreview = $Margin/VBox/PreviewPanel/AppearancePreview
@onready var name_input: LineEdit = $Margin/VBox/NameInput
@onready var pronoun_option: OptionButton = $Margin/VBox/PronounOption
@onready var appearance_option: OptionButton = $Margin/VBox/AppearanceOption
@onready var save_button: Button = $Margin/VBox/SaveButton
@onready var back_button: Button = $Margin/VBox/BackButton

func _ready() -> void:
    GameClock.enter_menu()
    var founder := EmployeeManager.ensure_founder()
    name_input.text = founder.display_name()

    for pronoun_set in Pronouns.SETS:
        pronoun_option.add_item(str(pronoun_set["label"]))
        pronoun_option.set_item_metadata(pronoun_option.item_count - 1, pronoun_set["id"])
    for index in pronoun_option.item_count:
        if str(pronoun_option.get_item_metadata(index)) == founder.pronoun_id:
            pronoun_option.select(index)

    for label in OfficeCharacterArt.APPEARANCE_NAMES:
        appearance_option.add_item(label)
    var selected := founder.appearance_index
    if selected < 0:
        selected = absi(founder.portrait_seed) % OfficeCharacterArt.SHEETS.size()
    appearance_option.select(selected)
    preview.set_appearance(selected)

    appearance_option.item_selected.connect(func(index): preview.set_appearance(index))
    save_button.pressed.connect(_save)
    back_button.pressed.connect(_back)

func _save() -> void:
    var founder := EmployeeManager.ensure_founder()
    var cleaned_name := name_input.text.strip_edges()
    if cleaned_name.is_empty():
        cleaned_name = GameState.founder_name
    var parts := cleaned_name.split(" ", false, 1)
    founder.first_name = parts[0] if not parts.is_empty() else "You"
    founder.last_name = parts[1] if parts.size() > 1 else ""
    founder.pronoun_id = str(pronoun_option.get_item_metadata(pronoun_option.selected))
    founder.appearance_index = appearance_option.selected
    GameState.founder_name = founder.display_name()
    GameState.founder_pronoun_id = founder.pronoun_id
    SaveManager.autosave()
    _back()

func _back() -> void:
    get_tree().change_scene_to_file("res://scenes/company/CompanyScreen.tscn")
