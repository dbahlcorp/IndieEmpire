extends TestCase

## Cash runway. Cash on its own doesn't say whether a studio is in trouble --
## the same balance can mean months of safety or days, depending on burn.
## This is purely informational: nothing here gates or alters anything.

func run() -> void:
    _runway_is_cash_over_burn()
    _formats_a_real_runway()
    _formats_no_burn_as_indefinite()
    _formats_a_negative_balance_as_overdrawn()
    await _the_studio_screen_shows_the_panel()
    await _the_panel_tracks_a_real_hire()
    await _a_dire_runway_does_not_block_anything()

func _company(starting_cash: int = 200_000) -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(starting_cash, Ledger.Kind.OTHER, "seed")
    # The bedroom holds only the founder -- real hires below need real room.
    OfficeManager.move_to("shared_workspace")

func _hire(role: String, seniority: String = "mid") -> void:
    var candidate := EmployeeManager.generate_candidate(role, seniority)
    GameState.labor_candidates.append(candidate)
    var result := LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)
    check_equal(str(result.get("status", "")), "accepted", "hiring a %s actually landed" % role)

func _runway_is_cash_over_burn() -> void:
    section("the estimate is exactly cash divided by burn")
    check_approx(FinanceManager.cash_runway_months(127_400, 16_200), 127_400.0 / 16_200.0,
        "matches the mock-up's own arithmetic")
    check_approx(FinanceManager.cash_runway_months(24_000, 4000), 6.0, "a clean case")

func _formats_a_real_runway() -> void:
    section("a real runway reads as N.N months")
    check_equal(Format.runway_label(7.8), "7.8 months", "one decimal place")
    check_equal(Format.runway_label(0.04), "0.0 months", "even a sliver of runway is not overdrawn")

func _formats_no_burn_as_indefinite() -> void:
    section("no burn at all is indefinite, not zero")
    check_equal(Format.runway_label(FinanceManager.cash_runway_months(50_000, 0)), "No burn",
        "a studio with nothing going out has no countdown")

func _formats_a_negative_balance_as_overdrawn() -> void:
    section("an already-negative balance reads as overdrawn")
    check_equal(Format.runway_label(-3.5), "Overdrawn", "not a nonsensical negative months figure")

func _open_studio_screen() -> Control:
    var packed: PackedScene = load("res://scenes/studio/StudioScreen.tscn")
    var screen: Control = packed.instantiate()
    add_child(screen)
    await get_tree().process_frame
    await get_tree().process_frame
    return screen

func _close(screen: Control) -> void:
    screen.queue_free()
    await get_tree().process_frame

func _the_studio_screen_shows_the_panel() -> void:
    section("the home screen leads with runway, not just the raw cash figure")
    _company()
    _hire("programmer")
    _hire("artist")

    var screen := await _open_studio_screen()
    var burn := int(EmployeeManager.monthly_expenses()["total"])
    var expected_runway := FinanceManager.cash_runway_months(GameState.cash, burn)

    var body: String = screen.runway_label.text
    check(body.contains("RUNWAY"), "the heading is shown")
    check(body.contains("Cash"), "Cash is labelled")
    check(body.contains("Monthly Expenses"), "Monthly Expenses is labelled")
    check(body.contains("Estimated Runway"), "and Estimated Runway")
    check(body.contains(Format.money_exact(GameState.cash)), "with the real cash figure")
    check(body.contains(Format.money_exact(burn)), "the real monthly burn")
    check(body.contains(Format.runway_label(expected_runway)), "and the real runway estimate")
    await _close(screen)

func _the_panel_tracks_a_real_hire() -> void:
    section("a new hire raises the burn shown, in real time")
    _company()

    var screen := await _open_studio_screen()
    var burn_before := int(EmployeeManager.monthly_expenses()["total"])
    check(screen.runway_label.text.contains(Format.money_exact(burn_before)),
        "starts showing today's burn (%s)" % Format.money_exact(burn_before))

    _hire("designer")
    screen._refresh()
    var burn_after := int(EmployeeManager.monthly_expenses()["total"])
    check_greater(float(burn_after), float(burn_before), "the hire actually raised the burn")
    check(screen.runway_label.text.contains(Format.money_exact(burn_after)),
        "and the panel now shows the new figure, not the stale one")
    await _close(screen)

func _a_dire_runway_does_not_block_anything() -> void:
    section("a frightening runway is information, not a gate")
    _company(50_000)
    _hire("programmer", "senior")
    _hire("artist", "senior")

    var screen := await _open_studio_screen()
    check(screen.runway_label.text.contains("Estimated Runway"), "the runway is still shown plainly")

    # The develop button's own gating is untouched by this feature -- it was
    # always about active project slots, never about cash.
    check_not_equal(screen.develop_button.text, "", "the rest of the screen still functions normally")
    await _close(screen)
