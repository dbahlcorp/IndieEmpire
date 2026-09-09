class_name LoanSimulator
extends RefCounted

## Pure maths for the emergency loan (PA.13). One loan at a time, priced to buy
## a struggling studio a few months of runway -- not to fix a business that
## spends more than it earns. The weekly repayment is a new fixed cost that
## lands the moment the loan does, the interest is deliberately steep, the
## principal is capped against the studio's own proven revenue, and a career is
## cut off after MAX_CAREER_LOANS. CrisisEconomyTest pins that a doomed studio
## that borrows the maximum every time still goes bankrupt.

## ~1%/week compounding is about 68%/year effective. Punitive on purpose: a
## loan is a last resort, not cheap money.
const WEEKLY_INTEREST_RATE := 0.010
const TERM_WEEKS := 52
const MIN_PRINCIPAL := 5_000
const MAX_PRINCIPAL := 250_000
const MAX_CAREER_LOANS := 4
## Principal is capped at this share of the best single year of income the
## studio has actually booked.
const PRINCIPAL_REVENUE_MULTIPLE := 0.60
## What a studio with no trading year yet can borrow against nothing but its
## own existence -- barely a month of a small payroll.
const NO_HISTORY_PRINCIPAL := 15_000

static func weekly_payment(principal: int, rate: float = WEEKLY_INTEREST_RATE, term: int = TERM_WEEKS) -> int:
    if principal <= 0 or term <= 0:
        return 0
    if rate <= 0.0:
        return int(ceil(float(principal) / float(term)))
    var p := float(principal)
    var discount := pow(1.0 + rate, -float(term))
    return int(ceil(p * rate / (1.0 - discount)))

static func total_repayable(principal: int, rate: float = WEEKLY_INTEREST_RATE, term: int = TERM_WEEKS) -> int:
    return weekly_payment(principal, rate, term) * term

static func total_interest(principal: int, rate: float = WEEKLY_INTEREST_RATE, term: int = TERM_WEEKS) -> int:
    return maxi(total_repayable(principal, rate, term) - principal, 0)

static func max_principal(best_annual_revenue: int, has_released_game: bool) -> int:
    var floor_value := NO_HISTORY_PRINCIPAL if not has_released_game else MIN_PRINCIPAL
    var by_revenue := int(round(float(maxi(best_annual_revenue, 0)) * PRINCIPAL_REVENUE_MULTIPLE))
    return clampi(maxi(floor_value, by_revenue), 0, MAX_PRINCIPAL)

static func eligibility(has_loan: bool, loans_taken: int, max_principal_available: int) -> Dictionary:
    if has_loan:
        return {"ok": false, "reason": "The studio already has an outstanding loan."}
    if loans_taken >= MAX_CAREER_LOANS:
        return {"ok": false, "reason": "No lender will extend the studio any more credit."}
    if max_principal_available < MIN_PRINCIPAL:
        return {"ok": false, "reason": "The studio has no borrowing capacity yet."}
    return {"ok": true, "max_principal": max_principal_available}

static func new_loan(principal: int, year: int, month: int, week: int) -> Dictionary:
    return {
        "principal": principal,
        "balance": float(principal),
        "weekly_payment": weekly_payment(principal),
        "weekly_interest_rate": WEEKLY_INTEREST_RATE,
        "weeks_total": TERM_WEEKS,
        "weeks_remaining": TERM_WEEKS,
        "taken_year": year,
        "taken_month": month,
        "taken_week": week,
    }

static func advance_one_week(loan: Dictionary) -> Dictionary:
    ## One week of the schedule. Returns {payment, interest, principal_paid,
    ## new_balance, closed}. The final week settles whatever is left so rounding
    ## never leaves a few dollars outstanding forever.
    var balance := float(loan.get("balance", 0.0))
    var rate := float(loan.get("weekly_interest_rate", WEEKLY_INTEREST_RATE))
    var scheduled := float(loan.get("weekly_payment", 0))
    var weeks_remaining := int(loan.get("weeks_remaining", 0))
    var interest := balance * rate

    var payment := scheduled
    var closed := false
    if weeks_remaining <= 1 or balance + interest <= scheduled + 1.0:
        payment = balance + interest
        closed = true

    var new_balance := maxf(balance + interest - payment, 0.0)
    return {
        "payment": int(round(payment)),
        "interest": int(round(interest)),
        "principal_paid": int(round(payment - interest)),
        "new_balance": new_balance,
        "closed": closed,
    }

static func payoff_amount(loan: Dictionary) -> int:
    ## Settling early costs the outstanding balance plus one week of interest --
    ## no rebate, but no penalty beyond that.
    var balance := float(loan.get("balance", 0.0))
    var rate := float(loan.get("weekly_interest_rate", WEEKLY_INTEREST_RATE))
    return int(ceil(balance * (1.0 + rate)))
