class_name Contract
extends RefCounted

## A piece of work done for somebody else. It pays reliably and on time, which
## is exactly what a studio between games needs, but it builds no catalogue and
## earns no fans.

var id: String = ""
var template_id: String = ""
var name: String = ""
var client: String = ""
var brief: String = ""

var work: int = 0
var work_done: float = 0.0
var payout: int = 0
var reputation_reward: float = 0.0

var deadline_weeks: int = 0
var weeks_worked: int = 0

var team_id: String = ""
var accepted_year: int = 0
var accepted_month: int = 1
var accepted_week: int = 1

var status: String = "offered"   # offered, active, completed, failed

const STRING_FIELDS := ["id", "template_id", "name", "client", "brief", "team_id", "status"]
const INT_FIELDS := [
    "work", "payout", "deadline_weeks", "weeks_worked",
    "accepted_year", "accepted_month", "accepted_week"
]
const FLOAT_FIELDS := ["work_done", "reputation_reward"]

func progress_percent() -> float:
    if work <= 0:
        return 0.0
    return clampf(work_done / float(work) * 100.0, 0.0, 100.0)

func weeks_remaining() -> int:
    return maxi(deadline_weeks - weeks_worked, 0)

func is_complete() -> bool:
    return work_done >= float(work)

func is_overdue() -> bool:
    return weeks_worked >= deadline_weeks and not is_complete()

func to_dict() -> Dictionary:
    var data: Dictionary = {}
    for field in STRING_FIELDS + INT_FIELDS + FLOAT_FIELDS:
        data[field] = get(field)
    return data

static func from_dict(data: Dictionary) -> Contract:
    var contract := Contract.new()
    for field in STRING_FIELDS:
        contract.set(field, str(data.get(field, "")))
    for field in INT_FIELDS:
        contract.set(field, int(data.get(field, 0)))
    for field in FLOAT_FIELDS:
        contract.set(field, float(data.get(field, 0.0)))
    return contract
