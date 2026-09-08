extends Node

signal week_advanced(year: int, month: int, week: int)

const MONTHS := [
    "JAN", "FEB", "MAR", "APR", "MAY", "JUN",
    "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"
]
const MONTH_NAMES := [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
]
const START_YEAR := 1985
const WEEKS_PER_MONTH := 4

var current_year: int = START_YEAR
var current_month: int = 1
var current_week: int = 1

func advance_week() -> void:
    current_week += 1
    if current_week > WEEKS_PER_MONTH:
        current_week = 1
        current_month += 1
    if current_month > 12:
        current_month = 1
        current_year += 1

    week_advanced.emit(current_year, current_month, current_week)

func absolute_week() -> int:
    return week_index(current_year, current_month, current_week)

static func week_index(year: int, month: int, week: int) -> int:
    return (year * 12 + (month - 1)) * WEEKS_PER_MONTH + (week - 1)

func weeks_since(year: int, month: int, week: int) -> int:
    return absolute_week() - week_index(year, month, week)

static func date_from_week_index(index: int) -> Dictionary:
    ## The inverse of week_index() -- turns an absolute week count back into
    ## a calendar date. See DeadlineSimulator, which projects a completion
    ## week forward and needs the real month/year to show for it.
    var month_index := index / WEEKS_PER_MONTH
    return {
        "year": month_index / 12,
        "month": month_index % 12 + 1,
        "week": index % WEEKS_PER_MONTH + 1
    }

func get_date_label() -> String:
    return "%s %d - W%d" % [MONTHS[current_month - 1], current_year, current_week]

static func format_date(year: int, month: int, week: int) -> String:
    if year <= 0:
        return "—"
    var index := clampi(month, 1, 12) - 1
    return "%s %d, W%d" % [MONTHS[index], year, clampi(week, 1, WEEKS_PER_MONTH)]

static func format_month(year: int, month: int) -> String:
    if year <= 0:
        return "—"
    var index := clampi(month, 1, 12) - 1
    return "%s %d" % [MONTH_NAMES[index], year]

func company_age_label() -> String:
    var weeks := weeks_since(GameState.founded_year, GameState.founded_month, GameState.founded_week)
    var years := weeks / (WEEKS_PER_MONTH * 12)
    if years < 1:
        var months := weeks / WEEKS_PER_MONTH
        return "%d month%s" % [months, "" if months == 1 else "s"]
    return "%d year%s" % [years, "" if years == 1 else "s"]

func set_date(year: int, month: int, week: int) -> void:
    current_year = year
    current_month = clampi(month, 1, 12)
    current_week = clampi(week, 1, WEEKS_PER_MONTH)

func reset_time() -> void:
    current_year = START_YEAR
    current_month = 1
    current_week = 1
