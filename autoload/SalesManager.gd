extends Node

## Owns the life of a released game on the market: putting it on sale, selling a
## week, banking the money, and taking it off sale. The curve maths lives in
## SalesSimulator.

const SALES_MILESTONES := [10_000, 100_000, 500_000, 1_000_000, 5_000_000]

func release(project: GameProject) -> void:
    # No deal signed means the studio is selling it itself, with the limited
    # reach that implies. Nothing ships without publishing terms.
    if project.publisher_id.is_empty():
        PublishingManager.sign_deal(project, PublishingSimulator.SELF_ID)

    var platform := DataManager.get_platform(project.platform_id)
    var size := DataManager.get_size(project.size_id)

    project.released = true
    project.sales_active = true
    project.weeks_on_market = 0
    project.weekly_sales.clear()
    project.weekly_revenue.clear()
    project.lifetime_sales = 0
    project.lifetime_revenue = 0
    project.release_year = TimeManager.current_year
    project.release_month = TimeManager.current_month
    project.release_week = TimeManager.current_week
    project.retail_price = int(size.get("retail_price", 15))
    project.royalty = float(platform.get("royalty", 0.0))
    project.word_of_mouth = SalesSimulator.word_of_mouth(project, GameState.consumer_reputation)
    project.current_demand = SalesSimulator.base_demand(
        project, platform, size,
        PlatformManager.install_base(platform),
        MarketManager.demand_for(project.genre_id),
        GameState.consumer_reputation,
        GameState.fans,
        float(GameState.difficulty().get("sales_multiplier", 1.0)),
        # This release plus everything of the studio's still on the shelf. It
        # is counted at launch, which is when a slate is either crowded or not;
        # what a game opens to shapes the whole curve that follows.
        GameState.games_on_market().size() + 1)

    # Reputation moves both ways: shipping badly costs the studio standing.
    var reputation_change := SalesSimulator.reputation_change(project.review_score)
    project.reputation_gained = reputation_change
    GameState.add_consumer_reputation(reputation_change)

    MarketManager.register_release(project.genre_id, project.size_id)
    GameState.released_games.append(project)
    TeamManager.record_project_result(project)
    GameState.active_projects.erase(project)
    TeamManager.release_project(project)
    GameState.select_project(GameState.active_projects[0] if not GameState.active_projects.is_empty() else null)

    EventBus.game_released.emit(project)

    # The launch week happens immediately; the rest arrive as time passes.
    sell_week(project)

func process_week() -> void:
    for game in GameState.games_on_market():
        sell_week(game)

func sell_week(project: GameProject) -> int:
    if not project.sales_active:
        return 0

    var platform := DataManager.get_platform(project.platform_id)
    var previous_units := project.last_week_units()

    var units := SalesSimulator.units_for_week(
        project,
        PlatformManager.popularity(platform),
        MarketManager.demand_for(project.genre_id),
        PlatformManager.install_base(platform))

    project.weeks_on_market += 1
    project.weekly_sales.append(units)

    var net_revenue := SalesSimulator.net_revenue(units, project.retail_price, project.royalty)
    var split := PublishingManager.settle_week(project, net_revenue)
    var studio_revenue := int(split["studio"])

    project.weekly_revenue.append(studio_revenue)
    project.lifetime_sales += units
    project.lifetime_revenue += studio_revenue

    var gained_fans := SalesSimulator.fans_from_week(
        units, project.review_score, GameState.fans)
    project.fans_gained += gained_fans
    GameState.add_fans(gained_fans)

    if studio_revenue > 0:
        FinanceManager.earn(studio_revenue, Ledger.Kind.SALES, "%s sales" % project.title, project.id)

    _check_milestones(project)
    if project.weeks_on_market >= 2 and units > previous_units and project.word_of_mouth > 1.10:
        EventBus.game_breakout_hit.emit(project)

    if SalesSimulator.should_leave_market(project, units):
        _leave_market(project)

    return units

func _leave_market(project: GameProject) -> void:
    project.sales_active = false
    EventBus.game_sales_ended.emit(project)
    if not project.is_profitable():
        EventBus.game_commercial_failure.emit(project)

func _check_milestones(project: GameProject) -> void:
    for milestone in SALES_MILESTONES:
        if project.lifetime_sales < milestone:
            continue
        var key := "%s:%d" % [project.id, milestone]
        if GameState.milestones.has(key):
            continue
        GameState.milestones.append(key)
        EventBus.game_hit_sales_milestone.emit(project, milestone)
