extends Node

## Owns the books: every transaction, and whether the studio is still solvent.
## Nothing else touches GameState.cash directly.

func spend(amount: int, kind: int, description: String, project_id: String = "") -> bool:
    if GameState.cash < amount:
        return false
    _apply(-amount, kind, description, project_id)
    return true

func earn(amount: int, kind: int, description: String, project_id: String = "") -> void:
    _apply(amount, kind, description, project_id)

func force_spend(amount: int, kind: int, description: String, project_id: String = "") -> void:
    ## For costs that cannot be declined; this is what can push cash negative.
    _apply(-amount, kind, description, project_id)

func _apply(delta: int, kind: int, description: String, project_id: String) -> void:
    GameState.cash += delta
    GameState.ledger.append(Ledger.make(kind, description, delta, project_id))

    # The detail is a rolling window, but the yearly totals are kept forever so
    # the player can always review the studio's whole financial history.
    _record_annual(delta)

    if GameState.ledger.size() > 600:
        GameState.ledger = GameState.ledger.slice(GameState.ledger.size() - 600)
    EventBus.company_cash_changed.emit(GameState.cash)

func _record_annual(delta: int) -> void:
    var key := str(TimeManager.current_year)
    if not GameState.annual_finance.has(key):
        GameState.annual_finance[key] = {"income": 0, "expenses": 0}
    var row: Dictionary = GameState.annual_finance[key]
    if delta >= 0:
        row["income"] = int(row.get("income", 0)) + delta
    else:
        row["expenses"] = int(row.get("expenses", 0)) + absi(delta)

func annual_history() -> Array:
    ## Oldest year first: [{year, income, expenses, net}]
    var years: Array = []
    for key in GameState.annual_finance:
        years.append(int(key))
    years.sort()

    var rows: Array = []
    for year in years:
        var row: Dictionary = GameState.annual_finance[str(year)]
        var income := int(row.get("income", 0))
        var expenses := int(row.get("expenses", 0))
        rows.append({"year": year, "income": income, "expenses": expenses, "net": income - expenses})
    return rows

func can_afford(amount: int) -> bool:
    return GameState.cash >= amount

func cash_runway_months(cash: int, monthly_burn: int) -> float:
    ## How many months a cash balance lasts at a given monthly burn rate.
    ## INF is the sentinel for "no burn -- runway is indefinite", kept
    ## distinct from any real result (a negative cash balance under a real
    ## burn rate legitimately produces a negative number of months).
    if monthly_burn <= 0:
        return INF
    return float(cash) / float(monthly_burn)

func recent_transactions(limit: int = 30) -> Array:
    var start := maxi(GameState.ledger.size() - limit, 0)
    return GameState.ledger.slice(start)

func transactions_for(project_id: String) -> Array:
    var rows: Array = []
    for entry in GameState.ledger:
        if str(entry.get("project_id", "")) == project_id:
            rows.append(entry)
    return rows

func expense(amount: int) -> int:
    ## Difficulty scales what things cost to run.
    return int(round(float(amount) * float(GameState.difficulty().get("expense_multiplier", 1.0))))

# --- Solvency ----------------------------------------------------------

func process_week() -> void:
    if GameState.bankrupt:
        return

    if GameState.cash >= 0:
        if GameState.overdrawn_weeks > 0:
            GameState.overdrawn_weeks = 0
            EventBus.company_recovered.emit()
        return

    GameState.overdrawn_weeks += 1

func check_solvency() -> void:
    if GameState.bankrupt or GameState.cash >= 0:
        return

    var grace := GameState.grace_weeks()
    if GameState.overdrawn_weeks >= grace:
        declare_bankruptcy()
        return

    EventBus.company_bankruptcy_warning.emit(grace - GameState.overdrawn_weeks)

func weeks_of_grace_left() -> int:
    if GameState.cash >= 0:
        return GameState.grace_weeks()
    return maxi(GameState.grace_weeks() - GameState.overdrawn_weeks, 0)

func is_in_trouble() -> bool:
    return GameState.cash < 0 and not GameState.bankrupt

func declare_bankruptcy() -> void:
    GameState.bankrupt = true
    GameState.current_project = null
    GameState.selected_project_id = ""
    GameState.active_projects.clear()
    for team in GameState.teams:
        team.project_id = ""
    for game in GameState.released_games:
        game.sales_active = false
    EventBus.company_bankrupt.emit()

func profit_breakdown(project: GameProject) -> Array:
    var rows: Array = []
    rows.append({"label": "Development", "amount": -project.development_cost})
    if project.platform_fee > 0:
        rows.append({"label": "Platform fee", "amount": -project.platform_fee})
    if project.labour_cost > 0:
        # Paid through payroll, not out of this project's budget -- but it is
        # what the game cost, so the rows have to show it or they will not add
        # up to the profit underneath them.
        rows.append({"label": "Wages", "amount": -project.labour_cost})
    if project.advance > 0:
        rows.append({"label": "Advance", "amount": project.advance})
    rows.append({"label": "Revenue", "amount": project.lifetime_revenue})
    rows.append({"label": "Profit", "amount": project.profit()})
    return rows
