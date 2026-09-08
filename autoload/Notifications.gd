extends CanvasLayer

## Toasts. Small events slide by; important ones stay longer and stack on top,
## but nothing ever blocks the thumb: they are never modal and never need a tap.

const MAX_VISIBLE := 3
const NORMAL_SECONDS := 2.6
const IMPORTANT_SECONDS := 4.5
const MARGIN := 16

var _stack: VBoxContainer
var _enabled := true

func _ready() -> void:
    layer = 128
    process_mode = Node.PROCESS_MODE_ALWAYS

    _stack = VBoxContainer.new()
    _stack.add_theme_constant_override("separation", 8)
    _stack.set_anchors_preset(Control.PRESET_TOP_WIDE)
    _stack.offset_left = MARGIN
    _stack.offset_right = -MARGIN
    _stack.offset_top = MARGIN
    _stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_stack)

    EventBus.notification_requested.connect(_on_notification)

func set_enabled(value: bool) -> void:
    _enabled = value
    if not value:
        for child in _stack.get_children():
            child.queue_free()

func is_enabled() -> bool:
    return _enabled

func _on_notification(title: String, body: String, important: bool) -> void:
    if not _enabled:
        return

    # Never let a burst of events bury the screen.
    while _stack.get_child_count() >= MAX_VISIBLE:
        var oldest := _stack.get_child(0)
        _stack.remove_child(oldest)
        oldest.queue_free()

    var toast := _build(title, body, important)
    _stack.add_child(toast)

    var seconds := IMPORTANT_SECONDS if important else NORMAL_SECONDS
    var tween := create_tween()
    tween.tween_property(toast, "modulate:a", 1.0, 0.15).from(0.0)
    tween.tween_interval(seconds)
    tween.tween_property(toast, "modulate:a", 0.0, 0.35)
    tween.tween_callback(toast.queue_free)

func _build(title: String, body: String, important: bool) -> Control:
    var panel := PanelContainer.new()
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.10, 0.10, 0.13, 0.94)
    style.border_color = Color(0.95, 0.75, 0.25) if important else Color(0.45, 0.55, 0.75)
    style.set_border_width_all(2)
    style.set_corner_radius_all(8)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    panel.add_theme_stylebox_override("panel", style)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 2)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var title_label := Label.new()
    title_label.text = title
    title_label.add_theme_font_size_override("font_size", 14)
    title_label.add_theme_color_override("font_color", Color(1, 1, 1))
    box.add_child(title_label)

    var body_label := Label.new()
    body_label.text = body
    body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body_label.add_theme_font_size_override("font_size", 12)
    body_label.add_theme_color_override("font_color", Color(0.82, 0.84, 0.9))
    box.add_child(body_label)

    panel.add_child(box)
    return panel
