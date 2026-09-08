extends Node

## Visual regression fixture for the live studio. It deliberately catches the
## old failure mode by photographing staff while they are between furniture.

const OUTPUT_DIR := "res://artifacts/studio-walking-2026-09-08"

func _ready() -> void:
    GameState.start_company("Indie Empire", "Alex", "normal")
    SaveManager.has_active_company = true
    GameState.office_id = "large_studio_floor"
    for index in 9:
        var employee := EmployeeManager.generate_candidate(
            ["programmer", "designer", "artist"][index % 3],
            ["junior", "mid", "senior"][index % 3],
            "Studio Tester %02d" % (index + 1), 9000 + index)
        employee.id = GameState.next_employee_id()
        employee.status = "active"
        GameState.employees.append(employee)
    GameClock.set_paused(true)

    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
    await _capture(Vector2i(430, 932), "studio-iphone.png")
    await _capture(Vector2i(1491, 932), "studio-desktop.png")
    get_tree().quit()

func _capture(viewport_size: Vector2i, filename: String) -> void:
    var viewport := SubViewport.new()
    viewport.size = viewport_size
    viewport.disable_3d = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child(viewport)
    var screen := load("res://scenes/studio/StudioScreen.tscn").instantiate() as Control
    viewport.add_child(screen)
    for frame in 5:
        await get_tree().process_frame

    var floor := screen.get_node("%OfficeArt") as OfficeFloorView
    var social: Array = floor.floor_plan["social"]
    for index in floor.actors.size():
        var actor: Dictionary = floor.actors[index]
        floor._route_actor(actor, social[index % social.size()], "social")
        for step in (index % 5) + 1:
            floor._advance_actor(actor, 0.42)
    floor.queue_redraw()
    # Headless compatibility does not emit frame_post_draw on every renderer.
    # Two process frames still flush this SubViewport before get_image().
    await get_tree().process_frame
    await get_tree().process_frame

    var image := viewport.get_texture().get_image()
    var output := ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, filename])
    var error := image.save_png(output)
    print("snapshot %s (%s)" % [output, error_string(error)])
    viewport.queue_free()
    await get_tree().process_frame
