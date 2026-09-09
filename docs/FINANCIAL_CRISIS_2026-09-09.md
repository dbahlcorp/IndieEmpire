# Financial crisis & recovery (PA.13) — 2026-09-09

## What shipped

A staged warning layer and a guided recovery screen on top of the existing
bankruptcy cliff, plus one new mechanic: a capped emergency loan.

- **`CrisisSimulator`** (pure) grades money position into `HEALTHY`,
  `RUNWAY_LOW`, `TROUBLE`, `CRITICAL`, `INSOLVENT`; names the single biggest
  recurring cost (`biggest_driver`); estimates conservative near-term income.
- **`FinanceManager`** stores the level on `GameState.crisis_level` and emits
  `financial_crisis_changed` / `company_bankruptcy_warning` only when the level
  *steps up*, not every overdrawn week. `RUNWAY_LOW` never pauses the clock;
  `TROUBLE` and `CRITICAL` each pause it once.
- **`CrisisScreen`** shows cash, burn, runway, upcoming payroll, project
  completion, near-term income and debt, then lists levers with consequences:
  cancel project, cut a feature, lay off staff, downgrade office
  (`OfficeManager.downgrade` — new), take contract work, take a loan.
- **`LoanSimulator` / `LoanManager`** — one loan at a time; principal capped at
  60% of the best proven trading year (`NO_HISTORY_PRINCIPAL` = $15K floor,
  `MAX_PRINCIPAL` = $250K ceiling); `WEEKLY_INTEREST_RATE` = 1%/week over a
  `TERM_WEEKS` = 52 amortised schedule; `MAX_CAREER_LOANS` = 4. The weekly
  repayment is drawn in the world tick just before the books settle, exactly
  like payroll. Taking a loan never touches `overdrawn_weeks`.

## Numbers

For a $100K loan: weekly payment ≈ $2,475, total repaid ≈ $128,700 (≈29%
interest over the year). That is deliberately steep — a loan is a last resort,
and doubling a small studio's effective burn only helps if revenue is about to
recover.

## Balance measurement

The design constraint is "loans must not make bankruptcy effectively
impossible."

- **`CrisisEconomyTest`** plays a structurally insolvent studio (five senior
  staff, a Professional Studio office, no game on the market and none coming)
  that reaches for the maximum loan every time it is eligible. It still goes
  bankrupt in **well under 240 weeks**, takes **no more than 4 loans**, and
  ends its life overdrawn — the loans bought months, not years, and never
  reset the grace clock.
- **`EconomyPlateauTest`** (full 1985–2050 career) is unchanged: the staged
  crisis tracking only reads state and emits events, and `LoanManager` returns
  immediately when there is no loan, so a career that never borrows is
  identical to before.
- The `BalanceProbe` manager does not model loan-taking (a loan is a player
  decision, not a manager reaction), so its bankruptcy rate — the ~25–31%
  measured in `docs/MEDIOCRE_GAMES_2026-09-08.md` — is untouched by this work.
  A future probe that opportunistically borrows would be the way to measure
  player-facing impact directly; `CrisisEconomyTest` is the guard until then.

## Save format

v25: `GameState.loan`, `GameState.crisis_level`, `GameState.loans_taken` in the
company block. Older saves load with no loan and `crisis_level` recomputed from
the restored cash and burn.
