class_name GameBackdrop
extends Control

## Lightweight illustrated backdrop shared by every screen. The geometry is
## intentionally drawn in-engine so it scales cleanly on every phone and does
## not add another texture dependency to the project.

var menu_mode := false

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    resized.connect(queue_redraw)

func _draw() -> void:
    var area := Rect2(Vector2.ZERO, size)
    draw_rect(area, Color("#ead7b4"))
    _draw_floor_pattern()
    draw_rect(Rect2(0, 0, size.x, 9), Color("#efb34f"))
    draw_rect(Rect2(0, 9, size.x, 3), Color("#a96932"))
    draw_rect(Rect2(0, size.y - 10, size.x, 10), Color("#254e58"))
    if menu_mode:
        _draw_menu_office()

func _draw_floor_pattern() -> void:
    var tile := 54.0
    var ink := Color(0.35, 0.25, 0.16, 0.055)
    var y := 90.0
    while y < size.y:
        draw_line(Vector2(0, y), Vector2(size.x, y + size.x * 0.28), ink, 1.0)
        y += tile
    y = 90.0
    while y < size.y + size.x * 0.28:
        draw_line(Vector2(0, y), Vector2(size.x, y - size.x * 0.28), ink, 1.0)
        y += tile

func _draw_menu_office() -> void:
    if size.x < 100.0:
        return
    var center := Vector2(size.x * 0.5, size.y * 0.39)
    # Soft pool of light behind the little starter office.
    draw_circle(center + Vector2(0, 24), 108, Color(1.0, 0.91, 0.68, 0.7))
    # Isometric rug.
    draw_colored_polygon(PackedVector2Array([
        center + Vector2(-118, 42), center + Vector2(0, -18),
        center + Vector2(118, 42), center + Vector2(0, 102)
    ]), Color("#74a38f"))
    draw_polyline(PackedVector2Array([
        center + Vector2(-118, 42), center + Vector2(0, -18),
        center + Vector2(118, 42), center + Vector2(0, 102),
        center + Vector2(-118, 42)
    ]), Color("#315d60"), 3.0)
    # Desk top and legs.
    draw_colored_polygon(PackedVector2Array([
        center + Vector2(-76, 13), center + Vector2(6, -28),
        center + Vector2(82, 10), center + Vector2(0, 52)
    ]), Color("#b96d3d"))
    draw_line(center + Vector2(-70, 17), center + Vector2(-70, 65), Color("#75452f"), 7)
    draw_line(center + Vector2(73, 14), center + Vector2(73, 61), Color("#75452f"), 7)
    # Chunky 1980s computer.
    draw_rect(Rect2(center + Vector2(-25, -70), Vector2(58, 48)), Color("#f3e5c5"), true)
    draw_rect(Rect2(center + Vector2(-18, -63), Vector2(44, 31)), Color("#254e58"), true)
    draw_rect(Rect2(center + Vector2(-12, -58), Vector2(32, 20)), Color("#79c1b6"), true)
    draw_line(center + Vector2(4, -22), center + Vector2(4, -10), Color("#ded0b4"), 7)
    draw_rect(Rect2(center + Vector2(-31, -10), Vector2(73, 10)), Color("#eadab9"), true)
    # Coffee and the first hand-written game idea.
    draw_circle(center + Vector2(55, -10), 10, Color("#f0a85d"))
    draw_rect(Rect2(center + Vector2(-65, 2), Vector2(33, 23)), Color("#fff5d9"), true)
    draw_line(center + Vector2(-60, 9), center + Vector2(-40, 9), Color("#6f8d83"), 2)
    draw_line(center + Vector2(-60, 15), center + Vector2(-45, 15), Color("#6f8d83"), 2)
