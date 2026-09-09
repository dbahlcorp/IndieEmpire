extends Node

## Owns the franchise/IP layer (PA.10). A released original game becomes an IP;
## sequels the player chooses to make extend it. State lives in
## GameState.franchises; the maths lives in FranchiseSimulator.
##
## Registration happens once per release, from SalesManager.release(), *after*
## the review score is final and the game is on GameState.released_games, but
## the launch-demand bonus a sequel earns is read *before* this runs -- see
## launch_demand_multiplier() -- so it reflects the anticipation the earlier
## entries built, not this release's own contribution to it.

func find_franchise(series_id: String) -> Franchise:
    return GameState.find_franchise(series_id)

func franchise_for(project: GameProject) -> Franchise:
    ## The franchise this project belongs to, or null. Set for a sequel from
    ## project creation; set for an original only once it has been released.
    if project == null or project.series_id.is_empty():
        return null
    return GameState.find_franchise(project.series_id)

func active_franchise(project: GameProject) -> Franchise:
    ## The franchise a project can actually draw benefits from mid-development:
    ## one that already has at least one released entry.
    var franchise := franchise_for(project)
    if franchise == null or franchise.entry_count() < 1:
        return null
    return franchise

func selectable_franchises() -> Array[Franchise]:
    ## Franchises the player can start a sequel in -- those with a released
    ## entry. Newest activity first.
    var out: Array[Franchise] = []
    for franchise in GameState.franchises:
        if franchise.entry_count() >= 1:
            out.append(franchise)
    out.sort_custom(func(a: Franchise, b: Franchise) -> bool:
        return a.weeks_since_last_release() < b.weeks_since_last_release())
    return out

func launch_demand_multiplier(project: GameProject) -> float:
    ## Read by SalesManager before register_release(). 1.0 unless the project is
    ## a sequel in a franchise that already has a released entry.
    return FranchiseSimulator.launch_demand_multiplier(active_franchise(project))

func suggested_sequel_title(franchise: Franchise) -> String:
    if franchise == null:
        return ""
    var base := franchise.name
    var next_number := franchise.entry_count() + 1
    # "Starfall" -> "Starfall 2"; "Starfall 2" -> "Starfall 3".
    var parts := base.rsplit(" ", true, 1)
    if parts.size() == 2 and parts[1].is_valid_int():
        return "%s %d" % [parts[0], int(parts[1]) + 1]
    return "%s %d" % [base, next_number]

func attach_to_series(project: GameProject, series_id: String) -> bool:
    ## Links a project being set up to an existing franchise. Its sequel_number
    ## is provisional until release (register_release re-derives it from the
    ## final order), but development-time UI needs something to show.
    var franchise := GameState.find_franchise(series_id)
    if franchise == null:
        return false
    project.series_id = series_id
    project.sequel_number = franchise.entry_count() + 1
    return true

func register_release(project: GameProject) -> Franchise:
    ## Called once, from SalesManager.release(). Creates the IP for a released
    ## original, extends it for a sequel, and moves the franchise's stateful
    ## reception forward.
    if project == null:
        return null

    var franchise := GameState.find_franchise(project.series_id) if not project.series_id.is_empty() else null

    if franchise == null:
        # A brand-new original becomes its own IP. A sequel whose franchise
        # somehow vanished falls back to the same path rather than crashing.
        franchise = Franchise.new()
        franchise.id = GameState.next_series_id()
        franchise.name = project.title
        franchise.original_game_id = project.id
        franchise.founded_year = project.release_year
        project.series_id = franchise.id
        GameState.franchises.append(franchise)

    if franchise.name.is_empty():
        franchise.name = project.title

    var prior_entries := franchise.entry_count()
    var average_before := franchise.average_review()
    var weeks_since_last := franchise.weeks_since_last_release()

    if not franchise.game_ids.has(project.id):
        franchise.game_ids.append(project.id)
    # The sequel number is simply the release-order position.
    project.sequel_number = franchise.game_ids.find(project.id) + 1
    if project.sequel_number == 1:
        franchise.original_game_id = project.id
        if project.entry_kind == "sequel":
            project.entry_kind = "original"
    elif project.entry_kind == "original":
        project.entry_kind = "sequel"

    var innovation_ratio := project.innovation / maxf(_expected_field(project), 1.0)
    if prior_entries >= 1:
        franchise.fatigue = FranchiseSimulator.fatigue_from_release(
            franchise.fatigue, weeks_since_last, innovation_ratio)
    franchise.fan_interest = FranchiseSimulator.fan_interest_from_release(
        franchise.fan_interest, project.review_score, average_before, prior_entries)
    franchise.reputation = FranchiseSimulator.reputation_from_release(
        franchise.reputation, project.review_score, prior_entries)
    franchise.last_release_year = project.release_year
    franchise.last_release_month = project.release_month
    franchise.last_release_week = project.release_week

    EventBus.franchise_updated.emit(franchise, project)
    return franchise

func process_week() -> void:
    ## Time away from a series cools its fatigue and its hype.
    for franchise in GameState.franchises:
        franchise.fatigue = FranchiseSimulator.fatigue_after_week(franchise.fatigue)
        franchise.fan_interest = FranchiseSimulator.fan_interest_after_week(
            franchise.fan_interest, franchise.reputation)

func backfill_from_history() -> void:
    ## Older saves have released games with no series_id. Each such game becomes
    ## its own single-entry IP, in release order, so the feature is usable in an
    ## existing career. No game is retroactively merged into a multi-entry
    ## series -- the player never chose that.
    for game in GameState.released_games:
        if not game.series_id.is_empty():
            continue
        var franchise := Franchise.new()
        franchise.id = GameState.next_series_id()
        franchise.name = game.title
        franchise.original_game_id = game.id
        franchise.founded_year = game.release_year
        franchise.game_ids.append(game.id)
        franchise.fan_interest = FranchiseSimulator.fan_interest_from_release(
            0.0, game.review_score, 0.0, 0)
        franchise.reputation = FranchiseSimulator.reputation_from_release(
            0.0, game.review_score, 0)
        franchise.last_release_year = game.release_year
        franchise.last_release_month = game.release_month
        franchise.last_release_week = game.release_week
        game.series_id = franchise.id
        game.sequel_number = 1
        GameState.franchises.append(franchise)

func _expected_field(project: GameProject) -> float:
    var size := DataManager.get_size(project.size_id)
    return maxf(float(size.get("work", 100)) * 0.40, 1.0)
