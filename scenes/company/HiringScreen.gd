extends Control

## A deliberately small labor market. Candidate details expand in place so the
## whole hiring flow remains comfortable on a portrait screen.

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
    rotation_label.text = "New candidates in %d week%s   Cash $%s\nEmployees %d / %d" % [
        GameState.labor_market_weeks_left,
        "" if GameState.labor_market_weeks_left == 1 else "s",
        Format.exact(GameState.cash),
        OfficeManager.headcount(), OfficeManager.capacity()
    ]
    var reputation := LaborMarketManager.employer_reputation()
    list.add_child(UiBuilder.label("EMPLOYER REPUTATION\n%s  %s" % [
        str(reputation["display"]), str(reputation["label"])], 15, true))
    list.add_child(UiBuilder.label(
        "Better places to work draw better candidates. Pay, the office, how "
        + "games do, crunch and how the current team feels all count.", 12))
    list.add_child(UiBuilder.divider())

    if not OfficeManager.has_capacity():
        list.add_child(UiBuilder.label(
            "OFFICE FULL\n\nYour current office cannot support additional employees.", 15, true
        ))
        var offices_button := UiBuilder.major_button("VIEW OFFICES")
        offices_button.pressed.connect(func():
            get_tree().change_scene_to_file("res://scenes/studio/OfficeScreen.tscn"))
        list.add_child(offices_button)
        list.add_child(UiBuilder.divider())

    if not _result_message.is_empty():
        list.add_child(UiBuilder.label(_result_message, 15, true))
        list.add_child(UiBuilder.divider())

    if GameState.labor_candidates.is_empty():
        list.add_child(UiBuilder.label(
            "No candidates remain in this rotation. New talent will arrive soon.", 15, true
        ))
        return

    for candidate in GameState.labor_candidates:
        _candidate_card(candidate)

func _candidate_card(candidate: Employee) -> void:
    var rarity := DataManager.get_candidate_rarity(candidate.rarity_id)
    var card_label := str(rarity.get("card_label", ""))
    if not card_label.is_empty():
        list.add_child(UiBuilder.label(card_label, 15, true))
    list.add_child(UiBuilder.employee_header(candidate, EmployeeManager.job_title(candidate)))
    var tier := EmployeeManager.reputation_tier(candidate)
    if not tier.is_empty():
        list.add_child(UiBuilder.label(
            "INDUSTRY REPUTATION: %s\nA known name -- expect to pay for it." % tier, 13, true))
    if not candidate.trait_ids.is_empty():
        var trait_id := candidate.trait_ids[0]
        list.add_child(UiBuilder.label("%s\n%s" % [
            EmployeeManager.trait_name(trait_id).to_upper(),
            EmployeeManager.trait_description(trait_id)
        ], 13))

    var highlights := _highlights(candidate)
    list.add_child(UiBuilder.label(
        "%s\nAge          %d\n\nSalary       $%s / month\nHiring fee   $%s" % [
            highlights,
            candidate.age,
            Format.exact(candidate.salary),
            Format.exact(candidate.hiring_fee)
        ], 14
    ))

    if _expanded == candidate:
        list.add_child(UiBuilder.label(_full_profile(candidate), 13))
        _offer_controls(candidate)
    else:
        var view_button := UiBuilder.button("VIEW")
        view_button.pressed.connect(_view.bind(candidate))
        list.add_child(view_button)
    list.add_child(UiBuilder.divider())

func _highlights(candidate: Employee) -> String:
    var values: Array = []
    for field in EmployeeManager.SKILL_FIELDS:
        values.append({"name": str(field).capitalize(), "value": int(candidate.get(field))})
    for field in ["creativity", "teamwork", "quality", "leadership"]:
        values.append({"name": str(field).capitalize(), "value": int(candidate.get(field))})
    values.sort_custom(func(a, b): return int(a["value"]) > int(b["value"]))
    var lines: Array[String] = []
    for index in mini(3, values.size()):
        lines.append("%-13s %d" % [values[index]["name"], values[index]["value"]])
    return "\n".join(lines)

func _full_profile(candidate: Employee) -> String:
    return "Programming %d   Design %d   Art %d\nWriting %d   Audio %d   Production %d\nTesting %d   Research %d\n\nCreativity %d   Speed %d   Quality %d\nTeamwork %d   Adaptability %d   Leadership %d" % [
        candidate.programming, candidate.design, candidate.art, candidate.writing,
        candidate.audio, candidate.production, candidate.testing, candidate.research,
        candidate.creativity, candidate.speed, candidate.quality, candidate.teamwork,
        candidate.adaptability, candidate.leadership
    ]

func _offer_controls(candidate: Employee) -> void:
    var chance := RecruitmentSimulator.acceptance_probability(
        candidate.salary, _offer_salary, LaborMarketManager.company_attractiveness()
    )
    list.add_child(UiBuilder.label("YOUR OFFER", 13, true))

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    var minus := UiBuilder.button("-")
    minus.custom_minimum_size.x = 58
    minus.disabled = _offer_salary <= _minimum_offer(candidate)
    minus.pressed.connect(_change_offer.bind(candidate, -50))
    row.add_child(minus)
    var amount := UiBuilder.label("$%s / month" % Format.exact(_offer_salary), 17, true)
    amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    row.add_child(amount)
    var plus := UiBuilder.button("+")
    plus.custom_minimum_size.x = 58
    plus.disabled = _offer_salary >= _maximum_offer(candidate)
    plus.pressed.connect(_change_offer.bind(candidate, 50))
    row.add_child(plus)
    list.add_child(row)

    list.add_child(UiBuilder.label("Chance of acceptance: %s" %
        RecruitmentSimulator.acceptance_label(chance), 14, true))
    _payroll_forecast(candidate)
    var offer_button := UiBuilder.major_button("MAKE OFFER")
    offer_button.disabled = (
        not FinanceManager.can_afford(candidate.hiring_fee)
        or not OfficeManager.has_capacity()
    )
    offer_button.pressed.connect(_make_offer.bind(candidate))
    list.add_child(offer_button)

func _payroll_forecast(candidate: Employee) -> void:
    ## What this specific offer would do to the books, before it's made.
    ## Nothing here changes what the offer costs -- it's purely informational.
    var current := EmployeeManager.monthly_expenses()
    var after := EmployeeManager.forecast_monthly_expenses(_offer_salary)
    var cash_after_fee := GameState.cash - candidate.hiring_fee
    var runway := FinanceManager.cash_runway_months(cash_after_fee, int(after["total"]))

    list.add_child(UiBuilder.label("PAYROLL FORECAST", 13, true))
    list.add_child(UiBuilder.label(
        "CURRENT MONTHLY BURN\n%s\n\nAfter Hire\n%s\n\nCash Runway\n%s" % [
            Format.money_exact(int(current["total"])),
            Format.money_exact(int(after["total"])),
            Format.runway_label(runway)
        ], 14, true
    ))

func _view(candidate: Employee) -> void:
    _expanded = candidate
    _offer_salary = int(round(float(candidate.salary) * 0.90 / 50.0)) * 50
    _result_message = ""
    _build()

func _change_offer(candidate: Employee, delta: int) -> void:
    _offer_salary = clampi(
        _offer_salary + delta, _minimum_offer(candidate), _maximum_offer(candidate)
    )
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

func _on_market_refreshed() -> void:
    _expanded = null
    _result_message = ""
    _build()
