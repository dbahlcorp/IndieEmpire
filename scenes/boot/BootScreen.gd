extends Control

## Decides where a launch lands: straight back into a running company, or the
## studio creation screen for a first-time player.

const SPLASH_HOLD_SECONDS := 0.9
const SPLASH_FADE_SECONDS := 0.25

@onready var fade: ColorRect = $Fade

func _ready() -> void:
    await get_tree().create_timer(SPLASH_HOLD_SECONDS).timeout
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    tween.tween_property(fade, "color:a", 1.0, SPLASH_FADE_SECONDS)
    await tween.finished
    _go("res://scenes/menu/MainMenuScreen.tscn")

func _go(path: String) -> void:
    # The tree is still building during _ready, so the switch has to wait a frame.
    get_tree().change_scene_to_file.call_deferred(path)
