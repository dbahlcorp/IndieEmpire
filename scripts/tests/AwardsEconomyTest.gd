extends TestCase

## PA.11 economic guard: sweeping the Game Awards year after year must not
## compound into an economic advantage.
##
## Plays a scripted "awards darling" studio that ships six strong releases every
## year for fifteen years and wins essentially everything. It then checks that
## the awards system's contribution stays bounded and one-off:
##
##   * every ceremony's reward is inside AwardsSimulator's per-ceremony caps
##   * consumer and recruiting reputation never leave 0..100
##   * the total fans the awards system has handed out across fifteen dominant
##     years is a rounding error next to what the games themselves sell
##
## The awards touch no cash and no sales multiplier and never change a game's
## quality, so this is the whole surface through which they could leak into the
## economy. EconomyPlateauTest owns the career-wide plateau check.

const YEARS := 15
const RELEASES_PER_YEAR := 6

func run() -> void:
    seed(11)
    GameState.start_company("Sweep", "Sam", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(50_000_000, Ledger.Kind.OTHER, "seed")
    var founder := EmployeeManager.founder()

    var total_award_fans := 0
    var total_award_reputation := 0.0
    var ceremonies := 0
    var worst_reward_reputation := 0.0
    var game_sales := 0

    for offset in YEARS:
        var year := 1985 + offset
        for i in RELEASES_PER_YEAR:
            var genre: String = ["adventure", "rpg", "action", "strategy", "simulation", "shooter"][i]
            var project := GameProject.new()
            project.id = GameState.next_project_id()
            project.title = "%d Winner %d" % [year, i]
            project.genre_id = genre
            project.theme_id = "fantasy"
            project.platform_id = "microstar_64"
            project.size_id = "medium"
            project.released = true
            project.release_year = year
            project.release_month = 6
            for field in ["gameplay", "technology", "graphics", "story", "sound",
                    "innovation", "polish", "performance", "narrative_quality", "balance"]:
                project.set(field, 90.0)
            project.review_score = 9.2
            project.word_of_mouth = 1.35
            project.bugs = 1
            project.lifetime_sales = 1_000_000
            project.fans_gained = 40_000
            project.credited_employee_ids.assign([founder.id])
            project.role_assignments = {"design": founder.id}
            GameState.released_games.append(project)
            game_sales += project.lifetime_sales

        TimeManager.set_date(year + 1, 1, 1)
        var ceremony := AwardsManager.run_annual_ceremony(year)
        if ceremony.is_empty():
            continue
        ceremonies += 1
        var rewards: Dictionary = ceremony["rewards"]
        total_award_fans += int(rewards["fans"])
        total_award_reputation += float(rewards["reputation"])
        worst_reward_reputation = maxf(worst_reward_reputation, float(rewards["reputation"]))

        check_less(float(rewards["fans"]), AwardsSimulator.CEREMONY_FANS_CAP + 0.01,
            "year %d ceremony fan reward within cap" % year)
        check_less(float(rewards["reputation"]), AwardsSimulator.CEREMONY_REPUTATION_CAP + 0.01,
            "year %d ceremony reputation reward within cap" % year)
        check_less(float(rewards["employer_reputation"]),
            AwardsSimulator.CEREMONY_EMPLOYER_REPUTATION_CAP + 0.01,
            "year %d ceremony recruiting reward within cap" % year)

    section("fifteen dominant years of ceremonies")
    check_greater(float(ceremonies), 10.0, "the studio actually held ceremonies (%d)" % ceremonies)
    check_between(GameState.consumer_reputation, 0.0, 100.0,
        "consumer reputation stayed bounded (%.1f)" % GameState.consumer_reputation)
    check_between(GameState.employer_reputation, 0.0, 100.0,
        "recruiting reputation stayed bounded (%.1f)" % GameState.employer_reputation)

    section("the awards contribution does not run away")
    check_less(float(worst_reward_reputation), AwardsSimulator.CEREMONY_REPUTATION_CAP + 0.01,
        "no single ceremony ever exceeded the reputation cap")
    # Fifteen clean-sweep years hand out far less audience than the catalogue
    # earns on its own -- awards are a garnish, not a growth engine.
    check_less(float(total_award_fans), float(game_sales) * 0.02,
        "awards granted %s fans against %s in sales -- under 2%%" % [
            Format.exact(total_award_fans), Format.exact(game_sales)])
    check_less(float(total_award_fans), float(AwardsSimulator.CEREMONY_FANS_CAP * YEARS) + 1.0,
        "and never more than the per-ceremony cap allows, year over year")
