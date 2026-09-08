class_name ProjectStaffSimulator
extends RefCounted

## Converts project assignments into output multipliers. One employee may fill
## several roles, but every extra role reduces all of that person's output.

const ROLE_SKILLS := {
    "lead_programmer": "programming",
    "game_designer": "design",
    "artist": "art",
    "writer": "writing",
    "audio_designer": "audio",
    "qa_tester": "testing",
    "producer": "production"
}
## A five-way split naturally dilutes toward the unfilled-role baseline more
## than the old three-way one did -- most early teams leave two or three of
## these five roles empty. Without this, a small studio's pace quietly drops
## by nearly a fifth for no reason the player did anything about. This
## restores parity for a typical early team; a fully-staffed one still earns
## noticeably more from it than a bare one does.
const PRODUCTION_PACE := 1.20

const ROLE_ATTRIBUTES := {
    "lead_programmer": ["quality", "adaptability"],
    "game_designer": ["creativity", "quality"],
    "artist": ["creativity", "quality"],
    "writer": ["creativity", "quality"],
    "audio_designer": ["creativity", "quality"],
    "qa_tester": ["quality", "adaptability"],
    "producer": ["teamwork", "leadership"]
}

static func workload_multiplier(workload_percent: int) -> float:
    if workload_percent <= 100:
        return 1.0
    return 1.0 / (1.0 + (float(workload_percent - 100) / 100.0) * 1.5)

static func team_output_multiplier(people: int) -> float:
    const POINTS := [
        Vector2(1, 1.0), Vector2(2, 1.8), Vector2(3, 2.5),
        Vector2(4, 3.1), Vector2(5, 3.6), Vector2(8, 4.5), Vector2(12, 5.2)
    ]
    if people <= 0:
        return 0.25
    if people >= 12:
        return 5.2
    for index in range(1, POINTS.size()):
        if people <= int(POINTS[index].x):
            var before: Vector2 = POINTS[index - 1]
            var after: Vector2 = POINTS[index]
            var weight := (float(people) - before.x) / (after.x - before.x)
            return lerpf(before.y, after.y, weight)
    return 5.2

static func chemistry_speed_multiplier(chemistry: float) -> float:
    chemistry = clampf(chemistry, 0.0, 100.0)
    if chemistry < 50.0:
        return lerpf(0.92, 1.0, chemistry / 50.0)
    return lerpf(1.0, 1.05, (chemistry - 50.0) / 50.0)

static func chemistry_bug_multiplier(chemistry: float) -> float:
    chemistry = clampf(chemistry, 0.0, 100.0)
    if chemistry < 50.0:
        return lerpf(1.05, 1.0, chemistry / 50.0)
    return lerpf(1.0, 0.95, (chemistry - 50.0) / 50.0)

static func effects(
    assignments: Dictionary,
    employees: Array[Employee],
    workloads: Dictionary,
    office_productivity: int = 0,
    chemistry: float = 50.0,
    max_useful_staff: int = 99,
    ideal_team_min: int = 1,
    studio_pace: Dictionary = {}
) -> Dictionary:
    # What an unfilled role still produces. A one-person studio is not a studio
    # with no artist: the founder does the art too, just roughly. This has to
    # stay well below a real specialist so hiring is still worth it.
    var result := {
        "programming": 0.45, "design": 0.45, "art": 0.45,
        "writing": 0.45, "audio": 0.45, "testing": 0.35,
        "production": 0.45
    }
    var maximum_overload := 0.0
    var producer := _assigned_employee(assignments, employees, "producer")
    var producer_raw := 0.25
    if producer != null:
        producer_raw = float(_contribution(
            producer, "production", ROLE_ATTRIBUTES["producer"],
            int(workloads.get(producer.id, 0)), 0.0
        )["effectiveness"])
    # Good production never erases overload, but can soften its efficiency
    # penalty by up to 18% through planning and coordination.
    var workload_relief := clampf((producer_raw - 0.5) * 0.14, 0.0, 0.18)
    var role_contributions: Dictionary = {}
    var contributor_ids: Array[String] = []
    var contributor_speed: Dictionary = {}
    result["innovation_modifier"] = 1.0
    for role_id in ROLE_SKILLS:
        var employee_id := str(assignments.get(role_id, ""))
        if employee_id.is_empty():
            continue
        var employee := _find_employee(employees, employee_id)
        if employee == null:
            continue
        var skill := str(ROLE_SKILLS[role_id])
        var workload := int(workloads.get(employee_id, 0))
        var contribution := _contribution(
            employee, skill, ROLE_ATTRIBUTES[role_id], workload, workload_relief
        )
        result[skill] = contribution["effectiveness"]
        result["polish_%s" % skill] = (
            float(contribution["effectiveness"]) * float(contribution["polish_modifier"])
        )
        if role_id == "game_designer":
            result["innovation_modifier"] = contribution["innovation_modifier"]
        contribution["employee_id"] = employee.id
        contribution["employee_name"] = employee.display_name()
        role_contributions[role_id] = contribution
        if employee.id not in contributor_ids:
            contributor_ids.append(employee.id)
        contributor_speed[employee.id] = contribution["speed_modifier"]
        maximum_overload = maxf(maximum_overload, _effective_overload(employee, workload))

    var office_bonus := 1.0 + clampf(float(office_productivity), 0.0, 25.0) / 100.0
    # Good production plans the work; a strong project lead keeps everybody
    # pointed the same direction. Different people, different contributions.
    var producer_coordination := clampf(1.0 + maxf(float(result["production"]) - 0.5, 0.0) * 0.07, 1.0, 1.10)
    var lead := LeadershipSimulator.pick_lead(employees)
    var leadership_coordination := LeadershipSimulator.coordination_multiplier(
        float(lead.leadership) if lead != null else LeadershipSimulator.BASELINE)
    # Every member of the assigned team contributes. Named roles determine the
    # craft multipliers; remaining members provide general project support.
    var team_size := employees.size()
    # A crowd on a project sized for far fewer erodes coordination no matter
    # how good the producer or the lead are -- this is what stops brute-force
    # staffing being free.
    var overstaffing_overhead := ScopeSimulator.coordination_overhead_multiplier(
        team_size, max_useful_staff)
    var coordination := clampf(
        producer_coordination * leadership_coordination * overstaffing_overhead, 0.50, 1.20)
    # Only so many people can usefully work on a project of a given size; the
    # rest have nothing to pick up.
    var useful_staff := mini(team_size, maxi(max_useful_staff, 1))
    var team_output := team_output_multiplier(useful_staff)
    var chemistry_speed := chemistry_speed_multiplier(chemistry)
    # Fewer people than the scope calls for is not just less output -- the
    # whole project drags.
    var scope_speed := ScopeSimulator.speed_multiplier(team_size, ideal_team_min)
    var trait_speed := 1.0
    if not contributor_speed.is_empty():
        trait_speed = 0.0
        for modifier in contributor_speed.values():
            trait_speed += float(modifier)
        trait_speed /= contributor_speed.size()
    # Production is the main phase, and its pace comes from exactly the same
    # five disciplines that generate its stats -- programming, art, design,
    # writing and audio. Production itself is not on this list: a producer's
    # contribution is coordination, already folded in below, not a sixth
    # source of raw output.
    # The office, the producer, the lead, team chemistry and personal working
    # styles all speed a team up, and they used to multiply -- a maxed studio
    # collected +80% from these five alone. They now add under a cap.
    #
    # `studio_pace` folds in the parts the caller owns rather than this file --
    # the studio's culture, its engine tooling, the pre-production plan -- so
    # that everything bearing on the team's pace resolves through ONE cap. Two
    # separately-capped stacks would just multiply, which is the whole problem.
    # See BonusStack for why capacity and penalties are left out.
    var pace_parts := {
        BonusStack.FACILITIES: [office_bonus],
        BonusStack.TEAM: [coordination, chemistry_speed, trait_speed]
    }
    for category in studio_pace:
        var existing: Array = pace_parts.get(category, [])
        pace_parts[category] = existing + Array(studio_pace[category])
    var pace_bonus := BonusStack.combine(pace_parts)
    result["pace_bonus"] = pace_bonus
    result["progress"] = clampf(
        (
            float(result["programming"]) + float(result["art"]) + float(result["design"])
            + float(result["writing"]) + float(result["audio"])
        ) / 5.0 * PRODUCTION_PACE
        * pace_bonus * team_output * scope_speed,
        0.25, 8.0
    )
    # Pre-production is concept and planning. Design and writing set the
    # vision; production and a lead programmer's early read on feasibility
    # set the scope. Art has nothing to build yet.
    result["preproduction_progress"] = clampf(
        (float(result["design"]) * 0.35 + float(result["writing"]) * 0.20
            + float(result["production"]) * 0.25 + float(result["programming"]) * 0.20)
        * pace_bonus * team_output * scope_speed,
        0.20, 8.0
    )
    result["overload"] = maximum_overload
    result["coordination"] = coordination
    result["scope_speed"] = scope_speed
    result["understaffed"] = ScopeSimulator.is_understaffed(team_size, ideal_team_min)
    result["overstaffed"] = ScopeSimulator.is_overstaffed(team_size, max_useful_staff)
    result["overstaffing_overhead"] = overstaffing_overhead
    result["leadership_coordination"] = leadership_coordination
    result["lead_employee_id"] = lead.id if lead != null else ""
    result["contributors"] = team_size
    result["useful_contributors"] = useful_staff
    result["named_contributors"] = contributor_ids.size()
    result["effective_team_output"] = team_output
    result["chemistry_speed"] = chemistry_speed
    result["chemistry_bug"] = chemistry_bug_multiplier(chemistry)
    result["trait_speed"] = trait_speed
    for skill in ["programming", "design", "art", "writing", "audio", "testing", "production"]:
        var key := "polish_%s" % skill
        if not result.has(key):
            result[key] = result[skill]
    result["role_contributions"] = role_contributions
    return result

static func _contribution(
    employee: Employee,
    skill: String,
    attributes: Array,
    workload: int,
    workload_relief: float
) -> Dictionary:
    var skill_factor := maxf(float(employee.get(skill)) / 50.0, 0.10)
    var attribute_value := 0.0
    for attribute in attributes:
        attribute_value += float(employee.get(str(attribute)))
    attribute_value /= maxf(float(attributes.size()), 1.0)
    var attribute_factor := maxf(attribute_value / 60.0, 0.20)
    var experience_factor := 1.0 + minf(
        float(maxi(employee.level - 1, 0)) * 0.04 + float(employee.experience) / 5000.0,
        0.35
    )
    # Good morale (80) is the baseline for a well-run studio, so that is 1.0.
    var morale_factor := 0.70 + float(employee.morale) * 0.00375
    var condition_factor := 0.55 + float(employee.energy) / 220.0
    condition_factor *= 1.0 - float(employee.stress) * 0.003
    condition_factor *= 1.0 - float(employee.burnout) * 0.005
    var effective_workload := workload
    if "workhorse" in employee.trait_ids and workload > 100:
        effective_workload = 100 + int(round(float(workload - 100) * 0.65))
    var base_workload := workload_multiplier(effective_workload)
    var workload_efficiency := base_workload + (1.0 - base_workload) * workload_relief
    # What they're actually working on. A real handicap with no machine of
    # their own, a real edge with a good one -- see EquipmentSimulator.
    var equipment_factor := EquipmentSimulator.contribution_multiplier(
        employee.workstation_tier, skill)
    # How good they are at this, and how much of it they can bring to bear
    # today. Skill, attributes and accumulated experience are core competence
    # -- the thing the player invests in most directly -- so they are not
    # capped. Condition and workload are penalties, so they are not capped
    # either. What *is* capped is the pile of situational percentages on top.
    var trait_bonus := 1.0
    if skill == "programming" and "lone_wolf" in employee.trait_ids:
        trait_bonus *= 1.08
    if skill == "testing" and "bug_hunter" in employee.trait_ids:
        trait_bonus *= 1.20
    if skill == "production" and "visionary" in employee.trait_ids:
        trait_bonus *= 0.92
    if "technical_genius" in employee.trait_ids:
        if skill == "programming":
            trait_bonus *= 1.15
        elif skill == "testing":
            trait_bonus *= 1.10
    var situational := BonusStack.combine({
        BonusStack.TEAM: [morale_factor, trait_bonus],
        BonusStack.FACILITIES: [equipment_factor]
    })
    var effectiveness := (
        skill_factor * attribute_factor * experience_factor
        * maxf(condition_factor, 0.20) * workload_efficiency * situational
    )
    return {
        "effectiveness": clampf(effectiveness, 0.12, 2.25),
        "skill": int(employee.get(skill)),
        "attribute": int(round(attribute_value)),
        "experience_factor": experience_factor,
        "morale_factor": morale_factor,
        "workload_efficiency": workload_efficiency,
        "polish_modifier": 1.10 if "perfectionist" in employee.trait_ids else 1.0,
        "speed_modifier": 0.92 if "perfectionist" in employee.trait_ids else 1.0,
        "innovation_modifier": 1.12 if "visionary" in employee.trait_ids else 1.0
    }

static func _effective_overload(employee: Employee, workload: int) -> float:
    var excess := maxi(workload - 100, 0)
    if "workhorse" in employee.trait_ids:
        excess = int(round(float(excess) * 0.65))
    return float(excess) / 100.0

static func _assigned_employee(
    assignments: Dictionary, employees: Array[Employee], role_id: String
) -> Employee:
    return _find_employee(employees, str(assignments.get(role_id, "")))

static func _find_employee(employees: Array[Employee], employee_id: String) -> Employee:
    for employee in employees:
        if employee.id == employee_id:
            return employee
    return null
