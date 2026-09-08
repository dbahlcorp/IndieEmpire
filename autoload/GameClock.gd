extends Node

## Real time. Weeks pass on their own; the player never advances the clock by
## hand. This is the only caller of TimeManager.advance_week() during play, so
## the world tick in World.gd is unchanged by it.

signal state_changed()

const BASE_WEEK_SECONDS := 2.0
const SPEEDS := [1.0, 2.0, 4.0]
const SPEED_LABELS := ["1x", "2x", "4x"]

var paused := false
var speed_index := 0

## Menus, setup dialogs and postmortems hold time still without touching the
## player's own pause choice.
var _suspended := true
var _accumulated := 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    EventBus.company_bankruptcy_warning.connect(_on_trouble)
    EventBus.company_bankrupt.connect(_on_bankrupt)

func _process(delta: float) -> void:
    if not is_running():
        return

    _accumulated += delta * SPEEDS[speed_index]
    while _accumulated >= BASE_WEEK_SECONDS:
        _accumulated -= BASE_WEEK_SECONDS
        TimeManager.advance_week()

        # A week can end the run or finish a project; stop rather than run on.
        if not is_running():
            _accumulated = 0.0
            return

func is_running() -> bool:
    if _suspended or paused:
        return false
    if not SaveManager.has_active_company or GameState.bankrupt:
        return false
    return true

func speed_label() -> String:
    return str(SPEED_LABELS[speed_index])

func cycle_speed() -> void:
    speed_index = (speed_index + 1) % SPEEDS.size()
    state_changed.emit()

func set_paused(value: bool) -> void:
    paused = value
    _accumulated = 0.0
    state_changed.emit()

func toggle_pause() -> void:
    set_paused(not paused)

func enter_gameplay(start_running: bool = true) -> void:
    ## Called by screens where time should flow.
    _suspended = false
    if start_running:
        paused = false
    _accumulated = 0.0
    state_changed.emit()

func enter_menu() -> void:
    ## Called by menus and setup screens: time holds, pause state untouched.
    _suspended = true
    _accumulated = 0.0
    state_changed.emit()

func pause_for_decision(_reason: String = "") -> void:
    ## Something needs the player, so stop the clock and let the screen say why.
    if not paused:
        paused = true
        _accumulated = 0.0
        state_changed.emit()

func _on_trouble(_weeks_left: int) -> void:
    pause_for_decision("financial trouble")

func _on_bankrupt() -> void:
    pause_for_decision("bankrupt")
