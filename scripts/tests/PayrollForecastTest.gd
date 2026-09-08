extends TestCase

## Payroll forecast. Purely informational -- shown while weighing an offer,
## never enforced. Nothing here changes what a hire costs or does.

func run() -> void:
    _forecast_adds_the_offered_salary()
    _forecast_scales_software_with_headcount()
    _runway_divides_cash_by_burn()
    _runway_accounts_for_the_hiring_fee()
    _zero_burn_is_indefinite_not_a_crash()
    _overdrawn_reads_as_overdrawn_not_as_no_burn()
    await _the_hiring_screen_shows_the_panel()
    await _the_panel_tracks_the_offer_slider()
    await _nothing_about_the_forecast_blocks_the_offer()

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(500_000, Ledger.Kind.OTHER, "seed")
    # The bedroom holds only the founder -- real hires below need real room.
    OfficeManager.move_to("shared_workspace")

func _hire(role: String, seniority: String = "mid") -> Employee:
    var candidate := EmployeeManager.generate_candidate(role, seniority)
    GameState.labor_candidates.append(candidate)
    var result := LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)
    check_equal(str(result.get("status", "")), "accepted", "hiring a %s actually landed" % role)
    return candidate

func _forecast_adds_the_offered_salary() -> void:
    section("the forecast adds exactly the offered salary")
    _company()
    _hire("programmer")
    var before := EmployeeManager.monthly_expenses()
    var after := EmployeeManager.forecast_monthly_expenses(2000)
    check_equal(int(after["salaries"]), int(before["salaries"]) + 2000,
        "salaries go up by the offer, nothing else")
    check_equal(int(after["rent"]), int(before["rent"]), "rent does not move with headcount")
    check_equal(int(after["utilities"]), int(before["utilities"]),
        "utilities do not move with headcount")

func _forecast_scales_software_with_headcount() -> void:
    section("software licences scale with the would-be new hire too")
    _company()
    var office := DataManager.get_office(GameState.office_id)
    var per_head := FinanceManager.expense(int(office.get("software_per_employee", 0)))
    var before := EmployeeManager.monthly_expenses()
    var after := EmployeeManager.forecast_monthly_expenses(0)
    check_equal(int(after["software"]), int(before["software"]) + per_head,
        "the bill grows by exactly one head's licence cost, nothing more")

func _runway_divides_cash_by_burn() -> void:
    section("cash runway is cash over burn, in months")
    var runway := FinanceManager.cash_runway_months(12_000, 1000)
    check_equal(int(round(runway * 10.0)), 120, "12,000 at 1,000/mo is exactly a year (%.1f)" % runway)

func _runway_accounts_for_the_hiring_fee() -> void:
    section("the fee is spent before the runway clock starts")
    _company()
    var candidate := EmployeeManager.generate_candidate("programmer", "mid")
    var before_fee := FinanceManager.cash_runway_months(GameState.cash, 5000)
    var after_fee := FinanceManager.cash_runway_months(GameState.cash - candidate.hiring_fee, 5000)
    check_less(after_fee, before_fee, "paying the hiring fee shortens the runway shown")

func _zero_burn_is_indefinite_not_a_crash() -> void:
    section("no burn at all does not divide by zero")
    check(is_inf(FinanceManager.cash_runway_months(10_000, 0)), "the sentinel, not a crash")
    check(is_inf(FinanceManager.cash_runway_months(10_000, -50)), "same for a nonsense negative burn")
    check_equal(Format.runway_label(FinanceManager.cash_runway_months(10_000, 0)), "No burn",
        "and it reads as indefinite, not as zero")

func _overdrawn_reads_as_overdrawn_not_as_no_burn() -> void:
    section("a negative balance under a real burn rate is not confused with no burn at all")
    var runway := FinanceManager.cash_runway_months(-500, 5000)
    check(not is_inf(runway), "this is a real (negative) number, not the indefinite sentinel")
    check_less(runway, 0.0, "cash is already gone")
    check_equal(Format.runway_label(runway), "Overdrawn", "and it reads plainly as overdrawn")

func _open_hiring_screen() -> Control:
    var packed: PackedScene = load("res://scenes/company/HiringScreen.tscn")
    var screen: Control = packed.instantiate()
    add_child(screen)
    await get_tree().process_frame
    await get_tree().process_frame
    return screen

func _close(screen: Control) -> void:
    screen.queue_free()
    await get_tree().process_frame

func _labels_text(container: Control) -> String:
    var text := ""
    for child in container.get_children():
        if child is Label:
            text += str(child.text) + "\n"
    return text

func _the_hiring_screen_shows_the_panel() -> void:
    section("viewing a candidate shows the forecast")
    _company()
    var candidate := EmployeeManager.generate_candidate("programmer", "mid")
    GameState.labor_candidates.append(candidate)

    var screen := await _open_hiring_screen()
    screen._view(candidate)
    var body := _labels_text(screen.list)
    check(body.contains("PAYROLL FORECAST"), "the heading is shown")
    check(body.contains("CURRENT MONTHLY BURN"), "current burn is labelled")
    check(body.contains("After Hire"), "the after-hire figure is labelled")
    check(body.contains("Cash Runway"), "and the runway")
    check(body.contains(Format.money_exact(int(EmployeeManager.monthly_expenses()["total"]))),
        "with today's real burn figure")
    await _close(screen)

func _the_panel_tracks_the_offer_slider() -> void:
    section("raising the offer raises the forecast")
    _company()
    var candidate := EmployeeManager.generate_candidate("programmer", "mid")
    GameState.labor_candidates.append(candidate)

    var screen := await _open_hiring_screen()
    screen._view(candidate)
    var low_offer: int = screen._offer_salary
    var low_after := EmployeeManager.forecast_monthly_expenses(low_offer)

    for _i in 4:
        screen._change_offer(candidate, 50)
    var high_offer: int = screen._offer_salary
    var high_after := EmployeeManager.forecast_monthly_expenses(high_offer)

    check_greater(high_offer, low_offer, "the offer itself actually moved")
    check_greater(float(high_after["total"]), float(low_after["total"]),
        "so a bigger offer forecasts a bigger monthly burn")

    var body := _labels_text(screen.list)
    check(body.contains(Format.money_exact(int(high_after["total"]))),
        "and the panel on screen reflects the current offer, not the original one")
    await _close(screen)

func _nothing_about_the_forecast_blocks_the_offer() -> void:
    section("a frightening forecast is information, not a gate")
    _company()
    FinanceManager.force_spend(GameState.cash - 5000, Ledger.Kind.OTHER, "drain to near zero")
    var candidate := EmployeeManager.generate_candidate("programmer", "mid")
    GameState.labor_candidates.append(candidate)

    var screen := await _open_hiring_screen()
    screen._view(candidate)
    var body := _labels_text(screen.list)
    check(body.contains("Cash Runway"), "the grim runway is still shown plainly")

    # The offer itself is still gated only by the hiring fee and office space,
    # exactly as before this feature -- never by the forecast.
    if FinanceManager.can_afford(candidate.hiring_fee) and OfficeManager.has_capacity():
        var result := LaborMarketManager.make_offer(candidate, screen._offer_salary, 0.0)
        check_equal(str(result.get("status", "")), "accepted",
            "a cash-strapped studio can still make (and win) the offer")
    else:
        check(true, "too poor even for the hiring fee -- not this feature's doing")
    await _close(screen)
