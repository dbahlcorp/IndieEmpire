extends Node

## Owns the one emergency loan a struggling studio can take (PA.13). State lives
## on GameState.loan / GameState.loans_taken; the maths lives in LoanSimulator.
## Hooked into World's weekly tick just before FinanceManager settles the books,
## so a repayment the studio cannot afford pushes cash down exactly like payroll
## does -- a loan buys time, it does not buy grace, and taking one never resets
## GameState.overdrawn_weeks.

func has_loan() -> bool:
    return not GameState.loan.is_empty()

func outstanding_debt() -> int:
    if not has_loan():
        return 0
    return int(ceil(float(GameState.loan.get("balance", 0.0))))

func weekly_payment() -> int:
    return int(GameState.loan.get("weekly_payment", 0)) if has_loan() else 0

func best_annual_revenue() -> int:
    var best := 0
    for row in FinanceManager.annual_history():
        best = maxi(best, int(row.get("income", 0)))
    return best

func max_principal() -> int:
    return LoanSimulator.max_principal(best_annual_revenue(), not GameState.released_games.is_empty())

func eligibility() -> Dictionary:
    return LoanSimulator.eligibility(has_loan(), GameState.loans_taken, max_principal())

func can_borrow() -> bool:
    return bool(eligibility().get("ok", false))

func take_loan(requested_principal: int) -> Dictionary:
    var check := eligibility()
    if not bool(check.get("ok", false)):
        return check
    var principal := clampi(
        requested_principal, LoanSimulator.MIN_PRINCIPAL, int(check.get("max_principal", 0)))

    GameState.loan = LoanSimulator.new_loan(
        principal, TimeManager.current_year, TimeManager.current_month, TimeManager.current_week)
    GameState.loans_taken += 1

    # The cash arrives; the grace clock is untouched. A loan is money, not time.
    FinanceManager.earn(principal, Ledger.Kind.LOAN, "Emergency loan")

    var payment := int(GameState.loan["weekly_payment"])
    EventBus.emergency_loan_taken.emit(principal, payment)
    EventBus.notify("LOAN APPROVED", "%s now, %s/week for %d weeks" % [
        Format.money(principal), Format.money(payment), LoanSimulator.TERM_WEEKS], true)
    NewsManager.post_loan_taken(principal, payment)
    SaveManager.autosave()
    return {"ok": true, "principal": principal, "weekly_payment": payment}

func repay_early() -> Dictionary:
    if not has_loan():
        return {"ok": false, "reason": "There is no loan to settle."}
    var payoff := LoanSimulator.payoff_amount(GameState.loan)
    if not FinanceManager.spend(payoff, Ledger.Kind.LOAN_PAYMENT, "Loan settled early"):
        return {"ok": false, "reason": "Not enough cash to settle the balance (%s)." % Format.money(payoff)}
    GameState.loan = {}
    EventBus.emergency_loan_settled.emit(true)
    EventBus.notify("LOAN SETTLED", "The emergency loan is paid off early.", false)
    SaveManager.autosave()
    return {"ok": true, "paid": payoff}

func process_week() -> void:
    if GameState.bankrupt or not has_loan():
        return
    var step := LoanSimulator.advance_one_week(GameState.loan)
    var payment := int(step["payment"])
    if payment > 0:
        FinanceManager.force_spend(payment, Ledger.Kind.LOAN_PAYMENT, "Loan repayment")
    GameState.loan["balance"] = float(step["new_balance"])
    GameState.loan["weeks_remaining"] = maxi(int(GameState.loan.get("weeks_remaining", 0)) - 1, 0)
    if bool(step["closed"]):
        GameState.loan = {}
        EventBus.emergency_loan_settled.emit(false)
        EventBus.notify("LOAN REPAID", "The emergency loan has been paid off.", false)

func loan_summary() -> Dictionary:
    ## For the crisis and financials screens. {} when there is no loan.
    if not has_loan():
        return {}
    var loan: Dictionary = GameState.loan
    return {
        "principal": int(loan.get("principal", 0)),
        "balance": outstanding_debt(),
        "weekly_payment": int(loan.get("weekly_payment", 0)),
        "weeks_remaining": int(loan.get("weeks_remaining", 0)),
        "weeks_total": int(loan.get("weeks_total", LoanSimulator.TERM_WEEKS)),
        "payoff": LoanSimulator.payoff_amount(loan),
    }
