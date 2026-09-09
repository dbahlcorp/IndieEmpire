extends TestCase

## PA.13 economic guard: the emergency loan must not make bankruptcy
## effectively impossible.
##
## Plays a structurally insolvent studio -- a senior team, a big office, no
## game on the market and none coming -- that reaches for the maximum loan the
## instant it is eligible, every time, until no lender will touch it. The claim:
## it still goes bankrupt, and not much later than it would have unaided.
##
## The regular BalanceProbe / EconomyPlateau careers do not model loans (a loan
## is a player choice, not a manager reaction), so this is the check that the
## mechanic itself cannot be abused into immortality.

## A doomed studio with no loans available dies within a handful of grace
## windows. Four maxed loans, each servicing a weekly repayment that only
## deepens the hole, must not stretch that into years and years.
const MAX_SURVIVAL_WEEKS := 240

func run() -> void:
    seed(13)
    GameState.start_company("Sinkhole", "Sam", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    GameState.cash = 0
    # One good year on the record, so the studio has real borrowing capacity...
    FinanceManager.earn(240_000, Ledger.Kind.SALES, "the year it all worked")
    # ...then spend it into an office and a team it cannot possibly carry.
    OfficeManager.move_to("shared_workspace")
    OfficeManager.move_to("small_office")
    OfficeManager.move_to("professional_studio")
    for role in ["programmer", "artist", "designer", "writer", "audio_designer"]:
        var candidate := EmployeeManager.generate_candidate(role, "senior")
        GameState.labor_candidates.append(candidate)
        LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)

    GameState.cash = int(EmployeeManager.monthly_payroll() / 2)
    var payroll := EmployeeManager.monthly_payroll()
    check_greater(float(payroll), 0.0, "a payroll with nothing behind it (%s/mo)" % Format.money_exact(payroll))

    var loans := 0
    var weeks := 0
    while not GameState.bankrupt and weeks < 600:
        if LoanManager.can_borrow():
            var result := LoanManager.take_loan(LoanManager.max_principal())
            if bool(result.get("ok", false)):
                loans += 1
        TimeManager.advance_week()
        weeks += 1

    section("a doomed studio that borrows to the hilt still dies")
    check(GameState.bankrupt, "bankruptcy still arrived (%d weeks, %d loans)" % [weeks, loans])
    check_less(float(weeks), float(MAX_SURVIVAL_WEEKS),
        "and the loans only bought months, not years (%d weeks)" % weeks)
    check_less(float(loans), float(LoanSimulator.MAX_CAREER_LOANS) + 1.0,
        "no more than the career limit of loans was ever extended (%d)" % loans)
    check_greater(float(loans), 0.0, "the studio did take at least one loan")
    check(GameState.loan.is_empty(), "no loan outstanding once the company folds")

    section("the grace clock was never reset by borrowing")
    # overdrawn_weeks only resets on genuinely positive cash; a loan that is
    # immediately eaten by payroll must not have bought a fresh grace window.
    check_greater(float(GameState.overdrawn_weeks), 0.0,
        "the studio ended its life overdrawn, not mid-grace-reset")
