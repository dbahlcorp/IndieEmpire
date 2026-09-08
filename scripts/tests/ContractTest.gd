extends TestCase

## Contract work: the paid jobs a studio falls back on between games.

func run() -> void:
    _offers()
    _taking_one()
    _doing_the_work()
    _missing_a_deadline()
    _abandoning()
    _competes_with_development()
    _persistence()
    _rescues_a_failing_studio()

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()

func _offers() -> void:
    section("the contract board")
    _company()
    ContractManager.refresh_offers(false)

    var offers := ContractManager.offers()
    check_not_empty(offers, "a brand new studio is offered work")
    check(offers.size() <= ContractManager.OFFER_COUNT,
        "no more than %d at a time (%d)" % [ContractManager.OFFER_COUNT, offers.size()])

    for contract in offers:
        check_greater(float(contract.payout), 0.0, "%s pays something" % contract.name)
        check_greater(float(contract.work), 0.0, "%s has work to do" % contract.name)
        check_greater(float(contract.deadline_weeks), 0.0, "%s has a deadline" % contract.name)
        var template := DataManager.get_contract_template(contract.template_id)
        check(ContractSimulator.is_available(template, 0.0, 0),
            "%s is one a new studio qualifies for" % contract.name)

    # The big jobs must stay out of reach until the studio has a name.
    var big := DataManager.get_contract_template("publisher_subcontract")
    check(not ContractSimulator.is_available(big, 0.0, 0), "a nobody cannot take the big jobs")
    check(ContractSimulator.is_available(big, 60.0, 15), "an established studio can")

    # And they pay better once you are known.
    var small := DataManager.get_contract_template("cover_disk")
    check_greater(
        float(ContractSimulator.payout_for(small, 80.0)),
        float(ContractSimulator.payout_for(small, 0.0)),
        "a known studio commands a better rate")

func _taking_one() -> void:
    section("taking a contract")
    _company()
    ContractManager.refresh_offers(false)
    var contract: Contract = ContractManager.offers()[0]

    check(ContractManager.can_accept(), "a free team can take work")
    check(ContractManager.accept(contract), "the contract is accepted")
    check(ContractManager.has_active_contract(), "it becomes the active contract")
    check_equal(contract.status, "active", "and is marked active")
    check_equal(contract.team_id, "team_a", "worked by a team")
    check(not GameState.contract_offers.has(contract), "and leaves the board")
    check(not ContractManager.can_accept(), "a second contract cannot be taken at once")

func _doing_the_work() -> void:
    section("doing the work and getting paid")
    _company()
    ContractManager.refresh_offers(false)
    var contract: Contract = ContractManager.offers()[0]
    ContractManager.accept(contract)

    var cash_before := GameState.cash
    var reputation_before := GameState.consumer_reputation
    check_greater(ContractManager.weekly_output(), 0.0, "the team produces work each week")

    var weeks := 0
    while ContractManager.has_active_contract() and weeks < 60:
        TimeManager.advance_week()
        weeks += 1

    check_equal(contract.status, "completed", "the contract was delivered (%d weeks)" % weeks)
    check(weeks <= contract.deadline_weeks, "and delivered on time")
    check_greater(float(GameState.cash), float(cash_before),
        "the studio is better off (%s -> %s)" % [
            Format.money_exact(cash_before), Format.money_exact(GameState.cash)])
    check_greater(float(GameState.cash), float(cash_before + contract.payout * 0.9),
        "the fee was paid, less running costs (fee %s)" % Format.money_exact(contract.payout))
    check_greater(GameState.consumer_reputation, reputation_before, "and it built some standing")
    check_equal(ContractManager.completed_count(), 1, "it is recorded as delivered")
    check_equal(ContractManager.total_contract_income(), contract.payout, "contract income is tracked")

    var kinds := {}
    for entry in GameState.ledger:
        kinds[int(entry.get("kind", -1))] = true
    check(kinds.has(Ledger.Kind.CONTRACT), "and it appears in the books")

    # Contract work builds no catalogue and no fans: that is the trade.
    check(GameState.released_games.is_empty(), "no game was added to the catalogue")
    check_equal(GameState.fans, 0, "and no fans were won")

func _missing_a_deadline() -> void:
    section("missing a deadline")
    _company()
    ContractManager.refresh_offers(false)
    var contract: Contract = ContractManager.offers()[0]
    ContractManager.accept(contract)

    # A job far beyond what this team could ever deliver in time.
    contract.work = 100_000
    GameState.consumer_reputation = 30.0   # there has to be standing available to lose
    var reputation_before := GameState.consumer_reputation
    var cash_before := GameState.cash

    var weeks := 0
    while ContractManager.has_active_contract() and weeks < contract.deadline_weeks + 5:
        TimeManager.advance_week()
        weeks += 1

    check_equal(contract.status, "failed", "an impossible contract fails")
    check_less(float(GameState.cash), float(cash_before + 1),
        "no fee was paid (%s)" % Format.money_exact(GameState.cash))
    check_less(GameState.consumer_reputation, reputation_before, "and standing was lost")
    check_equal(ContractManager.failed_count(), 1, "the failure is recorded")

func _abandoning() -> void:
    section("walking away")
    _company()
    ContractManager.refresh_offers(false)
    var contract: Contract = ContractManager.offers()[0]
    ContractManager.accept(contract)

    GameState.consumer_reputation = 40.0
    ContractManager.abandon()
    check(not ContractManager.has_active_contract(), "the contract is dropped")
    check_equal(contract.status, "failed", "and marked failed")
    check_less(GameState.consumer_reputation, 40.0, "walking away costs standing")
    check_greater(ContractSimulator.abandon_penalty(contract),
        ContractSimulator.late_penalty(contract),
        "and costs more than merely being late")
    check(ContractManager.can_accept(), "the team is free again")

func _competes_with_development() -> void:
    section("contracts and games compete for the team")
    _company()
    ContractManager.refresh_offers(false)
    ContractManager.accept(ContractManager.offers()[0])

    var project := DevelopmentSimulator.start_project(
        "Blocked", "fantasy", "adventure", "microstar_64", "small")
    check_null(project, "a contracted team cannot start a game")

    ContractManager.abandon()
    var freed := DevelopmentSimulator.start_project(
        "Allowed", "fantasy", "adventure", "microstar_64", "small")
    check_not_null(freed, "once free, it can")
    check(not ContractManager.can_accept(), "and now cannot take contract work")

func _persistence() -> void:
    section("contracts survive a save")
    _company()
    ContractManager.refresh_offers(false)
    var contract: Contract = ContractManager.offers()[0]
    ContractManager.accept(contract)
    TimeManager.advance_week()
    TimeManager.advance_week()

    var name := contract.name
    var done := contract.work_done
    var offers := GameState.contract_offers.size()

    check(SaveManager.save_game("save_contract"), "saved")
    GameState.reset_company()
    check(SaveManager.load_game("save_contract"), "loaded")

    var restored := ContractManager.active_contract()
    if check_not_null(restored, "the active contract came back"):
        check_equal(restored.name, name, "with its name")
        check_approx(restored.work_done, done, "and its progress")
        check_equal(restored.status, "active", "still active")
    check_equal(GameState.contract_offers.size(), offers, "the board came back too")

    # And it keeps working after the reload.
    var before := ContractManager.active_contract().work_done
    TimeManager.advance_week()
    if ContractManager.has_active_contract():
        check_greater(ContractManager.active_contract().work_done, before,
            "work continues after a reload")
    SaveManager.delete_save("save_contract")

func _rescues_a_failing_studio() -> void:
    section("a lifeline for a broke studio")
    _company()
    GameState.cash = 900   # not enough to start any game

    var cheapest := DevelopmentSimulator.get_minimum_project_cost()
    check_less(float(GameState.cash), float(cheapest),
        "cannot afford a project (%s of %s)" % [
            Format.money_exact(GameState.cash), Format.money_exact(cheapest)])

    ContractManager.refresh_offers(false)
    check(ContractManager.can_accept(), "but contract work is still open to it")
    var contract: Contract = ContractManager.offers()[0]
    ContractManager.accept(contract)

    var weeks := 0
    while ContractManager.has_active_contract() and weeks < 60 and not GameState.bankrupt:
        TimeManager.advance_week()
        weeks += 1

    check(not GameState.bankrupt, "the studio stayed alive")
    check_equal(contract.status, "completed", "the job was delivered")
    check_greater(float(GameState.cash), float(cheapest),
        "and it can afford to make a game again (%s)" % Format.money_exact(GameState.cash))
