extends Control

## The company dashboard: the home screen of the game.

@onready var company_label: Label = %CompanyLabel
@onready var burn_label: Label = %BurnLabel
@onready var project_cards: VBoxContainer = %Projects
@onready var cash_label: Label = %CashLabel
@onready var reputation_label: Label = %ReputationLabel
@onready var runway_label: Label = %RunwayLabel
@onready var fans_label: Label = %FansLabel
@onready var office_art: OfficeFloorView = %OfficeArt
@onready var office_label: Label = %OfficeText
@onready var office_button: Button = %OfficeButton
@onready var teams_button: Button = %TeamsButton
@onready var release_panel: Label = %ReleasePanel
@onready var warning_label: Label = %WarningLabel
@onready var develop_button: Button = %DevelopButton
@onready var postmortem_button: Button = %PostmortemButton
@onready var event_button: Button = %EventButton
@onready var contracts_button: Button = %ContractsButton

func _ready() -> void:
    GameClock.enter_gameplay(false)
    EventBus.week_ticked.connect(func(_y, _m, _w): _refresh())
    if GameState.bankrupt:
        get_tree().change_scene_to_file.call_deferred("res://scenes/company/GameOverScreen.tscn")
        return

    develop_button.pressed.connect(_on_develop_pressed)
    postmortem_button.pressed.connect(_on_postmortem_pressed)
    event_button.pressed.connect(_on_event_pressed)
    contracts_button.pressed.connect(_on_contracts_pressed)
    office_button.pressed.connect(_on_office_pressed)
    teams_button.pressed.connect(_on_teams_pressed)
    %FinanceButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/company/FinancialsScreen.tscn"))
    _refresh()

func _refresh() -> void:
    company_label.text = GameState.company_name.to_upper()
    _refresh_projects()
    cash_label.text = Format.display(GameState.cash)
    reputation_label.text = "%.1f reputation" % GameState.consumer_reputation
    fans_label.text = "%s fans" % Format.count(GameState.fans)
    runway_label.text = _runway_text()
    var burn := int(EmployeeManager.monthly_expenses()["total"])
    burn_label.text = "%s / month   ·   %s runway" % [Format.display(burn), Format.runway_label(FinanceManager.cash_runway_months(GameState.cash, burn))]

    var office := OfficeManager.current_office()
    office_art.set_office(GameState.office_id)
    office_label.text = "%s  ·  %d / %d PEOPLE\n%s comfort  ·  %s prestige  ·  $%s rent" % [
        str(office.get("name", "Office")).to_upper(),
        OfficeManager.headcount(), OfficeManager.capacity(),
        office.get("comfort", "Poor"), office.get("prestige", "None"),
        Format.exact(OfficeManager.monthly_rent(office))
    ]
    release_panel.text = _release_text()

    if not GameState.active_projects.is_empty():
        develop_button.text = "DEVELOPMENT (%d / %d TEAMS)" % [
            GameState.active_projects.size(), TeamManager.MAX_TEAMS
        ]
    else:
        develop_button.text = "DEVELOP GAME"

    var contract := ContractManager.active_contract()
    if contract != null:
        contracts_button.text = "CONTRACT · %.0f%%" % contract.progress_percent()
    elif not ContractManager.offers().is_empty():
        contracts_button.text = "CONTRACTS (%d)" % ContractManager.offers().size()
    else:
        contracts_button.text = "CONTRACTS"

    var pending := GameState.pending_postmortems()
    postmortem_button.visible = not pending.is_empty()
    if not pending.is_empty():
        postmortem_button.text = "POSTMORTEM: %s" % pending[0].title

    event_button.visible = StudioEventManager.has_pending()
    if StudioEventManager.has_pending():
        event_button.text = str(StudioEventManager.pending_event().get("title", "STUDIO EVENT"))

    warning_label.text = ""
    var waiting := RetentionManager.requests().size() + RetentionManager.leaving().size()
    if waiting > 0:
        warning_label.text = "%d staff matter%s need answering" % [
            waiting, "" if waiting == 1 else "s"]

    if FinanceManager.is_in_trouble():
        warning_label.text = "FINANCIAL TROUBLE\nCash $%s. %d week%s to recover." % [
            Format.exact(GameState.cash),
            FinanceManager.weeks_of_grace_left(),
            "" if FinanceManager.weeks_of_grace_left() == 1 else "s"
        ]
    else:
        warning_label.text = ""

func _runway_text() -> String:
    ## How long the cash on hand actually lasts at the current burn rate --
    ## this is the number that matters more than the raw cash figure above it.
    var burn := int(EmployeeManager.monthly_expenses()["total"])
    var runway := FinanceManager.cash_runway_months(GameState.cash, burn)
    return "RUNWAY\nCash  %s\nMonthly Expenses  %s\nEstimated Runway  %s" % [
        Format.money_exact(GameState.cash),
        Format.money_exact(burn),
        Format.runway_label(runway)
    ]

func _release_text() -> String:
    var text := ""

    var contract := ContractManager.active_contract()
    if contract != null:
        text += "CONTRACT: %s
for %s
%.0f%% done, %d week%s left
%s on delivery

" % [
            contract.name.to_upper(), contract.client, contract.progress_percent(),
            contract.weeks_remaining(), "" if contract.weeks_remaining() == 1 else "s",
            Format.money_exact(contract.payout)]

    var selling := GameState.games_on_market()
    if selling.is_empty():
        return text.strip_edges() if not text.is_empty() else "Nothing on sale right now."

    for game in selling:
        var revenue := 0
        if not game.weekly_revenue.is_empty():
            revenue = game.weekly_revenue[game.weekly_revenue.size() - 1]
        text += "%s\nWeek %d sales\n%s copies\n+$%s\n\n" % [
            game.title.to_upper(),
            game.weeks_on_market,
            Format.count(game.last_week_units()),
            Format.exact(revenue)
        ]
    return text.strip_edges()

func _on_contracts_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/company/ContractsScreen.tscn")

func _on_develop_pressed() -> void:
    if GameState.active_projects.is_empty():
        ScreenRouter.selected_team_id = "team_a"
        get_tree().change_scene_to_file("res://scenes/development/NewGameScreen.tscn")
    else:
        get_tree().change_scene_to_file("res://scenes/studio/TeamsScreen.tscn")

func _on_postmortem_pressed() -> void:
    var pending := GameState.pending_postmortems()
    if pending.is_empty():
        return
    ScreenRouter.selected_game_id = pending[0].id
    get_tree().change_scene_to_file("res://scenes/release/PostmortemScreen.tscn")

func _on_event_pressed() -> void:
    if StudioEventManager.has_pending():
        get_tree().change_scene_to_file("res://scenes/company/StudioEventScreen.tscn")

func _on_office_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/studio/OfficeScreen.tscn")

func _on_teams_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/studio/TeamsScreen.tscn")



var _cards: Dictionary = {}

func _refresh_projects() -> void:
    var active_ids: Array[String] = []
    for active in GameState.active_projects:
        active_ids.append(active.id)
    for id in _cards.keys():
        if id not in active_ids:
            var old_button: Button = _cards[id]["button"]
            project_cards.remove_child(old_button)
            old_button.queue_free()
            _cards.erase(id)
    var idle := project_cards.get_node_or_null("Idle") as Label
    if active_ids.is_empty():
        if idle == null:
            idle = Label.new()
            idle.name = "Idle"
            idle.text = "YOUR NEXT GAME STARTS HERE"
            idle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            idle.add_theme_font_size_override("font_size", 13)
            project_cards.add_child(idle)
        return
    if idle != null:
        project_cards.remove_child(idle)
        idle.queue_free()
    for active in GameState.active_projects:
        if not _cards.has(active.id):
            var button := Button.new()
            button.custom_minimum_size.y = 72
            button.text = ""
            button.pressed.connect(_open_project.bind(active))
            project_cards.add_child(button)
            var margin := MarginContainer.new()
            margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
            for side in ["left", "right", "top", "bottom"]:
                margin.add_theme_constant_override("margin_" + side, 9)
            margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
            button.add_child(margin)
            var stack := VBoxContainer.new()
            stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
            stack.add_theme_constant_override("separation", 3)
            margin.add_child(stack)
            var label := Label.new()
            label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
            label.add_theme_font_size_override("font_size", 13)
            label.mouse_filter = Control.MOUSE_FILTER_IGNORE
            stack.add_child(label)
            var bar := ProgressBar.new()
            bar.custom_minimum_size.y = 6
            bar.show_percentage = false
            bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
            stack.add_child(bar)
            _cards[active.id] = {"button": button, "label": label, "bar": bar}
        var phase := "Planning" if active.preproduction_progress < 100.0 else "Production"
        var progress := active.preproduction_progress if active.preproduction_progress < 100.0 else active.development_progress
        if active.development_progress >= 100.0:
            phase = "Polishing" if active.polishing else "Ready to ship"
        var team := TeamManager.find_team(active.team_id)
        var label: Label = _cards[active.id]["label"]
        label.text = "%s  ·  %s\n%s  ·  %d%%" % [active.title, team.name if team != null else "Team", phase, int(progress)]
        var bar: ProgressBar = _cards[active.id]["bar"]
        bar.value = progress

func _open_project(active: GameProject) -> void:
    GameState.select_project(active)
    get_tree().change_scene_to_file("res://scenes/development/DevelopmentScreen.tscn")


