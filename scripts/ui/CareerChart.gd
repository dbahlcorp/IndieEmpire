class_name CareerChart
extends Control

## Lightweight, mobile-first line chart for career statistics. The chart is
## presentation-only and keeps a readable text equivalent for accessibility.

const BASE_HEIGHT := 184.0
const PAD_LEFT := 16.0
const PAD_RIGHT := 16.0
const PAD_TOP := 20.0
const PAD_BOTTOM := 28.0

var _points: Array = []
var _series_name := "Value"
var _money := false

func _ready() -> void:
    custom_minimum_size = Vector2(0, BASE_HEIGHT)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure(points: Array, series_name: String, money := false) -> CareerChart:
    _points.clear()
    for point in points:
        _points.append({
            "label": str(point.get("label", "")),
            "value": float(point.get("value", 0.0)),
        })
    _series_name = series_name
    _money = money
    tooltip_text = text_summary()
    queue_redraw()
    return self

func point_count() -> int:
    return _points.size()

func mapped_points(plot_rect: Rect2) -> PackedVector2Array:
    var mapped := PackedVector2Array()
    if _points.is_empty():
        return mapped
    var bounds := value_bounds()
    var low := float(bounds.x)
    var high := float(bounds.y)
    var span := maxf(high - low, 1.0)
    for i in _points.size():
        var x := plot_rect.position.x + plot_rect.size.x * 0.5
        if _points.size() > 1:
            x = plot_rect.position.x + plot_rect.size.x * float(i) / float(_points.size() - 1)
        var fraction := (float(_points[i]["value"]) - low) / span
        var y := plot_rect.end.y - fraction * plot_rect.size.y
        mapped.append(Vector2(x, y))
    return mapped

func value_bounds() -> Vector2:
    if _points.is_empty():
        return Vector2.ZERO
    var low := 0.0
    var high := 0.0
    for point in _points:
        low = minf(low, float(point["value"]))
        high = maxf(high, float(point["value"]))
    if is_equal_approx(low, high):
        high = low + 1.0
    return Vector2(low, high)

func concise_summary() -> String:
    if _points.is_empty():
        return "No %s history recorded yet." % _series_name.to_lower()
    var first: Dictionary = _points.front()
    var latest: Dictionary = _points.back()
    var best: Dictionary = _points.front()
    var lowest: Dictionary = _points.front()
    for point in _points:
        if float(point["value"]) > float(best["value"]):
            best = point
        if float(point["value"]) < float(lowest["value"]):
            lowest = point
    var copy := "%s: %s in %s; %s in %s. High %s (%s)." % [
        _series_name,
        _format_value(float(first["value"])), first["label"],
        _format_value(float(latest["value"])), latest["label"],
        _format_value(float(best["value"])), best["label"],
    ]
    if float(lowest["value"]) < 0.0:
        copy += " Low %s (%s)." % [_format_value(float(lowest["value"])), lowest["label"]]
    return copy

func text_summary() -> String:
    if _points.is_empty():
        return "No %s history recorded yet." % _series_name.to_lower()
    var lines: Array[String] = []
    for point in _points:
        lines.append("%s: %s" % [point["label"], _format_value(float(point["value"]))])
    return "\n".join(lines)

func _format_value(value: float) -> String:
    var rounded := int(round(value))
    if _money:
        return "%s$%s" % ["-" if rounded < 0 else "", Format.count(absi(rounded))]
    return Format.count(rounded)

func _draw() -> void:
    var area := Rect2(Vector2.ZERO, size)
    draw_rect(area, Color(1, 1, 1, 0.32))
    var plot := Rect2(
        Vector2(PAD_LEFT, PAD_TOP),
        Vector2(maxf(size.x - PAD_LEFT - PAD_RIGHT, 1.0),
            maxf(size.y - PAD_TOP - PAD_BOTTOM, 1.0)))

    if _points.is_empty():
        draw_string(get_theme_default_font(), Vector2(PAD_LEFT, size.y * 0.5),
            "No history yet", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, VisualTheme.MUTED)
        return

    var bounds := value_bounds()
    var span := maxf(bounds.y - bounds.x, 1.0)
    var zero_fraction := (0.0 - bounds.x) / span
    var baseline_y := plot.end.y - zero_fraction * plot.size.y
    draw_line(Vector2(plot.position.x, baseline_y), Vector2(plot.end.x, baseline_y),
        Color(VisualTheme.OUTLINE, 0.45), 1.0)

    var mapped := mapped_points(plot)
    if mapped.size() > 1:
        draw_polyline(mapped, VisualTheme.SKY_DARK, 3.0, true)
    for i in mapped.size():
        var color := VisualTheme.GREEN_DARK if float(_points[i]["value"]) >= 0.0 else VisualTheme.RED
        draw_circle(mapped[i], 5.0, color)
        draw_circle(mapped[i], 5.0, VisualTheme.OUTLINE, false, 1.0)

    var font := get_theme_default_font()
    var label_indices := {0: true, _points.size() - 1: true}
    if _points.size() > 4:
        label_indices[int((_points.size() - 1) / 2.0)] = true
    for index in label_indices:
        var position: Vector2 = mapped[int(index)]
        draw_string(font, Vector2(position.x - 18.0, size.y - 7.0),
            str(_points[int(index)]["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
            VisualTheme.MUTED)

