extends TestCase

## Expanding is a bet, not a purchase.
##
## The office ladder above Large Studio Floor exists to give a late-game studio
## somewhere for its money to go. That only works if signing for a floor you
## cannot carry actually hurts -- the move-in cost is the small half of the
## decision, and the rent afterwards is the half that closes studios.
##
## `can_move_to()` deliberately only checks the move-in cost, so the game will
## let a player make this mistake. These checks pin that: the same studio, the
## same office, is fatal at the wrong time and fine at the right one.

func run() -> void:
    _the_ladder_keeps_climbing()
    _rent_per_desk_gets_steeper()
    _prices_drift_with_the_era()
    _the_game_lets_you_overreach()
    _overreaching_drains_a_studio()
    _the_same_move_is_affordable_once_earned()

func _studio(cash: int, office_id: String = "large_studio_floor") -> void:
    GameState.start_company("Overreach", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(cash, Ledger.Kind.OTHER, "seed capital")
    for step in ["shared_workspace", "small_office", "professional_studio",
            "large_studio_floor", "studio_building", "campus"]:
        OfficeManager.move_to(step)
        if step == office_id:
            return

func _the_ladder_keeps_climbing() -> void:
    section("the ladder runs past the twelve-person floor")
    var by_tier := {}
    for office in DataManager.offices:
        by_tier[int(office.get("tier", -1))] = office
    check(by_tier.has(5) and by_tier.has(6), "there are two floors above Large Studio Floor")

    var previous := -1
    for tier in range(0, 7):
        if not by_tier.has(tier):
            continue
        var capacity := int(by_tier[tier].get("capacity", 0))
        check_greater(float(capacity), float(previous), "tier %d seats more than the one below (%d)" % [
            tier, capacity])
        previous = capacity

    # The top floor exists to make the second team reachable, so it has to seat
    # what the biggest project can actually use.
    check_equal(int(by_tier[6].get("capacity", 0)),
        int(DataManager.get_size("aaa").get("max_useful_staff", 0)),
        "the top floor seats exactly what the biggest project can use")
    check_equal(int(by_tier[6].get("capacity", 0)),
        int(DataManager.get_size("large").get("max_useful_staff", 0)) * TeamManager.MAX_TEAMS,
        "which is also two full Medium teams")

func _rent_per_desk_gets_steeper() -> void:
    ## Scaling up has to cost more per person than staying small, or the top of
    ## the ladder is a free upgrade rather than a commitment.
    section("space gets dearer per desk, not cheaper")
    var previous := 0.0
    for office_id in ["small_office", "professional_studio", "large_studio_floor",
            "studio_building", "campus"]:
        var office := DataManager.get_office(office_id)
        var per_desk := float(office.get("rent", 0)) / maxf(float(office.get("capacity", 1)), 1.0)
        check_greater(per_desk, previous,
            "%s costs more per desk than the floor below ($%.0f)" % [office_id, per_desk])
        previous = per_desk

func _prices_drift_with_the_era() -> void:
    section("offices are priced in the money of the day")
    _studio(50_000_000, "large_studio_floor")
    var campus := DataManager.get_office("campus")

    TimeManager.current_year = 1985
    var early_move := OfficeManager.move_in_cost(campus)
    var early_rent := OfficeManager.monthly_rent(campus)
    TimeManager.current_year = 2050
    var late_move := OfficeManager.move_in_cost(campus)
    var late_rent := OfficeManager.monthly_rent(campus)

    check_greater(float(late_move), float(early_move) * 2.0,
        "a 2050 campus costs far more to move into (%s against %s)" % [
            Format.money_exact(late_move), Format.money_exact(early_move)])
    check_greater(float(late_rent), float(early_rent) * 2.0,
        "and far more to rent (%s against %s)" % [
            Format.money_exact(late_rent), Format.money_exact(early_rent)])
    TimeManager.current_year = 1990

func _the_game_lets_you_overreach() -> void:
    ## Not a bug. The move-in cost is affordable long before the rent is, and
    ## the player is allowed to find that out.
    section("the game permits a move it cannot carry")
    _studio(1_200_000, "large_studio_floor")
    var campus := DataManager.get_office("studio_building")
    check(GameState.cash > OfficeManager.move_in_cost(campus),
        "the studio can afford the move-in")
    var yearly := OfficeManager.monthly_rent(campus) * 12
    check_less(float(GameState.cash - OfficeManager.move_in_cost(campus)), float(yearly),
        "but not a year of the rent that follows")
    check(OfficeManager.can_move_to("studio_building"),
        "and the game still allows the move")

func _overreaching_drains_a_studio() -> void:
    section("signing for a floor you cannot carry")
    _studio(1_200_000, "large_studio_floor")
    check(OfficeManager.move_to("studio_building"), "the studio moves up too early")
    var started := GameState.cash

    for i in 52:
        TimeManager.advance_week()
    check_less(float(GameState.cash), float(started),
        "a year later it is poorer, with no games to show for it (%s from %s)" % [
            Format.money_exact(GameState.cash), Format.money_exact(started)])
    check_less(float(GameState.cash), 0.0,
        "in fact it has run out of money entirely (%s)" % Format.money_exact(GameState.cash))

func _the_same_move_is_affordable_once_earned() -> void:
    section("the same move, made once the studio can carry it")
    _studio(30_000_000, "large_studio_floor")
    check(OfficeManager.move_to("studio_building"), "the studio moves up")
    for i in 52:
        TimeManager.advance_week()
    check_greater(float(GameState.cash), 0.0,
        "a year on it is still solvent (%s)" % Format.money_exact(GameState.cash))
    check(not GameState.bankrupt, "and still trading")
