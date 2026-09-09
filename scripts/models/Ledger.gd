class_name Ledger
extends RefCounted

## Every dollar in and out is written down. The screens read this rather than
## recomputing totals, and later milestones (salaries, offices, marketing) only
## have to add new transaction types.

enum Kind {
    SALES,
    DEVELOPMENT,
    PLATFORM_FEE,
    UPFRONT,
    POLISH,
    HIRING,
    PAYROLL,
    CONTRACT,
    ADVANCE,
    TRAINING,
    OFFICE,
    UTILITIES,
    SOFTWARE,
    OFFICE_MOVE,
    OTHER,
    OFFICE_CUSTOMIZATION,
    SEVERANCE,
    EQUIPMENT,
    ENGINE,
    LOAN,
    LOAN_PAYMENT
}

const KIND_NAMES := {
    Kind.SALES: "Sales",
    Kind.DEVELOPMENT: "Development",
    Kind.PLATFORM_FEE: "Platform fee",
    Kind.UPFRONT: "Project start",
    Kind.POLISH: "Polish",
    Kind.HIRING: "Hiring",
    Kind.PAYROLL: "Payroll",
    Kind.CONTRACT: "Contract work",
    Kind.ADVANCE: "Publisher advance",
    Kind.TRAINING: "Training",
    Kind.OFFICE: "Office",
    Kind.UTILITIES: "Utilities",
    Kind.SOFTWARE: "Software",
    Kind.OFFICE_MOVE: "Office move",
    Kind.OFFICE_CUSTOMIZATION: "Office customization",
    Kind.SEVERANCE: "Severance",
    Kind.EQUIPMENT: "Equipment",
    Kind.ENGINE: "Engine development",
    Kind.LOAN: "Loan",
    Kind.LOAN_PAYMENT: "Loan repayment",
    Kind.OTHER: "Other"
}

static func kind_name(kind: int) -> String:
    return str(KIND_NAMES.get(kind, "Other"))

static func make(kind: int, description: String, amount: int, project_id: String = "") -> Dictionary:
    return {
        "year": TimeManager.current_year,
        "month": TimeManager.current_month,
        "week": TimeManager.current_week,
        "kind": kind,
        "description": description,
        "amount": amount,
        "project_id": project_id
    }

static func date_label(entry: Dictionary) -> String:
    return TimeManager.format_date(
        int(entry.get("year", 0)),
        int(entry.get("month", 1)),
        int(entry.get("week", 1))
    )

static func amount_label(entry: Dictionary) -> String:
    var amount := int(entry.get("amount", 0))
    var sign_text := "+" if amount >= 0 else "-"
    return "%s$%s" % [sign_text, Format.exact(absi(amount))]
