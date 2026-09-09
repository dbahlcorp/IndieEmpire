extends TestCase

## PA.10 economic guard: a sequel must not trivially dominate a new IP.
##
## Plays one studio that ships a five-entry Tiny-scope franchise about once a
## year, with a standalone control game of identical scope and execution
## alongside it. Every release's quality is pinned to the same values, the
## genre trend is held flat, and the review roll is seeded identically, so the
## only thing separating the entries is their franchise standing -- fan
## interest, fatigue, and the raised review bar.
##
## The measurement is each release's launch demand (project.current_demand),
## which SalesSimulator computes with no randomness at all.
##
## The claim, the same shape as EconomyPlateauTest's for the whole career: the
## franchise gives a genuine early lift, but it does NOT compound. By the later
## entries fatigue has caught up and the milked series is a worse bet than an
## unrelated new game -- the "not an automatic money printer" property the
## PA.10 brief calls for.

const SEED := 4
const ENTRIES := 5
## Idle weeks between one entry shipping and the next being greenlit -- a studio
## milking the series roughly once a year.
const CADENCE_WEEKS := 6
const SALES_WEEKS := 20
## Core quality every release is pinned to -- comfortably over Tiny's bar (28)
## but under the over-delivery clamp, so the raised sequel bar has room to bite.
const FIXED_QUALITY := 33.0
## Innovation pinned near its own bar (work * 0.4 for Tiny ~ 36) so a milked
## sequel earns no fatigue relief it would not really have earned.
const FIXED_INNOVATION := 30.0
const REVIEW_SEED := 4242

var _control_demand := 0.0
var _demand: Array[float] = []
var _revenue: Array[int] = []
var _reviews: Array[float] = []
var _fatigue_at_release: Array[float] = []

func run() -> void:
    seed(SEED)
    _company()

    EventBus.franchise_updated.connect(func(fr: Franchise, _p: GameProject):
        _fatigue_at_release.append(fr.fatigue))

    var control := _run_release("Control Game", "")
    _control_demand = control.current_demand
    var control_revenue := control.lifetime_revenue

    var series_id := ""
    for i in ENTRIES:
        var entry := _run_release("Chronicle %d" % (i + 1), series_id)
        _demand.append(entry.current_demand)
        _revenue.append(entry.lifetime_revenue)
        if series_id.is_empty():
            series_id = entry.series_id
        _advance(CADENCE_WEEKS)

    _dump_series(control_revenue)
    _the_franchise_helps_early()
    _but_it_does_not_compound()
    _fatigue_is_the_mechanism()

# --- scripted studio ------------------------------------------------

func _company() -> void:
    GameState.start_company("Probe", "Ari", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(20_000_000, Ledger.Kind.OTHER, "seed")
    for role in ["programmer", "designer", "artist", "writer"]:
        var candidate := EmployeeManager.generate_candidate(role, "senior")
        GameState.labor_candidates.append(candidate)
        LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)
    _pin_trend()

func _pin_trend() -> void:
    GameState.genre_trends["adventure"] = 1.0
    GameState.weeks_until_trend_shift = 999_999
    # Hold saturation flat too: the studio's own back-catalogue pressure would
    # otherwise pollute the "identical execution" comparison, since the later
    # entries accrue more of it than the control did.
    GameState.genre_saturation.clear()

func _run_release(title: String, series_id: String) -> GameProject:
    var project := DevelopmentSimulator.start_project(
        title, "fantasy", "adventure", "microstar_64", "small", "team_a", {}, "", [], {}, series_id)
    var guard := 0
    while project.development_progress < 100.0 and guard < 400:
        guard += 1
        TimeManager.advance_week()
        _pin_trend()
    for field in ["gameplay", "technology", "graphics", "story", "sound",
            "polish", "performance", "narrative_quality", "balance"]:
        project.set(field, FIXED_QUALITY)
    project.innovation = FIXED_INNOVATION
    project.bugs = 3
    project.known_bugs = 3
    seed(REVIEW_SEED)
    _reviews.append(ReviewSimulator.calculate_review(project))
    project.critic_reviews = ReviewSimulator.critic_scores(project)
    SalesManager.release(project)
    guard = 0
    while project.sales_active and guard < SALES_WEEKS:
        guard += 1
        TimeManager.advance_week()
        _pin_trend()
    return project

func _advance(weeks: int) -> void:
    for i in weeks:
        TimeManager.advance_week()
        _pin_trend()

# --- assertions ---------------------------------------------------

func _dump_series(control_revenue: int) -> void:
    section("what the series did")
    print("  control:  review %.1f | demand %.1f | revenue $%s" % [
        _reviews[0], _control_demand, Format.exact(control_revenue)])
    for i in _demand.size():
        print("  entry %d:  review %.1f | launch demand %.1f (%+.0f%% vs control) | revenue $%s | fatigue %.0f" % [
            i + 1, _reviews[i + 1], _demand[i],
            (_demand[i] / maxf(_control_demand, 0.01) - 1.0) * 100.0,
            Format.exact(_revenue[i]), _fatigue_at_release[i + 1]])
    check(true, "series played to %d entries" % _demand.size())

func _the_franchise_helps_early() -> void:
    section("a young franchise is a real advantage")
    check_greater(_demand[1], _demand[0] * 1.06,
        "entry 2 rides the original's goodwill and opens bigger than entry 1 did (%.1f vs %.1f)" % [
            _demand[1], _demand[0]])
    check_greater(_demand[1], _control_demand,
        "and opens bigger than an unrelated new IP of identical scope and execution")
    check_greater(float(_revenue[1]), 0.0, "and it sold")

func _but_it_does_not_compound() -> void:
    section("but the advantage does not compound release over release")
    check_less(_demand[ENTRIES - 1], _demand[1],
        "the fifth entry opens smaller than the second, not larger")
    check_less(_demand[ENTRIES - 1], _control_demand * 1.10,
        "and by the fifth entry the franchise is no better than a fresh IP")
    check_less(float(_revenue[ENTRIES - 1]), float(_revenue[0]) * 1.5,
        "lifetime revenue is not running away across the series")

func _fatigue_is_the_mechanism() -> void:
    section("fatigue is what holds it down")
    check_near(_fatigue_at_release[1], 0.0, 0.01,
        "the original adds no fatigue -- nothing to be tired of yet")
    check_greater(_fatigue_at_release[ENTRIES], 30.0,
        "by the fifth annual entry the series is badly fatigued (%.0f)" % _fatigue_at_release[ENTRIES])
    check_less(_reviews[ENTRIES], _reviews[1],
        "and the raised bar means later entries score lower for the same work (%.2f vs %.2f)" % [
            _reviews[ENTRIES], _reviews[1]])
