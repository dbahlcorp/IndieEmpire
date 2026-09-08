extends TestCase

## Two different ways a studio wears out its own welcome.
##
## `MarketSimulator` already models **genre** saturation: ship three shooters in
## a row and the third one lands in a market you flooded yourself. That was
## always there, and it works -- but a studio running two teams simply rotates
## genres, so it never bit the thing it was meant to. A measured 66-year career
## shipped 190 games with every one selling as though it were the only release
## the studio had ever made.
##
## `SalesSimulator.catalogue_crowding` is the second axis: a studio's own back
## catalogue is still on the shelf. Five of your games on sale at once compete
## for the same buyers no matter how carefully you spread them across genres.
##
## The third is not saturation of the market but of the studio's own standing:
## reputation and fans both used to pay out in a straight line, so success
## compounded without limit. They now bend.

func run() -> void:
    _genre_saturation_still_works()
    _saturation_fades()
    _a_clean_slate_is_never_penalised()
    _each_release_on_sale_takes_a_share()
    _crowding_has_a_floor()
    _crowding_actually_reaches_demand()
    _the_two_axes_are_independent()
    _reputation_pays_less_the_more_you_have()
    _fans_pay_less_the_more_you_have()
    _winning_new_fans_gets_harder()

# --- The genre axis, which already existed -----------------------------

func _genre_saturation_still_works() -> void:
    section("flooding one genre still wears it out")
    var clean := MarketSimulator.add_saturation(0.0, 1.0)
    var twice := MarketSimulator.add_saturation(clean, 1.0)
    check_greater(twice, clean, "a second release in a genre saturates it further")
    check_less(MarketSimulator.demand(1.0, twice), MarketSimulator.demand(1.0, clean),
        "and demand falls with it")
    check(MarketSimulator.add_saturation(0.9, 5.0) <= MarketSimulator.SATURATION_MAX,
        "saturation is capped, so a genre never dies outright")
    check_greater(MarketSimulator.demand(1.0, MarketSimulator.SATURATION_MAX),
        0.0, "even a flooded genre keeps a floor of demand")

func _saturation_fades() -> void:
    section("a flooded genre recovers if left alone")
    var level := MarketSimulator.SATURATION_MAX
    for week in 52:
        level = MarketSimulator.decay_saturation(level)
    check_less(level, MarketSimulator.SATURATION_MAX * 0.6,
        "a year away and most of the damage is gone (%.2f from %.2f)" % [
            level, MarketSimulator.SATURATION_MAX])
    check_greater(level, 0.0, "but it is not instant")

# --- The catalogue axis, which is new ----------------------------------

func _a_clean_slate_is_never_penalised() -> void:
    section("a small shelf costs nothing")
    check_approx(SalesSimulator.catalogue_crowding(0), 1.0,
        "a studio with an empty shelf is untouched")
    check_approx(SalesSimulator.catalogue_crowding(1), 1.0,
        "and so is one whose only release is the game itself")
    # A bedroom studio must be able to ship its first games without being
    # charged for competing with itself; crowding is the price of a real slate.
    check_approx(SalesSimulator.catalogue_crowding(SalesSimulator.CROWDING_FREE_SLOTS), 1.0,
        "and one still inside its free slots")
    check_less(SalesSimulator.catalogue_crowding(SalesSimulator.CROWDING_FREE_SLOTS + 1), 1.0,
        "the first release past them is where it starts")

func _each_release_on_sale_takes_a_share() -> void:
    section("every game of yours already on sale takes a share")
    # Only the region before the floor is strictly decreasing; the floor
    # itself is covered by _crowding_has_a_floor().
    var last_falling := SalesSimulator.CROWDING_FREE_SLOTS + int(ceil(
        (1.0 - SalesSimulator.MIN_CATALOGUE_FACTOR) / SalesSimulator.CATALOGUE_CROWDING))
    var previous := 1.01
    for concurrent in range(SalesSimulator.CROWDING_FREE_SLOTS + 1, last_falling + 1):
        var factor := SalesSimulator.catalogue_crowding(concurrent)
        check_less(factor, previous,
            "%d on sale is worse than %d (%.2f)" % [concurrent, concurrent - 1, factor])
        previous = factor
    check_less(SalesSimulator.catalogue_crowding(6), 0.75,
        "six at once is a real penalty, not a rounding error (%.2f)" % [
            SalesSimulator.catalogue_crowding(6)])

func _crowding_has_a_floor() -> void:
    ## A studio should never be able to crowd itself out of existence -- past a
    ## point, extra releases stop making the last one worse.
    section("crowding bottoms out")
    check_approx(SalesSimulator.catalogue_crowding(50), SalesSimulator.MIN_CATALOGUE_FACTOR,
        "a huge slate lands on the floor, not below it")
    check_greater(SalesSimulator.MIN_CATALOGUE_FACTOR, 0.0,
        "and the floor leaves a game something to earn")

func _crowding_actually_reaches_demand() -> void:
    ## The maths above is worth nothing if base_demand does not apply it. This
    ## builds the same game twice and changes only how crowded the shelf is.
    section("a crowded shelf really does cut launch demand")
    GameState.start_company("Prolific", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    GameState.fans = 0
    GameState.consumer_reputation = 0.0

    var platform := DataManager.get_platform("famiclone")
    var size := DataManager.get_size("medium")
    var project := GameProject.new()
    project.genre_id = "action"
    project.theme_id = "space"
    project.platform_id = "famiclone"
    project.size_id = "medium"
    project.review_score = 8.0
    project.publisher_reach = 1.0

    var alone := SalesSimulator.base_demand(
        project, platform, size, 5_000_000, 1.0, 0.0, 0, 1.0, 1)
    var crowded := SalesSimulator.base_demand(
        project, platform, size, 5_000_000, 1.0, 0.0, 0, 1.0, 6)

    check_greater(alone, 0.0, "the game has demand on an empty shelf (%.0f)" % alone)
    check_less(crowded, alone,
        "and less of it with five others already on sale (%.0f against %.0f)" % [crowded, alone])
    check_approx(crowded / alone, SalesSimulator.catalogue_crowding(6),
        "by exactly the crowding factor")

func _the_two_axes_are_independent() -> void:
    ## Rotating genres dodges genre saturation. It does not dodge the fact that
    ## the studio's other games are still on the shelf -- which is the whole
    ## reason the second axis exists.
    section("rotating genres does not dodge a crowded shelf")
    var fresh_genre := MarketSimulator.demand(1.0, 0.0)
    check_approx(fresh_genre, 1.0, "an untouched genre is at full demand")
    check_less(SalesSimulator.catalogue_crowding(6), 1.0,
        "but six of your own games on sale still costs you")

# --- Diminishing standing ----------------------------------------------

func _reputation_pays_less_the_more_you_have() -> void:
    section("reputation is worth less at the top than at the bottom")
    var unknown := SalesSimulator.reputation_reach(0.0)
    check_approx(unknown, 1.0, "an unknown studio gets no help from its name")

    var first_quarter := SalesSimulator.reputation_reach(25.0) - unknown
    var last_quarter := (SalesSimulator.reputation_reach(100.0)
        - SalesSimulator.reputation_reach(75.0))
    check_greater(first_quarter, last_quarter,
        "the first 25 points of standing buy more than the last (%.3f against %.3f)" % [
            first_quarter, last_quarter])
    check_greater(SalesSimulator.reputation_reach(100.0),
        SalesSimulator.reputation_reach(50.0),
        "but more standing is still always better")
    check_approx(SalesSimulator.reputation_reach(100.0),
        1.0 + SalesSimulator.REPUTATION_REACH, "and it tops out where it says it does")
    check_approx(SalesSimulator.reputation_reach(140.0),
        SalesSimulator.reputation_reach(100.0),
        "reputation past the cap adds nothing")

func _fans_pay_less_the_more_you_have() -> void:
    section("each new fan is worth less than the last")
    check_approx(SalesSimulator.fan_reach(0), 0.0, "no fans, no head start")

    var small := SalesSimulator.fan_reach(100_000)
    var large := SalesSimulator.fan_reach(1_000_000)
    check_greater(large, small, "a bigger following is still worth more")
    check_less(large, small * 10.0,
        "but ten times the fans is not ten times the head start (%.0f against %.0f)" % [
            large, small])
    # Per-fan value has to fall, which is the whole point.
    check_less(large / 1_000_000.0, small / 100_000.0,
        "so each individual fan is worth less at a million than at a hundred thousand")

func _winning_new_fans_gets_harder() -> void:
    section("an audience is finite")
    check_approx(SalesSimulator.fan_gain_multiplier(0), 1.0,
        "a studio with no following wins them at full rate")
    check_less(SalesSimulator.fan_gain_multiplier(1_000_000),
        SalesSimulator.fan_gain_multiplier(100_000),
        "a studio that already has a million wins them more slowly")
    check_greater(SalesSimulator.fan_gain_multiplier(5_000_000), 0.0,
        "but never stops entirely")

    var established := SalesSimulator.fans_from_week(100_000, 9.0, 2_000_000)
    var newcomer := SalesSimulator.fans_from_week(100_000, 9.0, 0)
    check_greater(newcomer, established,
        "the same hit wins more followers for a newcomer (%d against %d)" % [
            newcomer, established])
    # Losing followers is not made easier by having a lot of them.
    check_less(float(SalesSimulator.fans_from_week(100_000, 2.0, 2_000_000)), 0.0,
        "a bad game still sheds followers")
