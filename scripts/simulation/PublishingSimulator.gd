class_name PublishingSimulator
extends RefCounted

## Who sells the game, and what they take for it.
##
## Self-publishing keeps every penny but reaches only the audience a small
## studio can reach on its own. A publisher opens the whole market and takes the
## majority of the money for doing it. That trade is what stops a successful
## studio from simply compounding forever.

const SELF_ID := "self"

static func is_self_published(publisher_id: String) -> bool:
    return publisher_id.is_empty() or publisher_id == SELF_ID

static func is_available(publisher: Dictionary, reputation: float, games_released: int) -> bool:
    if reputation < float(publisher.get("min_reputation", 0)):
        return false
    return games_released >= int(publisher.get("min_games", 0))

static func developer_share(publisher: Dictionary, reputation: float) -> float:
    ## A studio with a name negotiates a better split, but never a good one.
    var base := float(publisher.get("developer_share", 1.0))
    if is_self_published(str(publisher.get("id", ""))):
        return 1.0
    var bonus := clampf(reputation, 0.0, 100.0) / 100.0 * 0.08
    return clampf(base + bonus, 0.0, 0.60)

static func advance_for(publisher: Dictionary, project: GameProject) -> int:
    ## Paid on signing, and recouped out of the developer's share before the
    ## studio sees a penny of royalties.
    ## Deliberately against cash_cost() rather than the fully-loaded cost: an
    ## unrecouped advance is money a failed game keeps, so scaling it to wages
    ## as well would cushion exactly the failures the books are meant to show.
    var multiplier := float(publisher.get("advance_multiplier", 0.0))
    if multiplier <= 0.0:
        return 0
    return int(round(float(project.cash_cost()) * multiplier / 100.0)) * 100

static func reach(publisher: Dictionary) -> float:
    return float(publisher.get("reach", 1.0))

static func share_label(share: float) -> String:
    return "%d%%" % int(round(share * 100.0))

static func summarise(publisher: Dictionary, project: GameProject, reputation: float) -> Dictionary:
    var share := developer_share(publisher, reputation)
    return {
        "id": str(publisher.get("id", "")),
        "name": str(publisher.get("name", "?")),
        "blurb": str(publisher.get("blurb", "")),
        "developer_share": share,
        "advance": advance_for(publisher, project),
        "reach": reach(publisher)
    }
