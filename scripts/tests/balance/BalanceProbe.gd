extends TestCase

## BALANCE PROBE -- not a pass/fail suite.
##
## Plays the same randomised manager career as the Phase A acceptance run, but
## instead of asserting, it dumps every release and a yearly snapshot of the
## books as CSV so the curves can actually be looked at. Run it several times
## with different seeds to see the spread rather than one lucky career.
##
##     godot --headless --path . res://scripts/tests/balance/BalanceProbe.tscn -- --seed=7

## Headcount at which a second team is worth opening: past what one `large`
## project can usefully absorb.
const SECOND_TEAM_AT := 13

const OFFICE_LADDER := ["shared_workspace", "small_office", "professional_studio",
	"large_studio_floor", "studio_building", "campus"]

var out_dir := "user://balance"
var seed_value := 0
## How far to play. The default still ends where the acceptance run does; pass
## --until=2050 to exercise the whole authored timeline.
var until_year := 1995
var max_weeks := 1500
var games_csv: Array[String] = []
var years_csv: Array[String] = []
var granted := 0
var hires := 0
var office_moves := 0
var rested := 0
## How crowded the studio's own slate was when each game launched.
var concurrent_at_launch := {}
var genre_demand_at_launch := {}
## How many people were on the team that actually built each release.
var team_size_at_launch := {}

func run() -> void:
	_read_args()
	seed(seed_value)
	DirAccess.make_dir_recursive_absolute(out_dir)

	games_csv.append("seed,index,year,size,platform,publisher,review,quality,expected_quality,quality_ratio,bugs,dev_weeks,polish_weeks,units,revenue,advance,dev_cost,labour_cost,profit,attach_pct,concurrent,genre_demand,team_size,useful_staff")
	years_csv.append("seed,year,cash,staff,payroll_mo,office,teams,rent_mo,released,avg_review,consumer_rep,fans")

	_play()
	_dump()

func _read_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed_value = int(arg.split("=")[1])
		elif arg.begins_with("--out="):
			out_dir = str(arg.split("=")[1])
		elif arg.begins_with("--until="):
			until_year = int(arg.split("=")[1])
			max_weeks = (until_year - 1984) * 53

func _play() -> void:
	section("playing seed %d" % seed_value)
	GameState.start_company("Nova Forge", "Darren", "normal")
	SaveManager.has_active_company = true
	World.sync_year()

	var recorded := {}
	var last_year := TimeManager.current_year
	var weeks := 0
	while TimeManager.current_year <= until_year and weeks < max_weeks:
		if GameState.bankrupt:
			break
		_answer_people()
		_look_after_people()
		_grow()
		_work()
		TimeManager.advance_week()
		weeks += 1
		for game in GameState.released_games:
			if not game.sales_active and not game.postmortem_reviewed:
				PostmortemSimulator.analyse(game)
			if not game.sales_active and not recorded.has(game.id):
				recorded[game.id] = true
				_record_game(game)
		if TimeManager.current_year != last_year:
			last_year = TimeManager.current_year
			_record_year()

	for game in GameState.released_games:
		if not recorded.has(game.id):
			_record_game(game)
	_record_year()

	print("  played %d weeks to %s, bankrupt=%s" % [
		weeks, TimeManager.get_date_label(), str(GameState.bankrupt)])
	print("  %s cash | %d staff | %s | payroll %s/mo | %d games | avg review %.2f" % [
		Format.money_exact(GameState.cash), EmployeeManager.active_employees().size(),
		GameState.office_id, Format.money_exact(EmployeeManager.monthly_payroll()),
		GameState.released_games.size(), CompanyStats.average_review()])
	print("  hires %d, granted %d, office moves %d, departures %d" % [
		hires, granted, office_moves, GameState.departed_employees.size()])

func _record_game(game: GameProject) -> void:
	var size := DataManager.get_size(game.size_id)
	var expected := maxf(float(size.get("expected_quality", 100)), 1.0)
	var platform := DataManager.get_platform(game.platform_id)
	var base := int(platform.get("peak_users", 0))
	var attach := 0.0
	if base > 0:
		attach = float(game.lifetime_sales) / float(base) * 100.0
	games_csv.append("%d,%d,%d,%s,%s,%s,%.2f,%.1f,%.1f,%.3f,%d,%d,%d,%d,%d,%d,%d,%d,%d,%.2f,%d,%.3f,%d,%d" % [
		seed_value, GameState.released_games.find(game), game.release_year,
		game.size_id, game.platform_id,
		game.publisher_id if not game.publisher_id.is_empty() else "self",
		game.review_score, game.average_quality(), expected,
		game.average_quality() / expected, game.bugs,
		game.development_weeks, game.polish_weeks,
		game.lifetime_sales, game.lifetime_revenue, game.advance,
		game.total_cost(), game.labour_cost, game.profit(), attach,
		int(concurrent_at_launch.get(game.id, 1)),
		float(genre_demand_at_launch.get(game.id, 1.0)),
		int(team_size_at_launch.get(game.id, 0)),
		int(size.get("max_useful_staff", 99))])

func _record_year() -> void:
	years_csv.append("%d,%d,%d,%d,%d,%s,%d,%d,%d,%.2f,%.1f,%d" % [
		seed_value, TimeManager.current_year, GameState.cash,
		EmployeeManager.active_employees().size(),
		EmployeeManager.monthly_payroll(), GameState.office_id,
		GameState.teams.size(), OfficeManager.monthly_rent(),
		GameState.released_games.size(), CompanyStats.average_review(),
		GameState.consumer_reputation, GameState.fans])

func _dump() -> void:
	_write("%s/games_%d.csv" % [out_dir, seed_value], games_csv)
	_write("%s/years_%d.csv" % [out_dir, seed_value], years_csv)
	check(true, "dumped %d releases and %d yearly rows" % [games_csv.size() - 1, years_csv.size() - 1])

func _write(path: String, lines: Array[String]) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("  wrote %s" % ProjectSettings.globalize_path(path))

# --- the same manager the acceptance run uses --------------------------

func _look_after_people() -> void:
	for employee in MoraleManager.at_burnout_risk():
		if MoraleManager.give_time_off(employee):
			rested += 1
	for team in GameState.teams:
		if MoraleManager.is_crunching(team.id) and not MoraleManager.at_burnout_risk().is_empty():
			MoraleManager.set_crunch(team.id, false)

func _answer_people() -> void:
	for request in RetentionManager.requests().duplicate():
		if RetentionManager.can_grant(request) and GameState.cash > request.monthly_increase() * 12:
			if RetentionManager.grant(request):
				granted += 1
		else:
			RetentionManager.refuse(request)

func _grow() -> void:
	var payroll := EmployeeManager.monthly_payroll()
	var running_costs := EmployeeManager.monthly_expenses()
	if GameState.cash < int(running_costs["total"]) * 18 + 60_000:
		return
	if payroll > 0 and GameState.cash < payroll * 18:
		return

	if not OfficeManager.has_capacity():
		for office_id in OFFICE_LADDER:
			if OfficeManager.can_move_to(office_id) and _can_carry_office(office_id):
				if OfficeManager.move_to(office_id):
					office_moves += 1
				break
		return

	if GameState.labor_candidates.is_empty():
		LaborMarketManager.refresh_market(false)
	if GameState.labor_candidates.is_empty():
		return

	var candidate: Employee = GameState.labor_candidates[0]
	if str(LaborMarketManager.make_offer(candidate, candidate.salary, 0.0).get("status", "")) == "accepted":
		hires += 1

func _can_carry_office(office_id: String) -> bool:
	## can_move_to() only asks whether the move-in cost is affordable. The rent
	## afterwards is the part that kills studios -- the top floors cost several
	## times what the one below them does -- so a sensible manager checks it can
	## still make payroll for a year once it has signed.
	var target := DataManager.get_office(office_id)
	if target.is_empty():
		return false
	var move_in := OfficeManager.move_in_cost(target)
	var monthly := OfficeManager.monthly_rent(target)
	monthly += FinanceManager.expense(int(target.get("utilities", 0)))
	monthly += EmployeeManager.monthly_payroll()
	return GameState.cash - move_in > monthly * 12

func _work() -> void:
	_staff_teams()
	for team in GameState.teams.duplicate():
		_work_team(team)

func _staff_teams() -> void:
	## Once there are more people than one project can use, open a second team
	## and keep the two roughly even. MAX_TEAMS is 2, so this is the whole of it.
	var staff := EmployeeManager.active_employees()
	if staff.size() >= SECOND_TEAM_AT and GameState.teams.size() < TeamManager.MAX_TEAMS:
		TeamManager.create_second_team()
	for employee in TeamManager.unassigned_employees():
		TeamManager.assign_employee(employee, TeamManager.team_for_new_hire())
	if GameState.teams.size() < 2:
		return
	var a := TeamManager.members("team_a")
	var b := TeamManager.members("team_b")
	if a.size() - b.size() >= 2 and TeamManager.find_team("team_a").project_id.is_empty():
		TeamManager.assign_employee(a[a.size() - 1], "team_b")

func _work_team(team: StudioTeam) -> void:
	var project: GameProject = null
	for candidate in GameState.active_projects:
		if candidate.id == team.project_id:
			project = candidate
			break

	if project == null:
		if TeamManager.members(team.id).is_empty():
			return
		if not ContractManager.has_active_contract():
			if GameState.cash < DevelopmentSimulator.get_minimum_project_cost() * 2:
				if GameState.contract_offers.is_empty():
					ContractManager.refresh_offers(false)
				if ContractManager.can_accept() and not GameState.contract_offers.is_empty():
					if ContractManager.accept(GameState.contract_offers[0]):
						return
		if ContractManager.has_active_contract():
			return
		_start_project(team.id)
		return

	if project.development_progress < 100.0:
		return

	if project.bugs > 3 and project.polish_weeks < 5 and FinanceManager.can_afford(
			DevelopmentSimulator.get_polish_cost(project) * 4):
		project.polishing = true
		return

	project.polishing = false

	var best_id := PublishingSimulator.SELF_ID
	var best_value := 0.0
	for offer in PublishingManager.offers_for(project):
		var value := float(offer["reach"]) * float(offer["developer_share"])
		if value > best_value:
			best_value = value
			best_id = str(offer["id"])
	PublishingManager.sign_deal(project, best_id)

	ReviewSimulator.calculate_review(project)
	project.critic_reviews = ReviewSimulator.critic_scores(project)
	concurrent_at_launch[project.id] = GameState.games_on_market().size() + 1
	genre_demand_at_launch[project.id] = MarketManager.demand_for(project.genre_id)
	team_size_at_launch[project.id] = TeamManager.working_members(project.team_id).size()
	SalesManager.release(project)

func _start_project(team_id: String) -> void:
	var genres := MarketManager.unlocked_genres()
	var themes := MarketManager.unlocked_themes()
	var platforms := PlatformManager.available_platforms()
	if genres.is_empty() or themes.is_empty() or platforms.is_empty():
		return

	genres.sort_custom(func(a, b):
		return MarketManager.demand_for(str(a.get("id", ""))) > MarketManager.demand_for(str(b.get("id", ""))))
	platforms.sort_custom(func(a, b):
		return PlatformManager.install_base(a) > PlatformManager.install_base(b))

	var genre_id := str(genres[0].get("id", ""))
	var theme_id := str(themes[randi() % themes.size()].get("id", ""))
	if randf() > 0.35:
		var best := -1.0
		for theme in themes:
			var id := str(theme.get("id", ""))
			if ExperienceManager.combo_shipments(id, genre_id) == 0:
				continue
			var value := KnowledgeSimulator.true_compatibility(id, genre_id)
			if value > best:
				best = value
				theme_id = id

	var headcount := TeamManager.members(team_id).size()
	var size_id := "small"
	for size in MarketManager.unlocked_sizes():
		if headcount >= int(size.get("max_useful_staff", 99)):
			size_id = str(size.get("id", ""))

	var platform_id := str(platforms[0].get("id", ""))
	var cost := DevelopmentSimulator.get_upfront_cost(platform_id, size_id)
	cost += DevelopmentSimulator.get_platform_fee(platform_id)
	if not FinanceManager.can_afford(cost * 2):
		size_id = "small"
		cost = DevelopmentSimulator.get_upfront_cost(platform_id, size_id)
		cost += DevelopmentSimulator.get_platform_fee(platform_id)
		if not FinanceManager.can_afford(cost * 2):
			return

	DevelopmentSimulator.start_project(
		"Project %d" % (GameState.released_games.size() + GameState.active_projects.size() + 1),
		theme_id, genre_id, platform_id, size_id, team_id)
