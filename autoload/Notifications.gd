extends CanvasLayer

## Toasts. Small events slide by; important ones stay longer and stack on top,
## but nothing ever blocks the thumb: they are never modal and never need a tap.

const MAX_VISIBLE := 3
const NORMAL_SECONDS := 2.6
const IMPORTANT_SECONDS := 4.5
const MARGIN := 16
const MAX_WIDTH := 390

var _stack: VBoxContainer
var _enabled := true

func _ready() -> void:
    layer = 128
    process_mode = Node.PROCESS_MODE_ALWAYS

    _stack = VBoxContainer.new()
    _stack.add_theme_constant_override("separation", 8)
    _stack.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    _stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_stack)
    get_viewport().size_changed.connect(_layout_stack)
    _layout_stack()

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
    toast.position.x = 24.0
    toast.modulate.a = 0.0
    tween.set_parallel(true)
    tween.tween_property(toast, "modulate:a", 1.0, 0.16)
    tween.tween_property(toast, "position:x", 0.0, 0.18).set_trans(Tween.TRANS_QUAD)
    tween.set_parallel(false)
    tween.tween_interval(seconds)
    tween.tween_property(toast, "modulate:a", 0.0, 0.24)
    tween.tween_callback(toast.queue_free)

func _build(title: String, body: String, important: bool) -> Control:
    var panel := PanelContainer.new()
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var style := StyleBoxFlat.new()
    var tone := _tone_for(title, body, important)
    style.bg_color = Color(0.09, 0.20, 0.22, 0.97)
    style.border_color = {
        "positive": VisualTheme.GREEN,
        "warning": VisualTheme.WARNING,
        "danger": VisualTheme.RED,
        "special": VisualTheme.GOLD
    }.get(tone, VisualTheme.SKY)
    style.set_border_width_all(2)
    style.set_corner_radius_all(8)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    panel.add_theme_stylebox_override("panel", style)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var icon := TextureRect.new()
    icon.texture = UiIcons.texture(_icon_for(tone))
    icon.custom_minimum_size = Vector2(26, 26)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(icon)

    var box := VBoxContainer.new()
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    box.add_theme_constant_override("separation", 3)
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

    row.add_child(box)
    panel.add_child(row)
    return panel

func _layout_stack() -> void:
    var width := minf(MAX_WIDTH, get_viewport().get_visible_rect().size.x - MARGIN * 2.0)
    _stack.offset_left = -width - MARGIN
    _stack.offset_right = -MARGIN
    _stack.offset_top = MARGIN

func _tone_for(title: String, body: String, important: bool) -> String:
    var copy := (title + " " + body).to_lower()
    if copy.contains("failure") or copy.contains("bankrupt") or copy.contains("departed") \
            or copy.contains("resignation") or copy.contains("lost"):
        return "danger"
    if copy.contains("trouble") or copy.contains("warning") or copy.contains("delayed") \
            or copy.contains("struggling") or copy.contains("declined"):
        return "warning"
    if copy.contains("complete") or copy.contains("researched") or copy.contains("welcome") \
            or copy.contains("paid") or copy.contains("milestone") or copy.contains("promoted"):
        return "positive"
    return "special" if important else "info"

func _icon_for(tone: String) -> String:
    return {
        "positive": "success", "warning": "warning", "danger": "warning",
        "special": "reputation"
    }.get(tone, "news")
