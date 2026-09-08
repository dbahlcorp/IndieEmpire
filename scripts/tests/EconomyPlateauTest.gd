extends "res://scripts/tests/balance/BalanceProbe.gd"

## Does the economy stop compounding?
##
## SLOW -- this plays a full 1985-2050 career, about 100 seconds. It earns that
## because it is the only check that can answer the question at all: whether
## income and costs eventually meet is a property of the whole simulation, and
## no unit test on a constant can see it.
##
## It exists because the question has been got wrong twice, in the same way both
## times. A 65-year career ends on about $1.2 billion, and both the September 7
## balance pass and the QUALITY_ANCHOR investigation read that number and called
## it a late-game runaway. It is not one. Costs inflate 5.3x by 2050, so a
## balance that stopped growing thirty years earlier still prints an
## ever-larger figure. In 1985 dollars the same career is flat from about 2020,
## and in runway -- cash over monthly overhead, which needs no deflating at all
## -- it plateaus around fifty years and stays there.
##
## So this asserts the inflation-neutral thing, and asserts it in both
## directions: the late game must neither compound nor collapse into a
## treadmill. See docs/LATE_GAME_ECONOMY_2026-09-08.md.

## A fixed seed, so a failure is a real change rather than an unlucky career.
const CAREER_SEED := 1
const CAREER_END := 2050

## Real growth the late game is allowed, per year, in either direction. The
## measured figure is +0.4%/yr; a genuine runaway compounds several times
## faster than this and a treadmill goes visibly negative.
const MAX_REAL_GROWTH := 0.015
## How much bigger the real balance may get across the whole back half. A
## runaway is a multiple, not a few percent -- measured is 1.09x.
const MAX_REAL_RATIO := 1.50
## And how much smaller, so over-correcting is caught too.
const MIN_REAL_RATIO := 0.60

var _years: Array[Dictionary] = []

func run() -> void:
    seed_value = CAREER_SEED
    until_year = CAREER_END
    max_weeks = (until_year - 1984) * 53
    seed(seed_value)
    _play()
    _parse_years()
    if not _the_career_actually_got_somewhere():
        return
    _the_late_game_does_not_compound()
    _the_late_game_is_not_a_treadmill_either()
    _nominal_cash_alone_would_have_said_otherwise()

func _parse_years() -> void:
    ## BalanceProbe records a row per year as CSV. Read them back rather than
    ## duplicating its manager loop here -- the point is to measure the same
    ## career the balance probe measures, not a second one that drifts from it.
    for line in years_csv:
        var f := line.split(",")
        if f.size() < 8 or not str(f[1]).is_valid_int():
            continue
        var year := int(f[1])
        _years.append({
            "year": year,
            "cash": float(f[2]),
            "staff": int(f[3]),
            "overhead": float(f[4]) + float(f[7]),
            "released": int(f[8]),
            "real": float(f[2]) / maxf(InflationSimulator.multiplier_for_year(year), 0.01)
        })

func _at(year: int) -> Dictionary:
    var best := {}
    for row in _years:
        if int(row["year"]) <= year and (best.is_empty() or int(row["year"]) > int(best["year"])):
            best = row
    return best

func _the_career_actually_got_somewhere() -> bool:
    section("the career this measures is a successful one")
    # Every assertion below is about growth stopping. They would all pass on a
    # studio that went bankrupt in 1986 and sat at zero for sixty years, so
    # establish first that there is a real economy to measure.
    if not check(not _years.is_empty(), "the career produced yearly records"):
        return false
    var last: Dictionary = _years[_years.size() - 1]
    check_greater(float(last["year"]), float(CAREER_END - 2),
        "it ran to %d" % int(last["year"]))
    check(not GameState.bankrupt, "and did not go bankrupt")
    check_greater(float(last["staff"]), 15.0,
        "ending at %d staff" % int(last["staff"]))
    check_greater(float(last["released"]), 100.0,
        "having shipped %d games" % int(last["released"]))
    check_greater(float(last["real"]), 50_000_000.0,
        "and genuinely rich in 1985 dollars (%.0fM)" % (float(last["real"]) / 1e6))
    return true

func _halfway() -> int:
    return int((1985 + CAREER_END) / 2)

func _the_late_game_does_not_compound() -> void:
    section("the back half of a career does not compound")
    var mid := _at(_halfway())
    var end := _at(CAREER_END + 1)
    if mid.is_empty() or end.is_empty():
        check(false, "the career covers both halves")
        return
    var span := maxi(int(end["year"]) - int(mid["year"]), 1)
    var ratio := float(end["real"]) / maxf(float(mid["real"]), 1.0)
    var growth := pow(ratio, 1.0 / float(span)) - 1.0
    check_less(growth, MAX_REAL_GROWTH,
        "real cash grows %+.2f%%/yr from %d to %d, in 1985 dollars"
            % [growth * 100.0, int(mid["year"]), int(end["year"])])
    check_less(ratio, MAX_REAL_RATIO,
        "and only %.2fx across the whole back half (%.0fM to %.0fM)"
            % [ratio, float(mid["real"]) / 1e6, float(end["real"]) / 1e6])

    # Runway needs no deflating at all: it is cash measured in months of the
    # studio's own costs, so inflation cancels out of it entirely. If this is
    # flat the economy has met itself, whatever the nominal column says.
    var mid_runway := float(mid["cash"]) / maxf(float(mid["overhead"]), 1.0)
    var end_runway := float(end["cash"]) / maxf(float(end["overhead"]), 1.0)
    check_less(end_runway / maxf(mid_runway, 1.0), MAX_REAL_RATIO,
        "runway holds at %.0f to %.0f years rather than growing"
            % [mid_runway / 12.0, end_runway / 12.0])

func _the_late_game_is_not_a_treadmill_either() -> void:
    section("but it does not collapse either")
    # The September 7 pass turned this down deliberately, noting that driving
    # steady-state profit to zero makes the late game a treadmill with no
    # reward. Flat is the target; shrinking is a different failure.
    var mid := _at(_halfway())
    var end := _at(CAREER_END + 1)
    if mid.is_empty() or end.is_empty():
        return
    check_greater(float(end["real"]) / maxf(float(mid["real"]), 1.0), MIN_REAL_RATIO,
        "a maxed studio still at least holds its real position")
    check_greater(float(end["real"]), float(_at(2000).get("real", 0.0)),
        "and is better off than it was at the halfway point of its growth")

func _nominal_cash_alone_would_have_said_otherwise() -> void:
    section("which the nominal figure alone would have hidden")
    # Pinning the trap itself. If this check ever fails it means inflation no
    # longer outruns nominal cash growth, and the shortcut of reading the
    # nominal column would happen to be safe -- at which point this test's
    # framing needs revisiting rather than quietly passing.
    var mid := _at(_halfway())
    var end := _at(CAREER_END + 1)
    if mid.is_empty() or end.is_empty():
        return
    var nominal_ratio := float(end["cash"]) / maxf(float(mid["cash"]), 1.0)
    var real_ratio := float(end["real"]) / maxf(float(mid["real"]), 1.0)
    check_greater(nominal_ratio, real_ratio * 1.3,
        "nominal cash grows %.2fx while the real balance grows %.2fx -- reading "
        % [nominal_ratio, real_ratio]
        + "the nominal column is what made this look like a runaway twice")
