extends TestCase

## Who sells the game, and what they take for it.

func run() -> void:
    _the_offers()
    _self_publishing()
    _signing()
    _the_advance()
    _the_split()
    _reach_is_what_you_pay_for()
    _better_terms_with_standing()
    _persistence()

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(500_000, Ledger.Kind.OTHER, "seed")

func _build(size: String = "small") -> GameProject:
    var project := DevelopmentSimulator.start_project(
        "Deal", "fantasy", "adventure", "microstar_64", size)
    var guard := 0
    while project.development_progress < 100.0 and guard < 200:
        guard += 1
        TimeManager.advance_week()
    ReviewSimulator.calculate_review(project)
    return project

func _summed(project: GameProject) -> int:
    var total := 0
    for amount in project.weekly_revenue:
        total += amount
    return total

func _the_offers() -> void:
    section("who will take it")
    _company()
    var project := _build()

    var offers := PublishingManager.offers_for(project)
    check_not_empty(offers, "a new studio has somewhere to go")

    var ids: Array[String] = []
    for offer in offers:
        ids.append(str(offer["id"]))
    check(ids.has("self"), "self-publishing is always an option")
    check(ids.has("thrift"), "and a budget label will take anything")
    check(not ids.has("atlas"), "but the biggest label will not talk to a nobody")

    GameState.consumer_reputation = 70.0
    for i in 15:
        GameState.released_games.append(GameProject.new())
    var later := PublishingManager.offers_for(project)
    var later_ids: Array[String] = []
    for offer in later:
        later_ids.append(str(offer["id"]))
    check(later_ids.has("atlas"), "a known studio gets the big offers")
    check_greater(float(later.size()), float(offers.size()), "and more of them")

func _self_publishing() -> void:
    section("self-publishing")
    _company()
    var project := _build()
    check(PublishingManager.self_publish(project), "the studio can publish itself")

    check_equal(project.developer_share, 1.0, "and keeps everything")
    check_equal(project.advance, 0, "with no advance")
    check_less(project.publisher_reach, 1.0,
        "but reaches far less of the market (%.2fx)" % project.publisher_reach)
    check(project.is_self_published(), "and is marked self-published")

    SalesManager.release(project)
    var guard := 0
    while project.sales_active and guard < 200:
        guard += 1
        TimeManager.advance_week()
    check_equal(project.publisher_revenue, 0, "nobody took a cut")
    check_equal(project.lifetime_revenue, _summed(project), "every penny reached the studio")

func _signing() -> void:
    section("signing a deal")
    _company()
    var project := _build()

    check(PublishingManager.sign_deal(project, "thrift"), "a deal can be signed")
    check_less(project.developer_share, 1.0,
        "the studio keeps only part of it (%s)" %
        PublishingSimulator.share_label(project.developer_share))
    var alone := PublishingSimulator.reach(DataManager.get_publisher("self"))
    check_greater(project.publisher_reach, alone,
        "in exchange for reach (%.2fx against %.2fx alone)" % [project.publisher_reach, alone])
    check_equal(PublishingManager.publisher_name(project), "Thrift Interactive", "named on the game")
    check(not project.is_self_published(), "and is not self-published")

    _company()
    var second := _build()
    check(not PublishingManager.sign_deal(second, "atlas"),
        "an unknown studio cannot sign the biggest label")

func _the_advance() -> void:
    section("the advance")
    _company()
    var project := _build()
    var cash_before := GameState.cash

    PublishingManager.sign_deal(project, "thrift")
    check_greater(float(project.advance), 0.0,
        "an advance is paid on signing (%s)" % Format.money_exact(project.advance))
    check_equal(GameState.cash, cash_before + project.advance, "and reaches the bank immediately")
    check_equal(project.advance_remaining, project.advance, "with all of it still to recoup")

    var kinds := {}
    for entry in GameState.ledger:
        kinds[int(entry.get("kind", -1))] = true
    check(kinds.has(Ledger.Kind.ADVANCE), "and it appears in the books")

    SalesManager.release(project)
    var guard := 0
    while project.advance_remaining > 0 and project.sales_active and guard < 200:
        guard += 1
        TimeManager.advance_week()
    check_less(float(project.advance_remaining), float(project.advance),
        "sales pay the advance back first")

func _the_split() -> void:
    section("the split")
    _company()
    var project := _build()
    PublishingManager.sign_deal(project, "thrift")
    project.advance_remaining = 0

    var settled := PublishingManager.settle_week(project, 1000)
    check_equal(int(settled["studio"]) + int(settled["publisher"]), 1000,
        "every penny is accounted for")
    check_greater(float(settled["publisher"]), float(settled["studio"]),
        "the publisher takes the larger share (%d vs %d)" % [
            int(settled["publisher"]), int(settled["studio"])])

    SalesManager.release(project)
    var guard := 0
    while project.sales_active and guard < 200:
        guard += 1
        TimeManager.advance_week()

    check_greater(float(project.publisher_revenue), 0.0, "the publisher was paid")
    check_greater(float(PublishingManager.lifetime_publisher_cut()), 0.0,
        "and the studio can see what it gave away (%s)" %
        Format.money_exact(PublishingManager.lifetime_publisher_cut()))
    check_equal(project.lifetime_revenue, _summed(project), "the weekly figures reconcile")

func _units_under(publisher_id: String) -> int:
    var total := 0
    for run in 4:
        _company()
        var project := _build()
        project.review_score = 8.0
        PublishingManager.sign_deal(project, publisher_id)
        SalesManager.release(project)
        var guard := 0
        while project.sales_active and guard < 200:
            guard += 1
            TimeManager.advance_week()
        total += project.lifetime_sales
    return total / 4

func _reach_is_what_you_pay_for() -> void:
    section("reach is what the cut buys")
    var self_units := _units_under("self")
    var signed_units := _units_under("thrift")
    check_greater(float(signed_units), float(self_units),
        "a publisher sells far more copies (%s vs %s)" % [
            Format.exact(signed_units), Format.exact(self_units)])

func _better_terms_with_standing() -> void:
    section("standing improves the terms")
    var publisher := DataManager.get_publisher("thrift")
    var unknown := PublishingSimulator.developer_share(publisher, 0.0)
    var famous := PublishingSimulator.developer_share(publisher, 90.0)
    check_greater(famous, unknown,
        "a known studio negotiates a better split (%s vs %s)" % [
            PublishingSimulator.share_label(famous),
            PublishingSimulator.share_label(unknown)])
    check_less(famous, 0.61, "but never a good one")

func _persistence() -> void:
    section("the deal survives a save")
    _company()
    var project := _build()
    PublishingManager.sign_deal(project, "thrift")
    SalesManager.release(project)
    TimeManager.advance_week()

    var share := project.developer_share
    var cut := project.publisher_revenue
    var id := project.id

    check(SaveManager.save_game("save_publishing"), "saved")
    GameState.reset_company()
    check(SaveManager.load_game("save_publishing"), "loaded")

    var restored := GameState.find_game(id)
    if check_not_null(restored, "the game came back"):
        check_equal(restored.publisher_id, "thrift", "with its publisher")
        check_approx(restored.developer_share, share, "and its split")
        check_equal(restored.publisher_revenue, cut, "and what the publisher took")
    SaveManager.delete_save("save_publishing")
