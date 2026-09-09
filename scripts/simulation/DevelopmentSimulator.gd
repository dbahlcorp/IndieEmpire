class_name DevelopmentSimulator
extends RefCounted

const BASE_WEEKLY_COST := 380
const BASE_POLISH_COST := 500

## How much quality one unit of completed work is worth. Production quality is
## banked per unit of work finished rather than per week elapsed -- see the
## `content` term in advance_project() -- and this sets the exchange rate.
##
## Calibrated so a competent team still lands near its size's authored
## `expected_quality`, which is what ReviewSimulator measures a release
## against. Retuning it moves every review score, so measure with the balance
## probe rather than adjusting it by eye.
const QUALITY_PER_WORK_UNIT := 0.0667

## How far past its own size's quality bar a project keeps absorbing effort at
## full rate, before returns fall away. A scope holds what it holds: there is
## only so much game in a Tiny game, and past a point extra craft has nothing
## left to attach itself to.
##
## This is the quality half of what `max_useful_staff` already does for
## throughput. Without it, Tiny was the one size whose team could vastly exceed
## what its scope called for -- a cash-strapped veteran studio falling back to a
## small project brought a dozen people's craft to a bar authored for a founder
## in a bedroom. Measured ratios drifted 0.96 (1985-87) to 1.94 (1991-93), while
## Medium and Large held 0.95-0.99 and 0.94-1.04 across the same career, because
## those sizes are only ever attempted by teams sized for them. 70% of late
## Tiny releases pinned the review-side over-delivery clamp and scored an
## identical 8.5, which is both too high and completely undifferentiated.
const SCOPE_ABSORPTION := 0.18

static func scope_absorption(project: GameProject) -> float:
    ## What share of this week's craft the project can still take on, given how
    ## far past its size's bar it already is. 1.0 until the bar is met, then
    ## decaying -- asymptotic rather than a wall, so a genuinely exceptional
    ## small game can still pull ahead of a merely good one instead of every
    ## over-resourced project landing on the same clipped number.
    var expected := maxf(float(DataManager.get_size(
        project.size_id).get("expected_quality", 100)), 1.0)
    var over := project.average_quality() / expected - 1.0
    if over <= 0.0:
        return 1.0
    return exp(-over / SCOPE_ABSORPTION)

## How much concept-and-planning work a size implies, authored rather than
## derived from the main "work" budget -- pre-production does not scale with
## a project the same way production does, so a fraction of "work" quietly
## under- or over-sized it at the extremes.
const PREPRODUCTION_WORK := {"small": 36.0, "medium": 55.0, "large": 75.0, "aaa": 110.0}
## How much accumulated polish reads as a complete pass, for the phase bar.
## Purely a display target -- the player can keep polishing past it.
const POLISH_TARGET := {"small": 50.0, "medium": 120.0, "large": 220.0, "aaa": 380.0}

static func polish_target(size_id: String) -> float:
    return float(POLISH_TARGET.get(size_id, 90.0))

static func required_effort(size_id: String, feature_ids: Array = []) -> float:
    ## What the size alone asks for, plus whatever the chosen features add.
    ## The single source every production-phase read of "work" should use --
    ## see advance_project(), estimate_remaining() and the pre-start preview.
    var size := DataManager.get_size(size_id)
    return maxf(float(size.get("work", 100)) + float(FeatureSimulator.effort_bonus(feature_ids)), 1.0)

static func polish_percent(project: GameProject) -> float:
    return clampf(project.polish / polish_target(project.size_id) * 100.0, 0.0, 100.0)

static func drop_feature(project: GameProject, feature_id: String) -> bool:
    ## Cuts scope mid-build, in answer to a projected deadline miss: the
    ## feature's effort bonus comes off required_effort() immediately, since
    ## that reads project.feature_ids live, and FeatureSimulator stops paying
    ## out its remaining quality_potential from here on. Whatever quality it
    ## already banked stays.
    if project == null or project.released or not project.feature_ids.has(feature_id):
        return false
    project.feature_ids.erase(feature_id)
    return true

static func estimate_remaining(project: GameProject) -> Dictionary:
    ## A live re-forecast from wherever the project actually is right now --
    ## the same maths the pre-start estimate uses, just picking up mid-flight
    ## instead of from zero. Empty once there is nothing left to project
    ## through: released, or already in polish, which has no finish line to
    ## estimate against.
    if project == null or project.released or project.current_phase() == "polish":
        return {}
    return _estimate(project)

static func schedule_drag() -> float:
    ## What is slowing the studio down this week on top of the team itself.
    ## A studio event -- a failed workstation, a burst pipe -- is a penalty, so
    ## it stays outside the bonus cap at full weight: trouble should be felt.
    ##
    ## The upsides that used to sit beside it here (the plan, engine tooling,
    ## culture) now go through staff_effects() instead, so that everything
    ## bearing on pace resolves through one cap rather than two that multiply.
    ##
    ## Shared with the schedule estimate on purpose. These were two separate
    ## copies of the same arithmetic and had already drifted -- the estimate
    ## left the engine's progress bonus out, so a studio with build tools was
    ## quoted a slower schedule than it actually ran.
    return StudioEventManager.development_efficiency_multiplier()

static func _estimate(project: GameProject) -> Dictionary:

    var size := DataManager.get_size(project.size_id)
    var staff := staff_effects(project)
    var lead := LeadershipSimulator.pick_lead(TeamManager.working_members(project.team_id))
    var leadership := float(lead.leadership) if lead != null else LeadershipSimulator.BASELINE
    var half_width := LeadershipSimulator.schedule_half_width(leadership)
    var complexity_budget := FeatureSimulator.complexity_budget(project.size_id, project.feature_ids)
    if bool(complexity_budget.get("over_scoped", false)):
        half_width *= 1.0 + minf((float(complexity_budget["ratio"]) - 1.0) * 0.35, 0.65)
    var preprod_drag := schedule_drag()

    var preprod_remaining := maxf(100.0 - project.preproduction_progress, 0.0)
    var preprod_work := float(PREPRODUCTION_WORK.get(project.size_id, 45.0))
    var preprod_staff := float(staff.get("preproduction_progress", 1.0))
    var preprod_focus := DevelopmentFocusSimulator.multiplier(
        project, "pre_production", "progress")
    var preprod_rate_fast := (
        (12.0 + half_width) * (100.0 / maxf(preprod_work, 1.0)) * preprod_staff
        * preprod_drag * preprod_focus)
    var preprod_rate_slow := (
        maxf(12.0 - half_width, 1.0) * (100.0 / maxf(preprod_work, 1.0)) * preprod_staff
        * preprod_drag * preprod_focus)
    var preprod_weeks_fast := preprod_remaining / maxf(preprod_rate_fast, 0.0001)
    var preprod_weeks_slow := preprod_remaining / maxf(preprod_rate_slow, 0.0001)

    # Production has not started until pre-production finishes, so from
    # inside pre-production the whole run is still ahead of it.
    var prod_remaining := (
        100.0 if project.preproduction_progress < 100.0
        else maxf(100.0 - project.development_progress, 0.0))
    var work := required_effort(project.size_id, project.feature_ids)
    var prod_staff := float(staff.get("progress", 1.0))
    var plan_drag := schedule_drag()
    var production_focus := DevelopmentFocusSimulator.multiplier(
        project, "production", "progress")
    var prod_rate_fast := (
        (11.0 + half_width) * (100.0 / work) * prod_staff
        * plan_drag * production_focus)
    var prod_rate_slow := (
        maxf(11.0 - half_width, 1.0) * (100.0 / work) * prod_staff
        * plan_drag * production_focus)
    var prod_weeks_fast := prod_remaining / maxf(prod_rate_fast, 0.0001)
    var prod_weeks_slow := prod_remaining / maxf(prod_rate_slow, 0.0001)

    var weeks_min := maxi(int(ceil(preprod_weeks_fast + prod_weeks_fast)), 0)
    var weeks_max := maxi(int(ceil(preprod_weeks_slow + prod_weeks_slow)), weeks_min)

    var headcount := TeamManager.working_members(project.team_id).size()
    var ideal_max := int(size.get("max_useful_staff", 99))
    var multiplier := (
        float(size.get("cost_multiplier", 1.0)) * platform_cost_multiplier(project.platform_id)
        * ScopeSimulator.cost_overhead_multiplier(headcount, ideal_max)
    )

    return {
        "weeks_min": weeks_min,
        "weeks_max": weeks_max,
        "cost_min": _remaining_cost(
            project, int(ceil(preprod_weeks_fast)), int(ceil(prod_weeks_fast)), multiplier),
        "cost_max": _remaining_cost(
            project, int(ceil(preprod_weeks_slow)), int(ceil(prod_weeks_slow)), multiplier)
    }

static func _remaining_cost(project: GameProject, preprod_weeks: int, prod_weeks: int, multiplier: float) -> int:
    var cost := 0
    if project.preproduction_progress < 100.0:
        # total_weeks() stays at zero throughout pre-production, so it never
        # ramps -- every remaining week costs the same flat rate.
        var preprod_base := BASE_WEEKLY_COST + 15
        for i in preprod_weeks:
            cost += era_cost(int(round(
                float(preprod_base) * multiplier * PREPRODUCTION_COST_SHARE
                * DevelopmentFocusSimulator.multiplier(project, "pre_production", "cost"))))
    for i in prod_weeks:
        var week_index := project.development_weeks + i + 1
        var base := BASE_WEEKLY_COST + week_index * 15
        cost += era_cost(int(round(float(base) * multiplier
            * DevelopmentFocusSimulator.multiplier(project, "production", "cost"))))
    return cost

static func get_upfront_cost(platform_id: String, size_id: String = "small") -> int:
    var platform := DataManager.get_platform(platform_id)
    var size := DataManager.get_size(size_id)
    var base := int(platform.get("development_cost", 500)) + 1_200
    return era_cost(int(base * float(size.get("cost_multiplier", 1.0))))

static func get_platform_fee(platform_id: String) -> int:
    var platform := DataManager.get_platform(platform_id)
    return int(platform.get("platform_fee", 0))

static func get_minimum_project_cost() -> int:
    var cheapest := -1
    for platform in PlatformManager.available_platforms():
        var id := str(platform.get("id", ""))
        var cost := get_upfront_cost(id, "small") + get_platform_fee(id)
        if cheapest < 0 or cost < cheapest:
            cheapest = cost
    return cheapest if cheapest >= 0 else 2_000

static func platform_cost_multiplier(platform_id: String) -> float:
    var platform := DataManager.get_platform(platform_id)
    return float(platform.get("cost_multiplier", 1.0))

static func get_weekly_cost(project: GameProject) -> int:
    var size := DataManager.get_size(project.size_id)
    var multiplier := float(size.get("cost_multiplier", 1.0)) * platform_cost_multiplier(project.platform_id)
    # A crowd on a small project still has to be paid, desked and
    # coordinated -- the week costs more for it, not the same for no extra
    # speed. This is what stops brute-force staffing being free.
    var headcount := TeamManager.working_members(project.team_id).size()
    var ideal_max := int(size.get("max_useful_staff", 99))
    multiplier *= ScopeSimulator.cost_overhead_multiplier(headcount, ideal_max)
    var base := BASE_WEEKLY_COST + int((project.total_weeks() + 1) * 15)
    var phase := project.current_phase()
    if phase not in ["pre_production", "production"]:
        phase = "production"
    multiplier *= DevelopmentFocusSimulator.multiplier(project, phase, "cost")
    return era_cost(int(round(float(base) * multiplier)))

static func era_cost(amount: int) -> int:
    ## Difficulty, then the times. Salaries and rent already drift with
    ## InflationSimulator; the development budget did not, so a 2050 project
    ## was quoted 1985 prices while paying 2050 wages out of the same studio.
    return FinanceManager.expense(int(round(float(amount)
        * InflationSimulator.multiplier_for_year(TimeManager.current_year))))

static func weekly_labour_cost(project: GameProject) -> int:
    ## A week of this team's wages. Everyone on the team counts, including
    ## anyone away on a course -- they are still paid, and they are still this
    ## project's cost. Charged to the project's books only; the money itself
    ## leaves the bank monthly through payroll.
    var monthly := 0
    for employee in TeamManager.members(project.team_id):
        monthly += employee.salary
    return int(round(float(monthly) * 12.0 / 52.0))

static func accrue_labour(project: GameProject) -> int:
    var weekly := weekly_labour_cost(project)
    project.labour_cost += weekly
    return weekly

static func get_polish_cost(project: GameProject) -> int:
    var size := DataManager.get_size(project.size_id)
    var multiplier := float(size.get("cost_multiplier", 1.0)) * platform_cost_multiplier(project.platform_id)
    multiplier *= DevelopmentFocusSimulator.multiplier(project, "polish", "cost")
    return era_cost(int(round(float(BASE_POLISH_COST) * multiplier)))

static func start_project(
    title: String, theme_id: String, genre_id: String, platform_id: String,
    size_id: String, team_id: String = "team_a", assignments: Dictionary = {},
    engine_id: String = "", feature_ids: Array = [], priority_choices: Dictionary = {},
    series_id: String = ""
) -> GameProject:
    var team := TeamManager.find_team(team_id)
    if team == null or not team.project_id.is_empty():
        return null

    # The team's time is already sold to a client.
    var contract := GameState.active_contract
    if contract != null and contract.team_id == team_id:
        return null

    # An empty dictionary means "staff it the obvious way", which is what the
    # default argument implies. Previously it could never validate.
    var resolved := assignments.duplicate() if not assignments.is_empty()         else TeamManager.default_assignments(team_id)
    if not TeamManager.valid_assignments(team_id, resolved):
        return null
    # An empty dictionary means "leave everything Normal", which is always
    # within budget by construction -- see ProjectPrioritySimulator.BUDGET.
    # Anything else has to actually respect the point budget: the picker UI
    # already refuses to reach an invalid combination by tapping alone, but a
    # caller that skips the UI (a stale draft, a future automation) does not
    # get a free pass around the tradeoff.
    if not priority_choices.is_empty() and not ProjectPrioritySimulator.is_within_budget(priority_choices):
        return null
    var upfront := get_upfront_cost(platform_id, size_id)
    var fee := get_platform_fee(platform_id)
    if not FinanceManager.can_afford(upfront + fee):
        return null

    var project := GameProject.new()
    project.id = GameState.next_project_id()
    project.title = title
    project.theme_id = theme_id
    project.genre_id = genre_id
    project.platform_id = platform_id
    project.size_id = size_id
    project.team_id = team_id
    project.engine_id = engine_id if EngineManager.has_engine(engine_id) else ""
    # A stale selection (the year moved on, a prerequisite was removed, or
    # the selected engine lacks a capability) is dropped rather than trusted.
    var chosen: Array[String] = []
    var selected_engine_features := FeatureSimulator.engine_features(project.engine_id)
    for id in feature_ids:
        var feature := DataManager.get_game_feature(str(id))
        if not feature.is_empty() and FeatureSimulator.is_available(
                feature, TimeManager.current_year, GameState.completed_technologies,
                selected_engine_features, chosen):
            chosen.append(str(id))
    project.feature_ids = chosen
    project.role_assignments = resolved
    project.priority_choices = ProjectPrioritySimulator.sanitize(priority_choices)
    # A sequel: link it to the franchise now so development-time UI and the
    # production-phase bonuses can read it. Ignored if the series is unknown.
    if not series_id.is_empty() and FranchiseManager.attach_to_series(project, series_id):
        project.entry_kind = "sequel"
    project.start_year = TimeManager.current_year
    project.start_month = TimeManager.current_month
    project.start_week = TimeManager.current_week

    FinanceManager.spend(upfront, Ledger.Kind.UPFRONT, "%s project start" % title, project.id)
    project.development_cost = upfront

    if fee > 0:
        FinanceManager.spend(fee, Ledger.Kind.PLATFORM_FEE, "%s platform licence" % title, project.id)
        project.platform_fee = fee

    team.project_id = project.id
    _refresh_lead(project)
    GameState.active_projects.append(project)
    GameState.select_project(project)
    EventBus.game_started.emit(project)
    return project

static func process_week(project: GameProject) -> Dictionary:
    ## One week of work, chosen by the project's own phase.
    if project == null or project.released:
        return {}
    if project.preproduction_progress < 100.0:
        return advance_preproduction(project)
    if project.development_progress >= 100.0:
        return polish_week(project) if project.polishing else {}
    return advance_project(project)

## A small planning effort costs less than a full production team, and this
## phase adds real weeks a first project's tight starting budget was never
## charged for before it existed. Without a discount here, a first project's
## total cost quietly eats almost the entire starting stake before a single
## sale, leaving no room for an ordinary bad week.
const PREPRODUCTION_COST_SHARE := 0.60

static func advance_preproduction(project: GameProject) -> Dictionary:
    ## Concept and planning. No quality stats accumulate yet, and nothing can
    ## go wrong that QA would need to catch -- there is nothing built.
    if project.released:
        return {}

    var weekly_cost := int(round(float(get_weekly_cost(project)) * PREPRODUCTION_COST_SHARE))
    FinanceManager.force_spend(
        weekly_cost, Ledger.Kind.DEVELOPMENT, "%s pre-production" % project.title, project.id)

    var leadership := _refresh_lead(project)
    var staff := staff_effects(project)

    var scale := 100.0 / maxf(PREPRODUCTION_WORK.get(project.size_id, 45.0), 1.0)
    var half_width := LeadershipSimulator.schedule_half_width(leadership)
    var weekly_roll := randf_range(12.0 - half_width, 12.0 + half_width)
    project.preproduction_progress = minf(
        project.preproduction_progress
            + weekly_roll * scale * float(staff["preproduction_progress"]) * schedule_drag()
                * DevelopmentFocusSimulator.multiplier(
                    project, "pre_production", "progress"),
        100.0
    )
    project.development_cost += weekly_cost
    accrue_labour(project)

    if project.preproduction_progress >= 100.0:
        _complete_preproduction(project, staff)

    return {"weekly_cost": weekly_cost, "phase": "pre_production"}

static func _complete_preproduction(project: GameProject, staff: Dictionary) -> void:
    ## A strong planning phase gives real production a head start on
    ## direction and voice -- it does not touch the disciplines that only
    ## exist once something is actually being built. A weak one leaves the
    ## whole rest of production paying for it.
    var effectiveness := float(staff.get("preproduction_progress", 1.0))
    var quality := PreproductionSimulator.quality_bonus(effectiveness)
    project.innovation += quality * 6.0 * DevelopmentFocusSimulator.quality_multiplier(
        project, "pre_production", "innovation")
    project.narrative_quality += quality * 5.0 * DevelopmentFocusSimulator.quality_multiplier(
        project, "pre_production", "narrative_quality") * ProjectPrioritySimulator.quality_multiplier(
        project.priority_choices, "narrative_quality")

    project.production_efficiency_modifier = PreproductionSimulator.production_efficiency_modifier(
        effectiveness) + float(DevelopmentFocusSimulator.choice(
            project, "pre_production").get("efficiency_add", 0.0))
    EventBus.preproduction_completed.emit(
        project, project.production_efficiency_modifier, project.preproduction_flaw_label())

static func advance_project(project: GameProject) -> Dictionary:
    if project.released:
        return {}

    var weekly_cost := get_weekly_cost(project)
    FinanceManager.force_spend(
        weekly_cost, Ledger.Kind.DEVELOPMENT, "%s development" % project.title, project.id)

    var leadership := _refresh_lead(project)
    var work := required_effort(project.size_id, project.feature_ids)
    var progress_scale := 100.0 / work
    var staff := staff_effects(project)
    var feature_effort := float(FeatureSimulator.effort_bonus(project.feature_ids))
    var feature_share := clampf(feature_effort / maxf(work, 1.0), 0.0, 0.80)
    var feature_capacity := lerpf(
        1.0, FeatureSimulator.execution_multiplier(project.feature_ids, staff), feature_share)
    # A disciplined studio wastes less of the week -- that one is folded into
    # staff_effects(); a meticulous one ships fewer bugs; an adventurous one
    # takes more chances. All small.
    var culture_bugs := CultureSimulator.bug_multiplier(CultureManager.value("quality_focus"))
    var culture_innovation := CultureSimulator.innovation_multiplier(
        CultureManager.value("creative_freedom"))
    var engine := EngineManager.effects_for(project.engine_id)
    # How the engine itself is to work with this week: team familiarity, age
    # and accumulated modifications. 1.0 with no custom engine. Small, capped.
    var engine_condition := EngineManager.condition_for(project.engine_id)

    # PA.10 -- what a sequel inherits from its franchise. All null-safe: a
    # standalone game, or a franchise's own first entry, gets 1.0 / 1.0 / 1.0.
    var franchise := FranchiseManager.active_franchise(project)
    var franchise_speed := 1.0 + FranchiseSimulator.team_familiarity_speed_bonus(franchise)
    var franchise_quality := 1.0 + FranchiseSimulator.design_knowledge_quality_bonus(franchise)
    var franchise_novelty := 1.0
    if franchise != null:
        franchise_novelty = FranchiseSimulator.novelty_multiplier(
            franchise.weeks_since_last_release())

    project.development_weeks += 1
    # The midpoint (11.0) matches the old flat randf_range(8, 14): a strong
    # lead only narrows the swing around it, an absent or weak one widens it.
    # Average speed is untouched -- this is about a steady schedule, not a
    # faster one.
    var half_width := LeadershipSimulator.schedule_half_width(leadership)
    var weekly_roll := randf_range(11.0 - half_width, 11.0 + half_width)
    # The plan set at the end of pre-production speeds every week that follows
    # -- that goes through staff_effects() with the rest of the pace bonuses.
    # What is left here is a studio event dragging on the week, which is a
    # penalty and so stays outside the cap.
    var plan_drag := schedule_drag()
    var progress_before := project.development_progress
    project.development_progress = minf(
        project.development_progress
            + weekly_roll * progress_scale * float(staff["progress"]) * plan_drag * feature_capacity
                * float(engine_condition["speed"]) * franchise_speed
                * DevelopmentFocusSimulator.multiplier(
                    project, "production", "progress"),
        100.0
    )
    # Chosen features pay out their quality potential in proportion to the
    # production progress actually made this week, so a feature nobody
    # finished building never counts, and one built steadily across the whole
    # project earns its full worth by the end.
    FeatureSimulator.apply_quality_potential(
        project, project.development_progress - progress_before, staff)

    var compatibility := _calculate_compatibility(project)
    var genre_bonus := ExperienceManager.genre_bonus(project.genre_id)
    var theme_bonus := ExperienceManager.theme_bonus(project.theme_id)
    var platform_bonus := ExperienceManager.platform_bonus(project.platform_id)
    var output := float(staff["effective_team_output"])

    # Quality is banked against the work actually finished this week, not
    # against the calendar. It used to be a flat per-week amount while the
    # finish line stayed fixed at 100% progress, which meant a *slower* team
    # banked more quality for the same project: total quality came out
    # proportional to work / pace, so the team's own craft largely cancelled
    # out and every pace bonus quietly made the game worse. Capping those
    # bonuses made reviews go up, which is how this was found.
    #
    # Paying per unit of work completed decouples the two. Speed now means
    # throughput -- more games per year -- rather than worse games, and a
    # better team makes a better game instead of a faster one.
    #
    # This is the same rule FeatureSimulator.apply_quality_potential() already
    # used for chosen features; the core stats simply were not on it.
    var built := (project.development_progress - progress_before) / 100.0
    # franchise_quality folds in a sequel's reused design knowledge -- small, and
    # smaller than the review bar its franchise standing raises (see
    # FranchiseSimulator). 1.0 for a standalone game.
    var content := built * work * QUALITY_PER_WORK_UNIT * scope_absorption(project) * franchise_quality

    # Each stat draws on a different mix of what the studio knows and what its
    # engine can do, so each gets its own stack -- but every stack is bounded
    # the same way, and within a category the parts add rather than multiply.
    # Compatibility, the focus and team size stay outside: the first two are
    # trade-offs and the third is capacity, not a bonus. See BonusStack.
    var gameplay_bonus := BonusStack.combine({
        BonusStack.KNOWLEDGE: [genre_bonus, theme_bonus]})
    var technology_bonus := BonusStack.combine({
        BonusStack.KNOWLEDGE: [platform_bonus],
        BonusStack.STRATEGY: [engine["technology"]]})
    var graphics_bonus := BonusStack.combine({
        BonusStack.KNOWLEDGE: [platform_bonus],
        BonusStack.STRATEGY: [engine["graphics"]]})
    var story_bonus := BonusStack.combine({
        BonusStack.KNOWLEDGE: [theme_bonus]})
    var sound_bonus := BonusStack.combine({
        BonusStack.STRATEGY: [engine["sound"]]})
    var innovation_bonus := BonusStack.combine({
        BonusStack.TEAM: [staff["innovation_modifier"], culture_innovation]})
    var performance_bonus := BonusStack.combine({
        BonusStack.STRATEGY: [engine["performance"]]})

    _add_focused_quality(project, "production", "gameplay",
        randf_range(3.0, 7.0) * compatibility * float(staff["design"]) * output * gameplay_bonus * content)
    _add_focused_quality(project, "production", "technology",
        randf_range(2.5, 6.0) * float(staff["programming"]) * output * technology_bonus * content)
    _add_focused_quality(project, "production", "graphics",
        randf_range(2.0, 5.0) * float(staff["art"]) * output * graphics_bonus * content)
    _add_focused_quality(project, "production", "story",
        randf_range(2.0, 6.0) * _story_weight(project.genre_id)
            * float(staff["writing"]) * output * story_bonus * content)
    _add_focused_quality(project, "production", "sound",
        randf_range(1.5, 4.0) * float(staff["audio"]) * output * sound_bonus * content)
    _add_focused_quality(project, "production", "innovation",
        randf_range(1.0, 4.0) * compatibility * float(staff["design"])
            * output * innovation_bonus * content * franchise_novelty)
    _add_focused_quality(project, "production", "performance",
        randf_range(2.0, 5.0) * float(staff["programming"]) * output * performance_bonus * content)
    _add_focused_quality(project, "production", "narrative_quality",
        randf_range(1.5, 4.0) * (float(staff["writing"]) * 0.80
            + float(staff["design"]) * 0.20) * output * content)
    var polish_staff := (
        float(staff["polish_art"]) * 0.35 + float(staff["polish_testing"]) * 0.25
        + float(staff["polish_production"]) * 0.40
    )
    _add_focused_quality(project, "production", "polish",
        randf_range(1.0, 3.0) * polish_staff * output * content)
    # Balance is a core stat like gameplay or technology, not a refinement
    # like polish -- a design-led team is already tuning as they build. Sized
    # to match its production-phase siblings, so a project that never enters
    # polish is not quietly punished on a stat it never had a fair shot at.
    _add_focused_quality(project, "production", "balance",
        randf_range(2.0, 5.0) * float(staff["design"]) * output * content)

    # Tired people ship more bugs: the other half of the crunch bargain.
    var crunch_bugs := MoraleManager.crunch_bug_multiplier(project.team_id)
    var bug_risk := crunch_bugs * culture_bugs * (
        (1.30 - float(staff["testing"]) * 0.32 - float(staff["programming"]) * 0.12)
        * (1.0 + float(staff["overload"]) * 0.8) * float(staff["chemistry_bug"])
        * float(engine["bugs"]) * float(engine_condition["bugs"])
        * FeatureSimulator.bug_risk_multiplier(
            project.feature_ids, project.size_id)
        * DevelopmentFocusSimulator.multiplier(project, "production", "bug_risk")
    )
    var new_bugs := maxi(int(round(float(randi_range(0, 4)) * bug_risk)), 0)
    project.bugs_created += new_bugs
    project.bugs += new_bugs
    # New bugs are invisible until QA actually finds them.
    _discover_bugs(project, float(staff["testing"]), false)
    project.development_cost += weekly_cost
    accrue_labour(project)

    if project.development_progress >= 100.0 and project.completion_year == 0:
        project.completion_year = TimeManager.current_year
        project.completion_month = TimeManager.current_month
        project.completion_week = TimeManager.current_week

    return {"weekly_cost": weekly_cost, "compatibility": compatibility, "bugs": new_bugs}

static func polish_week(project: GameProject) -> Dictionary:
    if project.released:
        return {}

    _refresh_lead(project)
    var cost := get_polish_cost(project)
    FinanceManager.force_spend(
        cost, Ledger.Kind.POLISH, "%s polish" % project.title, project.id)

    var staff := staff_effects(project)
    var output := float(staff["effective_team_output"])
    var testing_effectiveness := float(staff["testing"])

    # Dedicated testing time turns up more of what is actually there before
    # any of it gets fixed.
    _discover_bugs(project, testing_effectiveness, true,
        DevelopmentFocusSimulator.multiplier(project, "polish", "bug_discovery"))

    var bug_fix_skill := testing_effectiveness * 0.80 + float(staff["programming"]) * 0.20
    var potential_fix := maxi(int(round(float(randi_range(2, 5)) * bug_fix_skill * output
        * DevelopmentFocusSimulator.multiplier(project, "polish", "bug_fix"))), 1)
    # Nobody fixes a bug they do not know exists.
    var fixed := mini(potential_fix, project.known_bugs)
    project.bugs -= fixed
    project.known_bugs -= fixed
    project.bugs_fixed += fixed

    # Every fix is a chance to quietly break something else. Good QA keeps
    # that chance small; it never reaches zero.
    var regressions := QASimulator.roll_regressions(
        fixed, QASimulator.regression_rate(testing_effectiveness)
            * DevelopmentFocusSimulator.multiplier(project, "polish", "regressions"))
    # A paid polish week should always make at least a little net progress
    # when the team had known bugs to work on. Regressions still reduce the
    # gain, but cannot erase every fix from the week.
    regressions = mini(regressions, maxi(fixed - 1, 0))
    if regressions > 0:
        project.bugs += regressions
        project.bugs_created += regressions

    project.polish_weeks += 1

    # Polish itself: QA, artists and designers going back over what is
    # already there. Not the producer -- there is nothing left to plan.
    var polish_staff := (
        float(staff["polish_art"]) * 0.35 + float(staff["polish_testing"]) * 0.35
        + float(staff["polish_design"]) * 0.30
    )
    _add_focused_quality(project, "polish", "polish",
        randf_range(4.0, 8.0) * polish_staff * output)

    # Performance: the programmer's own pass, a little stronger than the
    # incidental gains made during production.
    _add_focused_quality(project, "polish", "performance",
        randf_range(0.6, 1.8) * float(staff["programming"]) * output)

    # Balance: only really possible now that a whole game exists to tune.
    # Mostly the designer's call, checked by QA playing it and a programmer
    # actually wiring the changes in.
    var balance_staff := (
        float(staff["design"]) * 0.55 + float(staff["polish_testing"]) * 0.30
        + float(staff["programming"]) * 0.15
    )
    _add_focused_quality(project, "polish", "balance",
        randf_range(2.0, 5.0) * balance_staff * output)

    # Extra time in polish still lifts the rest of the game a little too --
    # the only way to push a project past what its size was expected to
    # deliver. QA, artists and designers are the headline act here, but
    # nothing else stops moving just because it is not one of them.
    _add_focused_quality(project, "polish", "gameplay",
        randf_range(0.5, 1.8) * float(staff["design"]) * output)
    _add_focused_quality(project, "polish", "graphics",
        randf_range(0.4, 1.5) * float(staff["art"]) * output)
    _add_focused_quality(project, "polish", "sound",
        randf_range(0.4, 1.5) * float(staff["audio"]) * output)
    _add_focused_quality(project, "polish", "story",
        randf_range(0.3, 1.2) * float(staff["writing"]) * output)
    _add_focused_quality(project, "polish", "narrative_quality",
        randf_range(0.3, 1.0) * float(staff["writing"]) * output)

    project.development_cost += cost
    accrue_labour(project)

    return {"weekly_cost": cost, "bugs_fixed": fixed}

static func _discover_bugs(project: GameProject, testing_effectiveness: float, polishing: bool,
        focus_multiplier: float = 1.0) -> void:
    var gap := project.bugs - project.known_bugs
    if gap <= 0:
        return
    var rate := clampf(QASimulator.discovery_rate(testing_effectiveness, polishing)
        * focus_multiplier, 0.0, 1.0)
    project.known_bugs += QASimulator.discovered_this_week(gap, rate)

static func _add_focused_quality(project: GameProject, phase: String, field: String,
        amount: float) -> void:
    ## Two independent tradeoff layers compose here: the phase's own live
    ## focus (DevelopmentFocusSimulator, changeable while this phase runs)
    ## and the project's whole-build priority (ProjectPrioritySimulator, set
    ## once at greenlight and fixed). Neither replaces the other.
    project.set(field, float(project.get(field)) + amount
        * DevelopmentFocusSimulator.quality_multiplier(project, phase, field)
        * ProjectPrioritySimulator.quality_multiplier(project.priority_choices, field))

static func _refresh_lead(project: GameProject) -> float:
    ## Whoever has the most leadership on the team leads -- not necessarily
    ## whoever is best at the actual work. Returns their leadership so the
    ## same weekly pass can put it straight to use.
    var lead := LeadershipSimulator.pick_lead(TeamManager.working_members(project.team_id))
    project.lead_employee_id = lead.id if lead != null else ""
    return float(lead.leadership) if lead != null else LeadershipSimulator.BASELINE

static func _calculate_compatibility(project: GameProject) -> float:
    var platform := DataManager.get_platform(project.platform_id)
    var platform_genres: Dictionary = platform.get("audience", {})

    var theme_score := KnowledgeSimulator.true_compatibility(project.theme_id, project.genre_id)
    var platform_score := float(platform_genres.get(project.genre_id, 1.0))

    return clampf((theme_score + platform_score) / 2.0, 0.65, 1.35)

static func _story_weight(genre_id: String) -> float:
    var genre := DataManager.get_genre(genre_id)
    return float(genre.get("story_weight", 0.8))

static func staff_effects(project: GameProject) -> Dictionary:
    var team_employees := TeamManager.working_members(project.team_id)
    var workloads: Dictionary = {}
    for employee in team_employees:
        workloads[employee.id] = TeamManager.workload_percent(employee.id)
    var office_productivity := OfficeManager.productivity()
    var team := TeamManager.find_team(project.team_id)
    var chemistry := team.chemistry if team != null else 50.0
    var size := DataManager.get_size(project.size_id)
    # Everything else that bears on how fast this team works, handed over so it
    # resolves through the same single cap rather than multiplying on top of it.
    var effects := ProjectStaffSimulator.effects(
        project.role_assignments, team_employees, workloads, office_productivity, chemistry,
        int(size.get("max_useful_staff", 99)), int(size.get("ideal_team_min", 1)),
        {
            BonusStack.TEAM: [
                CultureSimulator.progress_multiplier(CultureManager.value("efficiency"))],
            BonusStack.STRATEGY: [
                1.0 + project.production_efficiency_modifier,
                EngineManager.effects_for(project.engine_id)["progress"]]
        }
    )

    # Crunch buys extra hours, at a cost paid in morale and stress each week.
    var crunch := MoraleManager.crunch_output_multiplier(project.team_id)
    if crunch != 1.0:
        effects["progress"] = float(effects["progress"]) * crunch
        effects["crunching"] = true
    return effects
