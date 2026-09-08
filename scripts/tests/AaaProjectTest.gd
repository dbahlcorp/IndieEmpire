extends TestCase

## The top project tier, actually built and shipped.
##
## AAA sat in the data behind `unlock_year: 2050` for as long as the timeline
## stopped in the nineties, so nothing had ever run a project through it. Now
## that a career reaches 2050 it is reachable, and the randomised balance probe
## does not exercise it -- a twenty-person studio split into two teams of ten
## tops out at Medium, because a team only qualifies for a size it can staff.
## AAA is what the studio gets for keeping everyone on one project instead.
##
## So this drives one the long way: twenty people, one team, campus office,
## start to shipped, and checks the numbers land where the tier is authored to
## put them rather than merely that nothing crashed.

const SIZE_ID := "aaa"

var project: GameProject = null

func run() -> void:
    _a_studio_big_enough()
    _the_tier_unlocks()
    _a_team_of_twenty_can_start_one()
    _it_is_the_biggest_thing_the_studio_can_build()
    _it_runs_to_completion()
    _it_ships_and_reads_as_a_real_game()

# --- Setup -------------------------------------------------------------

func _a_studio_big_enough() -> void:
    section("a twenty-person studio on a campus")
    GameState.start_company("Colossus", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    # AAA is a late-career tier; put the clock and the catalogue where it lives.
    TimeManager.current_year = 2014
    World.sync_year()
    FinanceManager.earn(40_000_000, Ledger.Kind.OTHER, "seed capital")

    for office_id in ["shared_workspace", "small_office", "professional_studio",
            "large_studio_floor", "studio_building", "campus"]:
        OfficeManager.move_to(office_id)
    check_equal(GameState.office_id, "campus", "the studio reached the campus")
    check_equal(OfficeManager.capacity(), 20, "which seats twenty")

    # Employee roles, not project roles -- see data/employee_roles.json.
    var roles := ["programmer", "designer", "artist", "writer",
        "audio_designer", "qa_tester", "producer"]
    var wanted := OfficeManager.capacity() - EmployeeManager.active_employees().size()
    for index in wanted:
        var candidate := EmployeeManager.generate_candidate(roles[index % roles.size()], "senior")
        if candidate == null:
            continue
        GameState.labor_candidates.append(candidate)
        LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)

    var staff := EmployeeManager.active_employees()
    print("    office %s, capacity %d, hired %d, cash %s" % [
        GameState.office_id, OfficeManager.capacity(), staff.size(),
        Format.money_exact(GameState.cash)])
    check_equal(staff.size(), 20, "twenty people on the payroll")

    # Everyone on one team: the whole point of the tier.
    for employee in staff:
        TeamManager.assign_employee(employee, "team_a")
    check_equal(TeamManager.members("team_a").size(), 20, "all twenty on one team")

func _the_tier_unlocks() -> void:
    section("the tier unlocks on its own terms")
    var size := DataManager.get_size(SIZE_ID)
    check_equal(int(size.get("max_useful_staff", 0)), 20,
        "AAA can use exactly a campus of people")
    check(TimeManager.current_year >= int(size.get("unlock_year", 9999)),
        "the year is late enough (%d)" % TimeManager.current_year)

    # Its game-count requirement is real, so meet it rather than bypass it.
    check(not UnlockManager.is_size_unlocked(SIZE_ID),
        "not unlocked before the catalogue exists")
    for i in int(size.get("unlock_games", 0)):
        var filler := GameProject.new()
        filler.id = "filler_%d" % i
        filler.title = "Back Catalogue %d" % i
        GameState.released_games.append(filler)
    UnlockManager.refresh(false)
    check(UnlockManager.is_size_unlocked(SIZE_ID),
        "unlocked once the studio has the catalogue for it")

# --- Building one ------------------------------------------------------

func _a_team_of_twenty_can_start_one() -> void:
    section("starting an AAA project")
    var platform := PlatformManager.available_platforms()
    if not check_not_empty(platform, "there is hardware to build for in %d" % TimeManager.current_year):
        return
    # The biggest market on sale, the way a player picking a platform would.
    platform.sort_custom(func(a, b):
        return PlatformManager.install_base(a) > PlatformManager.install_base(b))
    var platform_id := str(platform[0].get("id", ""))

    print("    building for %s, install base %s in %d" % [
        platform_id, Format.exact(PlatformManager.install_base(platform[0])),
        TimeManager.current_year])
    project = DevelopmentSimulator.start_project(
        "Colossus", "space", "action", platform_id, SIZE_ID, "team_a",
        TeamManager.default_assignments("team_a"))
    if not check_not_null(project, "the project started"):
        return
    check_equal(project.size_id, SIZE_ID, "at the AAA scope")
    check_equal(TeamManager.find_team("team_a").project_id, project.id,
        "and the team owns it")

func _it_is_the_biggest_thing_the_studio_can_build() -> void:
    section("bigger than every tier below it")
    if project == null:
        return
    var effort := DevelopmentSimulator.required_effort(SIZE_ID, [])
    for smaller in ["small", "medium", "large"]:
        check_greater(effort, DevelopmentSimulator.required_effort(smaller, []),
            "asks more effort than %s" % smaller)

    var team := TeamManager.members("team_a").size()
    var size := DataManager.get_size(SIZE_ID)
    check(not ScopeSimulator.is_understaffed(team, int(size.get("ideal_team_min", 0))),
        "twenty people is not understaffed for it")
    check(not ScopeSimulator.is_overstaffed(team, int(size.get("max_useful_staff", 0))),
        "and not overstaffed either -- it is exactly the right crew")

func _it_runs_to_completion() -> void:
    section("building it, week by week")
    if project == null:
        return
    var weeks := 0
    # Authored at 40-80 weeks; allow generous headroom before calling it stuck.
    while project.development_progress < 100.0 and weeks < 400:
        TimeManager.advance_week()
        weeks += 1
        if weeks % 50 == 0:
            print("      week %d: %.1f%% built, %s cash, %d on the team" % [
                weeks, project.development_progress, Format.money_exact(GameState.cash),
                TeamManager.members("team_a").size()])
        if GameState.bankrupt:
            print("      bankrupt at week %d" % weeks)
            break

    check(not GameState.bankrupt,
        "a forty-million-dollar studio can afford to build one")
    if not check(project.development_progress >= 100.0,
            "production finished (%.1f%% after %d weeks)" % [project.development_progress, weeks]):
        return

    var size := DataManager.get_size(SIZE_ID)
    check_between(float(project.development_weeks),
        float(size.get("dev_weeks_min", 40)) * 0.5, float(size.get("dev_weeks_max", 80)) * 2.0,
        "took a plausible number of weeks for the tier (%d, authored %s-%s)" % [
            project.development_weeks, size.get("dev_weeks_min", "?"), size.get("dev_weeks_max", "?")])
    check_greater(float(project.labour_cost), float(project.development_cost),
        "wages dominate its cost, as they do at every scale (%s against %s)" % [
            Format.money_exact(project.labour_cost), Format.money_exact(project.development_cost)])

func _it_ships_and_reads_as_a_real_game() -> void:
    section("shipping it")
    if project == null or project.development_progress < 100.0:
        return

    var expected := maxf(float(DataManager.get_size(SIZE_ID).get("expected_quality", 1)), 1.0)
    var ratio := project.average_quality() / expected
    # The whole point of expected_quality: a properly crewed team should land
    # near its own tier's bar, not far above or below it.
    check_between(ratio, 0.55, 1.60,
        "a full crew lands near the AAA quality bar (ratio %.2f)" % ratio)

    PublishingManager.sign_deal(project, PublishingSimulator.SELF_ID)
    ReviewSimulator.calculate_review(project)
    check_between(project.review_score, 2.5, 9.8,
        "it reviews on the ordinary scale (%.1f)" % project.review_score)

    SalesManager.release(project)
    check(project.released, "it released")
    var weeks := 0
    while project.sales_active and weeks < 120:
        TimeManager.advance_week()
        weeks += 1
    check_greater(float(project.lifetime_sales), 0.0,
        "it sold copies (%s)" % Format.exact(project.lifetime_sales))
    check_greater(float(project.total_cost()), 0.0,
        "and cost real money to make (%s)" % Format.money_exact(project.total_cost()))

    var platform := DataManager.get_platform(project.platform_id)

    # This debut loses money, and should: a 6.3 from a studio with no
    # reputation is a bad AAA game, and a bad AAA game is meant to hurt. What
    # would be a broken tier is one that cannot pay for itself even when it
    # lands -- so check the headroom is really there.
    var install := PlatformManager.install_base(platform)
    var ceiling := float(install) * SalesSimulator.max_attach_for(install)
    var best_case := ceiling * float(project.retail_price) * (1.0 - project.royalty)
    check_greater(best_case, float(project.total_cost()) * 3.0,
        "a AAA hit could comfortably clear its cost (ceiling %s copies is worth %s against %s spent)" % [
            Format.exact(int(ceiling)), Format.money_exact(int(best_case)),
            Format.money_exact(project.total_cost())])
    print("    AAA result: review %.1f over %d dev weeks" % [
        project.review_score, project.development_weeks])
    print("      quality %.0f against a bar of %.0f" % [project.average_quality(), expected])
    print("      launch demand %s, sold %s on an install base of %s" % [
        Format.exact(int(project.current_demand)), Format.exact(project.lifetime_sales),
        Format.exact(PlatformManager.install_base(platform))])
    print("      cost %s (wages %s + budget %s), profit %s" % [
        Format.money_exact(project.total_cost()), Format.money_exact(project.labour_cost),
        Format.money_exact(project.cash_cost()), Format.money_exact(project.profit())])
