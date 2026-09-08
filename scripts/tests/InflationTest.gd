extends TestCase

## Salaries and rent both drift upward over a long playthrough, on the same
## authored year -> multiplier curve (data/inflation.json), so a decades-long
## studio does not keep paying 1985 prices forever. Approximate and
## fictionalized on purpose -- see InflationSimulator.

func run() -> void:
    _matches_authored_breakpoints()
    _interpolates_between_breakpoints()
    _clamps_before_the_curve_starts()
    _extrapolates_past_the_curve()
    _scales_a_real_salary()
    _scales_real_rent()

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(400_000, Ledger.Kind.OTHER, "seed")

func _matches_authored_breakpoints() -> void:
    section("the authored breakpoints read back exactly")
    check_approx(InflationSimulator.multiplier_for_year(1985), 1.0, "1985")
    check_approx(InflationSimulator.multiplier_for_year(1990), 1.15, "1990")
    check_approx(InflationSimulator.multiplier_for_year(2000), 1.55, "2000")
    check_approx(InflationSimulator.multiplier_for_year(2010), 2.1, "2010")
    check_approx(InflationSimulator.multiplier_for_year(2020), 2.8, "2020")

func _interpolates_between_breakpoints() -> void:
    section("years between two breakpoints land in between")
    # Halfway between 1990 (1.15x) and 2000 (1.55x).
    check_approx(InflationSimulator.multiplier_for_year(1995), 1.35, "1995 sits at the midpoint")
    check_greater(InflationSimulator.multiplier_for_year(1996), InflationSimulator.multiplier_for_year(1994),
        "and the curve only ever climbs between two rising breakpoints")

func _clamps_before_the_curve_starts() -> void:
    section("nothing before the curve starts is worth less than 1985")
    check_approx(InflationSimulator.multiplier_for_year(1985), 1.0, "at the founding year")
    check_approx(InflationSimulator.multiplier_for_year(1970), 1.0, "and long before it, the same")

func _extrapolates_past_the_curve() -> void:
    section("a playthrough that outlives the authored curve keeps drifting")
    var at_2020 := InflationSimulator.multiplier_for_year(2020)
    var at_2030 := InflationSimulator.multiplier_for_year(2030)
    check_greater(at_2030, at_2020, "the economy does not freeze in 2020")
    # 2010 (2.1x) to 2020 (2.8x) is +0.07x/year; ten more years should keep
    # roughly that pace rather than jumping or flattening.
    check_between(at_2030, at_2020 + 0.5, at_2020 + 0.9,
        "and the pace roughly matches the final authored segment (%.2f)" % at_2030)

func _scales_a_real_salary() -> void:
    section("a real hire actually costs more, decades later")
    _company()
    TimeManager.set_date(1985, 1, 1)
    var early := EmployeeManager.generate_candidate("programmer", "mid")

    TimeManager.set_date(2000, 1, 1)
    var later := EmployeeManager.generate_candidate("programmer", "mid")

    check_greater(later.salary, early.salary,
        "the year-2000 hire commands more pay for the same role and seniority (%d vs %d)" % [
            later.salary, early.salary])

func _scales_real_rent() -> void:
    section("rent actually rises on the books, decades later")
    _company()
    OfficeManager.move_to("shared_workspace")

    TimeManager.set_date(1985, 1, 1)
    var early_rent: int = int(EmployeeManager.monthly_expenses()["rent"])

    TimeManager.set_date(2000, 1, 1)
    var later_rent: int = int(EmployeeManager.monthly_expenses()["rent"])

    check_greater(int(later_rent), int(early_rent),
        "the same office costs more to run in 2000 than in 1985 (%d vs %d)" % [
            later_rent, early_rent])
