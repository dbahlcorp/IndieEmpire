extends Control

## A readable set of books: exact amounts remain available, but the player can
## now understand cash position, burn, and recent movement at a glance.

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var back_button: Button = $Margin/VBox/BackButton

func _ready() -> void:
    GameClock.enter_menu()
    back_button.pressed.connect(_on_back)
    _build()

func _build() -> void:
    UiBuilder.clear(list)
    _position_section()
    _monthly_section()
    _annual_section()
    _games_section()
    _ledger_section()

func _position_section() -> void:
    var revenue := CompanyStats.lifetime_revenue()
    var costs := CompanyStats.lifetime_costs()
    var net := revenue - costs
    list.add_child(UiBuilder.section_header(
        "Financial position", "The studio's lifetime performance and available cash."))
    var grid := UiBuilder.stat_grid([
        {"icon": "cash", "label": "Cash", "value": Format.money_exact(GameState.cash)},
        {"icon": "cash", "label": "Revenue", "value": Format.money_exact(revenue)},
        {"icon": "payroll", "label": "Costs", "value": Format.money_exact(costs)},
        {"icon": "reputation", "label": "Net", "value": Format.signed_money(net)}
    ], _columns(4))
    list.add_child(grid)
    var net_card := grid.get_child(3) as PanelContainer
    net_card.theme_type_variation = &"PositivePanel" if net >= 0 else &"DangerPanel"

func _monthly_section() -> void:
    list.add_child(UiBuilder.divider())
    var monthly := EmployeeManager.monthly_expenses()
    list.add_child(UiBuilder.section_header(
        "Monthly burn", "Recurring expenses paid by the studio each month."))
    list.add_child(UiBuilder.stat_grid([
        {"icon": "staff", "label": "Salaries", "value": Format.money_exact(int(monthly["salaries"]))},
        {"icon": "rent", "label": "Rent", "value": Format.money_exact(int(monthly["rent"]))},
        {"icon": "utilities", "label": "Utilities", "value": Format.money_exact(int(monthly["utilities"]))},
        {"icon": "skills", "label": "Software", "value": Format.money_exact(int(monthly["software"]))}
    ], _columns(4)))
    var runway := FinanceManager.cash_runway_months(GameState.cash, int(monthly["total"]))
    var total := UiBuilder.info_card(
        "Total %s / month" % Format.money_exact(int(monthly["total"])),
        "Cash runway: %s" % Format.runway_label(runway), "expenses")
    total.theme_type_variation = (
        &"DangerPanel" if FinanceManager.is_in_trouble()
        else &"WarningPanel" if runway < 4.0
        else &"ElevatedPanel")
    list.add_child(total)
    if FinanceManager.is_in_trouble():
        var weeks := FinanceManager.weeks_of_grace_left()
        var warning := UiBuilder.info_card(
            "Overdrawn — action required",
            "%d week%s remain to return the studio to positive cash." % [
                weeks, "" if weeks == 1 else "s"], "warning")
        warning.theme_type_variation = &"DangerPanel"
        list.add_child(warning)

func _annual_section() -> void:
    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.section_header(
        "By year", "Income, expenses, and net result for each trading year."))
    var history := FinanceManager.annual_history()
    if history.is_empty():
        list.add_child(UiBuilder.empty_state(
            "No trading history", "Annual results will appear after the first transaction.")["panel"])
        return
    var grid := GridContainer.new()
    grid.columns = _columns(3)
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for row in history:
        var net := int(row["net"])
        var panel := PanelContainer.new()
        panel.theme_type_variation = &"PositivePanel" if net >= 0 else &"DangerPanel"
        panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var stack := VBoxContainer.new()
        stack.add_child(UiBuilder.heading("Year %d" % int(row["year"])))
        stack.add_child(UiBuilder.status_row("cash", "Income\n%s" %
            Format.money_exact(int(row["income"])), 14))
        stack.add_child(UiBuilder.status_row("payroll", "Costs\n%s" %
            Format.money_exact(int(row["expenses"])), 14))
        var result := UiBuilder.label("NET  %s" % Format.signed_money(net), 18)
        result.theme_type_variation = &"PositiveLabel" if net >= 0 else &"DangerLabel"
        stack.add_child(result)
        panel.add_child(stack)
        grid.add_child(panel)
    list.add_child(grid)

func _games_section() -> void:
    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.section_header(
        "Game performance", "Development cost, lifetime revenue, and profit by release."))
    if GameState.released_games.is_empty():
        list.add_child(UiBuilder.empty_state(
            "No games released yet",
            "Release a game to begin comparing its commercial performance.")["panel"])
        return
    var grid := GridContainer.new()
    grid.columns = 2 if get_viewport_rect().size.x >= 800.0 else 1
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for game in GameState.released_games:
        grid.add_child(_game_card(game))
    list.add_child(grid)

func _game_card(game: GameProject) -> PanelContainer:
    var profit := game.profit()
    var panel := PanelContainer.new()
    panel.theme_type_variation = &"PositivePanel" if profit >= 0 else &"DangerPanel"
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.custom_minimum_size = Vector2(270, 0)
    var stack := VBoxContainer.new()
    var title := UiBuilder.label(game.title.to_upper(), 18)
    title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    stack.add_child(title)
    stack.add_child(UiBuilder.label("Released %s" % game.release_date_label(), 13))
    stack.add_child(UiBuilder.stat_grid([
        {"icon": "payroll", "label": "Cost", "value": Format.money_exact(game.total_cost())},
        {"icon": "cash", "label": "Revenue", "value": Format.money_exact(game.lifetime_revenue)}
    ], 2))
    var result := UiBuilder.label("PROFIT  %s" % Format.signed_money(profit), 18)
    result.theme_type_variation = &"PositiveLabel" if profit >= 0 else &"DangerLabel"
    stack.add_child(result)
    var open := UiBuilder.button("VIEW GAME DETAILS")
    open.pressed.connect(_open_game.bind(game.id))
    stack.add_child(open)
    panel.add_child(stack)
    return panel

func _ledger_section() -> void:
    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.section_header(
        "Recent transactions", "The latest income and expenses recorded by the studio."))
    var entries := FinanceManager.recent_transactions(40)
    if entries.is_empty():
        list.add_child(UiBuilder.empty_state(
            "No transactions yet", "Income and expenses will be recorded here.")["panel"])
        return
    entries.reverse()
    var last_date := ""
    for entry in entries:
        var date := Ledger.date_label(entry)
        if date != last_date:
            var date_label := UiBuilder.label(date.to_upper(), 13)
            date_label.theme_type_variation = &"CardCaption"
            list.add_child(date_label)
            last_date = date
        list.add_child(_transaction_row(entry))

func _transaction_row(entry: Dictionary) -> PanelContainer:
    var amount := int(entry.get("amount", 0))
    var panel := PanelContainer.new()
    panel.theme_type_variation = &"PositivePanel" if amount >= 0 else &"ElevatedPanel"
    var row := HBoxContainer.new()
    var copy := VBoxContainer.new()
    copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    copy.add_child(UiBuilder.label(str(entry.get("description", "Transaction")), 14))
    var kind := UiBuilder.label(Ledger.kind_name(int(entry.get("kind", Ledger.Kind.OTHER))), 12)
    kind.theme_type_variation = &"MutedLabel"
    copy.add_child(kind)
    row.add_child(copy)
    var value := UiBuilder.label(Ledger.amount_label(entry), 16)
    value.theme_type_variation = &"PositiveLabel" if amount >= 0 else &"DangerLabel"
    value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    row.add_child(value)
    panel.add_child(row)
    return panel

func _columns(wide_count: int) -> int:
    return wide_count if get_viewport_rect().size.x >= 800.0 else min(2, wide_count)

func _open_game(game_id: String) -> void:
    ScreenRouter.open_game(game_id, scene_file_path)
    get_tree().change_scene_to_file("res://scenes/studio/GameDetailScreen.tscn")

func _on_back() -> void:
    get_tree().change_scene_to_file("res://scenes/company/CompanyScreen.tscn")
