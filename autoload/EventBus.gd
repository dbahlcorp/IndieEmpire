extends Node

## Every cross-system announcement in the game. Simulation emits, UI listens.
## Nothing here should ever reach into a screen directly.

# --- Time ---
signal week_ticked(year: int, month: int, week: int)
signal year_changed(year: int)

# --- Games ---
signal game_started(project: GameProject)
signal preproduction_completed(project: GameProject, modifier: float, flaw_label: String)
signal game_released(project: GameProject)
signal project_abandoned(project: GameProject)
signal game_hit_sales_milestone(project: GameProject, milestone: int)
signal game_sales_ended(project: GameProject)
signal game_breakout_hit(project: GameProject)
signal game_commercial_failure(project: GameProject)
## The live schedule forecast got measurably worse since it was last
## checked -- not a random event, but a read of the real bottleneck. See
## DelaySimulator and ProjectManager, which checks this every week.
signal project_schedule_slipped(project: GameProject, weeks: int, causes: Array)
## A franchise gained an entry, or its fan interest / fatigue / reputation
## moved. Emitted once per release from FranchiseManager. See PA.10.
signal franchise_updated(franchise: Franchise, project: GameProject)

signal employee_at_risk(employee: Employee)
signal employee_burnt_out(employee: Employee)
signal staff_request_raised(request: StaffRequest)
signal staff_request_refused(request: StaffRequest)
signal staff_request_ignored(request: StaffRequest)
signal employee_promoted(employee: Employee, seniority: String)
signal employee_raise_granted(employee: Employee, salary: int)
signal employee_resigned(employee: Employee)
signal employee_retained(employee: Employee)
signal employee_departed(employee: Employee)
## The studio let somebody go. Distinct from a resignation: severance is paid,
## the team takes it harder, and enough of them in a row costs the studio
## standing. Fired in place of employee_departed, not alongside it.
signal employee_laid_off(employee: Employee)
signal mass_layoffs_reported(count: int)

# --- Studio events ---
signal studio_event_raised(event_id: String)
signal studio_event_resolved(event_id: String, choice_index: int, outcome: String)
signal employee_concerned(employee: Employee, concerns: Array)
signal culture_shifted(id: String, before: float, after: float, cause: String)
signal employee_reputation_gained(employee: Employee, project: GameProject, amount: int)
signal employee_tier_up(employee: Employee, tier: String)

# --- Training ---
signal training_started(employee: Employee, course_id: String)
signal training_completed(employee: Employee, skill: String, gain: int)
## A specialization course paid off: employee.specialization_id is now set
## (or changed) to specialization_id. Separate from training_completed so a
## listener can react to the specialization itself without parsing which
## skill a course happened to teach. Distinct from seniority/promotion --
## see the comments on Employee.seniority and Employee.specialization_id.
signal employee_specialized(employee: Employee, specialization_id: String)

signal publishing_deal_signed(project: GameProject)

# --- Contracts ---
signal contract_accepted(contract: Contract)
signal contract_completed(contract: Contract)
signal contract_failed(contract: Contract, abandoned: bool)

# --- Platforms ---
signal platform_announced(platform: Dictionary)
signal platform_released(platform: Dictionary)
signal platform_retiring(platform: Dictionary)
signal platform_discontinued(platform: Dictionary)

# --- Market ---
signal genre_trend_changed(genre_id: String, before: float, after: float)

# --- Company ---
signal company_cash_changed(cash: int)
signal company_fans_changed(fans: int)
signal company_bankruptcy_warning(weeks_left: int)
signal company_recovered()
signal company_bankrupt()
signal employee_hired(employee: Employee)
signal labor_market_refreshed()
signal office_moved(office: Dictionary)
signal employee_workstation_equipped(employee: Employee, tier_id: String)
signal employee_skill_level_up(employee: Employee, skill: String, level: int)

# --- Progression ---
signal genre_unlocked(id: String, name: String)
signal theme_unlocked(id: String, name: String)
signal size_unlocked(id: String, name: String)
signal experience_level_up(kind: String, id: String, name: String, level: int)
signal research_points_gained(amount: float, reason: String)
signal research_started(tech_id: String, display_name: String)
signal research_completed(tech_id: String, display_name: String)
signal technology_researched(tech_id: String, display_name: String)
signal engine_project_started(name: String)
signal engine_completed(engine_id: String, name: String)
## Annual Game Awards (PA.11). award_nominated / award_won fire once per
## category per game as a ceremony is applied; awards_ceremony_held fires once
## with the whole year's result (the GameState.award_ceremonies entry) for the
## news feed and the ceremony screen.
signal award_nominated(project: GameProject, award_name: String)
signal award_won(project: GameProject, award_name: String)
signal awards_ceremony_held(ceremony: Dictionary)

# --- Contextual onboarding ---
signal tutorial_presented(id: String)
signal tutorial_completed(id: String)
signal onboarding_skipped()

# --- Feed and toasts ---
signal news_posted(item: Dictionary)
signal notification_requested(title: String, body: String, important: bool)

func notify(title: String, body: String, important: bool = false) -> void:
    notification_requested.emit(title, body, important)
