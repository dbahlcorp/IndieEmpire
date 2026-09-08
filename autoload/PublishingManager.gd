extends Node

## Signing a game away. Offers are generated per project, the deal is stored on
## the project, and the weekly revenue split runs through here.

func offers_for(project: GameProject) -> Array:
    var offers: Array = []
    if project == null:
        return offers
    for publisher in DataManager.publishers:
        if not PublishingSimulator.is_available(
                publisher, GameState.consumer_reputation, GameState.released_games.size()):
            continue
        offers.append(PublishingSimulator.summarise(publisher, project, GameState.consumer_reputation))
    return offers

func sign_deal(project: GameProject, publisher_id: String) -> bool:
    if project == null or project.released:
        return false

    var publisher := DataManager.get_publisher(publisher_id)
    if publisher.is_empty():
        return false
    if not PublishingSimulator.is_available(
            publisher, GameState.consumer_reputation, GameState.released_games.size()):
        return false

    project.publisher_id = publisher_id
    project.developer_share = PublishingSimulator.developer_share(publisher, GameState.consumer_reputation)
    project.publisher_reach = PublishingSimulator.reach(publisher)
    project.advance = PublishingSimulator.advance_for(publisher, project)
    project.advance_remaining = project.advance

    if project.advance > 0:
        FinanceManager.earn(project.advance, Ledger.Kind.ADVANCE,
            "%s advance (%s)" % [project.title, publisher.get("name", "?")])

    EventBus.publishing_deal_signed.emit(project)
    SaveManager.autosave()
    return true

func self_publish(project: GameProject) -> bool:
    return sign_deal(project, PublishingSimulator.SELF_ID)

func publisher_name(project: GameProject) -> String:
    if project == null:
        return ""
    var publisher := DataManager.get_publisher(project.publisher_id)
    return str(publisher.get("name", "Self-Published"))

## Splits one week of gross revenue and returns what the studio actually banks.
func settle_week(project: GameProject, net_revenue: int) -> Dictionary:
    if net_revenue <= 0:
        return {"studio": 0, "publisher": 0, "recouped": 0}

    var share := project.developer_share if project.developer_share > 0.0 else 1.0
    var studio_share := int(round(float(net_revenue) * share))
    var publisher_cut := net_revenue - studio_share

    # The advance comes out of the studio's share before it sees anything.
    var recouped := 0
    if project.advance_remaining > 0:
        recouped = mini(project.advance_remaining, studio_share)
        project.advance_remaining -= recouped
        studio_share -= recouped

    project.publisher_revenue += publisher_cut
    return {"studio": studio_share, "publisher": publisher_cut, "recouped": recouped}

func lifetime_publisher_cut() -> int:
    var total := 0
    for game in GameState.released_games:
        total += game.publisher_revenue
    return total
