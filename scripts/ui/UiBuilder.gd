class_name UiBuilder
extends RefCounted

## Small helpers for the screens that build their contents in code.

static func label(text: String, size: int = 15, centered: bool = false) -> Label:
    var node := Label.new()
    node.text = text
    node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    node.add_theme_font_size_override("font_size", size)
    if centered:
        node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    return node

static func heading(text: String) -> Label:
    var node := label(text.to_upper(), 17)
    node.theme_type_variation = &"SectionHeading"
    return node

static func employee_header(employee: Employee, subtitle: String = "", portrait_size: int = 74) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    var portrait := EmployeePortrait.new()
    portrait.employee = employee
    portrait.custom_minimum_size = Vector2(portrait_size, portrait_size)
    row.add_child(portrait)
    var copy := VBoxContainer.new()
    copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    copy.alignment = BoxContainer.ALIGNMENT_CENTER
    copy.add_child(label(employee.display_name().to_upper(), 18))
    if not subtitle.is_empty():
        copy.add_child(label(subtitle, 14))
    row.add_child(copy)
    return row

static func status_row(icon_id: String, text: String, size: int = 15) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    var icon := TextureRect.new()
    icon.texture = UiIcons.texture(icon_id)
    icon.custom_minimum_size = Vector2(22, 22)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(icon)
    var copy := label(text, size)
    copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    copy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    row.add_child(copy)
    return row

static func stat_card(icon_id: String, title: String, value: String) -> PanelContainer:
    var card := PanelContainer.new()
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 9)
    var icon := TextureRect.new()
    icon.texture = UiIcons.texture(icon_id)
    icon.custom_minimum_size = Vector2(26, 26)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    row.add_child(icon)
    var copy := VBoxContainer.new()
    copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var title_label := label(title.to_upper(), 11)
    title_label.theme_type_variation = &"CardCaption"
    copy.add_child(title_label)
    var value_label := label(value, 17)
    value_label.theme_type_variation = &"CardValue"
    copy.add_child(value_label)
    row.add_child(copy)
    card.add_child(row)
    return card

static func progress_meter(title: String, value: int, icon_id: String) -> VBoxContainer:
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 4)
    stack.add_child(status_row(icon_id, "%s   %d" % [title, value], 14))
    var bar := ProgressBar.new()
    bar.max_value = 100
    bar.value = clampi(value, 0, 100)
    bar.show_percentage = false
    bar.custom_minimum_size = Vector2(0, 16)
    stack.add_child(bar)
    return stack

static func identity_row(texture: Texture2D, text: String, icon_size: Vector2 = Vector2(34, 34), font_size: int = 15) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    var icon := TextureRect.new()
    icon.texture = texture
    icon.custom_minimum_size = icon_size
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(icon)
    var copy := label(text, font_size)
    copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    copy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    row.add_child(copy)
    return row

static func divider() -> Control:
    var line := HSeparator.new()
    line.custom_minimum_size = Vector2(0, 8)
    return line

## Mobile sizing: nothing tappable is smaller than TAP_HEIGHT, and a screen's
## primary action gets MAJOR_HEIGHT. No hover-only affordances anywhere.
const TAP_HEIGHT := 54
const MAJOR_HEIGHT := 64

static func button(text: String, height: int = TAP_HEIGHT) -> Button:
    var node := Button.new()
    node.text = text
    node.custom_minimum_size = Vector2(0, maxi(height, TAP_HEIGHT))
    node.add_theme_font_size_override("font_size", 15)
    return node

static func major_button(text: String) -> Button:
    var node := button(text, MAJOR_HEIGHT)
    node.add_theme_font_size_override("font_size", 18)
    return node

static func toggle(text: String, pressed: bool) -> CheckButton:
    var node := CheckButton.new()
    node.text = text
    node.button_pressed = pressed
    node.custom_minimum_size = Vector2(0, TAP_HEIGHT)
    node.add_theme_font_size_override("font_size", 15)
    return node

static func meter(percent: float, width: int = 10) -> String:
    ## A filled bar for a 0-100 value, for things the player should be able to
    ## read at a glance rather than compare digits.
    var filled := clampi(int(round(percent / 100.0 * float(width))), 0, width)
    return "#".repeat(filled) + ".".repeat(width - filled)

static func score_bar(score: float) -> String:
    ## A ten-point score as filled and empty blocks.
    var filled := clampi(int(round(score)), 0, 10)
    return "#".repeat(filled) + ".".repeat(10 - filled)

static func clear(container: Node) -> void:
    for child in container.get_children():
        child.queue_free()

static func collapsible_section(title: String, expanded: bool = false) -> Dictionary:
    ## A tap-to-expand card: the header always shows, the body only takes
    ## space once opened. For long, optional content -- a feature list, a
    ## priority picker -- on a portrait screen, where showing everything at
    ## once pushes the primary action off the bottom. Returns {"panel",
    ## "body", "header"}: add content to "body", add "panel" to your own
    ## container, and set "header".text again if you want to show a live
    ## summary (item count, current selection) after content changes.
    var panel := PanelContainer.new()
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 6)

    var header := Button.new()
    header.custom_minimum_size = Vector2(0, TAP_HEIGHT)
    header.add_theme_font_size_override("font_size", 15)
    header.alignment = HORIZONTAL_ALIGNMENT_LEFT
    header.text = "%s  %s" % ["▾" if expanded else "▸", title]

    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation", 6)
    body.visible = expanded

    header.pressed.connect(func():
        body.visible = not body.visible
        header.text = "%s  %s" % ["▾" if body.visible else "▸", title])

    stack.add_child(header)
    stack.add_child(body)
    panel.add_child(stack)
    return {"panel": panel, "body": body, "header": header}
