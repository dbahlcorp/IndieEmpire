class_name GameProject
extends RefCounted

## A game, from pitch to retirement. Identified by a stable id, never by title,
## so sequels and remasters can reference each other later.

# --- Identity ---
var id: String = ""
var title: String = ""
var genre_id: String = ""
var theme_id: String = ""
var platform_id: String = ""
var size_id: String = "small"
var team_id: String = ""
var engine_id: String = ""
## Chosen once at project start and fixed for the whole build. See
## FeatureSimulator and DevelopmentSimulator.required_effort().
var feature_ids: Array[String] = []
## Per-feature execution evidence accumulated as production advances. Kept
## separate from the catalog so balance data can evolve without rewriting the
## historical outcome of a shipped game.
var feature_outcomes: Dictionary = {}
var role_assignments: Dictionary = {}
## Franchise membership (PA.10). Empty until the game is released (an original
## becomes its own IP then) or the project is set up as a sequel. See
## FranchiseManager and Franchise.
var series_id: String = ""
## 1-based position in its franchise's release order. 1 == the original.
## Provisional while in development; re-derived from the final order at release.
var sequel_number: int = 1
## What kind of entry this is within its franchise. "original" or "sequel"
## today; "remake" / "remaster" / "spinoff" / "expansion" are reserved for
## future entry kinds and carry no distinct mechanics yet. See
## FranchiseSimulator.ENTRY_KINDS.
var entry_kind: String = "original"
## Who actually worked on this, refreshed every development week. Used after
## release -- once the team has moved on to something else -- to credit the
## right people for how the game went on to do.
var credited_employee_ids: Array[String] = []
## Whoever has the most leadership on the team, refreshed every development
## week. Not necessarily whoever is best at the actual work.
var lead_employee_id: String = ""

# --- Development history ---
var start_year: int = 0
var start_month: int = 1
var start_week: int = 1
var completion_year: int = 0
var completion_month: int = 1
var completion_week: int = 1
var development_weeks: int = 0
var polish_weeks: int = 0
var development_cost: int = 0
var platform_fee: int = 0
## What this project's team was paid while building it, accrued a week at a
## time. Payroll leaves the bank monthly as a company-wide cost and is *not*
## charged again here -- this is attribution, so a game's books show what it
## actually cost to make. Without it a release only had to out-earn its
## running costs, which nothing with a team ever failed to do.
var labour_cost: int = 0
var bugs_created: int = 0
var bugs_fixed: int = 0
## The truth. Never shown to the player directly while a project is in
## development -- see known_bugs.
var bugs: int = 0
## What QA has actually found so far. Always <= bugs; how far below is the
## whole point. See QASimulator.
var known_bugs: int = 0
## Concept and planning, before a line of real production work happens. See
## DevelopmentSimulator.advance_preproduction.
var preproduction_progress: float = 0.0
## Set once, when pre-production finishes: how much clearer -- or murkier --
## the plan left production. Applied to every week of production that
## follows. See PreproductionSimulator.
var production_efficiency_modifier: float = 0.0
## The bulk of the build. Only moves once pre-production is complete.
var development_progress: float = 0.0
var polishing: bool = false
## Optional. 0 means the player has not set one -- purely a self-imposed
## planning tool, nothing in the simulation enforces it.
var budget_target: int = 0
## Optional target release date. deadline_year 0 means the player has not
## set one -- same free pass as budget_target. See DeadlineSimulator.
var deadline_year: int = 0
var deadline_month: int = 1
var deadline_week: int = 1
## The best (lowest) live schedule forecast seen so far, as an absolute week
## index. 0 means nothing has been tracked yet. See DelaySimulator, which
## ratchets this forward only once a real slip is reported, so small weekly
## noise can accumulate into a real one instead of being silently rebased
## away.
var expected_completion_index: int = 0
## The player's live direction for each stage. Missing choices are Balanced so
## projects from older saves continue without a migration penalty.
var focus_choices: Dictionary = {}
## The player's one-time whole-project emphasis, chosen at greenlight and
## fixed for the build -- see ProjectPrioritySimulator. Missing choices are
## Normal, the same free-pass convention focus_choices already uses.
var priority_choices: Dictionary = {}

# --- Quality ---
var gameplay: float = 0.0
var technology: float = 0.0
var graphics: float = 0.0
var story: float = 0.0
var sound: float = 0.0
var innovation: float = 0.0
var polish: float = 0.0
var performance: float = 0.0
var narrative_quality: float = 0.0
## How well the game is tuned -- pacing, difficulty, systems that work
## together rather than against each other. Mostly earned in polish, where
## there is finally a whole game to actually balance.
var balance: float = 0.0

# --- Release ---
var release_year: int = 0
var release_month: int = 1
var release_week: int = 1
var review_score: float = 0.0
var critic_reviews: Array = []
var released: bool = false

# --- Sales ---
var weekly_sales: Array[int] = []
var weekly_revenue: Array[int] = []
var lifetime_sales: int = 0
var lifetime_revenue: int = 0
var weeks_on_market: int = 0
var sales_active: bool = false
var current_demand: float = 0.0
var retail_price: int = 15
var royalty: float = 0.0
var publisher_id: String = ""
var developer_share: float = 1.0
var publisher_reach: float = 1.0
var advance: int = 0
var advance_remaining: int = 0
var publisher_revenue: int = 0

# --- Reception ---
var word_of_mouth: float = 1.0
var fans_gained: int = 0
var reputation_gained: float = 0.0

# --- Analysis ---
var postmortem_reviewed: bool = false
var went_well: Array[String] = []
var went_poorly: Array[String] = []
var lessons: Array[String] = []

const FLOAT_FIELDS := [
    "preproduction_progress", "production_efficiency_modifier",
    "development_progress", "gameplay", "technology", "graphics", "story",
    "sound", "innovation", "polish", "review_score", "current_demand",
    "royalty", "word_of_mouth", "reputation_gained", "developer_share", "publisher_reach", "performance",
    "narrative_quality", "balance"
]
const INT_FIELDS := [
    "start_year", "start_month", "start_week", "completion_year",
    "completion_month", "completion_week", "development_weeks", "polish_weeks",
    "development_cost", "platform_fee", "labour_cost", "bugs_created", "bugs_fixed", "bugs", "known_bugs",
    "budget_target", "deadline_year", "deadline_month", "deadline_week",
    "expected_completion_index",
    "advance", "advance_remaining", "publisher_revenue",
    "release_year", "release_month", "release_week", "lifetime_sales",
    "lifetime_revenue", "weeks_on_market", "retail_price", "fans_gained",
    "sequel_number"
]
const STRING_FIELDS := ["id", "title", "genre_id", "theme_id", "platform_id", "size_id", "team_id",
    "publisher_id", "lead_employee_id", "engine_id", "series_id", "entry_kind"]
const BOOL_FIELDS := ["released", "sales_active", "postmortem_reviewed", "polishing"]
const STRING_ARRAY_FIELDS := [
    "went_well", "went_poorly", "lessons", "credited_employee_ids", "feature_ids"
]
const INT_ARRAY_FIELDS := ["weekly_sales", "weekly_revenue"]

func average_quality() -> float:
    ## Balance is not folded into this average -- like polish, it earns its
    ## own weight in ReviewSimulator instead of diluting the core blend the
    ## rest of the economy is tuned around.
    return (
        gameplay + technology + graphics + story + sound + innovation + polish
        + performance + narrative_quality
    ) / 9.0

func total_weeks() -> int:
    return development_weeks + polish_weeks

func current_phase() -> String:
    ## Pre-Production -> Production -> Polish -> Released. Polish has no hard
    ## finish line -- it is done once the player decides it is.
    if released:
        return "released"
    if preproduction_progress < 100.0:
        return "pre_production"
    if development_progress < 100.0:
        return "production"
    return "polish"

func phase_label() -> String:
    match current_phase():
        "pre_production":
            return "PRE-PRODUCTION"
        "production":
            return "PRODUCTION"
        "polish":
            return "POLISH"
        _:
            return "RELEASED"

func cash_cost() -> int:
    ## What came out of this project's own budget. The development budget the
    ## player sets, and what a publisher advances against, are both about this
    ## number rather than the fully-loaded one.
    return development_cost + platform_fee

func total_cost() -> int:
    ## What the game actually cost to make, wages included.
    return cash_cost() + labour_cost

func profit() -> int:
    ## The advance counts as income: it is money the studio actually received.
    return lifetime_revenue + advance - total_cost()

func is_self_published() -> bool:
    return PublishingSimulator.is_self_published(publisher_id)

func preproduction_flaw_label() -> String:
    ## Empty for the ordinary middle -- only named at the extremes.
    return PreproductionSimulator.label(production_efficiency_modifier)

func is_profitable() -> bool:
    return profit() > 0

func peak_week_units() -> int:
    var best := 0
    for units in weekly_sales:
        best = maxi(best, units)
    return best

func last_week_units() -> int:
    if weekly_sales.is_empty():
        return 0
    return weekly_sales[weekly_sales.size() - 1]

func release_date_label() -> String:
    return TimeManager.format_date(release_year, release_month, release_week)

func start_date_label() -> String:
    return TimeManager.format_date(start_year, start_month, start_week)

func completion_date_label() -> String:
    return TimeManager.format_date(completion_year, completion_month, completion_week)

func in_franchise() -> bool:
    return not series_id.is_empty()

func is_sequel() -> bool:
    return sequel_number > 1

func has_deadline() -> bool:
    return deadline_year > 0

func deadline_label() -> String:
    return TimeManager.format_month(deadline_year, deadline_month) if has_deadline() else "—"

func clear_deadline() -> void:
    deadline_year = 0
    deadline_month = 1
    deadline_week = 1

func to_dict() -> Dictionary:
    var data: Dictionary = {}
    for field in STRING_FIELDS + INT_FIELDS + FLOAT_FIELDS + BOOL_FIELDS:
        data[field] = get(field)
    for field in INT_ARRAY_FIELDS + STRING_ARRAY_FIELDS:
        data[field] = get(field)
    data["critic_reviews"] = critic_reviews
    data["role_assignments"] = role_assignments.duplicate()
    data["focus_choices"] = focus_choices.duplicate()
    data["priority_choices"] = priority_choices.duplicate()
    data["feature_outcomes"] = feature_outcomes.duplicate(true)
    return data

static func from_dict(data: Dictionary) -> GameProject:
    var project := GameProject.new()

    for field in STRING_FIELDS:
        project.set(field, str(data.get(field, "")))
    for field in INT_FIELDS:
        project.set(field, int(data.get(field, 0)))
    for field in FLOAT_FIELDS:
        project.set(field, float(data.get(field, 0.0)))
    # Projects from saves predating these measures inherit nearby disciplines.
    if not data.has("performance"):
        project.performance = project.technology * 0.85
    if not data.has("narrative_quality"):
        project.narrative_quality = project.story * 0.85
    if not data.has("balance"):
        # A save from before balance existed did all its tuning as part of
        # gameplay -- the closest existing measure of the same thing.
        project.balance = project.gameplay * 0.85
    # sequel_number is 1-based; a pre-PA.10 save has no field and reads 0.
    if project.sequel_number < 1:
        project.sequel_number = 1
    if project.entry_kind.is_empty():
        project.entry_kind = "sequel" if project.sequel_number > 1 else "original"
    # Saves from before phases existed: a project already under way was never
    # in pre-production to begin with, so it should not be sent back to it.
    if not data.has("preproduction_progress") and (
        project.development_progress > 0.0 or project.released
    ):
        project.preproduction_progress = 100.0
    for field in BOOL_FIELDS:
        project.set(field, bool(data.get(field, false)))

    for field in INT_ARRAY_FIELDS:
        var numbers: Array[int] = []
        for value in data.get(field, []):
            numbers.append(int(value))
        project.set(field, numbers)

    for field in STRING_ARRAY_FIELDS:
        var lines: Array[String] = []
        for value in data.get(field, []):
            lines.append(str(value))
        project.set(field, lines)

    var reviews: Array = []
    for entry in data.get("critic_reviews", []):
        if entry is Dictionary:
            reviews.append({
                "outlet": str(entry.get("outlet", "")),
                "score": float(entry.get("score", 0.0))
            })
    project.critic_reviews = reviews

    for role_id in data.get("role_assignments", {}):
        project.role_assignments[str(role_id)] = str(data["role_assignments"][role_id])

    var saved_focuses: Dictionary = {}
    if data.get("focus_choices", {}) is Dictionary:
        saved_focuses = data.get("focus_choices", {})
    for phase in DevelopmentFocusSimulator.OPTIONS:
        var focus_id := str(saved_focuses.get(phase, DevelopmentFocusSimulator.DEFAULT_ID))
        project.focus_choices[phase] = (
            focus_id if DevelopmentFocusSimulator.is_valid(phase, focus_id)
            else DevelopmentFocusSimulator.DEFAULT_ID)

    var saved_priorities: Dictionary = {}
    if data.get("priority_choices", {}) is Dictionary:
        saved_priorities = data.get("priority_choices", {})
    project.priority_choices = ProjectPrioritySimulator.sanitize(saved_priorities)

    var saved_outcomes = data.get("feature_outcomes", {})
    if saved_outcomes is Dictionary:
        for feature_id in saved_outcomes:
            var raw = saved_outcomes[feature_id]
            if raw is Dictionary:
                project.feature_outcomes[str(feature_id)] = {
                    "progress": float(raw.get("progress", 0.0)),
                    "execution_total": float(raw.get("execution_total", 0.0)),
                    "genre_relevance": float(raw.get("genre_relevance", 1.0)),
                    "realised_potential": float(raw.get("realised_potential", 0.0))
                }

    if project.id.is_empty():
        project.id = GameState.next_project_id()
    if project.word_of_mouth <= 0.0:
        project.word_of_mouth = 1.0

    return project

func focus_id(phase: String) -> String:
    var value := str(focus_choices.get(phase, DevelopmentFocusSimulator.DEFAULT_ID))
    return value if DevelopmentFocusSimulator.is_valid(phase, value) \
        else DevelopmentFocusSimulator.DEFAULT_ID

func set_focus(phase: String, focus_id_value: String) -> bool:
    if not DevelopmentFocusSimulator.is_valid(phase, focus_id_value):
        return false
    focus_choices[phase] = focus_id_value
    return true

func priority_level(category: String) -> String:
    var value := str(priority_choices.get(category, ProjectPrioritySimulator.DEFAULT_LEVEL))
    return value if ProjectPrioritySimulator.is_valid_level(value) \
        else ProjectPrioritySimulator.DEFAULT_LEVEL
