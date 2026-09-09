extends TestCase

func run() -> void:
    section("spatial controller navigation")
    var stage := Control.new()
    stage.custom_minimum_size = Vector2(500, 400)
    add_child(stage)

    var top_left := _button("Top left", Vector2(20, 20))
    var top_right := _button("Top right", Vector2(260, 20))
    var bottom_left := _button("Bottom left", Vector2(20, 180))
    var bottom_right := _button("Bottom right", Vector2(260, 180))
    stage.add_child(top_left)
    stage.add_child(top_right)
    stage.add_child(bottom_left)
    stage.add_child(bottom_right)
    await get_tree().process_frame
    UiFocus.wire(stage)

    check_equal(top_left.get_node(top_left.focus_neighbor_right), top_right,
        "right stays on the same row")
    check_equal(top_left.get_node(top_left.focus_neighbor_bottom), bottom_left,
        "down stays in the same column")
    check_equal(bottom_right.get_node(bottom_right.focus_neighbor_top), top_right,
        "up returns to the nearest control")
    check_equal(bottom_right.get_node(bottom_right.focus_neighbor_left), bottom_left,
        "left stays on the same row")
    check_equal(top_left.get_node(top_left.focus_previous), bottom_right,
        "previous focus wraps")
    check_equal(bottom_right.get_node(bottom_right.focus_next), top_left,
        "next focus wraps")

    section("unavailable controls are skipped")
    top_right.disabled = true
    bottom_left.hide()
    UiFocus.wire(stage)
    check_equal(UiFocus.first(stage), top_left, "the first available control is discoverable")
    check_equal(top_left.get_node(top_left.focus_next), bottom_right,
        "disabled and hidden controls are not in the focus chain")
    check_equal(top_left.focus_mode, Control.FOCUS_ALL,
        "interactive controls expose full keyboard and controller focus")
    stage.queue_free()

func _button(text: String, position: Vector2) -> Button:
    var button := Button.new()
    button.text = text
    button.position = position
    button.size = Vector2(160, 56)
    return button
