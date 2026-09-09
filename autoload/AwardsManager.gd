extends Node

## Owns the Annual Game Awards (PA.11). Once a year, the previous year's
## releases are judged against the authored categories in data/awards.json; the
## result is recorded permanently on GameState.award_ceremonies, the winning
## teams get a line in their career record, and the studio collects a set of
## restrained, one-off rewards (reputation, fans, morale, recruiting standing,
## franchise prestige -- never cash, never a quality bonus).
##
## The maths lives in AwardsSimulator. This manager owns the cadence, the state
## and the side effects, the same way StudioEventManager owns its queue.
##
## With no rival studios yet (M4), every eligible release is one of the
## studio's own games, so a ceremony that forms is entirely the player's --
## still a real prestige goal, and the eligibility pool simply widens when
## competitors arrive.

## Deterministic per career and year: the nominee shortlist and winner do not
## change if the same year is rebuilt, but two studios' careers differ.
const CEREMONY_SEED_SALT := 0x5A11

func process_week() -> void:
    if not SaveManager.has_active_company or GameState.bankrupt:
        return
    var judged_through := TimeManager.current_year - 1
    if judged_through <= GameState.last_awards_year:
        return
    # An older save (or a brand-new field) has never run the ceremony. Adopt the
    # current position without retro-awarding a career's worth of back-years.
    if GameState.last_awards_year <= 0:
        GameState.last_awards_year = judged_through
        return
    for year in range(GameState.last_awards_year + 1, judged_through + 1):
        run_annual_ceremony(year)
    GameState.last_awards_year = judged_through

func run_annual_ceremony(year: int) -> Dictionary:
    ## Build, record and apply the ceremony for one release year. Returns the
    ## recorded ceremony, or {} when too few eligible releases existed for any
    ## category to form. Safe to call directly from tests.
    if not GameState.find_ceremony(year).is_empty():
        return {}

    var releases := _releases_in_year(year)
    if releases.is_empty():
        return {}

    var rng := RandomNumberGenerator.new()
    rng.seed = _ceremony_seed(year)
    var ceremony := AwardsSimulator.build_ceremony(
        year, releases, DataManager.awards, rng)
    if (ceremony.get("categories", []) as Array).is_empty():
        return {}

    ceremony["held_year"] = TimeManager.current_year
    ceremony["seen"] = false
    ceremony["rewards"] = AwardsSimulator.ceremony_rewards(ceremony)
    GameState.award_ceremonies.append(ceremony)

    _record_employee_awards(ceremony)
    _apply_rewards(ceremony)
    _announce(ceremony)

    EventBus.awards_ceremony_held.emit(ceremony)
    GameClock.pause_for_decision("game awards")
    return ceremony

# --- Cadence helpers -------------------------------------------------------

func _releases_in_year(year: int) -> Array:
    var out: Array = []
    for game in GameState.released_games:
        if game.released and game.release_year == year:
            out.append(game)
    return out

func _ceremony_seed(year: int) -> int:
    return absi(hash("%s|%d|%d" % [
        GameState.company_name, GameState.founded_year, year])) ^ CEREMONY_SEED_SALT

# --- Side effects ---------------------------------------------------------

func _record_employee_awards(ceremony: Dictionary) -> void:
    var year := int(ceremony.get("year", 0))
    for category in ceremony.get("categories", []):
        var game := GameState.find_game(str(category.get("winner_id", "")))
        if game == null:
            continue
        var credited: Array = game.credited_employee_ids.duplicate()
        for assigned_id in game.role_assignments.values():
            if not str(assigned_id).is_empty() and str(assigned_id) not in credited:
                credited.append(str(assigned_id))
        if not game.lead_employee_id.is_empty() and game.lead_employee_id not in credited:
            credited.append(game.lead_employee_id)
        for employee_id in credited:
            var employee := EmployeeManager.find_any_employee(str(employee_id))
            if employee == null:
                continue
            if _already_recorded(employee, str(category.get("award_id", "")), game.id, year):
                continue
            employee.awards.append({
                "award_id": str(category.get("award_id", "")),
                "name": str(category.get("name", "")),
                "project_id": game.id,
                "year": year,
            })

func _already_recorded(employee: Employee, award_id: String, project_id: String, year: int) -> bool:
    for entry in employee.awards:
        if str(entry.get("award_id", "")) == award_id \
                and str(entry.get("project_id", "")) == project_id \
                and int(entry.get("year", 0)) == year:
            return true
    return false

func _apply_rewards(ceremony: Dictionary) -> void:
    var rewards: Dictionary = ceremony.get("rewards", {})

    GameState.add_consumer_reputation(float(rewards.get("reputation", 0.0)))
    GameState.add_employer_reputation(float(rewards.get("employer_reputation", 0.0)))
    var fans := int(rewards.get("fans", 0))
    if fans > 0:
        GameState.add_fans(fans)
    var morale := int(rewards.get("morale", 0))
    if morale != 0:
        for employee in EmployeeManager.active_employees():
            employee.morale = clampi(employee.morale + morale, 0, 100)

    # Franchise prestige: a win renews audience interest in that series.
    for category in ceremony.get("categories", []):
        var game := GameState.find_game(str(category.get("winner_id", "")))
        if game == null:
            continue
        var franchise := GameState.franchise_for_game(game)
        if franchise == null:
            continue
        franchise.fan_interest = clampf(
            franchise.fan_interest
            + AwardsSimulator.franchise_prestige(str(category.get("award_id", ""))),
            0.0, 100.0)

func _announce(ceremony: Dictionary) -> void:
    # One headline for the whole ceremony; per-category detail lives on the
    # ceremony screen and each game's page.
    var goty := _category(ceremony, "goty")
    var wins := int(ceremony.get("rewards", {}).get("wins", 0))
    var year := int(ceremony.get("year", 0))
    var winner_game: GameProject = null
    var award_label := ""
    if not goty.is_empty():
        winner_game = GameState.find_game(str(goty.get("winner_id", "")))
        award_label = "Game of the Year"
    elif wins > 0:
        var first: Dictionary = ceremony.get("categories", [])[0]
        winner_game = GameState.find_game(str(first.get("winner_id", "")))
        award_label = str(first.get("name", "an award"))

    if winner_game != null:
        EventBus.award_won.emit(winner_game, award_label)
    for category in ceremony.get("categories", []):
        var nominees: Array = category.get("nominees", [])
        if nominees.size() > 1:
            var runner_up := GameState.find_game(str(nominees[1].get("game_id", "")))
            if runner_up != null:
                EventBus.award_nominated.emit(runner_up, str(category.get("name", "")))
            break

    NewsManager.post_awards_ceremony(ceremony)
    if winner_game != null:
        EventBus.notify("GAME AWARDS", "%s wins %s at the %d Game Awards" % [
            winner_game.title, award_label, year + 1], true)
    else:
        EventBus.notify("GAME AWARDS", "The %d Game Awards were handed out" % (year + 1), true)

# --- UI queries ---------------------------------------------------------

func latest_ceremony() -> Dictionary:
    if GameState.award_ceremonies.is_empty():
        return {}
    return GameState.award_ceremonies[GameState.award_ceremonies.size() - 1]

func unseen_ceremony() -> Dictionary:
    for ceremony in GameState.award_ceremonies:
        if not bool(ceremony.get("seen", true)):
            return ceremony
    return {}

func has_unseen_ceremony() -> bool:
    return not unseen_ceremony().is_empty()

func mark_seen(year: int) -> void:
    for ceremony in GameState.award_ceremonies:
        if int(ceremony.get("year", 0)) == year:
            ceremony["seen"] = true
    SaveManager.autosave()

func _category(ceremony: Dictionary, award_id: String) -> Dictionary:
    for category in ceremony.get("categories", []):
        if str(category.get("award_id", "")) == award_id:
            return category
    return {}
