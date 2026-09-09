extends Control

## Studio creation. The only starting era in M2 is 1985.

@onready var name_input: LineEdit = $Margin/Scroll/VBox/NameInput
@onready var founder_input: LineEdit = $Margin/Scroll/VBox/FounderInput
@onready var pronoun_option: OptionButton = $Margin/Scroll/VBox/PronounOption
@onready var appearance_preview: EmployeeAppearancePreview = $Margin/Scroll/VBox/AppearanceRow/AppearancePreview
@onready var appearance_option: OptionButton = $Margin/Scroll/VBox/AppearanceRow/AppearanceOption
@onready var background_option: OptionButton = $Margin/Scroll/VBox/BackgroundOption
@onready var background_detail: Label = $Margin/Scroll/VBox/BackgroundDetail
@onready var trait_option: OptionButton = $Margin/Scroll/VBox/TraitOption
@onready var trait_detail: Label = $Margin/Scroll/VBox/TraitDetail
@onready var difficulty_option: OptionButton = $Margin/Scroll/VBox/DifficultyOption
@onready var difficulty_label: Label = $Margin/Scroll/VBox/DifficultyLabel
@onready var start_button: Button = $Margin/Scroll/VBox/StartButton
@onready var load_button: Button = $Margin/Scroll/VBox/LoadButton

func _ready() -> void:
    GameClock.enter_menu()
    for pronoun_set in Pronouns.SETS:
        pronoun_option.add_item(str(pronoun_set["label"]))
        pronoun_option.set_item_metadata(pronoun_option.item_count - 1, pronoun_set["id"])
    for index in pronoun_option.item_count:
        if str(pronoun_option.get_item_metadata(index)) == Pronouns.DEFAULT:
            pronoun_option.select(index)

    for label in OfficeCharacterArt.APPEARANCE_NAMES:
        appearance_option.add_item(label)
    appearance_option.select(0)
    appearance_option.item_selected.connect(func(index): appearance_preview.set_appearance(index))
    appearance_preview.set_appearance(0)

    for background in DataManager.founder_backgrounds:
        background_option.add_item(str(background.get("name", "?")))
        background_option.set_item_metadata(background_option.item_count - 1, background.get("id", ""))
    # Generalist is the no-strong-lean default.
    for index in background_option.item_count:
        if str(background_option.get_item_metadata(index)) == "generalist":
            background_option.select(index)
    background_option.item_selected.connect(_on_background_changed)

    for trait_data in DataManager.employee_traits:
        trait_option.add_item(str(trait_data.get("name", "?")))
        trait_option.set_item_metadata(trait_option.item_count - 1, trait_data.get("id", ""))
    # Perfectionist is as reasonable a default founder as any.
    for index in trait_option.item_count:
        if str(trait_option.get_item_metadata(index)) == "perfectionist":
            trait_option.select(index)
    trait_option.item_selected.connect(_on_trait_changed)

    for difficulty in DataManager.difficulties:
        difficulty_option.add_item(str(difficulty.get("name", "?")))
        difficulty_option.set_item_metadata(difficulty_option.item_count - 1, difficulty.get("id", ""))

    # Normal is the balanced default.
    for index in difficulty_option.item_count:
        if str(difficulty_option.get_item_metadata(index)) == "normal":
            difficulty_option.select(index)

    difficulty_option.item_selected.connect(_on_difficulty_changed)
    start_button.pressed.connect(_on_start_pressed)
    load_button.pressed.connect(_on_load_pressed)

    load_button.visible = SaveManager.has_any_save()
    _refresh()

func _selected_difficulty() -> String:
    if difficulty_option.item_count == 0 or difficulty_option.selected < 0:
        return "normal"
    return str(difficulty_option.get_item_metadata(difficulty_option.selected))

func _selected_pronouns() -> String:
    if pronoun_option.item_count == 0 or pronoun_option.selected < 0:
        return Pronouns.DEFAULT
    return str(pronoun_option.get_item_metadata(pronoun_option.selected))

func _selected_background() -> String:
    if background_option.item_count == 0 or background_option.selected < 0:
        return "generalist"
    return str(background_option.get_item_metadata(background_option.selected))

func _selected_trait() -> String:
    if trait_option.item_count == 0 or trait_option.selected < 0:
        return "perfectionist"
    return str(trait_option.get_item_metadata(trait_option.selected))

func _refresh() -> void:
    var difficulty := DataManager.get_difficulty(_selected_difficulty())
    difficulty_label.text = "Starting cash $%s   Bankruptcy grace %d weeks\nStarting year 1985" % [
        Format.exact(int(difficulty.get("starting_cash", 10_000))),
        int(difficulty.get("grace_weeks", 6))
    ]
    _refresh_background_detail()
    _refresh_trait_detail()

func _refresh_trait_detail() -> void:
    ## Chosen once, deliberately -- replaces the random 1-2 traits everybody
    ## else gets. See EmployeeManager.create_founder().
    var trait_data := DataManager.get_employee_trait(_selected_trait())
    trait_detail.text = str(trait_data.get("description", ""))

func _on_trait_changed(_index: int) -> void:
    _refresh()

func _refresh_background_detail() -> void:
    ## Replayability, not a promotion: a one-time tilt to starting skills
    ## only, spelled out before committing to it. See
    ## EmployeeManager._apply_background.
    var background := DataManager.get_founder_background(_selected_background())
    var modifiers: Dictionary = background.get("skill_modifiers", {})
    var lines: Array[String] = []
    for skill in EmployeeManager.SKILL_FIELDS:
        if not modifiers.has(skill):
            continue
        var amount := int(modifiers[skill])
        lines.append("%s %s%d" % [str(skill).capitalize(), "+" if amount >= 0 else "", amount])
    background_detail.text = "%s\n%s" % [str(background.get("description", "")), "   ".join(lines)]

func _on_background_changed(_index: int) -> void:
    _refresh()

func _on_difficulty_changed(_index: int) -> void:
    _refresh()

func _on_start_pressed() -> void:
    GameState.start_company(
        name_input.text,
        founder_input.text,
        _selected_difficulty(),
        _selected_pronouns(),
        appearance_option.selected,
        _selected_background(),
        _selected_trait()
    )
    SaveManager.has_active_company = true
    World.sync_year()
    GameClock.apply_default_speed()
    SaveManager.autosave()
    get_tree().change_scene_to_file("res://scenes/studio/StudioScreen.tscn")

func _on_load_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/company/SaveSlotScreen.tscn")
