class_name OfficeLayout
extends RefCounted

## One source of truth for floor geometry, furniture occupancy and navigation.
## World positions are cell centers; projected positions are normalized to 3:2 art.
const LAYOUTS := {
    "bedroom": 1, "shared_workspace": 3, "small_office": 5,
    "professional_studio": 8, "large_studio_floor": 12,
    "studio_building": 16, "campus": 20
}

static func get_layout(office_id: String) -> Dictionary:
    var capacity := int(LAYOUTS.get(office_id, 1))
    var columns := mini(4, ceili(sqrt(float(capacity))))
    var rows := ceili(float(capacity) / columns)
    var dimensions := Vector2i(columns * 3 + 3, rows * 3 + 3)
    var layout := {"dimensions": dimensions, "desks": [], "desk_cells": [], "social": [], "blocked": [], "props": [], "features": []}
    for index in capacity:
        var cell := Vector2i(2 + (index % columns) * 3, 2 + (index / columns) * 3)
        layout["desk_cells"].append(cell)
        layout["blocked"].append(cell)
        layout["desks"].append(project(Vector2(cell + Vector2i(0, 1)) + Vector2(0.5, 0.5), dimensions))
    var props: Array = layout["props"]
    props.append({"cell": Vector2i(1, 1), "kind": "shelf"})
    props.append({"cell": Vector2i(dimensions.x - 2, 1), "kind": "plant"})
    if office_id == "bedroom":
        props.append({"cell": Vector2i(4, 2), "kind": "bed"})
    else:
        props.append({"cell": Vector2i(1, dimensions.y - 3), "kind": "coffee"})
    # Larger offices gain authored visual zones. These are presentation of the
    # office tier, not new simulation bonuses or purchase state.
    var tier := ["bedroom", "shared_workspace", "small_office",
        "professional_studio", "large_studio_floor", "studio_building",
        "campus"].find(office_id)
    var features: Array = layout["features"]
    if tier >= 2:
        features.append({"kind": "break_room", "anchor": Vector2(0.17, 0.73)})
    if tier >= 3:
        features.append({"kind": "meeting_room", "anchor": Vector2(0.79, 0.37)})
    if tier >= 4:
        features.append({"kind": "qa_lab", "anchor": Vector2(0.79, 0.69)})
    for prop in props:
        layout["blocked"].append(prop["cell"])
    for x in range(1, dimensions.x - 2, 2):
        layout["social"].append(project(Vector2(x + 0.5, dimensions.y - 1.5), dimensions))
    layout["entrance"] = project(Vector2(dimensions.x - 1.5, dimensions.y - 1.5), dimensions)
    layout["hub"] = project(Vector2(dimensions.x / 2.0, dimensions.y - 1.5), dimensions)
    return layout

static func desk_count(office_id: String) -> int:
    return int(LAYOUTS.get(office_id, 1))

static func project(point: Vector2, dimensions: Vector2i) -> Vector2:
    var total := float(dimensions.x + dimensions.y)
    return Vector2(0.5 + (point.x - point.y + (dimensions.y - dimensions.x) * 0.5) * 0.88 / total,
        0.22 + (point.x + point.y) * 0.66 / total)

static func unproject(point: Vector2, dimensions: Vector2i) -> Vector2:
    var total := float(dimensions.x + dimensions.y)
    var difference := (point.x - 0.5) * total / 0.88 - (dimensions.y - dimensions.x) * 0.5
    var sum := (point.y - 0.22) * total / 0.66
    return Vector2((sum + difference) * 0.5, (sum - difference) * 0.5)

static func is_walkable(cell: Vector2i, layout: Dictionary) -> bool:
    var dimensions: Vector2i = layout["dimensions"]
    return cell.x > 0 and cell.y > 0 and cell.x < dimensions.x - 1 and cell.y < dimensions.y - 1 and cell not in layout["blocked"]

static func nearest_cell(point: Vector2, layout: Dictionary) -> Vector2i:
    var world := unproject(point, layout["dimensions"])
    var best := Vector2i(-1, -1)
    var distance := INF
    var dimensions: Vector2i = layout["dimensions"]
    for y in range(1, dimensions.y - 1):
        for x in range(1, dimensions.x - 1):
            var cell := Vector2i(x, y)
            if not is_walkable(cell, layout):
                continue
            var candidate := world.distance_squared_to(Vector2(cell) + Vector2(0.5, 0.5))
            if candidate < distance:
                distance = candidate
                best = cell
    return best

static func route(from: Vector2, to: Vector2, layout: Dictionary) -> Array[Vector2]:
    var dimensions: Vector2i = layout["dimensions"]
    var grid := AStarGrid2D.new()
    grid.region = Rect2i(Vector2i.ZERO, dimensions)
    grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
    grid.update()
    for y in dimensions.y:
        for x in dimensions.x:
            var cell := Vector2i(x, y)
            grid.set_point_solid(cell, not is_walkable(cell, layout))
    var start := nearest_cell(from, layout)
    var target := nearest_cell(to, layout)
    var result: Array[Vector2] = []
    if start == Vector2i(-1, -1) or target == Vector2i(-1, -1):
        return result
    for cell in grid.get_id_path(start, target):
        var point := project(Vector2(cell) + Vector2(0.5, 0.5), dimensions)
        if point.distance_to(from) > 0.001:
            result.append(point)
    return result

static func route_is_walkable(path: Array, layout: Dictionary) -> bool:
    ## This is also useful to tests and future room editors: every projected
    ## waypoint must resolve to a free navigation cell.
    for waypoint in path:
        if not waypoint is Vector2:
            return false
        var world := unproject(waypoint, layout["dimensions"])
        var cell := Vector2i(floori(world.x), floori(world.y))
        if not is_walkable(cell, layout):
            return false
    return true
