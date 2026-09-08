extends Node

## Pure company state and nothing else. Every rule that reads or changes it
## lives in a manager or a simulator; screens only read from it.

# --- Company ---
var company_name: String = "Indie Empire"
var founder_name: String = "You"
var founder_pronoun_id: String = Pronouns.DEFAULT
## Chosen once at studio creation, purely for the founder's starting skill
## profile -- see DataManager.get_founder_background() and
## EmployeeManager.create_founder(). No bearing on seniority or promotion.
var founder_background_id: String = "generalist"
## Chosen once at studio creation. Replaces the random 1-2 traits every
## other employee rolls -- see EmployeeManager.create_founder() and
## data/employee_traits.json. A second, unrelated one-time creation choice
## from founder_background_id above: this is who they *are*, that is what
## they came from.
var founder_trait_id: String = "perfectionist"
var difficulty_id: String = "normal"
var cash: int = 10_000
var fans: int = 0
## How the market sees the studio's games: reviews, sales and word of mouth
## all move this. See PublishingManager, SalesManager, ContractManager.
var consumer_reputation: float = 0.0
## How the industry sees the studio as somewhere to work, independent of how
## good its games are -- a studio can ship hits while treating people badly.
## Starts at CultureSimulator.NEUTRAL, same convention as the culture values:
## unproven, not yet judged either way. See LaborMarketManager, RetentionManager.
var employer_reputation: float = 50.0
var founded_year: int = 1985
var founded_month: int = 1
var founded_week: int = 1

var current_project: GameProject = null
var active_projects: Array[GameProject] = []
var selected_project_id: String = ""
var released_games: Array[GameProject] = []
var next_id: int = 1

# --- People ---
var employees: Array[Employee] = []
var next_employee_number: int = 1
var labor_candidates: Array[Employee] = []
var labor_market_weeks_left: int = 0
var labor_market_generation: int = 0
var office_quality: int = 0
var office_id: String = "bedroom"
var owned_office_customizations: Array[String] = ["classic"]
var equipped_office_customization: String = "classic"
var office_remodel: Dictionary = {}
var teams: Array[StudioTeam] = []

# --- Knowledge ---
var genre_experience: Dictionary = {}       # genre_id -> xp
var theme_experience: Dictionary = {}       # theme_id -> xp
var platform_experience: Dictionary = {}    # platform_id -> xp
var combo_knowledge: Dictionary = {}        # "theme|genre" -> shipments
var platform_genre_knowledge: Dictionary = {} # "platform|genre" -> shipments
var feature_knowledge: Dictionary = {}       # "feature|genre" -> postmortems

# --- Technology ---
## Completed technology ids from data/technologies.json. Starter techs are
## always present. Gates game features (FeatureSimulator) and engine building
## (EngineManager). Renamed from researched_engine_features in save v20.
var completed_technologies: Array = []
## In-flight research: [{tech_id, progress: float, researcher_ids: Array}].
## See ResearchManager / ResearchSimulator.
var active_research: Array = []
## The pooled research resource, earned from shipping games, postmortems,
## experimenting with unfamiliar features and innovation -- never a passive
## drip. Spent down as active research draws on it.
var research_points: float = 0.0
## Feature ids the studio has already shipped at least once, so a genuinely
## new feature choice can pay a one-time experimentation research bonus.
var experimented_feature_ids: Array = []
var custom_engines: Array = []
var next_engine_number: int = 1

# --- Market ---
var genre_trends: Dictionary = {}           # genre_id -> popularity multiplier
var genre_saturation: Dictionary = {}       # genre_id -> recent release pressure
var weeks_until_trend_shift: int = 12

# --- Unlocks ---
var unlocked_genres: Array = []
var unlocked_themes: Array = []
var unlocked_sizes: Array = []
var known_platforms: Array = []

# --- Books ---
var staff_requests: Array[StaffRequest] = []
var departed_employees: Array[Employee] = []
## Absolute week index of each layoff, pruned by RetentionManager to a rolling
## window. Enough of them close together costs the studio its standing.
var recent_layoffs: Array = []
var next_request_number: int = 1

# --- Studio events ---
## The one decision waiting on the player, if any: {event_id, employee_id, weeks_left}.
var pending_studio_event: Dictionary = {}
## event_id -> absolute week it last fired, so an event does not recur immediately.
var studio_event_cooldowns: Dictionary = {}
## Transient consequences still in force: [{kind, amount, weeks_left}].
var studio_event_effects: Array = []

var crunch_teams: Array = []

var contract_offers: Array[Contract] = []
var active_contract: Contract = null
var completed_contracts: Array[Contract] = []
var contract_offer_weeks_left: int = 0
var next_contract_number: int = 1

var ledger: Array = []                      # rolling recent detail
var annual_finance: Dictionary = {}         # year -> permanent income/expense summary
var news: Array = []
var culture: Dictionary = {}
var milestones: Array = []

# --- Solvency ---
var overdrawn_weeks: int = 0
var bankrupt: bool = false

func difficulty() -> Dictionary:
    var found := DataManager.get_difficulty(difficulty_id)
    return found if not found.is_empty() else {
        "starting_cash": 10_000, "sales_multiplier": 1.0,
        "expense_multiplier": 1.0, "grace_weeks": 6
    }

func grace_weeks() -> int:
    return int(difficulty().get("grace_weeks", 6))

func next_request_id() -> String:
    var id := "request_%06d" % next_request_number
    next_request_number += 1
    return id

func next_contract_id() -> String:
    var id := "contract_%06d" % next_contract_number
    next_contract_number += 1
    return id

func next_project_id() -> String:
    var id := "project_%06d" % next_id
    next_id += 1
    return id

func next_employee_id() -> String:
    var id := "employee_%06d" % next_employee_number
    next_employee_number += 1
    return id

func find_game(id: String) -> GameProject:
    for game in released_games:
        if game.id == id:
            return game
    return null

func find_active_project(id: String) -> GameProject:
    for project in active_projects:
        if project.id == id:
            return project
    return null

func select_project(project: GameProject) -> void:
    current_project = project
    selected_project_id = project.id if project != null else ""

func has_title(title: String) -> bool:
    var wanted := title.strip_edges().to_lower()
    for project in active_projects:
        if project.title.strip_edges().to_lower() == wanted:
            return true
    for game in released_games:
        if game.title.strip_edges().to_lower() == wanted:
            return true
    return false

func add_fans(amount: int) -> void:
    # A disappointing release can lose followers, but never below zero.
    fans = maxi(fans + amount, 0)
    EventBus.company_fans_changed.emit(fans)

func add_consumer_reputation(amount: float) -> void:
    consumer_reputation = clampf(consumer_reputation + amount, 0.0, 100.0)

func add_employer_reputation(amount: float) -> void:
    employer_reputation = clampf(employer_reputation + amount, 0.0, 100.0)

func games_on_market() -> Array[GameProject]:
    var active: Array[GameProject] = []
    for game in released_games:
        if game.sales_active:
            active.append(game)
    return active

func has_income() -> bool:
    return not games_on_market().is_empty()

func pending_postmortems() -> Array[GameProject]:
    var pending: Array[GameProject] = []
    for game in released_games:
        if not game.sales_active and not game.postmortem_reviewed:
            pending.append(game)
    return pending

func abandon_project(project: GameProject = null) -> GameProject:
    if project == null:
        project = current_project
    if project == null:
        return null
    active_projects.erase(project)
    TeamManager.release_project(project)
    CultureManager.note_abandoned_project()
    EventBus.project_abandoned.emit(project)
    select_project(active_projects[0] if not active_projects.is_empty() else null)
    return project

func is_game_over() -> bool:
    return bankrupt

func start_company(
    name: String,
    founder: String,
    chosen_difficulty: String,
    pronoun_id: String = Pronouns.DEFAULT,
    appearance_index: int = 0,
    background_id: String = "generalist",
    trait_id: String = "perfectionist"
) -> void:
    var trimmed_name := name.strip_edges()
    var trimmed_founder := founder.strip_edges()
    company_name = trimmed_name if not trimmed_name.is_empty() else "Indie Empire"
    founder_name = trimmed_founder if not trimmed_founder.is_empty() else "You"
    founder_pronoun_id = pronoun_id if Pronouns.is_known(pronoun_id) else Pronouns.DEFAULT
    founder_background_id = (
        background_id if not DataManager.get_founder_background(background_id).is_empty()
        else "generalist")
    founder_trait_id = (
        trait_id if not DataManager.get_employee_trait(trait_id).is_empty()
        else "perfectionist")
    difficulty_id = chosen_difficulty
    reset_company()
    var created_founder := EmployeeManager.founder()
    if created_founder != null:
        created_founder.appearance_index = clampi(
            appearance_index, 0, OfficeCharacterArt.SHEETS.size() - 1)

func reset_company() -> void:
    TimeManager.reset_time()

    cash = int(difficulty().get("starting_cash", 10_000))
    fans = 0
    consumer_reputation = 0.0
    employer_reputation = 50.0
    founded_year = TimeManager.current_year
    founded_month = TimeManager.current_month
    founded_week = TimeManager.current_week

    current_project = null
    active_projects.clear()
    selected_project_id = ""
    released_games.clear()
    next_id = 1
    # Clear technology before anyone is seeded -- Employee.is_away() consults
    # ResearchManager, so no stale in-flight research must linger.
    EngineManager.reset_technology()
    ResearchManager.reset()
    CultureManager.seed_culture()
    EmployeeManager.seed_founder()
    TeamManager.seed_teams()
    labor_candidates.clear()
    labor_market_weeks_left = 0
    labor_market_generation = 0
    office_quality = 0
    office_id = "bedroom"
    owned_office_customizations = ["classic"]
    equipped_office_customization = "classic"
    office_remodel = {}
    LaborMarketManager.refresh_market(false)

    genre_experience.clear()
    theme_experience.clear()
    platform_experience.clear()
    combo_knowledge.clear()
    platform_genre_knowledge.clear()
    feature_knowledge.clear()

    genre_trends.clear()
    genre_saturation.clear()
    weeks_until_trend_shift = 12

    unlocked_genres.clear()
    unlocked_themes.clear()
    unlocked_sizes.clear()
    known_platforms.clear()

    ledger.clear()
    annual_finance.clear()
    staff_requests.clear()
    departed_employees.clear()
    recent_layoffs.clear()
    pending_studio_event.clear()
    studio_event_cooldowns.clear()
    studio_event_effects.clear()
    next_request_number = 1
    crunch_teams.clear()
    contract_offers.clear()
    active_contract = null
    completed_contracts.clear()
    contract_offer_weeks_left = 0
    next_contract_number = 1
    news.clear()
    milestones.clear()

    overdrawn_weeks = 0
    bankrupt = false

    MarketManager.seed_trends()
    PlatformManager.sync_year()
    UnlockManager.refresh(false)
    NewsManager.post_founding()
