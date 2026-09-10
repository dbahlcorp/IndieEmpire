extends Control

## Recruitment is presented as a small talent board instead of a spreadsheet.
## Offer resolution and every hiring rule still live in LaborMarketManager.

@onready var rotation_label: Label = $Margin/VBox/RotationLabel
@onready var list: VBoxContainer = $Margin/VBox/Scroll/List

var _expanded: Employee = null
var _offer_salary: int = 0
var _result_message: String = ""

func _ready() -> void:
    GameClock.enter_gameplay(false)
    EventBus.week_ticked.connect(func(_y, _m, _w): _build())
    EventBus.labor_market_refreshed.connect(_on_market_refreshed)
    _build()
    TutorialManager.offer("first_hire", list)

func _build() -> void:
    UiBuilder.clear(list)
    rotation_label.text = "New candidates in %d week%s" % [
        GameState.labor_market_weeks_left,
        "" if GameState.labor_market_weeks_left == 1 else "s"]

    var reputation := LaborMarketManager.employer_reputation()
    var expenses := EmployeeManager.monthly_expenses()
    list.add_child(UiBuilder.stat_grid([
        {"icon": "reputation", "label": "Employer reputation", "value": "%s · %s" % [
            str(reputation["display"]), str(reputation["label"])]},
        {"icon": "capacity", "label": "Team capacity", "value": "%d / %d" % [
            OfficeManager.headcount(), OfficeManager.capacity()]},
        {"icon": "payroll", "label": "Monthly burn", "value":
            Format.money_exact(int(expenses["total"]))},
        {"icon": "cash", "label": "Cash", "value": Format.money_exact(GameState.cash)}
    ], _columns(4)))
    list.add_child(UiBuilder.info_card(
        "A workplace people want to join",
        "Pay, office quality, successful releases, crunch, and team morale all shape the talent you attract.",
        "capacity"))

    if not OfficeManager.has_capacity():
        var warning := UiBuilder.info_card(
            "Office full", "Move to a larger office before making another hire.", "warning")
        warning.theme_type_variation = &"WarningPanel"
        var warning_stack := warning.get_child(0) as VBoxContainer
        var offices_button := UiBuilder.button("VIEW OFFICES")
        offices_button.pressed.connect(func():
            get_tree().change_scene_to_file("res://scenes/studio/OfficeScreen.tscn"))
        warning_stack.add_child(offices_button)
        list.add_child(warning)

    if not _result_message.is_empty():
        var result := UiBuilder.info_card("Recruitment update", _result_message, "info")
        result.theme_type_variation = (
            &"PositivePanel" if _result_message.contains("accepted") else &"WarningPanel")
        list.add_child(result)

    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.section_header(
        "Candidates", "Compare the strongest skills, then expand a profile before making an offer."))
    if GameState.labor_candidates.is_empty():
        list.add_child(UiBuilder.empty_state(
            "No candidates this rotation",
            "The labor market refreshes automatically when the countdown reaches zero.")["panel"])
        return

    if _expanded != null and GameState.labor_candidates.has(_expanded):
        list.add_child(_candidate_panel(_expanded, true))
        _offer_controls(_expanded)
        if GameState.labor_candidates.size() > 1:
            list.add_child(UiBuilder.section_header("More candidates"))

    var grid := GridContainer.new()
    grid.columns = 2 if get_viewport_rect().size.x >= 800.0 else 1
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for candidate in GameState.labor_candidates:
        if candidate == _expanded:
            continue
        grid.add_child(_candidate_panel(candidate, false))
    if grid.get_child_count() > 0:
        list.add_child(grid)

func _candidate_panel(candidate: Employee, expanded: bool) -> PanelContainer:
    var rarity := DataManager.get_candidate_rarity(candidate.rarity_id)
    var panel := PanelContainer.new()
    panel.theme_type_variation = &"SpecialPanel" if not str(rarity.get("card_label", "")).is_empty() else &"ElevatedPanel"
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.custom_minimum_size = Vector2(300, 0)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 9)

    var card_label := str(rarity.get("card_label", ""))
    if not card_label.is_empty():
        stack.add_child(UiBuilder.status_chip(card_label, "special"))
    stack.add_child(UiBuilder.employee_header(
        candidate, "%s · age %d" % [EmployeeManager.job_title(candidate), candidate.age]))
    var tier := EmployeeManager.reputation_tier(candidate)
    if not tier.is_empty():
        stack.add_child(UiBuilder.status_chip("Industry reputation: %s" % tier, "special"))
    if not candidate.trait_ids.is_empty():
        var trait_id := candidate.trait_ids[0]
        stack.add_child(UiBuilder.info_card(
            EmployeeManager.trait_name(trait_id),
            EmployeeManager.trait_description(trait_id), "traits"))

    var highlights := _highlight_values(candidate)
    var skill_items: Array = []
    for highlight in highlights:
        skill_items.append({"icon": "skills", "label": str(highlight["name"]),
            "value": str(highlight["value"])})
    # Three narrow cards split headings such as PROGRAMMING mid-word at the
    # 430 px reference width. Two columns remain compact and phone-readable.
    stack.add_child(UiBuilder.stat_grid(skill_items, 2))
    stack.add_child(UiBuilder.stat_grid([
        {"icon": "payroll", "label": "Salary", "value": "%s / mo" %
            Format.money_exact(candidate.salary)},
        {"icon": "cash", "label": "Hiring fee", "value":
            Format.money_exact(candidate.hiring_fee)}
    ], 2))

    if expanded:
        var profile := UiBuilder.label(_full_profile(candidate), 13)
        profile.theme_type_variation = &"MutedLabel"
        stack.add_child(profile)
    else:
        var view_button := UiBuilder.button("VIEW CANDIDATE")
        view_button.tooltip_text = "Review the full profile and prepare a salary offer"
        view_button.pressed.connect(_view.bind(candidate))
        stack.add_child(view_button)
    panel.add_child(stack)
    return panel

func _highlight_values(candidate: Employee) -> Array:
    var values: Array = []
    for field in EmployeeManager.SKILL_FIELDS:
        values.append({"name": str(field).capitalize(), "value": int(candidate.get(field))})
    for field in ["creativity", "teamwork", "quality", "leadership"]:
        values.append({"name": str(field).capitalize(), "value": int(candidate.get(field))})
    values.sort_custom(func(a, b): return int(a["value"]) > int(b["value"]))
    return values.slice(0, mini(3, values.size()))

func _full_profile(candidate: Employee) -> String:
    return "FULL PROFILE\nProgramming %d   Design %d   Art %d\nWriting %d   Audio %d   Production %d\nTesting %d   Research %d\n\nCreativity %d   Speed %d   Quality %d\nTeamwork %d   Adaptability %d   Leadership %d" % [
        candidate.programming, candidate.design, candidate.art, candidate.writing,
        candidate.audio, candidate.production, candidate.testing, candidate.research,
        candidate.creativity, candidate.speed, candidate.quality, candidate.teamwork,
        candidate.adaptability, candidate.leadership]

func _offer_controls(candidate: Employee) -> void:
    var chance := RecruitmentSimulator.acceptance_probability(
        candidate.salary, _offer_salary, LaborMarketManager.company_attractiveness())
    list.add_child(UiBuilder.heading("PAYROLL FORECAST"))
    var current := EmployeeManager.monthly_expenses()
    var after := EmployeeManager.forecast_monthly_expenses(_offer_salary)
    var cash_after_fee := GameState.cash - candidate.hiring_fee
    var runway := FinanceManager.cash_runway_months(cash_after_fee, int(after["total"]))
    list.add_child(UiBuilder.label(
        "CURRENT MONTHLY BURN\n%s\n\nAfter Hire\n%s\n\nCash Runway\n%s" % [
            Format.money_exact(int(current["total"])),
            Format.money_exact(int(after["total"])),
            Format.runway_label(runway)], 14, true))

    var offer_panel := PanelContainer.new()
    offer_panel.theme_type_variation = &"ElevatedPanel"
    var stack := VBoxContainer.new()
    stack.add_child(UiBuilder.heading("Your salary offer"))
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    var minus := UiBuilder.button("−")
    minus.custom_minimum_size.x = 58
    minus.tooltip_text = "Lower monthly salary offer"
    minus.disabled = _offer_salary <= _minimum_offer(candidate)
    minus.pressed.connect(_change_offer.bind(candidate, -50))
    row.add_child(minus)
    var amount := UiBuilder.label("%s / month" % Format.money_exact(_offer_salary), 20, true)
    amount.theme_type_variation = &"HeroValue"
    amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    row.add_child(amount)
    var plus := UiBuilder.button("+")
    plus.custom_minimum_size.x = 58
    plus.tooltip_text = "Raise monthly salary offer"
    plus.disabled = _offer_salary >= _maximum_offer(candidate)
    plus.pressed.connect(_change_offer.bind(candidate, 50))
    row.add_child(plus)
    stack.add_child(row)
    stack.add_child(UiBuilder.status_chip(
        "Acceptance chance: %s" % RecruitmentSimulator.acceptance_label(chance),
        "positive" if chance >= 0.65 else "warning"))
    var offer_button := UiBuilder.major_button("MAKE OFFER")
    offer_button.disabled = (
        not FinanceManager.can_afford(candidate.hiring_fee)
        or not OfficeManager.has_capacity())
    offer_button.tooltip_text = (
        "Pay the hiring fee and send this salary offer"
        if not offer_button.disabled else "Requires office space and enough cash for the hiring fee")
    offer_button.pressed.connect(_make_offer.bind(candidate))
    stack.add_child(offer_button)
    offer_panel.add_child(stack)
    list.add_child(offer_panel)

func _view(candidate: Employee) -> void:
    _expanded = candidate
    _offer_salary = int(round(float(candidate.salary) * 0.90 / 50.0)) * 50
    _result_message = ""
    _build()

func _change_offer(candidate: Employee, delta: int) -> void:
    _offer_salary = clampi(
        _offer_salary + delta, _minimum_offer(candidate), _maximum_offer(candidate))
    _build()

func _make_offer(candidate: Employee) -> void:
    var name := candidate.display_name()
    var result := LaborMarketManager.make_offer(candidate, _offer_salary)
    match str(result.get("status", "invalid")):
        "accepted":
            _result_message = "%s accepted your offer." % name
            _expanded = null
        "declined":
            _result_message = "%s declined your offer." % name
            _expanded = null
        "unaffordable":
            _result_message = "You cannot afford the hiring fee."
        "office_full":
            _result_message = "Your office has no room for another employee."
    _build()

func _minimum_offer(candidate: Employee) -> int:
    return int(ceil(float(candidate.salary) * 0.60 / 50.0)) * 50

func _maximum_offer(candidate: Employee) -> int:
    return int(ceil(float(candidate.salary) * 1.50 / 50.0)) * 50

func _columns(wide_count: int) -> int:
    return wide_count if get_viewport_rect().size.x >= 800.0 else min(2, wide_count)

func _on_market_refreshed() -> void:
    _expanded = null
    _result_message = ""
    _build()
