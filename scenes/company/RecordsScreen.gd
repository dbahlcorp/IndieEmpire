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
    if records.is_empty() and GameState.award_ceremonies.is_empty():
        list.add_child(UiBuilder.label("Release a game to start setting records.", 16, true))
        return

    for record in records:
        list.add_child(UiBuilder.label(str(record["label"]).to_upper(), 13))
        list.add_child(UiBuilder.label("%s\n%s" % [record["title"], record["value"]], 16))
        list.add_child(UiBuilder.divider())

    _awards()

func _awards() -> void:
    if GameState.award_ceremonies.is_empty():
        return

    list.add_child(UiBuilder.heading("GAME AWARDS"))
    list.add_child(UiBuilder.label(
        "Nominations   %d\nAwards won     %d\nGame of the Year   %d" % [
            CompanyStats.total_award_nominations(),
            CompanyStats.total_awards_won(),
            CompanyStats.goty_wins()], 15))

    var ceremonies := GameState.award_ceremonies.duplicate()
    ceremonies.reverse()
    for ceremony in ceremonies:
        var year := int(ceremony.get("year", 0))
        var categories: Array = ceremony.get("categories", [])
        var goty := ""
        for category in categories:
            if str(category.get("award_id", "")) == "goty":
                goty = str(category.get("winner_title", ""))
        var summary := "%d ceremony  ·  %d award%s" % [
            year + 1, categories.size(), "" if categories.size() == 1 else "s"]
        if not goty.is_empty():
            summary += "\nGame of the Year: %s" % goty
        var open_button := UiBuilder.button(summary)
        open_button.pressed.connect(_open_ceremony.bind(year))
        list.add_child(open_button)
    list.add_child(UiBuilder.divider())

func _open_ceremony(year: int) -> void:
    ScreenRouter.open_awards_ceremony(year, "res://scenes/company/RecordsScreen.tscn")
    get_tree().change_scene_to_file("res://scenes/company/AwardsCeremonyScreen.tscn")

func _on_back() -> void:
    get_tree().change_scene_to_file("res://scenes/company/CompanyScreen.tscn")
