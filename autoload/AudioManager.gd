extends Node

## Persistent PA.8 audio director. It owns presentation feedback only: no
## callback changes simulation values, timing, rewards, or costs.

signal music_state_changed(state: String)
signal sfx_played(id: String)
signal haptic_requested(kind: String)

const MUSIC_SOURCE: AudioStreamWAV = preload(
    "res://assets/audio/music/studio_day_loop.wav")
const AMBIENCE_SOURCE: AudioStreamWAV = preload(
    "res://assets/audio/ambience/office_room_loop.wav")

const MUSIC_STATES := [
    "main_menu", "studio", "development", "release_results", "awards",
    "financial_danger"
]
const SFX_SOURCES := {
    "button_tap": preload("res://assets/audio/sfx/button_tap.wav"),
    "navigation": preload("res://assets/audio/sfx/navigation.wav"),
    "money_gain": preload("res://assets/audio/sfx/money_gain.wav"),
    "money_spent": preload("res://assets/audio/sfx/money_spent.wav"),
    "research_complete": preload("res://assets/audio/sfx/research_complete.wav"),
    "technology_unlock": preload("res://assets/audio/sfx/technology_unlock.wav"),
    "employee_hired": preload("res://assets/audio/sfx/employee_hired.wav"),
    "employee_promotion": preload("res://assets/audio/sfx/employee_promotion.wav"),
    "employee_resignation": preload("res://assets/audio/sfx/employee_resignation.wav"),
    "game_release": preload("res://assets/audio/sfx/game_release.wav"),
    "review_reveal": preload("res://assets/audio/sfx/review_reveal.wav"),
    "excellent_review": preload("res://assets/audio/sfx/excellent_review.wav"),
    "poor_review": preload("res://assets/audio/sfx/poor_review.wav"),
    "sales_milestone": preload("res://assets/audio/sfx/sales_milestone.wav"),
    "award_nomination": preload("res://assets/audio/sfx/award_nomination.wav"),
    "award_win": preload("res://assets/audio/sfx/award_win.wav"),
    "warning": preload("res://assets/audio/sfx/warning.wav"),
    "financial_crisis": preload("res://assets/audio/sfx/financial_crisis.wav"),
    "bankruptcy": preload("res://assets/audio/sfx/bankruptcy.wav")
}

const FADE_PER_SECOND := 0.85
const SFX_POOL_SIZE := 8
const REVIEW_EXCELLENT := 8.0
const REVIEW_POOR := 5.0

var music_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var music_state: String = "studio"
var music_restart_count: int = 0

var _music_level := 0.0
var _ambience_level := 0.0
var _sfx_cursor := 0
var _last_scene_path := ""
var _last_cash := 0
var _temporary_state := ""
var _temporary_state_until := 0
var _last_sfx_at: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    music_player = _looping_player(MUSIC_SOURCE)
    ambience_player = _looping_player(AMBIENCE_SOURCE)
    add_child(music_player)
    add_child(ambience_player)
    for index in SFX_POOL_SIZE:
        var player := AudioStreamPlayer.new()
        player.max_polyphony = 2
        add_child(player)
        sfx_players.append(player)
    _last_cash = GameState.cash
    _connect_feedback_events()
    get_tree().node_added.connect(_on_node_added)
    # Dummy/headless drivers do not need playback objects running. Real mobile
    # and desktop builds keep both loops alive so navigation never restarts them.
    if DisplayServer.get_name() != "headless":
        music_player.play()
        ambience_player.play()
        music_restart_count = 1

func _exit_tree() -> void:
    for player in [music_player, ambience_player] + sfx_players:
        if player != null:
            player.stop()
            player.stream = null

func _process(delta: float) -> void:
    if music_player == null or ambience_player == null:
        return
    var path := _current_scene_path()
    if not path.is_empty() and path != _last_scene_path:
        if not _last_scene_path.is_empty():
            play_sfx("navigation")
        _last_scene_path = path
    update_music_state(path)

    var master := Settings.master_volume
    var music_target := master * Settings.music_volume
    var ambience_target := 0.0
    if scene_uses_ambience(path):
        ambience_target = master * Settings.ambience_volume * office_ambience_scale(
            GameState.office_id)
    _music_level = move_toward(_music_level, music_target, FADE_PER_SECOND * delta)
    _ambience_level = move_toward(_ambience_level, ambience_target, FADE_PER_SECOND * delta)
    music_player.volume_db = _volume_db(_music_level)
    ambience_player.volume_db = _volume_db(_ambience_level)

func _connect_feedback_events() -> void:
    EventBus.company_cash_changed.connect(_on_cash_changed)
    EventBus.research_completed.connect(func(_id, _name): play_sfx("research_complete"))
    EventBus.technology_researched.connect(func(_id, _name):
        play_sfx("technology_unlock")
        haptic("major_achievement"))
    EventBus.employee_hired.connect(func(_employee): play_sfx("employee_hired"))
    EventBus.employee_promoted.connect(func(_employee, _seniority):
        play_sfx("employee_promotion")
        haptic("major_achievement"))
    EventBus.employee_resigned.connect(func(_employee): play_sfx("employee_resignation"))
    EventBus.game_released.connect(func(_project): play_sfx("game_release"))
    EventBus.game_hit_sales_milestone.connect(func(_project, _milestone):
        play_sfx("sales_milestone")
        haptic("major_achievement"))
    EventBus.award_nominated.connect(func(_project, _award):
        play_sfx("award_nomination")
        temporary_music_state("awards", 5.0))
    EventBus.award_won.connect(func(_project, _award):
        play_sfx("award_win")
        haptic("major_achievement")
        temporary_music_state("awards", 8.0))
    EventBus.project_schedule_slipped.connect(func(_project, _weeks, _causes):
        play_sfx("warning"))
    EventBus.employee_at_risk.connect(func(_employee): play_sfx("warning"))
    EventBus.platform_retiring.connect(func(_platform): play_sfx("warning"))
    EventBus.company_bankruptcy_warning.connect(func(_weeks):
        play_sfx("financial_crisis", 1.5))
    EventBus.company_recovered.connect(func(): _temporary_state = "")
    EventBus.company_bankrupt.connect(func():
        play_sfx("bankruptcy")
        request_music_state("financial_danger"))

func _on_node_added(node: Node) -> void:
    if not node is BaseButton or node.has_meta("audio_feedback_hooked"):
        return
    node.set_meta("audio_feedback_hooked", true)
    (node as BaseButton).pressed.connect(func():
        play_sfx("button_tap", 0.025)
        if node.has_meta("major_action"):
            haptic("major_confirmation"))

func _on_cash_changed(cash: int) -> void:
    if cash > _last_cash:
        play_sfx("money_gain", 0.05)
    elif cash < _last_cash:
        play_sfx("money_spent", 0.05)
    _last_cash = cash

func review_reveal(score: float) -> void:
    play_sfx("review_reveal")
    haptic("review_reveal")
    if score >= REVIEW_EXCELLENT:
        play_sfx("excellent_review")
        haptic("major_achievement")
    elif score < REVIEW_POOR:
        play_sfx("poor_review")

func play_sfx(id: String, cooldown_seconds: float = 0.0) -> bool:
    if not SFX_SOURCES.has(id):
        return false
    var now := Time.get_ticks_msec()
    var previous := int(_last_sfx_at.get(id, -1_000_000))
    if cooldown_seconds > 0.0 and now - previous < int(cooldown_seconds * 1000.0):
        return false
    _last_sfx_at[id] = now
    sfx_played.emit(id)
    if DisplayServer.get_name() == "headless" or sfx_players.is_empty():
        return true
    var player := sfx_players[_sfx_cursor]
    _sfx_cursor = (_sfx_cursor + 1) % sfx_players.size()
    player.stream = SFX_SOURCES[id]
    player.volume_db = _volume_db(Settings.master_volume * Settings.sfx_volume)
    player.play()
    return true

func haptic(kind: String) -> bool:
    if not Settings.haptics_enabled or kind not in [
        "major_confirmation", "review_reveal", "major_achievement"
    ]:
        return false
    haptic_requested.emit(kind)
    if not OS.has_feature("ios"):
        return true
    var profile: Dictionary = {
        "major_confirmation": {"duration": 18, "amplitude": 0.22},
        "review_reveal": {"duration": 24, "amplitude": 0.28},
        "major_achievement": {"duration": 38, "amplitude": 0.38}
    }[kind]
    Input.vibrate_handheld(int(profile["duration"]), float(profile["amplitude"]))
    return true

func update_music_state(path: String) -> String:
    var wanted := ""
    if GameState.bankrupt or FinanceManager.is_in_trouble():
        wanted = "financial_danger"
    elif not _temporary_state.is_empty() and Time.get_ticks_msec() < _temporary_state_until:
        wanted = _temporary_state
    else:
        _temporary_state = ""
        wanted = music_state_for_scene(path)
    request_music_state(wanted)
    return wanted

func request_music_state(state: String) -> bool:
    if state not in MUSIC_STATES or state == music_state:
        return false
    music_state = state
    music_state_changed.emit(state)
    # All PA.8 states intentionally use the same original placeholder loop.
    # When a licensed/original replacement is assigned later, this guard is
    # what prevents ordinary navigation from restarting an unchanged track.
    var source := music_source_for_state(state)
    if music_player.stream != source:
        music_player.stream = source
        if DisplayServer.get_name() != "headless":
            music_player.play()
            music_restart_count += 1
    return true

func temporary_music_state(state: String, seconds: float) -> bool:
    if state not in MUSIC_STATES:
        return false
    _temporary_state = state
    _temporary_state_until = Time.get_ticks_msec() + int(maxf(seconds, 0.0) * 1000.0)
    return request_music_state(state)

static func music_source_for_state(_state: String) -> AudioStreamWAV:
    ## Placeholder routing point. See assets/audio/README.md.
    return MUSIC_SOURCE

static func music_state_for_scene(path: String) -> String:
    if path.contains("MainMenu") or path.contains("NewCompany") \
            or path.contains("BootScreen") or path.contains("SettingsScreen"):
        return "main_menu"
    if path.contains("Development") or path.contains("NewGame") \
            or path.contains("Greenlight"):
        return "development"
    if path.contains("Release") or path.contains("Publishing") \
            or path.contains("Postmortem"):
        return "release_results"
    if path.to_lower().contains("award"):
        return "awards"
    return "studio"

static func scene_uses_ambience(path: String) -> bool:
    return path in [
        "res://scenes/studio/StudioScreen.tscn",
        "res://scenes/studio/OfficeScreen.tscn",
        "res://scenes/development/DevelopmentScreen.tscn"
    ]

static func office_ambience_scale(office_id: String) -> float:
    return {
        "bedroom": 0.48, "shared_workspace": 0.64, "small_office": 0.74,
        "professional_studio": 0.84, "large_studio_floor": 0.92,
        "studio_building": 0.97, "campus": 1.0
    }.get(office_id, 0.75)

func _looping_player(source: AudioStreamWAV) -> AudioStreamPlayer:
    var player := AudioStreamPlayer.new()
    source.loop_mode = AudioStreamWAV.LOOP_FORWARD
    source.loop_begin = 0
    source.loop_end = int(round(source.get_length() * float(source.mix_rate)))
    player.stream = source
    player.volume_db = -80.0
    return player

func _current_scene_path() -> String:
    var scene := get_tree().current_scene
    return scene.scene_file_path if scene != null else ""

static func _volume_db(linear: float) -> float:
    return linear_to_db(maxf(clampf(linear, 0.0, 1.0), 0.0001))
