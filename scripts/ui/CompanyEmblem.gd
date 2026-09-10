class_name CompanyEmblem
extends Control

## Deterministic local company mark. It uses no generated/user-submitted art and
## remains stable across saves because company and founder names are stable.

var company_name := "Indie Empire"
var founder_name := "You"

func _init() -> void:
    custom_minimum_size = Vector2(72, 72)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    resized.connect(queue_redraw)

func configure(company: String, founder: String) -> CompanyEmblem:
    company_name = company
    founder_name = founder
    tooltip_text = "%s studio emblem" % company
    queue_redraw()
    return self

func _draw() -> void:
    var side := minf(size.x, size.y)
    if side < 8.0:
        return
    var center := size * 0.5
    var seed := absi((company_name + ":" + founder_name).hash())
    var accents := [Color("#e98d48"), Color("#f0b34f"), Color("#4f91a2"), Color("#4f956f")]
    var accent: Color = accents[seed % accents.size()]
    var ink := Color("#263c40")
    var cream := Color("#fff7df")
    if seed % 2 == 0:
        draw_circle(center, side * 0.44, cream)
        draw_arc(center, side * 0.44, 0.0, TAU, 40, ink, side * 0.045, true)
    else:
        var shield := PackedVector2Array([
            center + Vector2(-side * 0.36, -side * 0.34), center + Vector2(side * 0.36, -side * 0.34),
            center + Vector2(side * 0.31, side * 0.16), center + Vector2(0, side * 0.42),
            center + Vector2(-side * 0.31, side * 0.16)])
        draw_colored_polygon(shield, cream)
        var outline := shield.duplicate()
        outline.append(shield[0])
        draw_polyline(outline, ink, side * 0.045, true)
    draw_rect(Rect2(center + Vector2(-side * 0.23, -side * 0.18), Vector2(side * 0.46, side * 0.31)), accent, true)
    draw_rect(Rect2(center + Vector2(-side * 0.17, -side * 0.12), Vector2(side * 0.34, side * 0.19)), cream, true)
    draw_line(center + Vector2(0, side * 0.14), center + Vector2(0, side * 0.26), ink, side * 0.04, true)
    draw_line(center + Vector2(-side * 0.16, side * 0.26), center + Vector2(side * 0.16, side * 0.26), ink, side * 0.04, true)
    var spark := center + Vector2(side * 0.25, -side * 0.23)
    draw_circle(spark, side * 0.07, Color("#f0b34f"))
    draw_line(spark - Vector2(side * 0.11, 0), spark + Vector2(side * 0.11, 0), ink, side * 0.025, true)
    draw_line(spark - Vector2(0, side * 0.11), spark + Vector2(0, side * 0.11), ink, side * 0.025, true)
