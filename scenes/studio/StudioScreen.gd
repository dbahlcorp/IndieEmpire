extends Control

## The company dashboard: the home screen of the game.

@onready var company_label: Label = $Margin/VBox/Scroll/Content/CompanyLabel
@onready var date_label: Label = $Margin/VBox/Scroll/Content/DateLabel
@onready var cash_label: Label = $Margin/VBox/Scroll/Content/Header/CashGroup/CashLabel
@onready var reputation_label: Label = $Margin/VBox/Scroll/Content/Header/ReputationGroup/ReputationLabel
@onready var runway_label: Label = $Margin/VBox/Scroll/Content/RunwayLabel
@onready var fans_label: Label = $Margin/VBox/Scroll/Content/FansGroup/FansLabel
@onready var office_art: OfficeFloorView = $Margin/VBox/Scroll/Content/OfficePanel/OfficeVBox/OfficeArt
@onready var office_label: Label = $Margin/VBox/Scroll/Content/OfficePanel/OfficeVBox/OfficeText
@onready var office_button: Button = $Margin/VBox/Scroll/Content/OfficeButton
@onready var teams_button: Button = $Margin/VBox/Scroll/Content/TeamsButton
@onready var release_panel: Label = $Margin/VBox/Scroll/Content/ReleasePanel
@onready var warning_label: Label = $Margin/VBox/Scroll/Content/WarningLabel
@onready var develop_button: Button = $Margin/VBox/DevelopButton
@onready var postmortem_button: Button = $Margin/VBox/Scroll/Content/PostmortemButton
@onready var event_button: Button = $Margin/VBox/Scroll/Content/EventButton
@onready var contracts_button: Button = $Margin/VBox/Scroll/Content/ContractsButton

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
    _refresh()

func _refresh() -> void:
    company_label.text = GameState.company_name.to_upper()
    date_label.text = TimeManager.get_date_label()
    cash_label.text = Format.display(GameState.cash)
    reputation_label.text = "%.1f reputation" % GameState.consumer_reputation
    fans_label.text = "%s fans" % Format.count(GameState.fans)
    runway_label.text = _runway_text()

    var office := OfficeManager.current_office()
    office_art.set_office(GameState.office_id)
    office_label.text = "%s\n\n%d / %d PEOPLE\nComfort %s   Prestige %s\nRent $%s / month" % [
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
        contracts_button.text = "CONTRACT: %s (%.0f%%)" % [contract.name, contract.progress_percent()]
    elif not ContractManager.offers().is_empty():
        contracts_button.text = "CONTRACT WORK (%d available)" % ContractManager.offers().size()
    else:
        contracts_button.text = "CONTRACT WORK"

    var pending := GameState.pending_postmortems()
    postmortem_button.visible = not pending.is_empty()
    if not pending.is_empty():
        postmortem_button.text = "POSTMORTEM: %s" % pending[0].title

    event_button.visible = StudioEventManager.has_pending()
    if StudioEventManager.has_pending():
        event_button.text = str(StudioEventManager.pending_event().get("title", "STUDIO EVENT"))

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
    return "RUNWAY\n\nCash\n%s\n\nMonthly Expenses\n%s\n\nEstimated Runway\n%s" % [
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

