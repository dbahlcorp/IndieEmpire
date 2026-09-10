extends Control

@onready var heading: Label = $Margin/VBox/Heading
@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var back_button: Button = $Margin/VBox/BackButton

func _ready() -> void:
    GameClock.enter_menu()
    heading.text = "BANKRUPT"
    back_button.text = "START NEW COMPANY"
    back_button.pressed.connect(_on_new_company_pressed)
    _build()

func _build() -> void:
    UiBuilder.clear(list)

    list.add_child(UiBuilder.company_identity_row("A studio history, now complete", 68))
    list.add_child(UiBuilder.label("%d - %d" % [GameState.founded_year, TimeManager.current_year], 16, true))
    list.add_child(UiBuilder.divider())

    var stats := ""
    for line in CompanyStats.summary_lines():
        stats += line + "\n"
    list.add_child(UiBuilder.label(stats.strip_edges(), 16))

    var highest := CompanyStats.highest_rated()
    if highest != null:
        var high_row := HBoxContainer.new()
        high_row.add_theme_constant_override("separation", 10)
        var cover := GameCoverArt.new().configure(highest)
        cover.custom_minimum_size = Vector2(64, 84)
        high_row.add_child(cover)
        var high_copy := UiBuilder.label("Highest rated\n%s - %.1f" % [highest.title, highest.review_score], 15)
        high_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        high_row.add_child(high_copy)
        list.add_child(high_row)

    var best := CompanyStats.best_selling()
    if best != null:
        list.add_child(UiBuilder.label("Best selling\n%s - %s" % [
            best.title, Format.exact(best.lifetime_sales)], 15))

    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.label("Company value\n$0", 16))

    if SaveManager.has_any_save():
        var load_button := UiBuilder.button("LOAD SAVE")
        load_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/company/SaveSlotScreen.tscn"))
        list.add_child(load_button)

func _on_new_company_pressed() -> void:
    SaveManager.has_active_company = false
    get_tree().change_scene_to_file("res://scenes/company/NewCompanyScreen.tscn")
