class_name ProjectEstimateSimulator
extends RefCounted

## Everything a player needs to judge a project before greenlighting it,
## built from the same simulation the project will actually run on -- never
## a made-up range. schedule_and_cost() is the pre-start twin of
## DevelopmentSimulator._estimate(): the real one reads a live GameProject,
## this one reads the same staffing formula (ProjectStaffSimulator.effects)
## before a GameProject exists to read it from. Originally lived inline on
## NewGameScreen as _estimate_schedule(); moved here so the setup screen and
## the greenlight confirmation screen read one number, not two copies that
## can drift apart.

## How much older than the current year a built engine has to be before it
## is called out as a real risk -- research and tooling both move on, and an
## engine nobody has touched since is genuinely more likely to be missing
## techniques a fresher one would have. Deliberately just a risk-explanation
## heuristic: it changes nothing about how the engine actually performs (see
## EngineManager.effects_for), only what the greenlight screen tells the
## player about their choice.
const ENGINE_OUTDATED_YEARS := 6

## How wide the schedule's fast/slow spread has to be, out of
## LeadershipSimulator's 1.2-4.2 range, before weak leadership is worth
## calling out on its own. Roughly the top third of that range.
const WIDE_SCHEDULE_HALF_WIDTH := 3.5

## How little of a genre's studio experience still reads as "little
## experience" for risk purposes -- Unknown or Beginner on
## KnowledgeSimulator's 0-5 scale.
const LOW_GENRE_EXPERIENCE_LEVEL := 1

## How much of a size's own required effort the chosen features can add
## before that ambition is worth flagging on its own, distinct from a team
## that is simply too small for the scope.
const AMBITIOUS_FEATURE_SHARE := 0.40

static func workloads_for(assignments: Dictionary) -> Dictionary:
    var workloads: Dictionary = {}
    for role in TeamManager.PROJECT_ROLES:
        var employee_id := str(assignments.get(role["id"], ""))
        if employee_id.is_empty():
            continue
        workloads[employee_id] = int(workloads.get(employee_id, 0)) + int(role["workload"])
    return workloads

static func schedule_and_cost(
        size_id: String, platform_id: String, team_id: String, assignments: Dictionary,
        upfront: int, feature_ids: Array = [], engine_id: String = "") -> Dictionary:
    ## A real forecast, not a generic per-scope range: built from exactly the
    ## staff and roles actually chosen, the same way the actual project
    ## would be. Empty ({}) once there is nothing real to forecast from --
    ## no scope, no team, or a team nobody can currently work on.
    var size := DataManager.get_size(size_id)
    if size.is_empty() or team_id.is_empty():
        return {}
    var employees := TeamManager.working_members(team_id)
    if employees.is_empty():
        return {}

    var workloads := workloads_for(assignments)
    var office_productivity := OfficeManager.productivity()
    var team := TeamManager.find_team(team_id)
    var chemistry := team.chemistry if team != null else 50.0
    var ideal_max := int(size.get("max_useful_staff", 99))
    var ideal_min := int(size.get("ideal_team_min", 1))

    var effects := ProjectStaffSimulator.effects(
        assignments, employees, workloads, office_productivity, chemistry, ideal_max, ideal_min)

    var lead := LeadershipSimulator.pick_lead(employees)
    var leadership := float(lead.leadership) if lead != null else LeadershipSimulator.BASELINE
    var half_width := LeadershipSimulator.schedule_half_width(leadership)
    var complexity_budget := FeatureSimulator.complexity_budget(size_id, feature_ids)
    if bool(complexity_budget.get("over_scoped", false)):
        half_width *= 1.0 + minf((float(complexity_budget["ratio"]) - 1.0) * 0.35, 0.65)
    # A brand-new engine widens the forecast (nobody knows how it will
    # behave); a well-worn one tightens it. See EngineSimulator.
    var engine_condition := EngineManager.condition_for(engine_id)
    if bool(engine_condition.get("has_engine", false)):
        half_width *= [1.30, 1.12, 1.0, 0.92, 0.85][
            clampi(int(engine_condition["familiarity"]), 0, 4)]
    var culture_progress := CultureSimulator.progress_multiplier(CultureManager.value("efficiency"))

    # Pre-production, fast and slow ends of the same weekly roll production
    # itself uses.
    var preprod_work := float(DevelopmentSimulator.PREPRODUCTION_WORK.get(size_id, 45.0))
    var preprod_scale := 100.0 / maxf(preprod_work, 1.0)
    var preprod_staff := float(effects.get("preproduction_progress", 1.0))
    var preprod_fast := 100.0 / maxf(
        (12.0 + half_width) * preprod_scale * preprod_staff * culture_progress, 0.01)
    var preprod_slow := 100.0 / maxf(
        maxf(12.0 - half_width, 1.0) * preprod_scale * preprod_staff * culture_progress, 0.01)

    # Production. The plan-efficiency swing from pre-production is not known
    # yet, so this assumes an unremarkable plan -- neither a bonus nor a
    # penalty.
    var work := DevelopmentSimulator.required_effort(size_id, feature_ids)
    var progress_scale := 100.0 / work
    var prod_staff := float(effects.get("progress", 1.0)) * float(engine_condition.get("speed", 1.0))
    var feature_effort := float(FeatureSimulator.effort_bonus(feature_ids))
    var feature_share := clampf(feature_effort / maxf(work, 1.0), 0.0, 0.80)
    prod_staff *= lerpf(
        1.0, FeatureSimulator.execution_multiplier(feature_ids, effects), feature_share)
    var prod_fast := 100.0 / maxf(
        (11.0 + half_width) * progress_scale * prod_staff * culture_progress, 0.01)
    var prod_slow := 100.0 / maxf(
        maxf(11.0 - half_width, 1.0) * progress_scale * prod_staff * culture_progress, 0.01)

    var weeks_min := maxi(int(ceil(preprod_fast + prod_fast)), 1)
    var weeks_max := maxi(int(ceil(preprod_slow + prod_slow)), weeks_min)

    var headcount := employees.size()
    var multiplier := (
        float(size.get("cost_multiplier", 1.0)) * DevelopmentSimulator.platform_cost_multiplier(platform_id)
        * ScopeSimulator.cost_overhead_multiplier(headcount, ideal_max)
    )

    return {
        "weeks_min": weeks_min,
        "weeks_max": weeks_max,
        "cost_min": upfront + _remaining_dev_cost(int(ceil(preprod_fast)), int(ceil(prod_fast)), multiplier),
        "cost_max": upfront + _remaining_dev_cost(int(ceil(preprod_slow)), int(ceil(prod_slow)), multiplier),
        # Everything below is not part of the original NewGameScreen return
        # shape -- additive, for risk_assessment() and callers that want the
        # raw ingredients rather than recomputing them.
        "half_width": half_width,
        "effects": effects,
        "headcount": headcount,
        "ideal_min": ideal_min,
        "ideal_max": ideal_max,
        "understaffed": ScopeSimulator.is_understaffed(headcount, ideal_min),
        "overstaffed": ScopeSimulator.is_overstaffed(headcount, ideal_max)
    }

static func _remaining_dev_cost(preprod_weeks: int, prod_weeks: int, multiplier: float) -> int:
    var cost := 0
    # Pre-production never ramps -- total_weeks() stays at zero throughout,
    # exactly matching how the real weekly cost is actually calculated.
    var preprod_base := DevelopmentSimulator.BASE_WEEKLY_COST + 15
    for i in preprod_weeks:
        cost += FinanceManager.expense(int(round(
            float(preprod_base) * multiplier * DevelopmentSimulator.PREPRODUCTION_COST_SHARE)))
    # Production ramps with each week actually spent building.
    for week_index in range(1, prod_weeks + 1):
        var base := DevelopmentSimulator.BASE_WEEKLY_COST + week_index * 15
        cost += FinanceManager.expense(int(round(float(base) * multiplier)))
    return cost

## Market fit ----------------------------------------------------------------
## The same theme/genre/platform compatibility DevelopmentSimulator actually
## scores production against (_calculate_compatibility), blended with how
## hungry the genre's market currently is (MarketManager.demand_for). Weighted
## toward compatibility, which is a fixed fact about this project; demand
## drifts week to week and should not dominate a one-time estimate.

static func market_fit(theme_id: String, genre_id: String, platform_id: String) -> Dictionary:
    var platform := DataManager.get_platform(platform_id)
    var platform_genres: Dictionary = platform.get("audience", {})
    var theme_score := KnowledgeSimulator.true_compatibility(theme_id, genre_id)
    var platform_score := float(platform_genres.get(genre_id, 1.0))
    var compatibility := clampf((theme_score + platform_score) / 2.0, 0.65, 1.35)
    var demand := MarketManager.demand_for(genre_id) if not genre_id.is_empty() else 1.0
    var score := compatibility * 0.7 + demand * 0.3
    return {"score": score, "label": _market_fit_label(score)}

static func _market_fit_label(score: float) -> String:
    if score >= 1.20:
        return "Excellent"
    if score >= 1.05:
        return "Promising"
    if score >= 0.90:
        return "Fair"
    if score >= 0.75:
        return "Weak"
    return "Poor"

## Team experience -------------------------------------------------------
## What the studio itself has learned, not any one hire's seniority -- the
## same genre/theme/platform knowledge ExperienceManager already tracks and
## the setup screen's own KNOWLEDGE panel already reads.

static func team_experience(genre_id: String, theme_id: String, platform_id: String) -> Dictionary:
    var genre_level := ExperienceManager.genre_level(genre_id) if not genre_id.is_empty() else 0
    var theme_level := ExperienceManager.theme_level(theme_id) if not theme_id.is_empty() else 0
    var platform_level := ExperienceManager.platform_level(platform_id) if not platform_id.is_empty() else 0
    var blended := float(genre_level) * 0.5 + float(theme_level) * 0.3 + float(platform_level) * 0.2
    return {"score": blended, "label": _team_experience_label(blended)}

static func _team_experience_label(blended: float) -> String:
    if blended >= 3.5:
        return "Strong"
    if blended >= 2.0:
        return "Developing"
    if blended >= 0.5:
        return "Limited"
    return "Weak"

## Risk ------------------------------------------------------------------
## Never just a word. Every point on the score is a named, concrete reason a
## real number or flag already in the simulation crossed a threshold -- the
## same discipline BottleneckSimulator already applies to a live project's
## own diagnosis panel.

static func risk_assessment(
        estimate: Dictionary, assignments: Dictionary, genre_id: String, size_id: String,
        engine_id: String, feature_ids: Array) -> Dictionary:
    var reasons: Array[String] = []
    var points := 0

    if bool(estimate.get("understaffed", false)):
        points += 2
        reasons.append("Scope is ambitious for the current team.")

    var effects: Dictionary = estimate.get("effects", {})
    var bottleneck := BottleneckSimulator.preview(assignments, effects)
    if not bottleneck.is_empty():
        points += 1 if bool(bottleneck.get("staffed", false)) else 2
        reasons.append("%s team is understaffed." % str(bottleneck.get("role_name", "")))

    var genre_level := ExperienceManager.genre_level(genre_id) if not genre_id.is_empty() else 0
    if genre_level <= LOW_GENRE_EXPERIENCE_LEVEL:
        points += 1
        reasons.append("Team has little %s experience." % DataManager.display_name(DataManager.genres, genre_id))

    if engine_id.is_empty():
        if not GameState.custom_engines.is_empty():
            points += 1
            reasons.append("No custom engine selected for this project.")
    else:
        var engine_condition := EngineManager.condition_for(engine_id)
        if int(engine_condition["age_years"]) >= ENGINE_OUTDATED_YEARS \
                or int(engine_condition["generation_gap"]) >= 1:
            points += 1
            reasons.append("Engine is outdated -- %s." % _outdated_detail(engine_condition))
        if int(engine_condition["familiarity"]) == 0:
            points += 1
            reasons.append("New engine -- the team will lose time learning it and ship more bugs.")
        if int(engine_condition["modifications"]) >= 3:
            points += 1
            reasons.append("Engine carries %d modifications and is getting harder to maintain." %
                int(engine_condition["modifications"]))

    if float(estimate.get("half_width", 0.0)) >= WIDE_SCHEDULE_HALF_WIDTH:
        points += 1
        reasons.append("No experienced project lead to keep the schedule steady.")

    if bool(estimate.get("overstaffed", false)):
        points += 1
        reasons.append("Team is larger than this scope needs, adding coordination overhead.")

    var size := DataManager.get_size(size_id)
    var base_work := maxf(float(size.get("work", 100)), 1.0)
    var complexity_budget := FeatureSimulator.complexity_budget(size_id, feature_ids)
    if bool(complexity_budget.get("over_scoped", false)):
        points += 2
        reasons.append("Chosen features exceed this scope's recommended complexity capacity.")
    elif float(FeatureSimulator.effort_bonus(feature_ids)) >= base_work * AMBITIOUS_FEATURE_SHARE:
        points += 1
        reasons.append(
            "Chosen features add significant scope beyond a standard %s project." % str(size.get("name", "")))

    return {"score": points, "label": _risk_label(points), "reasons": reasons}

static func _risk_label(points: int) -> String:
    if points >= 4:
        return "High"
    if points >= 2:
        return "Moderate"
    return "Low"

static func _outdated_detail(condition: Dictionary) -> String:
    var age := int(condition.get("age_years", 0))
    var gap := int(condition.get("generation_gap", 0))
    if gap >= 1:
        return "%s, %d generation%s behind current technology" % [
            EngineSimulator.generation_label(int(condition.get("generation", 1))),
            gap, "" if gap == 1 else "s"]
    return "built %d years ago" % age

## Bundle ------------------------------------------------------------------

static func full_estimate(
        genre_id: String, theme_id: String, platform_id: String, size_id: String,
        team_id: String, assignments: Dictionary, engine_id: String, feature_ids: Array
) -> Dictionary:
    ## Everything the greenlight screen needs, in one call, so it formats
    ## labels rather than deriving them.
    var upfront := DevelopmentSimulator.get_upfront_cost(platform_id, size_id)
    var fee := DevelopmentSimulator.get_platform_fee(platform_id)
    var schedule := schedule_and_cost(
        size_id, platform_id, team_id, assignments, upfront + fee, feature_ids, engine_id)
    return {
        "upfront": upfront,
        "platform_fee": fee,
        "schedule": schedule,
        "engine": EngineManager.condition_for(engine_id),
        "market": market_fit(theme_id, genre_id, platform_id),
        "experience": team_experience(genre_id, theme_id, platform_id),
        "risk": risk_assessment(schedule, assignments, genre_id, size_id, engine_id, feature_ids)
    }
