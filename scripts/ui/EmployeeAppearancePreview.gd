class_name EmployeeAppearancePreview
extends Control

## Animated preview used by CEO creation/customization screens.

var appearance_index := 0
var elapsed := 0.0

func _ready() -> void:
    custom_minimum_size = Vector2(104, 112)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(true)

func set_appearance(value: int) -> void:
    appearance_index = clampi(value, 0, OfficeCharacterArt.SHEETS.size() - 1)
    queue_redraw()

func _process(delta: float) -> void:
    elapsed += delta
    queue_redraw()

func _draw() -> void:
    var sheet := OfficeCharacterArt.sheet_for_appearance(appearance_index)
    if sheet == null:
        return
    var preview_size := minf(size.x, size.y) * 0.92
    var bob := sin(elapsed * 2.5) * 1.5
    var destination := Rect2(
        Vector2((size.x - preview_size) * 0.5, (size.y - preview_size) * 0.5 + bob),
        Vector2(preview_size, preview_size)
    )
    draw_texture_rect_region(sheet, destination, OfficeCharacterArt.frame_region(0, 3))

