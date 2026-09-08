extends Node

## Player preferences, kept separate from the company save so they survive a new
## company or a bankruptcy.

const PATH := "user://settings.json"

var compact_numbers: bool = true
var notifications_enabled: bool = true
var music_volume: float = 0.58
var ambience_volume: float = 0.42

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

func set_ambience_volume(value: float) -> void:
    ambience_volume = clampf(value, 0.0, 1.0)
    save_settings()

func save_settings() -> void:
    var file := FileAccess.open(PATH, FileAccess.WRITE)
    if file == null:
        push_error("Could not write settings (error %d)" % FileAccess.get_open_error())
        return
    file.store_string(JSON.stringify({
        "compact_numbers": compact_numbers,
        "notifications_enabled": notifications_enabled,
        "music_volume": music_volume,
        "ambience_volume": ambience_volume
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
    music_volume = clampf(float(data.get("music_volume", 0.58)), 0.0, 1.0)
    ambience_volume = clampf(float(data.get("ambience_volume", 0.42)), 0.0, 1.0)
