extends TestCase

## The studio surface has to hold up on a real phone, not just at the authored
## 430 x 932. Since the September 8 layout pass the desktop window opens at
## 1280 x 800 and the stretch aspect is "expand", so the logical viewport is no
## longer a fixed size -- it is whatever the device's own aspect ratio produces.
## This walks the real spread of devices, computes the logical viewport each one
## yields under the project's own stretch settings, and checks that the floating
## studio controls stay on screen, stay apart, and stay thumb-sized.

## Below this, a control is too small to hit reliably with a thumb. Apple and
## Android both publish ~44pt/48dp; the layout is authored in logical pixels
## that sit close enough to a point for this to be the right bar.
const MIN_TOUCH_TARGET := 44.0

## Physical screens worth caring about, as the device reports them.
const DEVICES := [
    {"name": "iPhone SE", "size": Vector2i(750, 1334)},
    {"name": "iPhone 15 Pro", "size": Vector2i(1179, 2556)},
    {"name": "Pixel 8", "size": Vector2i(1080, 2400)},
    {"name": "tall 21:9 Android", "size": Vector2i(1080, 2520)},
    {"name": "iPad portrait", "size": Vector2i(1536, 2048)},
    {"name": "foldable inner", "size": Vector2i(1768, 2208)},
    {"name": "phone landscape", "size": Vector2i(2400, 1080)},
    {"name": "desktop default", "size": Vector2i(1280, 800)},
]

## The floating controls that make up the studio surface. Each has to be fully
## on screen, and none of them may sit on top of another.
const SURFACE_CONTROLS := ["CompanyHUD", "ClockBar", "Projects", "BottomDock"]

func run() -> void:
    GameState.start_company("Indie Empire", "Alex", "normal")
    SaveManager.has_active_company = true
    GameClock.set_paused(true)
    _the_viewport_never_shrinks_below_the_authored_size()
    for device in DEVICES:
        await _the_studio_surface_survives(device)
    await _management_screens_stay_readable()

func settle() -> void:
    for i in range(5):
        await get_tree().process_frame

func _base_size() -> Vector2:
    ## Read from project.godot rather than written down here, so retuning the
    ## base viewport cannot leave this test quietly describing the old one.
    return Vector2(
        float(ProjectSettings.get_setting("display/window/size/viewport_width", 430)),
        float(ProjectSettings.get_setting("display/window/size/viewport_height", 932)))

func _logical_size(window: Vector2i) -> Vector2:
    ## What `canvas_items` + aspect `expand` turns a physical window into: the
    ## content is scaled by whichever axis is tightest, and the other axis gets
    ## the leftover room as extra logical pixels.
    var base := _base_size()
    var scale := minf(float(window.x) / base.x, float(window.y) / base.y)
    return (Vector2(window) / scale).floor()

func _the_viewport_never_shrinks_below_the_authored_size() -> void:
    section("expand only ever adds room, it never takes it away")
    # This is the property the whole surface layout leans on: because `expand`
    # scales by the tighter axis, every device gets at least the authored
    # 430 x 932 to lay out in. Nothing can be crushed, only stretched -- which
    # is why the layout code can size against fixed pixel numbers at all.
    var base := _base_size()
    for device in DEVICES:
        var logical := _logical_size(device["size"])
        check(logical.x >= base.x - 1.0 and logical.y >= base.y - 1.0,
            "%s -> %d x %d, never under the authored %d x %d"
                % [device["name"], logical.x, logical.y, base.x, base.y])

func _stage(logical: Vector2) -> SubViewport:
    ## A SubViewport sized to the *logical* viewport a device produces. The
    ## layout code only ever reads get_viewport_rect(), so this reproduces
    ## exactly what it would see on the device without needing a real window.
    var viewport := SubViewport.new()
    viewport.size = Vector2i(logical)
    viewport.disable_3d = true
    add_child(viewport)
    return viewport

func _the_studio_surface_survives(device: Dictionary) -> void:
    var logical := _logical_size(device["size"])
    section("%s -- %d x %d physical, %d x %d logical"
        % [device["name"], device["size"].x, device["size"].y, logical.x, logical.y])

    var viewport := _stage(logical)
    var screen := load("res://scenes/studio/StudioScreen.tscn").instantiate() as Control
    viewport.add_child(screen)
    VisualTheme._style_scene(screen)
    await settle()

    var bounds := Rect2(Vector2.ZERO, logical)
    var rects := {}
    for id in SURFACE_CONTROLS + ["OfficeArt"]:
        var control := screen.get_node("%" + id) as Control
        rects[id] = control.get_global_rect()
        check(bounds.encloses(rects[id]), "%s is fully on screen" % id)

    # The surface floats its panels rather than stacking them in a container,
    # so nothing enforces that they stay apart -- only the arithmetic in
    # _layout_surface() does. That arithmetic is what this checks.
    for i in range(SURFACE_CONTROLS.size()):
        for j in range(i + 1, SURFACE_CONTROLS.size()):
            var a: String = SURFACE_CONTROLS[i]
            var b: String = SURFACE_CONTROLS[j]
            check(not rects[a].intersects(rects[b]),
                "%s %s and %s %s do not overlap" % [a, rects[a], b, rects[b]])

    # The room is the backdrop the controls float over, so it is allowed to sit
    # under the HUD -- but it must not run under the dock, which is opaque and
    # would clip it.
    check(not rects["OfficeArt"].intersects(rects["BottomDock"]),
        "the room stops above the dock")
    check(rects["OfficeArt"].size.y >= 180.0,
        "the room keeps a usable height (%.0f)" % rects["OfficeArt"].size.y)

    for id in ["MenuButton", "DevelopButton"]:
        var button := screen.get_node("%" + id) as Control
        check(button.size.y >= MIN_TOUCH_TARGET,
            "%s is thumb-sized (%.0f >= %.0f)" % [id, button.size.y, MIN_TOUCH_TARGET])

    # The menu is the only way to reach nine of the ten management screens, so
    # it has to fit whatever the device gave us.
    screen.get_node("%MenuButton").pressed.emit()
    await settle()
    var panel := screen.get_node("%MenuPanel") as Control
    check(bounds.encloses(panel.get_global_rect()), "the studio menu fits on screen")
    for id in ["OfficeButton", "StaffButton", "CompanyButton"]:
        var button := screen.get_node("%" + id) as Control
        check(button.size.y >= MIN_TOUCH_TARGET,
            "menu entry %s is thumb-sized (%.0f)" % [id, button.size.y])
    screen.get_node("%CloseMenuButton").pressed.emit()

    screen.queue_free()
    viewport.queue_free()
    await settle()

func _management_screens_stay_readable() -> void:
    section("management screens stay within a readable measure at every width")
    # _fit_management_screen() centres these on a wide viewport and lets them
    # fill a narrow one. Both branches have to leave the content on screen.
    for device in DEVICES:
        var logical := _logical_size(device["size"])
        var viewport := _stage(logical)
        var office := load("res://scenes/studio/OfficeScreen.tscn").instantiate() as Control
        viewport.add_child(office)
        VisualTheme._style_scene(office)
        await settle()
        var margin := office.get_node("Margin") as Control
        var rect := margin.get_global_rect()
        check(Rect2(Vector2.ZERO, logical).encloses(rect),
            "%s: content stays on screen" % device["name"])
        check(rect.size.x <= 520.1,
            "%s: measure stays readable (%.0f <= 520)" % [device["name"], rect.size.x])
        check(rect.position.x >= 0.0,
            "%s: content does not start off the left edge" % device["name"])
        office.queue_free()
        viewport.queue_free()
        await settle()
