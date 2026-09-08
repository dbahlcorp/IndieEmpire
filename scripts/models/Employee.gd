class_name Employee
extends RefCounted

## A person employed by the studio. Roles and seniority are stored as stable
## string ids so authored roles can grow without invalidating old saves.

# --- Identity ---
var id: String = ""
var first_name: String = ""
var last_name: String = ""
var age: int = 18
var portrait_seed: int = 0
## -1 keeps legacy and generated employees seed-based. The CEO customizer sets
## an explicit sheet index so the player's choice is stable and editable.
var appearance_index: int = -1
var hire_year: int = 1985
var hire_month: int = 1
var hire_week: int = 1

# --- Employment ---
var role: String = "generalist"
var salary: int = 0
## Career level: junior/mid-level/senior/Lead. Only ever changes the job
## title and the pay band -- never the discipline itself, and never touched
## by specialization_id below. Two separate axes, on purpose: this is how
## far up the ladder they've climbed, not what they're good at within it.
var seniority: String = "junior"
var status: String = "active"
## Who currently employs this person: unemployed/player/competitor. Deliberately
## separate from status above -- status is their lifecycle stage with whoever
## currently employs them (candidate/active/departed/laid_off), this is *who*
## that is. Not an M3 mechanic yet: there are no competitor studios to move to
## or from, so "competitor" is never actually set by anything today. Recorded
## now so poaching -- an employee leaving for, or being hired away from, a
## rival studio -- has somewhere to record the move once M4/M5 adds
## competitors, instead of retrofitting every employment transition later.
var employer: String = "unemployed"
var assigned_team: String = ""
var hiring_fee: int = 0
## "" means nobody has bought them a computer yet. See EquipmentSimulator.
var workstation_tier: String = ""
## How rare this candidate was on the labor market: common/skilled/
## exceptional/star, from data/candidate_rarities.json. Set once at
## generation and kept for the rest of their career -- it is a fact about how
## they were found, not something that changes with tenure. See
## LaborMarketManager.refresh_market() and EmployeeManager.generate_candidate().
var rarity_id: String = "common"

# --- Skills ---
var programming: int = 0
var design: int = 0
var art: int = 0
var writing: int = 0
var audio: int = 0
var production: int = 0
var testing: int = 0
var research: int = 0

# --- Attributes ---
var creativity: int = 0
var speed: int = 0
var quality: int = 0
var teamwork: int = 0
var adaptability: int = 0
var leadership: int = 0

# --- Condition ---
var morale: int = 100
var energy: int = 100
var stress: int = 0
var burnout: int = 0

# --- Progression ---
var experience: int = 0
var level: int = 1
var training_points: int = 0
## Personal standing in the industry, 0-100. Separate from the studio's own
## reputation, and from the skills that earn it -- see EmployeeReputationSimulator.
var reputation: int = 0
var skill_experience: Dictionary = {}
var skill_levels: Dictionary = {}
## Expertise, not career level -- deliberately independent of seniority
## above. "Junior -> Senior" is the rung they're on; this is "Programmer ->
## AI Programmer", and a Junior can specialize the same as a Lead. "" means
## they have not specialized within their skill yet. Recorded now so a save
## already has somewhere to keep this; the actual moment an experienced
## employee is offered a choice of focus (see data/specializations.json) is
## an M4/M5 system, not this one.
var specialization_id: String = ""

var training_course_id: String = ""
var training_skill: String = ""
var training_weeks_left: int = 0
var time_off_weeks: int = 0
var notice_weeks: int = 0
var burnout_leave_weeks: int = 0
var refused_requests: int = 0
var pronoun_id: String = Pronouns.DEFAULT
var concern_raised: bool = false
var resignation_accepted: bool = false

var trait_ids: Array[String] = []

# --- Career history ---
## Kept for a whole career and preserved after they leave, so a former
## employee who resurfaces at a rival studio later has a real record behind
## them rather than a blank sheet.
## Every game they were credited on, newest last. Each entry:
## {project_id, title, role, seniority, review_score, shipped, year, month, week}
var project_history: Array = []
## Every salary they have been on here, newest last. The first entry is the
## offer they were hired on. Each entry: {amount, reason, year, month, week}
var salary_history: Array = []
## Promotions between seniority tiers, newest last. Each entry:
## {from, to, salary, year, month, week}
var promotion_history: Array = []
## Courses finished while employed here, newest last. Each entry:
## {course_id, course_name, skill, gain, year, month, week}
var training_history: Array = []
## Industry awards for work done here, newest last. Each entry:
## {award_id, name, project_id, year}. Nothing awards these yet -- the
## ceremony is a later milestone -- but the record is kept from the start so
## the history is already complete when it arrives.
var awards: Array = []

## Every career-history list and the type of each field it stores, so an
## older or hand-edited save is coerced back to the right types on load.
## JSON has no integers, so without this every year and salary would return
## as a float.
const HISTORY_SCHEMAS := {
    "project_history": {
        "project_id": "str", "title": "str", "role": "str", "seniority": "str",
        "review_score": "float", "shipped": "bool",
        "year": "int", "month": "int", "week": "int"
    },
    "salary_history": {
        "amount": "int", "reason": "str", "year": "int", "month": "int", "week": "int"
    },
    "promotion_history": {
        "from": "str", "to": "str", "salary": "int",
        "year": "int", "month": "int", "week": "int"
    },
    "training_history": {
        "course_id": "str", "course_name": "str", "skill": "str", "gain": "int",
        "year": "int", "month": "int", "week": "int"
    },
    "awards": {
        "award_id": "str", "name": "str", "project_id": "str", "year": "int"
    }
}

const OWNERSHIP_STATES := ["unemployed", "player", "competitor"]

const STRING_FIELDS := [
    "id", "first_name", "last_name", "role", "seniority", "status",
    "assigned_team", "training_course_id", "training_skill", "pronoun_id",
    "workstation_tier", "specialization_id", "rarity_id", "employer"
]
const INT_FIELDS := [
    "training_weeks_left", "time_off_weeks", "notice_weeks", "refused_requests",
    "burnout_leave_weeks",
    "age", "portrait_seed", "appearance_index", "hire_year", "hire_month", "hire_week", "salary", "hiring_fee",
    "programming", "design", "art", "writing", "audio", "production",
    "testing", "research", "creativity", "speed", "quality", "teamwork",
    "adaptability", "leadership", "morale", "energy", "stress", "burnout",
    "experience", "level", "training_points", "reputation"
]
const BOOL_FIELDS := ["concern_raised", "resignation_accepted"]

func they() -> String:
    return Pronouns.subject(pronoun_id)

func them() -> String:
    return Pronouns.object(pronoun_id)

func their() -> String:
    return Pronouns.possessive(pronoun_id)

func themselves() -> String:
    return Pronouns.reflexive(pronoun_id)

func verb(singular: String, plural: String) -> String:
    ## Agreement, so "she has" and "they have" both read correctly.
    return Pronouns.verb(pronoun_id, singular, plural)

func display_name() -> String:
    return (first_name + " " + last_name).strip_edges()

func is_active() -> bool:
    return status == "active"

func is_away() -> bool:
    ## Employed and paid, but not available for project work this week -- on a
    ## course, on leave, or assigned to a research project (a researcher
    ## cannot also contribute to a game).
    return (
        is_training() or time_off_weeks > 0 or burnout_leave_weeks > 0
        or ResearchManager.is_researching(id)
    )

func is_training() -> bool:
    ## Still employed and still paid, but not available for project work.
    return training_weeks_left > 0

func is_founder() -> bool:
    return role == "founder"

func has_specialized() -> bool:
    return not specialization_id.is_empty()

func specialization() -> Dictionary:
    ## {} until an M4/M5 system actually offers the choice and sets
    ## specialization_id. See data/specializations.json.
    return DataManager.get_specialization(specialization_id)

func hire_date_label() -> String:
    return TimeManager.format_date(hire_year, hire_month, hire_week)

# --- Career history queries ---

func games_shipped_count() -> int:
    var count := 0
    for entry in project_history:
        if bool(entry.get("shipped", false)):
            count += 1
    return count

func average_review_score() -> float:
    ## Across the games they actually shipped; 0.0 if they never shipped one.
    var total := 0.0
    var count := 0
    for entry in project_history:
        if not bool(entry.get("shipped", false)):
            continue
        total += float(entry.get("review_score", 0.0))
        count += 1
    return total / count if count > 0 else 0.0

func highest_rated_game() -> Dictionary:
    ## The best-reviewed shipped game they were credited on, or {} if none.
    var best: Dictionary = {}
    for entry in project_history:
        if not bool(entry.get("shipped", false)):
            continue
        if best.is_empty() or float(entry.get("review_score", 0.0)) > float(best.get("review_score", 0.0)):
            best = entry
    return best

func starting_salary() -> int:
    if salary_history.is_empty():
        return salary
    return int(salary_history[0].get("amount", salary))

func career_summary() -> Dictionary:
    ## A compact record for the employee and departed screens and, later, for
    ## a former employee who turns up working for a competitor.
    var best := highest_rated_game()
    return {
        "hired": {"year": hire_year, "month": hire_month, "week": hire_week},
        "projects_worked_on": project_history.size(),
        "games_shipped": games_shipped_count(),
        "average_review_score": average_review_score(),
        "highest_rated_game": str(best.get("title", "")),
        "highest_review_score": float(best.get("review_score", 0.0)),
        "awards": awards.size(),
        "promotions": promotion_history.size(),
        "courses_completed": training_history.size(),
        "starting_salary": starting_salary(),
        "current_salary": salary
    }

func to_dict() -> Dictionary:
    var data: Dictionary = {}
    for field in STRING_FIELDS + INT_FIELDS + BOOL_FIELDS:
        data[field] = get(field)
    data["trait_ids"] = trait_ids.duplicate()
    data["skill_experience"] = skill_experience.duplicate()
    data["skill_levels"] = skill_levels.duplicate()
    for list_name in HISTORY_SCHEMAS:
        data[list_name] = (get(list_name) as Array).duplicate(true)
    return data

static func from_dict(data: Dictionary) -> Employee:
    var employee := Employee.new()
    for field in STRING_FIELDS:
        employee.set(field, str(data.get(field, employee.get(field))))
    for field in INT_FIELDS:
        employee.set(field, int(data.get(field, employee.get(field))))
    for field in BOOL_FIELDS:
        employee.set(field, bool(data.get(field, employee.get(field))))
    # Saves written before pronouns existed, and anything unrecognised.
    if not Pronouns.is_known(employee.pronoun_id):
        employee.pronoun_id = Pronouns.DEFAULT
    if not employee.workstation_tier.is_empty() and not EquipmentSimulator.is_known_tier(
            employee.workstation_tier):
        employee.workstation_tier = ""
    if not employee.specialization_id.is_empty() and DataManager.get_specialization(
            employee.specialization_id).is_empty():
        employee.specialization_id = ""
    if DataManager.get_candidate_rarity(employee.rarity_id).is_empty():
        employee.rarity_id = "common"
    if employee.employer not in OWNERSHIP_STATES:
        employee.employer = "unemployed"

    var traits: Array[String] = []
    for value in data.get("trait_ids", []):
        traits.append(str(value))
    employee.trait_ids = traits

    for skill in data.get("skill_experience", {}):
        employee.skill_experience[str(skill)] = int(data["skill_experience"][skill])
    for skill in data.get("skill_levels", {}):
        employee.skill_levels[str(skill)] = maxi(int(data["skill_levels"][skill]), 1)

    for list_name in HISTORY_SCHEMAS:
        employee.set(list_name, _restore_history(
            data.get(list_name, []), HISTORY_SCHEMAS[list_name]))

    # Condition and skill values are percentages. Clamping on load keeps a
    # malformed or hand-edited save from poisoning later simulation maths.
    for field in [
        "programming", "design", "art", "writing", "audio", "production",
        "testing", "research", "creativity", "speed", "quality", "teamwork",
        "adaptability", "leadership", "morale", "energy", "stress", "burnout"
    ]:
        employee.set(field, clampi(int(employee.get(field)), 0, 100))
    employee.age = maxi(employee.age, 18)
    employee.salary = maxi(employee.salary, 0)
    employee.hiring_fee = maxi(employee.hiring_fee, 0)
    employee.level = maxi(employee.level, 1)
    employee.experience = maxi(employee.experience, 0)
    employee.training_points = maxi(employee.training_points, 0)
    return employee

static func _restore_history(source, schema: Dictionary) -> Array:
    ## Rebuild one career-history list, coercing each field to the type the
    ## schema names and dropping anything the schema does not recognise.
    var rows: Array = []
    if not (source is Array):
        return rows
    for entry in source:
        if not (entry is Dictionary):
            continue
        var row: Dictionary = {}
        for key in schema:
            if not entry.has(key):
                continue
            match str(schema[key]):
                "int":
                    row[key] = int(entry[key])
                "float":
                    row[key] = float(entry[key])
                "bool":
                    row[key] = bool(entry[key])
                _:
                    row[key] = str(entry[key])
        rows.append(row)
    return rows
