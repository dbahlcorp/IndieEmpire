extends Node

## THE WORLD TICK.
##
## One week is the fundamental unit of simulation, and this is the only place it
## is processed. The order below is deliberate and every later system should be
## added to it rather than hooking TimeManager directly:
##
##   GameClock (real time) -> TimeManager.advance_week()
##          |
##     PlatformManager   hardware ages, launches and dies
##     ProjectManager    the project in development does a week of work
##     ContractManager   contract work advances, completes or runs late
##     TrainingManager   courses run down and people come back better
##     ResearchManager   research projects advance; a technology may complete
##     MoraleManager     morale and stress settle after the week's work
##     RetentionManager  people ask for things, or hand in notice
##     StudioEventManager an event may be raised, or its penalty ages off
##     SalesManager      games on the market sell another week
##     MarketManager     trends drift, saturation decays
##     LaborMarketManager candidates rotate
##     EmployeeManager   monthly payroll settles
##     ExperienceManager (awarded on postmortem, nothing weekly yet)
##     UnlockManager     new content becomes available
##     FinanceManager    the books settle, then solvency is judged
##     NewsManager       stories are posted by the events above
##     SaveManager       the week is committed to disk

signal week_processed()

var _processing := false

func _ready() -> void:
    TimeManager.week_advanced.connect(_on_week_advanced)
    if GameState.genre_trends.is_empty():
        MarketManager.seed_trends()

func _on_week_advanced(year: int, month: int, week: int) -> void:
    if _processing:
        push_error("A week was advanced while one was still being processed.")
        return

    _processing = true

    PlatformManager.process_year_change()
    TeamManager.process_week()
    ProjectManager.process_week()
    ContractManager.process_week()
    TrainingManager.process_week()
    ResearchManager.process_week()
    MoraleManager.process_week()
    RetentionManager.process_week()
    StudioEventManager.process_week()
    CultureManager.process_week()
    SalesManager.process_week()
    MarketManager.process_week()
    LaborMarketManager.process_week()
    EmployeeManager.process_week()
    UnlockManager.refresh()
    FinanceManager.process_week()
    FinanceManager.check_solvency()
    SaveManager.autosave()

    _processing = false

    EventBus.week_ticked.emit(year, month, week)
    week_processed.emit()

func sync_year() -> void:
    ## Called after a load so a year boundary is not replayed.
    PlatformManager.sync_year()
