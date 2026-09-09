class_name SalesChart
extends Control

## A small, self-drawn weekly-sales bar chart. Custom `_draw()` rather than a
## charting library, matching StudioRoomRenderer / OfficeFloorView precedent.
##
## Presentation only: it is handed a copy of the numbers and never reads or
## writes simulation state. Every chart also exposes `text_summary()` so a
## screen can show a readable equivalent (accessibility, and when Reduce
## Motion is on the grow-in is skipped but the bars still render).

const BAR_GAP := 2.0
const BASE_HEIGHT := 132.0
const TOP_PAD := 14.0
const BOTTOM_PAD := 16.0

var _weeks: Array[int] = []
var _peak_index := -1
var _reveal := 1.0

func _ready() -> void:
    custom_minimum_size.y = BASE_HEIGHT
    size_flags_horizontal = Control.SIZE_EXPAND_FILL

func configure(weekly_sales: Array, animate := true) -> SalesChart:
    _weeks.clear()
    for value in weekly_sales:
        _weeks.append(maxi(int(value), 0))
    _peak_index = -1
    var best := -1
    for i in _weeks.size():
        if _weeks[i] > best:
            best = _weeks[i]
            _peak_index = i
    _reveal = 0.0 if (animate and not Settings.reduced_motion and _weeks.size() > 0) else 1.0
    queue_redraw()
    return self

func _process(delta: float) -> void:
    if _reveal >= 1.0:
        set_process(false)
        return
    _reveal = minf(_reveal + delta / 0.5, 1.0)
    queue_redraw()

func text_summary() -> String:
    if _weeks.is_empty():
        return "No sales recorded yet."
    var lines: Array[String] = []
    var previous := 0
    for i in _weeks.size():
        var arrow := ""
        if i > 0:
            arrow = "  up" if _weeks[i] > previous else ("  down" if _weeks[i] < previous else "")
        var peak := "   peak" if i == _peak_index and _weeks.size() > 1 else ""
        lines.append("Week %-2d  %10s%s%s" % [i + 1, Format.exact(_weeks[i]), arrow, peak])
        previous = _weeks[i]
    var total := 0
    for value in _weeks:
        total += value
    lines.append("Total    %10s" % Format.exact(total))
    return "\n".join(lines)

func _draw() -> void:
    var area := Rect2(Vector2.ZERO, size)
    draw_rect(area, Color(1, 1, 1, 0.04))

    if _weeks.is_empty():
        var font := get_theme_default_font()
        draw_string(font, Vector2(8, size.y * 0.5),
            "No sales recorded yet.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
            Color(1, 1, 1, 0.5))
        return

    var peak_value := maxi(_weeks[_peak_index] if _peak_index >= 0 else 1, 1)
    var plot_h := size.y - TOP_PAD - BOTTOM_PAD
    var count := _weeks.size()
    var bar_w := maxf((size.x - BAR_GAP * float(count - 1)) / float(count), 1.0)
    var baseline := size.y - BOTTOM_PAD

    # baseline
    draw_line(Vector2(0, baseline), Vector2(size.x, baseline), Color(1, 1, 1, 0.18), 1.0)

    for i in count:
        var frac := float(_weeks[i]) / float(peak_value)
        var h := plot_h * frac * _reveal
        var x := float(i) * (bar_w + BAR_GAP)
        var rect := Rect2(x, baseline - h, bar_w, h)
        var color := VisualTheme.ORANGE if i == _peak_index and count > 1 else VisualTheme.SKY
        draw_rect(rect, color)
        draw_rect(rect, VisualTheme.OUTLINE, false, 1.0)

    # sparse week labels: first, peak, last
    var font := get_theme_default_font()
    var label_indices := {0: true, count - 1: true}
    if _peak_index >= 0 and count > 2:
        label_indices[_peak_index] = true
    for i in label_indices:
        var x := float(i) * (bar_w + BAR_GAP) + bar_w * 0.5
        draw_string(font, Vector2(x - 8, size.y - 3),
            "W%d" % (int(i) + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
            Color(1, 1, 1, 0.55))
