extends Control

## PA.13 -- the financial crisis plan. Shows the studio's cash position the way
## the schedule-slip panel shows a deadline: the raw numbers, the single biggest
## cost driver named, and a set of concrete levers with their consequences.
##
## Every lever reuses an existing system -- abandon a project, lay someone off,
## downsize the office, cut a feature, take contract work -- plus the one new
## one, the emergency loan. Nothing here is a free bailout.

@onready var heading: Label = $Margin/VBox/Heading
@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var back_button: Button = $Margin/VBox/BackButton

var _confirm := ""
var _loan_amount := 0

var _return_scene := "res://scenes/studio/StudioScreen.tscn"

func _ready() -> void:
    GameClock.enter_menu()
    if ScreenRouter.return_scene.begins_with("res://"):
        _return_scene = ScreenRouter.return_scene
    back_button.pressed.connect(_on_back)
    _build()

func _build() -> void:
    UiBuilder.clear(list)
    var snap := FinanceManager.crisis_snapshot()
    var level := int(snap["level"])

    heading.text = CrisisSimulator.level_label(level) if level >= CrisisSimulator.RUNWAY_LOW else "FINANCES"

    _position(snap)
    _driver(snap)
    _actions(snap)

# --- The numbers -----------------------------------------------------

func _position(snap: Dictionary) -> void:
    var runway := Format.runway_label(float(snap["runway_months"]))
    var lines := [
        "Cash                    %s" % Format.money_exact(int(snap["cash"])),
        "Monthly burn            %s" % Format.money_exact(int(snap["monthly_burn"])),
        "Runway                  %s" % runway,
        "Upcoming payroll        %s  (in %d week%s)" % [
            Format.money_exact(int(snap["next_payroll"])), int(snap["weeks_until_payroll"]),
            "" if int(snap["weeks_until_payroll"]) == 1 else "s"],
    ]
    if not str(snap["project_title"]).is_empty():
        lines.append("Project completion      %s  (%s)" % [
            snap["project_completion"], snap["project_title"]])
    lines.append("Expected income (8 wk)  %s" % Format.money_exact(int(snap["near_term_income"])))
    lines.append("Debt                    %s" % Format.money_exact(int(snap["debt"])))
    if int(snap["level"]) >= CrisisSimulator.TROUBLE:
        lines.append("Weeks to insolvency     %d" % int(snap["grace_weeks_left"]))
    list.add_child(UiBuilder.label("\n".join(lines), 14))

    var income := int(snap["near_term_income"])
    var burn := int(snap["monthly_burn"])
    var verdict := ""
    if income >= burn * 2:
        verdict = "Near-term income covers the burn. Holding on may be enough."
    elif income >= burn:
        verdict = "Near-term income roughly covers the burn -- little margin for anything going wrong."
    else:
        verdict = "Near-term income does not cover the burn. Costs have to come down."
    list.add_child(UiBuilder.label(verdict, 13, true))
    list.add_child(UiBuilder.divider())

func _driver(snap: Dictionary) -> void:
    var driver: Dictionary = snap["driver"]
    list.add_child(UiBuilder.heading("BIGGEST COST"))
    list.add_child(UiBuilder.label("%s — %s / month  (%d%% of the burn)" % [
        str(driver["label"]), Format.money_exact(int(driver["amount"])),
        int(round(float(driver["share"]) * 100.0))], 15, true))
    if not str(driver.get("context", "")).is_empty():
        list.add_child(UiBuilder.label(str(driver["context"]), 13, true))
    list.add_child(UiBuilder.label(str(driver["advice"]), 13))
    list.add_child(UiBuilder.divider())

# --- The levers ------------------------------------------------------

func _actions(snap: Dictionary) -> void:
    list.add_child(UiBuilder.heading("WHAT YOU CAN DO"))

    _cancel_project_lever()
    _scope_lever()
    _layoff_lever()
    _office_lever()
    _contract_lever()
    _loan_lever(snap)

func _lever(title: String, consequence: String) -> void:
    list.add_child(UiBuilder.label(title.to_upper(), 14))
    list.add_child(UiBuilder.label(consequence, 12, true))

func _cancel_project_lever() -> void:
    var project := GameState.current_project
    if project == null:
        return
    _lever("Cancel %s" % project.title,
        "Frees the team you are paying immediately. All progress and its budget are lost.")
    if _confirm == "cancel":
        var row := _confirm_row(func():
            GameState.abandon_project(project)
            _confirm = ""
            _build())
        list.add_child(row)
    else:
        var button := UiBuilder.button("CANCEL PROJECT")
        button.pressed.connect(func(): _confirm = "cancel"; _build())
        list.add_child(button)
    list.add_child(UiBuilder.divider())

func _scope_lever() -> void:
    var project := GameState.current_project
    if project == null or project.feature_ids.is_empty():
        return
    _lever("Cut a feature from %s" % project.title,
        "Removes its remaining effort so the project finishes sooner and costs less to carry. Whatever quality it already earned stays.")
    var button := UiBuilder.button("REVIEW FEATURES")
    button.pressed.connect(func():
        GameState.select_project(project)
        get_tree().change_scene_to_file("res://scenes/development/DevelopmentScreen.tscn"))
    list.add_child(button)
    list.add_child(UiBuilder.divider())

func _layoff_lever() -> void:
    var headcount := EmployeeManager.active_employees().size()
    if headcount <= 1:
        return
    _lever("Lay off staff",
        "Cuts payroll from next month. Severance is paid now, the team's morale drops, and repeated rounds cost the studio its standing as an employer.")
    var button := UiBuilder.button("OPEN STAFF")
    button.pressed.connect(func():
        get_tree().change_scene_to_file("res://scenes/company/StaffScreen.tscn"))
    list.add_child(button)
    list.add_child(UiBuilder.divider())

func _office_lever() -> void:
    var cheaper := OfficeManager.cheaper_office()
    if cheaper.is_empty():
        return
    var rent_now := OfficeManager.monthly_rent()
    var rent_then := OfficeManager.monthly_rent(cheaper)
    _lever("Move to %s" % str(cheaper.get("name", "a smaller office")),
        "Cuts rent by about %s / month. One-off moving cost %s. Productivity and recruiting take a step down." % [
            Format.money(maxi(rent_now - rent_then, 0)),
            Format.money(OfficeManager.downgrade_cost(cheaper))])
    if not OfficeManager.can_downgrade():
        var need := EmployeeManager.active_employees().size() - int(cheaper.get("capacity", 0))
        var blocked := UiBuilder.button("NEEDS %d FEWER STAFF" % maxi(need, 1))
        blocked.disabled = true
        list.add_child(blocked)
    elif _confirm == "office":
        list.add_child(_confirm_row(func():
            OfficeManager.downgrade()
            _confirm = ""
            _build()))
    else:
        var button := UiBuilder.button("MOVE OFFICE")
        button.pressed.connect(func(): _confirm = "office"; _build())
        list.add_child(button)
    list.add_child(UiBuilder.divider())

func _contract_lever() -> void:
    if ContractManager.has_active_contract():
        return
    _lever("Take contract work",
        "A guaranteed payout for finished work, but it occupies a team that could be building something of your own.")
    var button := UiBuilder.button("VIEW CONTRACTS")
    button.pressed.connect(func():
        get_tree().change_scene_to_file("res://scenes/company/ContractsScreen.tscn"))
    list.add_child(button)
    list.add_child(UiBuilder.divider())

func _loan_lever(snap: Dictionary) -> void:
    var loan: Dictionary = snap["loan"]
    if not loan.is_empty():
        _lever("Emergency loan (active)",
            "Borrowed %s. %s outstanding, %s / week, %d weeks left." % [
                Format.money_exact(int(loan["principal"])), Format.money_exact(int(loan["balance"])),
                Format.money_exact(int(loan["weekly_payment"])), int(loan["weeks_remaining"])])
        var settle := UiBuilder.button("SETTLE EARLY (%s)" % Format.money(int(loan["payoff"])))
        settle.disabled = GameState.cash < int(loan["payoff"])
        settle.pressed.connect(func():
            LoanManager.repay_early()
            _build())
        list.add_child(settle)
        list.add_child(UiBuilder.divider())
        return

    var eligibility := LoanManager.eligibility()
    _lever("Take an emergency loan",
        "Cash now against a fixed weekly repayment at %d%% interest a week for %d weeks. It buys time; it does not fix a studio that spends more than it earns." % [
            int(round(LoanSimulator.WEEKLY_INTEREST_RATE * 100.0)), LoanSimulator.TERM_WEEKS])
    if not bool(eligibility.get("ok", false)):
        var blocked := UiBuilder.button(str(eligibility.get("reason", "Not available")).to_upper())
        blocked.disabled = true
        list.add_child(blocked)
        list.add_child(UiBuilder.divider())
        return

    var ceiling := int(eligibility["max_principal"])
    if _loan_amount <= 0:
        _loan_amount = ceiling
    _loan_amount = clampi(_loan_amount, LoanSimulator.MIN_PRINCIPAL, ceiling)
    var payment := LoanSimulator.weekly_payment(_loan_amount)
    var total := LoanSimulator.total_repayable(_loan_amount)

    list.add_child(UiBuilder.label(
        "Borrow %s  (max %s)\nRepay %s / week for %d weeks\nTotal repaid %s  (interest %s)" % [
            Format.money_exact(_loan_amount), Format.money_exact(ceiling),
            Format.money_exact(payment), LoanSimulator.TERM_WEEKS,
            Format.money_exact(total), Format.money_exact(total - _loan_amount)], 13))

    var step := maxi(int(ceiling / 10.0 / 1000.0) * 1000, 1000)
    var adjust := HBoxContainer.new()
    adjust.add_theme_constant_override("separation", 8)
    for delta in [-step, step]:
        var b := UiBuilder.button(("%+d" % (delta / 1000)) + "k")
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.disabled = _loan_amount + delta < LoanSimulator.MIN_PRINCIPAL or _loan_amount + delta > ceiling
        b.pressed.connect(func():
            _loan_amount = clampi(_loan_amount + delta, LoanSimulator.MIN_PRINCIPAL, ceiling)
            _build())
        adjust.add_child(b)
    var max_button := UiBuilder.button("MAX")
    max_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    max_button.pressed.connect(func(): _loan_amount = ceiling; _build())
    adjust.add_child(max_button)
    list.add_child(adjust)

    if _confirm == "loan":
        list.add_child(_confirm_row(func():
            LoanManager.take_loan(_loan_amount)
            _confirm = ""
            _build()))
    else:
        var button := UiBuilder.button("TAKE LOAN OF %s" % Format.money(_loan_amount))
        button.pressed.connect(func(): _confirm = "loan"; _build())
        list.add_child(button)
    list.add_child(UiBuilder.divider())

func _confirm_row(on_confirm: Callable) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    var yes := UiBuilder.button("CONFIRM")
    yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    yes.pressed.connect(on_confirm)
    row.add_child(yes)
    var no := UiBuilder.button("CANCEL")
    no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    no.pressed.connect(func(): _confirm = ""; _build())
    row.add_child(no)
    return row

func _on_back() -> void:
    get_tree().change_scene_to_file(_return_scene)
