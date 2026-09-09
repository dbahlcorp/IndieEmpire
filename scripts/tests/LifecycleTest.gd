extends TestCase

## PA.14 -- iOS can background or terminate the app at any moment (a call, the
## screen locking, a low-memory kill, the player swiping it away). AppLifecycle
## turns every one of those into: stop the clock, write the autosave slot now,
## regardless of the autosave preference. The player must never come back to
## lost weeks, a lost project, or a release that un-happened.

func run() -> void:
    _backgrounding_pauses_and_saves_even_with_autosave_off()
    _a_running_project_and_a_fresh_release_survive_a_suspend()
    _resume_does_not_silently_restart_the_clock()
    _suspend_is_idempotent()
    SaveManager.delete_save(SaveManager.AUTOSAVE)

func _seed_company() -> void:
    GameState.start_company("Lifeboat Studios", "Devan", "normal")
    SaveManager.has_active_company = true
    GameClock.enter_gameplay()
    AppLifecycle._suspended = false
    # Each case is its own genuine suspend, not a tight-loop re-fire.
    AppLifecycle._last_save_ms = -100000

func _backgrounding_pauses_and_saves_even_with_autosave_off() -> void:
    section("home button: clock stops, save is written")
    _seed_company()
    Settings.autosave_enabled = false
    SaveManager.delete_save(SaveManager.AUTOSAVE)
    GameClock.set_paused(false)

    AppLifecycle.handle_suspend()

    check(GameClock.paused, "the simulation clock is paused on the way out")
    check(SaveManager.has_save(SaveManager.AUTOSAVE),
        "a save exists even though routine autosave is turned off")
    Settings.autosave_enabled = true

func _a_running_project_and_a_fresh_release_survive_a_suspend() -> void:
    section("an active project and a just-shipped game are still there on reload")
    _seed_company()

    var in_dev := GameProject.new()
    in_dev.id = GameState.next_project_id()
    in_dev.title = "Work In Progress"
    in_dev.genre_id = "action"
    in_dev.theme_id = "space"
    GameState.active_projects.append(in_dev)
    GameState.select_project(in_dev)

    var shipped := GameProject.new()
    shipped.id = GameState.next_project_id()
    shipped.title = "Just Launched"
    shipped.released = true
    shipped.sales_active = true
    shipped.weekly_sales = [4200]
    GameState.released_games.append(shipped)

    AppLifecycle.handle_suspend()
    check(SaveManager.load_game(SaveManager.AUTOSAVE), "the safety save reloads cleanly")

    var reloaded_project := GameState.find_active_project(in_dev.id)
    check_not_null(reloaded_project, "the in-development project resumed")
    if reloaded_project != null:
        check_equal(reloaded_project.title, "Work In Progress", "with its title intact")

    var reloaded_game := GameState.find_game(shipped.id)
    check_not_null(reloaded_game, "the shipped game is on record")
    if reloaded_game != null:
        check(reloaded_game.sales_active, "and is still selling on the market")

func _resume_does_not_silently_restart_the_clock() -> void:
    section("coming back to the foreground leaves the clock where the player left it")
    _seed_company()
    AppLifecycle.handle_suspend()
    check(GameClock.paused, "paused while away")
    AppLifecycle.handle_resume()
    check(GameClock.paused, "still paused on return -- the player taps play, no weeks slip")

func _suspend_is_idempotent() -> void:
    section("focus-out and application-paused can both fire without harm")
    _seed_company()
    AppLifecycle.handle_suspend()
    var first := AppLifecycle._last_save_ms
    AppLifecycle.handle_suspend()
    check_equal(AppLifecycle._last_save_ms, first, "a back-to-back suspend does not re-save in a tight loop")
