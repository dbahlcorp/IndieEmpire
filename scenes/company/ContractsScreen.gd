extends Control

## Contract work is the studio's safety net. The board makes payout, workload,
## and delivery risk comparable without changing any contract simulation rules.

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var back_button: Button = $Margin/VBox/BackButton

var _confirm: ConfirmationDialog

func _ready() -> void:
    GameClock.enter_menu()
    back_button.pressed.connect(_on_back)
    _confirm = ConfirmationDialog.new()
    _confirm.title = "Abandon contract?"
    _confirm.dialog_text = "The client is left with nothing and your standing suffers."
    _confirm.ok_button_text = "ABANDON"
    _confirm.confirmed.connect(_on_abandon_confirmed)
    add_child(_confirm)
    _refresh()

func _refresh() -> void:
    UiBuilder.clear(list)
    _summary()
    var active := ContractManager.active_contract()
    if active != null:
        _show_active(active)
    else:
        _show_offers()
    _show_history()

func _summary() -> void:
    var active := ContractManager.active_contract()
    list.add_child(UiBuilder.stat_grid([
        {"icon": "cash", "label": "Contract income", "value":
            Format.money_exact(ContractManager.total_contract_income())},
        {"icon": "success", "label": "Delivered", "value":
            str(ContractManager.completed_count())},
        {"icon": "warning", "label": "Lost", "value":
            str(ContractManager.failed_count())},
        {"icon": "capacity", "label": "Current status", "value":
            "IN PROGRESS" if active != null else "AVAILABLE"}
    ], _stat_columns()))

func _show_active(contract: Contract) -> void:
    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.section_header(
        "Contract in progress", "The assigned team works automatically as simulation time advances."))
    var weekly := ContractManager.weekly_output()
    var remaining := maxf(float(contract.work) - contract.work_done, 0.0)
    var needed := ContractSimulator.expected_weeks(int(ceil(remaining)), weekly)
    var left := contract.weeks_remaining()
    var behind := needed > left

    var panel := PanelContainer.new()
    panel.theme_type_variation = &"DangerPanel" if behind else &"PositivePanel"
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 10)
    stack.add_child(UiBuilder.heading(contract.name))
    stack.add_child(UiBuilder.label("FOR %s" % contract.client.to_upper(), 13))
    stack.add_child(UiBuilder.label(contract.brief, 14))
    stack.add_child(UiBuilder.status_chip(
        "Behind schedule" if behind else "On schedule",
        "danger" if behind else "positive"))
    var bar := ProgressBar.new()
    bar.custom_minimum_size = Vector2(0, 28)
    bar.value = contract.progress_percent()
    stack.add_child(bar)
    stack.add_child(UiBuilder.stat_grid([
        {"icon": "technology", "label": "Completed", "value": "%d%%" %
            int(round(contract.progress_percent()))},
        {"icon": "cash", "label": "On delivery", "value":
            Format.money_exact(contract.payout)},
        {"icon": "warning", "label": "Deadline", "value": "%d week%s" % [
            left, "" if left == 1 else "s"]},
        {"icon": "capacity", "label": "Work remaining", "value": "~%d week%s" % [
            needed, "" if needed == 1 else "s"]}
    ], _stat_columns()))
    var abandon := UiBuilder.button("ABANDON CONTRACT")
    abandon.theme_type_variation = &"DangerButton"
    abandon.tooltip_text = "End this contract and take a reputation penalty"
    abandon.pressed.connect(func(): _confirm.popup_centered())
    stack.add_child(abandon)
    panel.add_child(stack)
    list.add_child(panel)

func _show_offers() -> void:
    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.section_header(
        "Available work", "Reliable client income that occupies your main team."))
    var offers := ContractManager.offers()
    if offers.is_empty():
        list.add_child(UiBuilder.empty_state(
            "Nothing on the board", "New client work will appear when the board refreshes.")["panel"])
        return

    var can_take := ContractManager.can_accept()
    if not can_take:
        var warning := UiBuilder.info_card(
            "Team unavailable",
            "Finish or abandon the team's current game before accepting contract work.",
            "warning")
        warning.theme_type_variation = &"WarningPanel"
        list.add_child(warning)

    var grid := GridContainer.new()
    grid.columns = 2 if get_viewport_rect().size.x >= 800.0 else 1
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for contract in offers:
        grid.add_child(_offer_card(contract, can_take))
    list.add_child(grid)

func _offer_card(contract: Contract, can_take: bool) -> PanelContainer:
    var weekly := ContractSimulator.weekly_work(
        TeamManager.working_members("team_a"), OfficeManager.productivity())
    var weeks := ContractSimulator.expected_weeks(contract.work, weekly)
    var risky := weeks > contract.deadline_weeks
    var impossible := weeks > contract.deadline_weeks * 2
    var panel := PanelContainer.new()
    panel.theme_type_variation = &"WarningPanel" if risky else &"ElevatedPanel"
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.custom_minimum_size = Vector2(300, 0)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 9)
    stack.add_child(UiBuilder.heading(contract.name))
    stack.add_child(UiBuilder.label("FOR %s" % contract.client.to_upper(), 12))
    stack.add_child(UiBuilder.label(contract.brief, 14))
    stack.add_child(UiBuilder.status_chip(
        "Very high delivery risk" if impossible else "Tight schedule" if risky else "Achievable",
        "danger" if impossible else "warning" if risky else "positive"))
    stack.add_child(UiBuilder.stat_grid([
        {"icon": "cash", "label": "Payout", "value": Format.money_exact(contract.payout)},
        {"icon": "warning", "label": "Deadline", "value": "%d weeks" % contract.deadline_weeks},
        {"icon": "capacity", "label": "Team estimate", "value": "~%d weeks" % weeks},
        {"icon": "reputation", "label": "Reputation", "value": "+%.1f" % contract.reputation_reward}
    ], 2))
    var take := UiBuilder.major_button("TAKE CONTRACT")
    take.disabled = not can_take or impossible
    take.tooltip_text = (
        "Assign the main team to this client project"
        if not take.disabled else
        "Unavailable while the team is busy or the delivery estimate is unrealistic")
    take.pressed.connect(_on_accept.bind(contract))
    stack.add_child(take)
    panel.add_child(stack)
    return panel

func _show_history() -> void:
    if GameState.completed_contracts.is_empty():
        return
    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.section_header(
        "Past work", "Your eight most recent client outcomes."))
    var recent := GameState.completed_contracts.slice(
        maxi(GameState.completed_contracts.size() - 8, 0))
    recent.reverse()
    var grid := GridContainer.new()
    grid.columns = 2 if get_viewport_rect().size.x >= 800.0 else 1
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for contract in recent:
        var delivered: bool = str(contract.status) == "completed"
        var card := UiBuilder.info_card(
            contract.name,
            "%s · %s" % [contract.client,
                Format.money_exact(contract.payout) if delivered else "Contract lost"],
            "success" if delivered else "warning")
        card.theme_type_variation = &"PositivePanel" if delivered else &"DangerPanel"
        grid.add_child(card)
    list.add_child(grid)

func _stat_columns() -> int:
    return 4 if get_viewport_rect().size.x >= 800.0 else 2

func _on_accept(contract: Contract) -> void:
    if ContractManager.accept(contract):
        _refresh()

func _on_abandon_confirmed() -> void:
    ContractManager.abandon()
    _refresh()

func _on_back() -> void:
    get_tree().change_scene_to_file("res://scenes/studio/StudioScreen.tscn")
