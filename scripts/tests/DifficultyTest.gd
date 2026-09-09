extends TestCase

## PA.14 -- difficulty is a small, clearly bounded set of economic and risk
## modifiers over one shared simulation, not three separate ones. Normal is the
## canonical balance target and stays neutral so BalanceProbe is unaffected.

const ECONOMIC_KEYS := [
    "starting_cash", "sales_multiplier", "expense_multiplier", "grace_weeks",
    "salary_multiplier", "project_risk_multiplier"
]

func run() -> void:
    _catalogue_is_the_three_expected_tiers()
    _normal_is_neutral()
    _tiers_are_ordered_sensibly()
    _modifiers_thread_into_the_simulation()
    _unknown_difficulty_falls_back_to_neutral()
    _difficulty_carries_no_content_rules()

func _catalogue_is_the_three_expected_tiers() -> void:
    section("difficulty catalogue")
    var ids: Array = DataManager.difficulties.map(func(d): return str(d.get("id", "")))
    check_equal(ids, ["relaxed", "normal", "hard"], "exactly relaxed / normal / hard")
    for tier in DataManager.difficulties:
        for key in ECONOMIC_KEYS:
            check(tier.has(key), "%s defines %s" % [tier.get("id", "?"), key])
        check_greater(float(tier["starting_cash"]), 0.0, "%s starts with cash" % tier["id"])
        check_greater(float(tier["sales_multiplier"]), 0.0, "%s sales multiplier positive" % tier["id"])
        check_greater(float(tier["expense_multiplier"]), 0.0, "%s expense multiplier positive" % tier["id"])
        check_greater(float(tier["grace_weeks"]), 0.0, "%s has a grace window" % tier["id"])
        check_between(float(tier["salary_multiplier"]), 0.5, 2.0, "%s salary multiplier sane" % tier["id"])
        check_between(float(tier["project_risk_multiplier"]), 0.5, 2.0, "%s risk multiplier sane" % tier["id"])

func _normal_is_neutral() -> void:
    section("Normal is the canonical target")
    var normal := DataManager.get_difficulty("normal")
    check_equal(int(normal["starting_cash"]), 10_000, "starting cash")
    check_approx(float(normal["sales_multiplier"]), 1.0, "sales multiplier")
    check_approx(float(normal["expense_multiplier"]), 1.0, "expense multiplier")
    check_equal(int(normal["grace_weeks"]), 6, "grace weeks")
    check_approx(float(normal["salary_multiplier"]), 1.0, "salary multiplier")
    check_approx(float(normal["project_risk_multiplier"]), 1.0, "project risk multiplier")

func _tiers_are_ordered_sensibly() -> void:
    section("relaxed is gentler than hard on every axis")
    var relaxed := DataManager.get_difficulty("relaxed")
    var normal := DataManager.get_difficulty("normal")
    var hard := DataManager.get_difficulty("hard")
    check_greater(float(relaxed["starting_cash"]), float(normal["starting_cash"]), "relaxed cash > normal")
    check_greater(float(normal["starting_cash"]), float(hard["starting_cash"]), "normal cash > hard")
    check_greater(float(relaxed["grace_weeks"]), float(hard["grace_weeks"]), "relaxed grace > hard grace")
    check_greater(float(relaxed["sales_multiplier"]), float(hard["sales_multiplier"]), "relaxed sales > hard sales")
    check_greater(float(hard["expense_multiplier"]), float(relaxed["expense_multiplier"]), "hard costs more to run")
    check_greater(float(hard["salary_multiplier"]), float(relaxed["salary_multiplier"]), "hard candidates cost more")
    check_greater(float(hard["project_risk_multiplier"]), float(relaxed["project_risk_multiplier"]),
        "hard projects are buggier")

func _modifiers_thread_into_the_simulation() -> void:
    section("the modifiers actually reach the systems that read them")
    var restore := GameState.difficulty_id

    GameState.difficulty_id = "hard"
    check_equal(GameState.grace_weeks(), 3, "grace_weeks() reads the tier")
    check_equal(FinanceManager.expense(1000), 1150, "expense() scales operating costs")
    check_approx(GameState.difficulty_salary_multiplier(), 1.12, "salary pressure helper")
    check_approx(GameState.difficulty_project_risk_multiplier(), 1.18, "project risk helper")
    check_approx(float(GameState.difficulty().get("sales_multiplier", -1.0)), 0.9,
        "SalesManager reads sales_multiplier off the same dict")

    GameState.difficulty_id = "relaxed"
    check_equal(FinanceManager.expense(1000), 800, "relaxed lowers operating costs")

    GameState.start_company("Probe Co", "Sam", "relaxed")
    check_equal(GameState.cash, 25_000, "start_company seeds the tier's starting cash")

    GameState.start_company("Probe Co", "Sam", "hard")
    check_equal(GameState.cash, 7_500, "a harder run starts with less")

    GameState.difficulty_id = restore

func _unknown_difficulty_falls_back_to_neutral() -> void:
    section("an unrecognised id degrades to Normal-equivalent numbers")
    var restore := GameState.difficulty_id
    GameState.difficulty_id = "does_not_exist"
    var fallback := GameState.difficulty()
    for key in ECONOMIC_KEYS:
        check(fallback.has(key), "fallback still defines %s" % key)
    check_equal(GameState.grace_weeks(), 6, "fallback grace matches Normal")
    check_approx(GameState.difficulty_salary_multiplier(), 1.0, "fallback salary is neutral")
    check_approx(GameState.difficulty_project_risk_multiplier(), 1.0, "fallback risk is neutral")
    GameState.difficulty_id = restore

func _difficulty_carries_no_content_rules() -> void:
    section("difficulty never changes what content is compatible or available")
    # The tier dicts are purely economic/risk scalars. Nothing here names a
    # genre, theme, platform, unlock, feature or compatibility rule, so no
    # difficulty can gate content differently from another.
    for tier in DataManager.difficulties:
        for key in tier.keys():
            check_in(str(key), ["id", "name"] + ECONOMIC_KEYS,
                "%s only carries economic/risk keys (%s)" % [tier.get("id", "?"), key])
