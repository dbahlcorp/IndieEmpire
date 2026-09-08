extends Control

## Company page: the numbers, the records, the books and the save slots.

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List

func _ready() -> void:
    GameClock.enter_gameplay(false)
    EventBus.week_ticked.connect(func(_y, _m, _w): _refresh())
    _refresh()

func _refresh() -> void:
    UiBuilder.clear(list)

    list.add_child(UiBuilder.label(GameState.company_name.to_upper(), 20, true))
    list.add_child(UiBuilder.label("Founded %s by %s\nAge %s\nDifficulty %s" % [
        TimeManager.format_month(GameState.founded_year, GameState.founded_month),
        GameState.founder_name,
        TimeManager.company_age_label(),
        DataManager.display_name(DataManager.difficulties, GameState.difficulty_id)
    ], 14, true))

    var customize_ceo := UiBuilder.button("CUSTOMIZE CEO")
    customize_ceo.pressed.connect(_go.bind("res://scenes/company/CeoCustomizationScreen.tscn"))
    list.add_child(customize_ceo)

    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.status_row(
        "cash", "Cash  $%s" % Format.count(GameState.cash), 16))
    list.add_child(UiBuilder.status_row(
        "fans", "Fans  %s" % Format.count(GameState.fans), 16))
    list.add_child(UiBuilder.status_row(
        "reputation", "Reputation  %.1f" % GameState.consumer_reputation, 16))

    list.add_child(UiBuilder.divider())
    var stats := ""
    for line in CompanyStats.summary_lines():
        stats += line + "\n"
    stats += "Total costs: $%s" % Format.exact(CompanyStats.lifetime_costs())
    list.add_child(UiBuilder.label(stats, 15))

    _culture()
    _strengths()
    _experience()
    _saves()

func _culture() -> void:
    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("CULTURE"))
    list.add_child(UiBuilder.label(
        "What the studio has become, from what it keeps doing.", 13, true))

    var text := ""
    for value in CultureSimulator.VALUES:
        var id := str(value["id"])
        var score := CultureManager.value(id)
        var filled := clampi(int(round(score / 10.0)), 0, 10)
        text += "%-18s %s%s
  %s
" % [
            str(value["name"]), "#".repeat(filled), ".".repeat(10 - filled),
            CultureManager.label(id)
        ]
    list.add_child(UiBuilder.label(text.strip_edges(), 14))

    var recent := CultureManager.recent_shifts()
    if not recent.is_empty():
        var causes := ""
        for shift in recent.slice(maxi(recent.size() - 5, 0)):
            causes += "%s %+.1f  %s
" % [
                CultureSimulator.value_data(str(shift["id"])).get("name", ""),
                float(shift["amount"]), str(shift["cause"])
            ]
        list.add_child(UiBuilder.label("RECENTLY
" + causes.strip_edges(), 13, true))

func _strengths() -> void:
    ## A curated identity snapshot -- part shipped-game track record, part
    ## who is actually on the roster right now -- distinct from the
    ## exhaustive breakdown STUDIO EXPERIENCE gives further down. See
    ## StudioIdentitySimulator.
    var top := StudioIdentitySimulator.strengths()
    if top.is_empty():
        return

    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("STUDIO STRENGTHS"))
    var text := ""
    for entry in top:
        text += "%-14s %s\n" % [str(entry["name"]), KnowledgeSimulator.stars_label(int(entry["level"]))]
    list.add_child(UiBuilder.label(text.strip_edges(), 15))

func _experience() -> void:
    if GameState.genre_experience.is_empty():
        return

    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("STUDIO EXPERIENCE"))

    var text := ""
    for genre in DataManager.genres:
        var id := str(genre.get("id", ""))
        var level := ExperienceManager.level_of(GameState.genre_experience, id)
        if level > 0:
            text += "%s %-12s %s\n" % [
                KnowledgeSimulator.stars_label(level),
                genre.get("name", id),
                KnowledgeSimulator.level_name(level)
            ]
    for theme in DataManager.themes:
        var id := str(theme.get("id", ""))
        var level := ExperienceManager.level_of(GameState.theme_experience, id)
        if level > 0:
            text += "%s %-12s %s\n" % [
                KnowledgeSimulator.stars_label(level),
                theme.get("name", id),
                KnowledgeSimulator.level_name(level)
            ]
    list.add_child(UiBuilder.label(text.strip_edges(), 14))

func _saves() -> void:
    list.add_child(UiBuilder.divider())

    var engines := UiBuilder.button("ENGINE LAB")
    engines.pressed.connect(_go.bind("res://scenes/company/EngineLabScreen.tscn"))
    list.add_child(engines)

    var financials := UiBuilder.button("FINANCIALS")
    financials.pressed.connect(_go.bind("res://scenes/company/FinancialsScreen.tscn"))
    list.add_child(financials)

    var records := UiBuilder.button("RECORDS")
    records.pressed.connect(_go.bind("res://scenes/company/RecordsScreen.tscn"))
    list.add_child(records)

    var saves := UiBuilder.button("MANAGE SAVES")
    saves.pressed.connect(_go.bind("res://scenes/company/SaveSlotScreen.tscn"))
    list.add_child(saves)

    var settings := UiBuilder.button("SETTINGS")
    settings.pressed.connect(func():
        ScreenRouter.return_scene = "res://scenes/company/CompanyScreen.tscn"
        get_tree().change_scene_to_file("res://scenes/menu/SettingsScreen.tscn"))
    list.add_child(settings)

    var menu := UiBuilder.button("MAIN MENU")
    menu.pressed.connect(_go.bind("res://scenes/menu/MainMenuScreen.tscn"))
    list.add_child(menu)

func _go(path: String) -> void:
    get_tree().change_scene_to_file(path)
