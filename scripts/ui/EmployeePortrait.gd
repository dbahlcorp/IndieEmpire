class_name EmployeePortrait
extends Control

const PORTRAIT_ART = preload("res://scripts/ui/ModularPortraitArt.gd")

## Compact procedural portrait. The stable seed composes reusable vector
## modules; the sprite rig constrains the family so close-up and office views
## still read as the same employee.

var employee: Employee:
    set(value):
        employee = value
        _last_expression = ""
        queue_redraw()

var _last_expression := ""
var _expression_poll := 0.0

func _init() -> void:
    custom_minimum_size = Vector2(74, 74)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(true)

func _process(delta: float) -> void:
    if employee == null:
        return
    _expression_poll += delta
    if _expression_poll < 0.25:
        return
    _expression_poll = 0.0
    var current: String = PORTRAIT_ART.expression(employee)
    if current != _last_expression:
        _last_expression = current
        queue_redraw()

func _draw() -> void:
    if employee == null:
        return
    PORTRAIT_ART.draw(self, Rect2(Vector2.ZERO, size), employee)
