class_name EngineEmblem
extends Control

## Compact deterministic product mark for a player-authored engine.

var engine_name := "Engine"
var engine_id := ""

func _init() -> void:
    custom_minimum_size = Vector2(48, 48)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    resized.connect(queue_redraw)

func configure(name: String, id: String = "") -> EngineEmblem:
    engine_name = name
    engine_id = id
    tooltip_text = "%s engine emblem" % name
    queue_redraw()
    return self

func _draw() -> void:
    var side := minf(size.x, size.y)
    var center := size * 0.5
    var seed := absi((engine_id + engine_name).hash())
    var accent: Color = [Color("#4f91a2"), Color("#e98d48"), Color("#7866a6"), Color("#4f956f")][seed % 4]
    var ink := Color("#263c40")
    draw_circle(center, side * 0.43, Color("#fff7df"))
    draw_arc(center, side * 0.43, 0.0, TAU, 32, ink, maxf(2.0, side * 0.06), true)
    var extent := side * 0.21
    for index in 4:
        var angle := PI * 0.25 + index * PI * 0.5
        var offset := Vector2(cos(angle), sin(angle)) * side * 0.23
        draw_rect(Rect2(center + offset - Vector2.ONE * side * 0.055, Vector2.ONE * side * 0.11), accent)
    draw_rect(Rect2(center - Vector2.ONE * extent, Vector2.ONE * extent * 2.0), accent)
    draw_circle(center, side * 0.09, Color("#fff7df"))
    draw_arc(center, side * 0.09, 0.0, TAU, 20, ink, maxf(1.5, side * 0.04), true)
