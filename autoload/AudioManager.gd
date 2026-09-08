extends Node

## Persistent two-layer game mix. Music follows the player everywhere; the
## quieter room bed fades in only where the illustrated office is present.

const MUSIC_SOURCE: AudioStreamWAV = preload(
    "res://assets/audio/music/studio_day_loop.wav")
const AMBIENCE_SOURCE: AudioStreamWAV = preload(
    "res://assets/audio/ambience/office_room_loop.wav")
const FADE_PER_SECOND := 0.85

var music_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var _music_level := 0.0
var _ambience_level := 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    music_player = _looping_player(MUSIC_SOURCE)
    ambience_player = _looping_player(AMBIENCE_SOURCE)
    add_child(music_player)
    add_child(ambience_player)
    # Dummy/headless audio drivers never release playback objects cleanly at
    # process exit. Real desktop and mobile displays start both layers here.
    if DisplayServer.get_name() != "headless":
        music_player.play()
        ambience_player.play()

func _exit_tree() -> void:
    # Explicitly release active playback objects for clean headless shutdowns
    # and mobile suspend/terminate cycles.
    if music_player != null:
        music_player.stop()
        music_player.stream = null
    if ambience_player != null:
        ambience_player.stop()
        ambience_player.stream = null

func _process(delta: float) -> void:
    if music_player == null or ambience_player == null:
        return
    var music_target := Settings.music_volume
    var ambience_target := Settings.ambience_volume if scene_uses_ambience(
        _current_scene_path()) else 0.0
    _music_level = move_toward(_music_level, music_target, FADE_PER_SECOND * delta)
    _ambience_level = move_toward(_ambience_level, ambience_target, FADE_PER_SECOND * delta)
    music_player.volume_db = _volume_db(_music_level)
    ambience_player.volume_db = _volume_db(_ambience_level)

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

static func scene_uses_ambience(path: String) -> bool:
    return path in [
        "res://scenes/studio/StudioScreen.tscn",
        "res://scenes/studio/OfficeScreen.tscn",
        "res://scenes/development/DevelopmentScreen.tscn"
    ]

static func _volume_db(linear: float) -> float:
    return linear_to_db(maxf(clampf(linear, 0.0, 1.0), 0.0001))
