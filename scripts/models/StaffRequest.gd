class_name StaffRequest
extends RefCounted

## Something an employee has asked the studio for. It sits in a queue until the
## player answers it, and being ignored is itself an answer.

const RAISE := "raise"
const PROMOTION := "promotion"

var id: String = ""
var employee_id: String = ""
var kind: String = RAISE
var reason: String = ""

var current_salary: int = 0
var requested_salary: int = 0
var new_seniority: String = ""

var created_year: int = 0
var created_month: int = 1
var created_week: int = 1
var weeks_left: int = 4

const STRING_FIELDS := ["id", "employee_id", "kind", "reason", "new_seniority"]
const INT_FIELDS := [
    "current_salary", "requested_salary",
    "created_year", "created_month", "created_week", "weeks_left"
]

func monthly_increase() -> int:
    return maxi(requested_salary - current_salary, 0)

func to_dict() -> Dictionary:
    var data: Dictionary = {}
    for field in STRING_FIELDS + INT_FIELDS:
        data[field] = get(field)
    return data

static func from_dict(data: Dictionary) -> StaffRequest:
    var request := StaffRequest.new()
    for field in STRING_FIELDS:
        request.set(field, str(data.get(field, "")))
    for field in INT_FIELDS:
        request.set(field, int(data.get(field, 0)))
    return request
