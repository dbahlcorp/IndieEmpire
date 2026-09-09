extends Node

## Player preferences, kept separate from the company save so they survive a new
## company or a bankruptcy.

const PATH := "user://settings.json"

var compact_numbers: bool = true
var notifications_enabled: bool = true
var master_volume: float = 1.0
var music_volume: float = 0.58
var sfx_volume: float = 0.72
var ambience_volume: float = 0.42
var haptics_enabled: bool = true
var onboarding_enabled: bool = true
## Minimise animation: results reveals, count-ups and chart grow-ins land
## instantly. Honoured by ReleaseResultsScreen and SalesChart today; other
## animated screens should check it as they gain motion.
var reduced_motion: bool = false
## Set the first time the player watches a full release-results reveal. After
## that the reveal offers a SKIP control and paces itself a little faster.
## Player-scoped on purpose -- it is about what this person has already seen,
## not about one company -- so it lives here rather than in the save.
var seen_release_reveal: bool = false

func _ready() -> void:
    load_settings()
    Notifications.set_enabled(notifications_enabled)

func set_compact_numbers(value: bool) -> void:
    compact_numbers = value
    save_settings()

func set_notifications_enabled(value: bool) -> void:
    notifications_enabled = value
    Notifications.set_enabled(value)
    save_settings()

func set_music_volume(value: float) -> void:
    music_volume = clampf(value, 0.0, 1.0)
    save_settings()

func set_master_volume(value: float) -> void:
    master_volume = clampf(value, 0.0, 1.0)
    save_settings()

func set_sfx_volume(value: float) -> void:
    sfx_volume = clampf(value, 0.0, 1.0)
    save_settings()

func set_ambience_volume(value: float) -> void:
    ambience_volume = clampf(value, 0.0, 1.0)
    save_settings()

func set_haptics_enabled(value: bool) -> void:
    haptics_enabled = value
    save_settings()

func set_reduced_motion(value: bool) -> void:
    reduced_motion = value
    save_settings()

func mark_release_reveal_seen() -> void:
    if seen_release_reveal:
        return
    seen_release_reveal = true
    save_settings()

func set_onboarding_enabled(value: bool) -> void:
    onboarding_enabled = value
    if not value and SaveManager.has_active_company:
        TutorialManager.skip_all()
    save_settings()

func save_settings() -> void:
    var file := FileAccess.open(PATH, FileAccess.WRITE)
    if file == null:
        push_error("Could not write settings (error %d)" % FileAccess.get_open_error())
        return
    file.store_string(JSON.stringify({
        "compact_numbers": compact_numbers,
        "notifications_enabled": notifications_enabled,
        "master_volume": master_volume,
        "music_volume": music_volume,
        "sfx_volume": sfx_volume,
        "ambience_volume": ambience_volume,
        "haptics_enabled": haptics_enabled,
        "onboarding_enabled": onboarding_enabled,
        "reduced_motion": reduced_motion,
        "seen_release_reveal": seen_release_reveal
    }, "\t"))
    file.close()

func load_settings() -> void:
    if not FileAccess.file_exists(PATH):
        return
    var file := FileAccess.open(PATH, FileAccess.READ)
    if file == null:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if not (parsed is Dictionary):
        return
    var data: Dictionary = parsed
    compact_numbers = bool(data.get("compact_numbers", true))
    notifications_enabled = bool(data.get("notifications_enabled", true))
    master_volume = clampf(float(data.get("master_volume", 1.0)), 0.0, 1.0)
    music_volume = clampf(float(data.get("music_volume", 0.58)), 0.0, 1.0)
    sfx_volume = clampf(float(data.get("sfx_volume", 0.72)), 0.0, 1.0)
    ambience_volume = clampf(float(data.get("ambience_volume", 0.42)), 0.0, 1.0)
    haptics_enabled = bool(data.get("haptics_enabled", true))
    onboarding_enabled = bool(data.get("onboarding_enabled", true))
    reduced_motion = bool(data.get("reduced_motion", false))
    seen_release_reveal = bool(data.get("seen_release_reveal", false))
