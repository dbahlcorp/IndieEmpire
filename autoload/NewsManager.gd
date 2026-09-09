extends Node

## Owns the news feed. Every system tells its story through here rather than
## writing player-facing text of its own.

const PLATFORM := "Platform"
const MARKET := "Market"
const COMPANY := "Company"
const GAME := "Game"
const INDUSTRY := "Industry"
const FINANCIAL := "Financial"

const MAX_ITEMS := 250
const SALES_MILESTONES := [10_000, 100_000, 500_000, 1_000_000, 5_000_000]

func _ready() -> void:
    EventBus.game_released.connect(_on_game_released)
    EventBus.preproduction_completed.connect(_on_preproduction_completed)
    EventBus.game_breakout_hit.connect(_on_breakout)
    EventBus.game_commercial_failure.connect(_on_failure)
    EventBus.game_hit_sales_milestone.connect(_on_milestone)
    EventBus.platform_announced.connect(_on_platform_announced)
    EventBus.platform_released.connect(_on_platform_released)
    EventBus.platform_retiring.connect(_on_platform_retiring)
    EventBus.platform_discontinued.connect(_on_platform_discontinued)
    EventBus.employee_burnt_out.connect(_on_burnt_out)
    EventBus.employee_promoted.connect(_on_promoted)
    EventBus.employee_tier_up.connect(_on_tier_up)
    EventBus.employee_resigned.connect(_on_resigned)
    EventBus.employee_departed.connect(_on_departed)
    EventBus.employee_laid_off.connect(_on_laid_off)
    EventBus.mass_layoffs_reported.connect(_on_mass_layoffs)
    EventBus.studio_event_resolved.connect(_on_studio_event_resolved)
    EventBus.contract_completed.connect(_on_contract_completed)
    EventBus.contract_failed.connect(_on_contract_failed)
    EventBus.company_bankruptcy_warning.connect(_on_bankruptcy_warning)
    EventBus.company_recovered.connect(_on_recovered)
    EventBus.company_bankrupt.connect(_on_bankrupt)
    EventBus.genre_unlocked.connect(_on_genre_unlocked)
    EventBus.theme_unlocked.connect(_on_theme_unlocked)
    EventBus.size_unlocked.connect(_on_size_unlocked)

func post(category: String, headline: String, body: String) -> void:
    var item := {
        "year": TimeManager.current_year,
        "month": TimeManager.current_month,
        "week": TimeManager.current_week,
        "category": category,
        "headline": headline,
        "body": body
    }
    GameState.news.push_front(item)
    if GameState.news.size() > MAX_ITEMS:
        GameState.news.resize(MAX_ITEMS)
    EventBus.news_posted.emit(item)

func post_founding() -> void:
    post(COMPANY,
        "%s OPENS ITS DOORS" % GameState.company_name.to_upper(),
        "%s has founded %s with %s in the bank." % [
            GameState.founder_name, GameState.company_name, Format.money_exact(GameState.cash)])

func post_awards_ceremony(ceremony: Dictionary) -> void:
    ## The annual Game Awards (PA.11). One story listing the studio's haul and
    ## the Game of the Year winner if it took one.
    var year := int(ceremony.get("year", 0)) + 1
    var categories: Array = ceremony.get("categories", [])
    if categories.is_empty():
        return
    var lines: Array[String] = []
    var goty := ""
    for category in categories:
        var name := str(category.get("name", ""))
        var winner := str(category.get("winner_title", ""))
        lines.append("%s — %s" % [name, winner])
        if str(category.get("award_id", "")) == "goty":
            goty = winner
    var wins := categories.size()
    var headline := "%s TAKES %d AT THE %d GAME AWARDS" % [
        GameState.company_name.to_upper(), wins, year]
    if not goty.is_empty():
        headline = "%s NAMED %d GAME OF THE YEAR" % [goty.to_upper(), year]
    post(INDUSTRY, headline,
        "The %d Game Awards recognised %s.\n\n%s" % [
            year, GameState.company_name, "\n".join(lines)])

func post_trend_shift(risen: String, gain: float, fallen: String, drop: float) -> void:
    if not risen.is_empty() and gain >= absf(drop):
        post(MARKET, "%s SALES SURGE" % risen.to_upper(),
            "%s games have seen a marked increase in popularity. Analysts expect the trend to hold for a season." % risen)
        EventBus.notify("MARKET TREND", "%s demand rising" % risen)
        return
    if not fallen.is_empty():
        post(MARKET, "%s LOSING GROUND" % fallen.to_upper(),
            "Retailers report cooling demand for %s games." % fallen.to_lower())
        EventBus.notify("MARKET TREND", "%s demand falling" % fallen)

# --- Event handlers ----------------------------------------------------

func _on_preproduction_completed(project: GameProject, modifier: float, flaw_label: String) -> void:
    ## Most projects plan adequately and this is not news. Only the extremes
    ## are worth a headline.
    if flaw_label.is_empty():
        return
    var sign := "+" if modifier >= 0.0 else ""
    post(GAME, "%s: %s" % [flaw_label, project.title.to_upper()],
        "%s\n%s\nProduction efficiency %s%d%%" % [
            flaw_label, PreproductionSimulator.description(flaw_label),
            sign, int(round(modifier * 100.0))])
    EventBus.notify(flaw_label, "%s -- production efficiency %s%d%%" % [
        project.title, sign, int(round(modifier * 100.0))], true)

func _on_game_released(project: GameProject) -> void:
    post(GAME, "%s RELEASED" % project.title.to_upper(),
        "%s ships %s on %s to an average review score of %.1f." % [
            GameState.company_name, project.title,
            DataManager.display_name(DataManager.platforms, project.platform_id),
            project.review_score])

func _on_breakout(project: GameProject) -> void:
    post(GAME, "BREAKOUT HIT",
        "%s is spreading through word of mouth. Sales climbed again this week." % project.title)
    EventBus.notify("BREAKOUT HIT", "%s is spreading by word of mouth" % project.title, true)

func _on_failure(project: GameProject) -> void:
    post(FINANCIAL, "COMMERCIAL FAILURE",
        "%s has fallen out of the charts. It cost %s against %s of revenue, a loss of %s." % [
            project.title, Format.money_exact(project.total_cost()),
            Format.money_exact(project.lifetime_revenue),
            Format.money_exact(absi(project.profit()))])
    EventBus.notify("COMMERCIAL FAILURE", "%s lost %s" % [
        project.title, Format.money(absi(project.profit()))], true)

func _on_milestone(project: GameProject, milestone: int) -> void:
    var tail := ""
    var best := CompanyStats.best_selling()
    if best != null and best.id == project.id:
        tail = " It is now the studio's best-selling title."
    post(COMPANY, "%s PASSES %s SALES" % [project.title.to_upper(), Format.compact(milestone)],
        "%s has sold more than %s copies.%s" % [project.title, Format.exact(milestone), tail])
    EventBus.notify("SALES MILESTONE", "%s passed %s copies" % [project.title, Format.compact(milestone)], true)

func _on_platform_announced(platform: Dictionary) -> void:
    post(PLATFORM, "NEW HARDWARE ANNOUNCED",
        "%s is scheduled to launch in %d at around $%d. Analysts expect strong consumer demand." % [
            platform.get("name", "?"), int(platform.get("release_year", 0)), int(platform.get("price", 0))])

func _on_platform_released(platform: Dictionary) -> void:
    post(PLATFORM, "%s NOW AVAILABLE" % str(platform.get("name", "?")).to_upper(),
        "Install base %s and climbing. Developers can now target the system." %
            Format.exact(PlatformManager.install_base(platform)))
    EventBus.notify("NEW PLATFORM", str(platform.get("name", "?")), true)

func _on_platform_retiring(platform: Dictionary) -> void:
    post(PLATFORM, "PRODUCTION TO END",
        "Production of the %s will wind down. Its audience will shrink from here." % platform.get("name", "?"))

func _on_platform_discontinued(platform: Dictionary) -> void:
    post(PLATFORM, "%s DISCONTINUED" % str(platform.get("name", "?")).to_upper(),
        "The %s is no longer a viable release platform." % platform.get("name", "?"))
    EventBus.notify("DISCONTINUED", str(platform.get("name", "?")), true)

func _on_burnt_out(employee: Employee) -> void:
    post(COMPANY, "EMPLOYEE BURNOUT",
        "%s has been signed off for %d weeks. Morale across the studio has taken a knock." % [
            employee.display_name(), MoraleSimulator.BURNOUT_LEAVE_WEEKS])

func _on_promoted(employee: Employee, seniority: String) -> void:
    post(COMPANY, "%s PROMOTED" % employee.display_name().to_upper(),
        "%s is now a %s %s." % [
            employee.display_name(), seniority.capitalize(),
            EmployeeManager.role_name(employee.role)])
    EventBus.notify("PROMOTED", "%s to %s" % [employee.display_name(), seniority.capitalize()], true)

func _on_tier_up(employee: Employee, tier: String) -> void:
    var article := "an" if tier.substr(0, 1) in ["A", "E", "I", "O", "U"] else "a"
    post(INDUSTRY, "%s IS NOW %s %s" % [
        employee.display_name().to_upper(), article.to_upper(), tier.to_upper()],
        "%s %s regarded in the industry as %s %s." % [
            employee.display_name(), employee.verb("is", "are"), article, tier])
    EventBus.notify("INDUSTRY REPUTATION", "%s is now %s %s" % [
        employee.display_name(), article, tier], true)

func _on_resigned(employee: Employee) -> void:
    post(COMPANY, "%s HANDS IN NOTICE" % employee.display_name().to_upper(),
        "%s intends to leave %s in %d weeks." % [
            employee.display_name(), GameState.company_name, employee.notice_weeks])

func _on_departed(employee: Employee) -> void:
    post(COMPANY, "%s HAS LEFT" % employee.display_name().to_upper(),
        "%s has left %s." % [employee.display_name(), GameState.company_name])
    EventBus.notify("DEPARTED", "%s has left the studio" % employee.display_name(), true)

func _on_laid_off(employee: Employee) -> void:
    post(COMPANY, "%s LET GO" % employee.display_name().to_upper(),
        "%s has laid off %s, %s." % [
            GameState.company_name, employee.display_name(),
            EmployeeManager.job_title(employee)])

func _on_mass_layoffs(count: int) -> void:
    post(INDUSTRY, "LAYOFFS AT %s" % GameState.company_name.to_upper(),
        ("%s has cut %d jobs in the space of a year. Word travels; the studio's "
        + "standing as an employer has taken a hit.") % [GameState.company_name, count])
    EventBus.notify("LAYOFFS", "%s's reputation is suffering" % GameState.company_name, true)

func _on_studio_event_resolved(event_id: String, _choice_index: int, outcome: String) -> void:
    if outcome.strip_edges().is_empty():
        return
    var event := DataManager.get_studio_event(event_id)
    post(COMPANY, str(event.get("title", "STUDIO NEWS")), outcome)

func _on_contract_completed(contract: Contract) -> void:
    post(COMPANY, "CONTRACT DELIVERED",
        "%s finished %s for %s, earning %s." % [
            GameState.company_name, contract.name, contract.client,
            Format.money_exact(contract.payout)])
    EventBus.notify("CONTRACT PAID", "%s for %s" % [
        Format.money(contract.payout), contract.client], true)

func _on_contract_failed(contract: Contract, abandoned: bool) -> void:
    var reason := "walked away from" if abandoned else "missed the deadline on"
    post(FINANCIAL, "CONTRACT LOST",
        "%s %s %s for %s. The fee goes unpaid and the studio's standing suffers." % [
            GameState.company_name, reason, contract.name, contract.client])
    EventBus.notify("CONTRACT LOST", contract.name, true)

func _on_bankruptcy_warning(weeks_left: int) -> void:
    var critical := GameState.crisis_level >= CrisisSimulator.CRITICAL
    var headline := "CRISIS: %s NEAR COLLAPSE" % GameState.company_name.to_upper() if critical \
        else "FINANCIAL TROUBLE"
    post(FINANCIAL, headline,
        "%s has run out of operating capital. %d week%s remain to return to positive cash. Open the crisis plan for options." % [
            GameState.company_name, weeks_left, "" if weeks_left == 1 else "s"])
    EventBus.notify("CRITICAL" if critical else "FINANCIAL TROUBLE", "%d week%s to recover" % [
        weeks_left, "" if weeks_left == 1 else "s"], true)

func post_loan_taken(principal: int, weekly_payment: int) -> void:
    post(FINANCIAL, "%s TAKES OUT A LOAN" % GameState.company_name.to_upper(),
        ("%s borrowed %s in emergency financing, repayable at %s per week for %d weeks. "
        + "It buys time, not a way out.") % [
            GameState.company_name, Format.money_exact(principal),
            Format.money_exact(weekly_payment), LoanSimulator.TERM_WEEKS])

func _on_recovered() -> void:
    post(FINANCIAL, "BACK IN THE BLACK", "%s is solvent again." % GameState.company_name)

func _on_bankrupt() -> void:
    post(FINANCIAL, "%s IS BANKRUPT" % GameState.company_name.to_upper(),
        "The studio could not return to positive cash flow in time.")

func _on_genre_unlocked(_id: String, name: String) -> void:
    post(INDUSTRY, "NEW GENRE UNLOCKED: %s" % name.to_upper(),
        "Your growing development experience allows the studio to take on %s games." % name)
    EventBus.notify("NEW GENRE", name, true)

func _on_theme_unlocked(_id: String, name: String) -> void:
    post(INDUSTRY, "NEW THEME UNLOCKED: %s" % name.to_upper(),
        "The studio has found inspiration for %s games." % name)
    EventBus.notify("NEW THEME", name, true)

func _on_size_unlocked(_id: String, name: String) -> void:
    post(INDUSTRY, "NEW PROJECT SIZE: %s" % name.to_upper(),
        "The studio can now take on %s projects." % name.to_lower())
    EventBus.notify("NEW PROJECT SIZE", name, true)
