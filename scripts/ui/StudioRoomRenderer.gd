class_name StudioRoomRenderer
extends RefCounted

## Floor and low furniture are drawn independently. No painted room is ever
## composited over people. Furniture and actors share the same ground-depth sort.
static func point(world: Vector2, rect: Rect2, plan: Dictionary) -> Vector2:
    return rect.position + OfficeLayout.project(world, plan["dimensions"]) * rect.size

static func polygon(canvas: CanvasItem, points: Array, color: Color) -> void:
    canvas.draw_colored_polygon(PackedVector2Array(points), color)

static func floor_and_walls(canvas: CanvasItem, rect: Rect2, plan: Dictionary) -> void:
    var d: Vector2i = plan["dimensions"]
    var a := point(Vector2.ZERO, rect, plan)
    var b := point(Vector2(d.x, 0), rect, plan)
    var c := point(Vector2(d), rect, plan)
    var e := point(Vector2(0, d.y), rect, plan)
    var lift := Vector2(0, rect.size.y * 0.17)
    var drop := Vector2(0, rect.size.y * 0.025)
    var accent := OfficeCustomizationManager.component_color("walls")
    var wall := Color("#e7d2a7").lerp(accent, 0.13)
    polygon(canvas, [a - lift, b - lift, b, a], wall)
    polygon(canvas, [a - lift, e - lift, e, a], wall.darkened(0.13))
    canvas.draw_line(a - lift, b - lift, Color("#74563c"), maxf(2, rect.size.y * 0.012))
    canvas.draw_line(a - lift, e - lift, Color("#74563c"), maxf(2, rect.size.y * 0.012))
    # Windows live on the back walls, away from all walkable cells.
    for side in 2:
        var end := b if side == 0 else e
        for i in range(1, 4):
            var center := a.lerp(end, float(i) / 4.0)
            var half := (end - a) * 0.065
            var top := lift * 0.82
            var bottom := lift * 0.23
            var corners := [center - half - top, center + half - top, center + half - bottom, center - half - bottom]
            polygon(canvas, corners, Color("#759c9c"))
            canvas.draw_polyline(PackedVector2Array(corners + [corners[0]]), Color("#fff1ce"), maxf(2, rect.size.y * 0.008))
            canvas.draw_line(center - top, center - bottom, Color("#fff1ce"), maxf(1, rect.size.y * 0.004))
    var floor_color := Color("#b78c58").lerp(OfficeCustomizationManager.component_color("flooring"), 0.12)
    for y in d.y:
        for x in d.x:
            var p := Vector2(x, y)
            var color := floor_color.lightened(0.055) if (x + y) % 2 == 0 else floor_color
            polygon(canvas, [point(p, rect, plan), point(p + Vector2(1, 0), rect, plan), point(p + Vector2.ONE, rect, plan), point(p + Vector2(0, 1), rect, plan)], color)
            canvas.draw_line(point(p, rect, plan), point(p + Vector2(1, 0), rect, plan), Color(0.35, 0.24, 0.13, 0.22), 1)
    polygon(canvas, [b, c, c + drop, b + drop], Color("#73523a"))
    polygon(canvas, [e, c, c + drop, e + drop], Color("#916441"))
    canvas.draw_line(e, c, Color("#e3b977"), maxf(1, rect.size.y * 0.006))
    canvas.draw_line(b, c, Color("#e3b977"), maxf(1, rect.size.y * 0.006))

static func box(canvas: CanvasItem, rect: Rect2, plan: Dictionary, cell: Vector2i, height: float, color: Color, footprint: float = 0.82) -> Vector2:
    var center := Vector2(cell) + Vector2(0.5, 0.5)
    var half := footprint * 0.5
    var a := point(center + Vector2(-half, -half), rect, plan)
    var b := point(center + Vector2(half, -half), rect, plan)
    var c := point(center + Vector2(half, half), rect, plan)
    var e := point(center + Vector2(-half, half), rect, plan)
    var lift := Vector2(0, height)
    polygon(canvas, [b, c, c - lift, b - lift], color.darkened(0.25))
    polygon(canvas, [e, c, c - lift, e - lift], color.darkened(0.12))
    polygon(canvas, [a - lift, b - lift, c - lift, e - lift], color)
    canvas.draw_polyline(PackedVector2Array([a - lift, b - lift, c - lift, e - lift, a - lift]), color.darkened(0.4), 1)
    return point(center, rect, plan) - lift

static func furniture(canvas: CanvasItem, rect: Rect2, plan: Dictionary, item: Dictionary, texture: Texture2D = null) -> void:
    var d: Vector2i = plan["dimensions"]
    var unit := rect.size.y / float(d.x + d.y)
    var cell: Vector2i = item["cell"]
    match str(item["kind"]):
        "desk":
            var wood := Color("#bf955d").lerp(OfficeCustomizationManager.component_color("desks"), 0.2)
            var top := box(canvas, rect, plan, cell, unit * 0.68, wood)
            if texture != null:
                var extent := unit * 1.35
                canvas.draw_texture_rect(texture, Rect2(top - Vector2(extent * 0.5, extent * 0.92), Vector2.ONE * extent), false)
            else:
                canvas.draw_line(top - Vector2(unit * 0.18, 0), top + Vector2(unit * 0.18, 0), Color("#efe3c5"), maxf(2, unit * 0.18))
        "shelf":
            var top := box(canvas, rect, plan, cell, unit * 2.1, Color("#76593e"))
            for i in 5:
                var color := [Color("#47828a"), Color("#bd654e"), Color("#ddb45c")][i % 3]
                canvas.draw_line(top + Vector2((i - 2) * unit * 0.14, 0), top + Vector2((i - 2) * unit * 0.14, -unit * 0.3), color, maxf(2, unit * 0.1))
        "plant":
            var top := box(canvas, rect, plan, cell, unit * 0.45, Color("#ad674c"), 0.5)
            for i in 5:
                var leaf := top + Vector2(sin(i * 2.4) * unit * 0.35, -unit * (0.3 + float(i % 3) * 0.18))
                canvas.draw_line(top, leaf, Color("#456b43"), maxf(1, unit * 0.08))
                canvas.draw_circle(leaf, unit * 0.24, Color("#65905a"))
        "coffee":
            var top := box(canvas, rect, plan, cell, unit * 0.9, Color("#427c80"))
            canvas.draw_rect(Rect2(top - Vector2(unit * 0.24, unit * 0.6), Vector2(unit * 0.48, unit * 0.6)), Color("#3c4140"))
            canvas.draw_circle(top - Vector2(0, unit * 0.24), unit * 0.13, Color("#eed3a1"))
        "bed":
            var top := box(canvas, rect, plan, cell, unit * 0.4, Color("#477a80"), 0.95)
            canvas.draw_line(top - Vector2(unit * 0.32, unit * 0.12), top + Vector2(unit * 0.05, -unit * 0.26), Color("#f6e7c7"), maxf(2, unit * 0.3))
