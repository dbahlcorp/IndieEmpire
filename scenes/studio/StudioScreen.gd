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
@onready var awards_button: Button = %AwardsButton
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
    awards_button.pressed.connect(_on_awards_pressed)
    contracts_button.pressed.connect(_on_contracts_pressed)
    office_button.pressed.connect(_on_office_pressed)
    teams_button.pressed.connect(_on_teams_pressed)
    %FinanceButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/company/FinancialsScreen.tscn"))
    _setup_surface()
    _refresh()
    TutorialManager.offer("bedroom", develop_button)

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
        develop_button.text = "PROJECTS (%d / %d)" % [
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

    var ceremony := AwardsManager.unseen_ceremony()
    awards_button.visible = not ceremony.is_empty()
    if not ceremony.is_empty():
        awards_button.text = "%d GAME AWARDS" % (int(ceremony.get("year", 0)) + 1)

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
    _refresh_attention()
    contracts_button.visible = TutorialManager.system_visible("contracts")
    %FinanceButton.visible = TutorialManager.system_visible("financials")
    if "office_growth" in GameState.tutorial_pending:
        TutorialManager.offer("office_growth", office_button)

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

func _on_awards_pressed() -> void:
    var ceremony := AwardsManager.unseen_ceremony()
    if ceremony.is_empty():
        return
    ScreenRouter.open_awards_ceremony(
        int(ceremony.get("year", 0)), "res://scenes/studio/StudioScreen.tscn")
    get_tree().change_scene_to_file("res://scenes/company/AwardsCeremonyScreen.tscn")

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




var _menu_was_paused := true

func _setup_surface() -> void:
    %MenuButton.pressed.connect(_open_menu)
    %AttentionButton.pressed.connect(_open_menu)
    %CloseMenuButton.pressed.connect(_close_menu)
    %Shade.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            _close_menu())
    var quick_destinations := {
        "GamesQuickButton": ["games", "res://scenes/studio/GamesScreen.tscn"],
        "TeamQuickButton": ["staff", "res://scenes/studio/TeamsScreen.tscn"],
        "ResearchQuickButton": ["research", "res://scenes/company/ResearchScreen.tscn"],
        "MarketQuickButton": ["market", "res://scenes/market/MarketScreen.tscn"],
        "CompanyQuickButton": ["company", "res://scenes/company/CompanyScreen.tscn"]
    }
    for node_name in quick_destinations:
        var quick := get_node("%" + node_name) as Button
        var details: Array = quick_destinations[node_name]
        quick.icon = UiIcons.texture(str(details[0]))
        quick.expand_icon = true
        quick.add_theme_constant_override("icon_max_width", 18)
        quick.tooltip_text = "Open %s" % quick.text.capitalize()
        quick.visible = TutorialManager.system_visible(str(details[0]))
        quick.pressed.connect(_go_to.bind(str(details[1])))
    var destinations := {
        "StaffButton": "res://scenes/company/StaffScreen.tscn",
        "HiringButton": "res://scenes/company/HiringScreen.tscn",
        "GamesButton": "res://scenes/studio/GamesScreen.tscn",
        "MarketButton": "res://scenes/market/MarketScreen.tscn",
        "EngineButton": "res://scenes/company/EngineLabScreen.tscn",
        "CompanyButton": "res://scenes/company/CompanyScreen.tscn"
    }
    for id in destinations:
        var destination_button := get_node("%" + id) as Button
        destination_button.pressed.connect(_go_to.bind(destinations[id]))
        var system_id: String = {
            "StaffButton": "staff", "HiringButton": "staff", "GamesButton": "games",
            "MarketButton": "market", "EngineButton": "engine", "CompanyButton": "company"
        }[id]
        destination_button.visible = TutorialManager.system_visible(system_id)
    resized.connect(_layout_surface)
    _layout_surface.call_deferred()

func _go_to(path: String) -> void:
    get_tree().change_scene_to_file(path)

func _layout_surface() -> void:
    var bounds := get_viewport_rect().size
    var wide := bounds.x >= 760.0
    var inset := 20.0
    var hud_width := minf(410.0, bounds.x - inset * 2.0)
    var hud := %CompanyHUD as Control
    hud.position = Vector2(inset, 20 if wide else 80)
    # Measure the HUD at the width it will actually occupy. Its height is
    # whatever the company name, cash, audience and burn lines come to, which
    # is font- and content-dependent -- a long company name wraps and makes it
    # taller. Same size/reset_size/size dance the dock does below.
    hud.size.x = hud_width
    hud.reset_size()
    hud.size.x = hud_width
    %CompanyPlate.position = hud.position - Vector2(10, 8)
    %CompanyPlate.size = Vector2(hud_width + 20, hud.size.y + 16)
    %ClockBar.position = Vector2(bounds.x - hud_width - inset, 20)
    %ClockBar.size = Vector2(hud_width, 48)
    %ClockPlate.position = %ClockBar.position - Vector2(8, 6)
    %ClockPlate.size = Vector2(hud_width + 16, 60)
    # Wide screens get two columns, so the cards sit beside the HUD. Portrait
    # has only one column, so they have to stack *below* it -- this was a fixed
    # 216, and the HUD is 211 tall from y=80, so the company figures were drawn
    # straight through the project cards on every phone.
    if wide:
        project_cards.position = Vector2(bounds.x - hud_width - inset, 86)
    else:
        project_cards.position = Vector2(inset, hud.position.y + hud.size.y + 12.0)
    project_cards.size.x = hud_width
    var dock_width := minf(660.0, bounds.x - inset * 2.0)
    var dock := %BottomDock as VBoxContainer
    dock.size.x = dock_width
    dock.reset_size()
    dock.size.x = dock_width
    dock.position = Vector2((bounds.x - dock_width) * 0.5, bounds.y - dock.size.y - inset)
    # The world owns the remaining screen; it never lives in a scrolling card.
    office_art.position = Vector2(0, 104 if wide else maxf(256, project_cards.position.y + project_cards.size.y + 12))
    office_art.size = Vector2(bounds.x, maxf(180, dock.position.y - office_art.position.y - 12))
    var panel := %MenuPanel as PanelContainer
    panel.size = Vector2(minf(540, bounds.x - 32), bounds.y - 80)
    panel.position = (bounds - panel.size) * 0.5

func _refresh_attention() -> void:
    warning_label.visible = not warning_label.text.is_empty()
    var count := RetentionManager.requests().size() + RetentionManager.leaving().size()
    count += GameState.pending_postmortems().size()
    count += 1 if StudioEventManager.has_pending() else 0
    count += 1 if AwardsManager.has_unseen_ceremony() else 0
    count += 1 if FinanceManager.is_in_trouble() else 0
    %AttentionButton.visible = count > 0
    %AttentionButton.text = "%d STUDIO MATTER%s · REVIEW" % [count, "S" if count != 1 else ""]
    _layout_surface.call_deferred()

func _open_menu() -> void:
    if %ManagementOverlay.visible:
        return
    _menu_was_paused = GameClock.paused
    GameClock.set_paused(true)
    %ManagementOverlay.show()
    _trap_menu_focus()
    %CloseMenuButton.grab_focus()

func _close_menu() -> void:
    %ManagementOverlay.hide()
    GameClock.set_paused(_menu_was_paused)
    %MenuButton.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel") and %ManagementOverlay.visible:
        _close_menu()
        get_viewport().set_input_as_handled()


func _trap_menu_focus() -> void:
    var buttons: Array[Control] = []
    for child in %ManagementOverlay.find_children("*", "Button", true, false):
        if child.is_visible_in_tree() and not child.disabled:
            buttons.append(child)
    for index in range(buttons.size()):
        var button := buttons[index]
        button.focus_next = button.get_path_to(buttons[(index + 1) % buttons.size()])
        button.focus_previous = button.get_path_to(buttons[(index + buttons.size() - 1) % buttons.size()])
