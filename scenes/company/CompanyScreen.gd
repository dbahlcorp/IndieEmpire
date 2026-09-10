extends Control

## Company page: the numbers, the records, the books and the save slots.

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List

func _ready() -> void:
    GameClock.enter_gameplay(false)
    EventBus.week_ticked.connect(func(_y, _m, _w): _refresh())
    _refresh()

func _refresh() -> void:
    UiBuilder.clear(list)

    var identity_row := HBoxContainer.new()
    identity_row.add_theme_constant_override("separation", 12)
    identity_row.add_child(CompanyEmblem.new().configure(GameState.company_name, GameState.founder_name))
    var company_card := UiBuilder.info_card(GameState.company_name, "Founded %s by %s\n%s old  ·  %s difficulty" % [
        TimeManager.format_month(GameState.founded_year, GameState.founded_month),
        GameState.founder_name,
        TimeManager.company_age_label(),
        DataManager.display_name(DataManager.difficulties, GameState.difficulty_id)
    ], "company")
    company_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    identity_row.add_child(company_card)
    list.add_child(identity_row)

    var customize_ceo := UiBuilder.button("CUSTOMIZE CEO")
    customize_ceo.pressed.connect(_go.bind("res://scenes/company/CeoCustomizationScreen.tscn"))
    list.add_child(customize_ceo)

    list.add_child(UiBuilder.stat_grid([
        {"icon": "cash", "label": "Cash", "value": Format.money(GameState.cash)},
        {"icon": "fans", "label": "Fans", "value": Format.count(GameState.fans)},
        {"icon": "reputation", "label": "Reputation", "value": "%.1f" % GameState.consumer_reputation},
        {"icon": "staff", "label": "Employees", "value": str(EmployeeManager.active_employees().size())}
    ], 4 if get_viewport_rect().size.x >= 840 else 2))

    list.add_child(UiBuilder.divider())
    var stats := ""
    for line in CompanyStats.summary_lines():
        stats += line + "\n"
    stats += "Total costs: $%s" % Format.exact(CompanyStats.lifetime_costs())
    list.add_child(UiBuilder.label(stats, 15))

    if TutorialManager.system_visible("culture"):
        _culture()
    _strengths()
    _experience()
    _saves()

func _culture() -> void:
    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("CULTURE"))
    list.add_child(UiBuilder.label(
        "What the studio has become, from what it keeps doing.", 13, true))

    for value in CultureSimulator.VALUES:
        var id := str(value["id"])
        var score := CultureManager.value(id)
        list.add_child(UiBuilder.progress_meter(
            str(value["name"]), int(round(score)), "morale"))
        var meaning := UiBuilder.label(CultureManager.label(id), 12, true)
        meaning.theme_type_variation = &"MutedLabel"
        list.add_child(meaning)

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

    if TutorialManager.system_visible("research"):
        var research := UiBuilder.button("RESEARCH")
        research.pressed.connect(_go.bind("res://scenes/company/ResearchScreen.tscn"))
        list.add_child(research)

    if TutorialManager.system_visible("engine"):
        var engines := UiBuilder.button("ENGINE LAB")
        engines.pressed.connect(_go.bind("res://scenes/company/EngineLabScreen.tscn"))
        list.add_child(engines)

    if TutorialManager.system_visible("financials"):
        var financials := UiBuilder.button("FINANCIALS")
        financials.pressed.connect(_go.bind("res://scenes/company/FinancialsScreen.tscn"))
        list.add_child(financials)

    var records := UiBuilder.button("STATISTICS")
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
