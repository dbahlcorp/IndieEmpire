extends Node

## Keeps a company safe across the things a phone does to an app it does not
## own: backgrounding, a phone call or alarm, the screen locking, a low-memory
## kill, or the player swiping the app away. iOS can suspend or terminate the
## process at any of these points with no further warning, so the rule is
## simple -- whenever focus is about to leave, stop the clock and write the
## autosave slot, regardless of the autosave preference.
##
## Nothing here advances or mutates the simulation. On the way back in the
## clock stays paused: the player taps play when they are ready, and no wall
## time is silently converted into simulated weeks.

## Debounce: focus-out and application-paused often arrive back to back.
const RESAVE_COOLDOWN_MS := 400

var _last_save_ms: int = -100000
var _suspended := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    # We do the saving, so the tree must not quit out from under us on a close
    # request before the write finishes.
    get_tree().set_auto_accept_quit(false)
    get_tree().set_quit_on_go_back(false)

func _notification(what: int) -> void:
    match what:
        NOTIFICATION_APPLICATION_PAUSED, \
        NOTIFICATION_APPLICATION_FOCUS_OUT, \
        NOTIFICATION_WM_WINDOW_FOCUS_OUT, \
        NOTIFICATION_OS_MEMORY_WARNING:
            handle_suspend()
        NOTIFICATION_APPLICATION_RESUMED, \
        NOTIFICATION_APPLICATION_FOCUS_IN, \
        NOTIFICATION_WM_WINDOW_FOCUS_IN:
            handle_resume()
        NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST:
            handle_quit_request()

func handle_suspend() -> void:
    ## Focus is leaving. Pause and persist. Safe to call repeatedly.
    if _suspended:
        return
    _suspended = true
    if SaveManager.has_active_company and not GameState.bankrupt:
        GameClock.set_paused(true)
    EventBus.app_suspending.emit()
    _safety_save()

func handle_resume() -> void:
    if not _suspended:
        return
    _suspended = false
    # The clock is left paused on purpose -- see the class comment.
    EventBus.app_resumed.emit()

func handle_quit_request() -> void:
    ## The player is closing the app (swipe-away, window close, Android back).
    handle_suspend()
    # Give the write a beat to flush before the process goes away.
    _safety_save()
    get_tree().quit()

func _safety_save() -> void:
    var now := Time.get_ticks_msec()
    if now - _last_save_ms < RESAVE_COOLDOWN_MS:
        return
    _last_save_ms = now
    if SaveManager.has_active_company:
        SaveManager.safety_save()
