class_name UiFocus
extends RefCounted

## Builds explicit, spatial controller navigation for the current scene. Godot's
## default tree-order focus remains as a fallback through focus_next/previous.

static func wire(root: Control) -> void:
    if root == null or not is_instance_valid(root):
        return
    var controls: Array[Control] = []
    _collect(root, controls)
    if controls.is_empty():
        return
    for index in controls.size():
        var control := controls[index]
        control.focus_next = control.get_path_to(controls[(index + 1) % controls.size()])
        control.focus_previous = control.get_path_to(
            controls[(index - 1 + controls.size()) % controls.size()])
        _set_neighbor(control, controls, Vector2.LEFT, &"focus_neighbor_left")
        _set_neighbor(control, controls, Vector2.RIGHT, &"focus_neighbor_right")
        _set_neighbor(control, controls, Vector2.UP, &"focus_neighbor_top")
        _set_neighbor(control, controls, Vector2.DOWN, &"focus_neighbor_bottom")

static func first(root: Control) -> Control:
    var controls: Array[Control] = []
    _collect(root, controls)
    return controls[0] if not controls.is_empty() else null

static func _collect(node: Node, result: Array[Control]) -> void:
    if node is Control:
        var control := node as Control
        if _is_interactive(control):
            control.focus_mode = Control.FOCUS_ALL
            result.append(control)
    for child in node.get_children():
        _collect(child, result)

static func _is_interactive(control: Control) -> bool:
    if not control.is_visible_in_tree():
        return false
    if control is BaseButton:
        return not (control as BaseButton).disabled
    if control is LineEdit or control is TextEdit:
        return true
    if control is Range and not control is ProgressBar and not control is ScrollBar:
        return true
    return false

static func _set_neighbor(source: Control, controls: Array[Control], direction: Vector2,
        property: StringName) -> void:
    var source_center := source.get_global_rect().get_center()
    var best: Control = null
    var best_score := INF
    for target in controls:
        if target == source:
            continue
        var delta := target.get_global_rect().get_center() - source_center
        var forward := delta.dot(direction)
        if forward <= 1.0:
            continue
        var cross := absf(delta.cross(direction))
        # Favour the same row/column, but still allow a diagonal escape from
        # asymmetrical cards and responsive grids.
        var score := forward + cross * 2.4
        if score < best_score:
            best_score = score
            best = target
    if best != null:
        source.set(property, source.get_path_to(best))
