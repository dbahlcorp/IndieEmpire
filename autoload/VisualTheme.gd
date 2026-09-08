extends Node

## Central visual language for the whole game. It takes inspiration from the
## friendly, tactile management UI of classic game-development tycoons while
## keeping Indie Empire's own palette and portrait-first information layout.

const INK := Color("#263c40")
const MUTED := Color("#617174")
const CREAM := Color("#fff7df")
const PAPER := Color("#f8e8c8")
const TEAL := Color("#315f65")
const TEAL_DARK := Color("#254a50")
const SKY := Color("#4f91a2")
const SKY_DARK := Color("#377180")
const ORANGE := Color("#e98d48")
const ORANGE_DARK := Color("#bd6636")
const RED := Color("#b94e48")
const OUTLINE := Color("#3c5558")
const PANEL_EDGE := Color("#a77c4d")
const GOLD := Color("#f0b34f")
const GOLD_DARK := Color("#c5792f")

var game_theme: Theme

func _ready() -> void:
    game_theme = _build_theme()
    get_tree().scene_changed.connect(func(): _style_scene(get_tree().current_scene))
    call_deferred("_style_scene", get_tree().current_scene)

func _build_theme() -> Theme:
    var theme := Theme.new()
    var regular := SystemFont.new()
    regular.font_names = PackedStringArray(["Avenir Next", "Trebuchet MS", "Verdana", "Segoe UI"])
    var bold := SystemFont.new()
    bold.font_names = PackedStringArray(["Avenir Next", "Trebuchet MS", "Verdana", "Segoe UI"])
    bold.font_weight = 700

    theme.default_font = regular
    theme.default_font_size = 15
    theme.set_font("font", "Label", regular)
    theme.set_color("font_color", "Label", INK)
    theme.set_color("font_shadow_color", "Label", Color(1, 1, 1, 0.35))
    theme.set_constant("shadow_offset_x", "Label", 0)
    theme.set_constant("shadow_offset_y", "Label", 1)

    theme.set_type_variation("ScreenTitle", "Label")
    theme.set_font("font", "ScreenTitle", bold)
    theme.set_color("font_color", "ScreenTitle", TEAL_DARK)
    theme.set_color("font_shadow_color", "ScreenTitle", Color(1, 1, 1, 0.75))
    theme.set_constant("shadow_offset_y", "ScreenTitle", 2)

    theme.set_type_variation("MutedLabel", "Label")
    theme.set_color("font_color", "MutedLabel", MUTED)
    theme.set_type_variation("DangerLabel", "Label")
    theme.set_font("font", "DangerLabel", bold)
    theme.set_color("font_color", "DangerLabel", RED)
    theme.set_type_variation("ClockLabel", "Label")
    theme.set_font("font", "ClockLabel", bold)
    theme.set_color("font_color", "ClockLabel", TEAL_DARK)

    theme.set_type_variation("SectionHeading", "Label")
    theme.set_font("font", "SectionHeading", bold)
    theme.set_color("font_color", "SectionHeading", TEAL_DARK)
    theme.set_color("font_shadow_color", "SectionHeading", Color(1, 1, 1, 0.72))
    theme.set_constant("shadow_offset_y", "SectionHeading", 1)
    theme.set_type_variation("CardCaption", "Label")
    theme.set_font("font", "CardCaption", bold)
    theme.set_color("font_color", "CardCaption", MUTED)
    theme.set_type_variation("CardValue", "Label")
    theme.set_font("font", "CardValue", bold)
    theme.set_color("font_color", "CardValue", INK)

    _add_button_type(theme, "Button", SKY, SKY_DARK, CREAM)
    theme.set_type_variation("PrimaryButton", "Button")
    _add_button_type(theme, "PrimaryButton", GOLD, GOLD_DARK, INK)
    theme.set_font("font", "PrimaryButton", bold)
    theme.set_type_variation("SecondaryButton", "Button")
    _add_button_type(theme, "SecondaryButton", PAPER, Color("#e5c99a"), INK)
    theme.set_type_variation("NavButton", "Button")
    _add_button_type(theme, "NavButton", TEAL, TEAL_DARK, Color.WHITE, 11)
    theme.set_font("font", "NavButton", bold)
    theme.set_type_variation("NavButtonActive", "Button")
    _add_button_type(theme, "NavButtonActive", ORANGE, ORANGE_DARK, Color.WHITE, 11)
    theme.set_stylebox("disabled", "NavButtonActive", _box(ORANGE, OUTLINE, 11, 2, 2))
    theme.set_color("font_disabled_color", "NavButtonActive", Color.WHITE)
    theme.set_font("font", "NavButtonActive", bold)
    theme.set_type_variation("ClockButton", "Button")
    _add_button_type(theme, "ClockButton", CREAM, Color("#e7cfa2"), TEAL_DARK, 12)
    theme.set_font("font", "ClockButton", bold)

    _add_button_type(theme, "OptionButton", CREAM, Color("#ead5aa"), INK)
    _add_button_type(theme, "CheckButton", CREAM, Color("#ead5aa"), INK)
    theme.set_stylebox("normal", "LineEdit", _box(CREAM, OUTLINE, 12, 2))
    theme.set_stylebox("focus", "LineEdit", _box(Color.WHITE, ORANGE, 12, 3))
    theme.set_color("font_color", "LineEdit", INK)
    theme.set_color("caret_color", "LineEdit", ORANGE_DARK)
    theme.set_stylebox("normal", "TextEdit", _box(CREAM, OUTLINE, 12, 2))
    theme.set_stylebox("focus", "TextEdit", _box(Color.WHITE, ORANGE, 12, 3))
    theme.set_color("font_color", "TextEdit", INK)

    theme.set_stylebox("panel", "Panel", _box(PAPER, PANEL_EDGE, 14, 2, 5))
    theme.set_stylebox("panel", "PanelContainer", _box(PAPER, PANEL_EDGE, 14, 2, 5))
    theme.set_stylebox("background", "ProgressBar", _box(Color("#d8c7a6"), OUTLINE, 9, 1))
    theme.set_stylebox("fill", "ProgressBar", _box(Color("#6ab29c"), TEAL_DARK, 9, 1))
    theme.set_color("font_color", "ProgressBar", Color.WHITE)
    theme.set_color("font_outline_color", "ProgressBar", TEAL_DARK)
    theme.set_constant("outline_size", "ProgressBar", 2)
    theme.set_stylebox("separator", "HSeparator", _separator())
    theme.set_color("font_color", "PopupMenu", INK)
    theme.set_stylebox("panel", "PopupMenu", _box(CREAM, OUTLINE, 10, 2, 4))
    theme.set_stylebox("hover", "PopupMenu", _box(Color("#f2c77e"), Color.TRANSPARENT, 6, 0))
    return theme

func _add_button_type(theme: Theme, type: String, base: Color, pressed: Color,
        font_color: Color, radius: int = 13) -> void:
    theme.set_stylebox("normal", type, _box(base, OUTLINE, radius, 2, 4))
    theme.set_stylebox("hover", type, _box(base.lightened(0.09), OUTLINE, radius, 2, 5))
    theme.set_stylebox("pressed", type, _box(pressed, OUTLINE, radius, 2, 1))
    theme.set_stylebox("focus", type, _box(base, ORANGE, radius, 3, 4))
    theme.set_stylebox("disabled", type, _box(TEAL_DARK, OUTLINE, radius, 2, 1))
    theme.set_color("font_color", type, font_color)
    theme.set_color("font_hover_color", type, font_color)
    theme.set_color("font_pressed_color", type, font_color)
    theme.set_color("font_focus_color", type, font_color)
    theme.set_color("font_disabled_color", type, Color(1, 1, 1, 0.92))
    theme.set_constant("outline_size", type, 0)

func _box(color: Color, border: Color, radius: int, width: int,
        shadow_size: int = 0) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = color
    box.border_color = border
    box.set_border_width_all(width)
    box.set_corner_radius_all(radius)
    box.content_margin_left = 14
    box.content_margin_right = 14
    box.content_margin_top = 8
    box.content_margin_bottom = 8
    if shadow_size > 0:
        box.shadow_color = Color(0.18, 0.12, 0.08, 0.22)
        box.shadow_size = shadow_size
        box.shadow_offset = Vector2(0, 3)
    return box

func _separator() -> StyleBoxLine:
    var line := StyleBoxLine.new()
    line.color = Color("#b99061")
    line.thickness = 2
    line.grow_begin = 2
    line.grow_end = 2
    return line

func _style_scene(root: Node) -> void:
    if root == null or not root is Control:
        return
    var control := root as Control
    control.theme = game_theme
    var backdrop := GameBackdrop.new()
    backdrop.name = "GameBackdrop"
    backdrop.menu_mode = root.name == "MainMenuScreen"
    control.add_child(backdrop)
    control.move_child(backdrop, 0)
    _add_studio_context(control)
    _apply_mobile_safe_area(control)
    _style_tree(control)
    if control.name != "StudioScreen":
        _fit_management_screen(control)
        if not control.resized.is_connected(_fit_management_screen.bind(control)):
            control.resized.connect(_fit_management_screen.bind(control))

func _apply_mobile_safe_area(root: Control) -> void:
    var margin := root.get_node_or_null("Margin") as MarginContainer
    if margin == null:
        return
    var safe := DisplayServer.get_display_safe_area()
    var window_size := DisplayServer.window_get_size()
    if safe.size == Vector2i.ZERO or window_size.x <= 0 or window_size.y <= 0:
        return
    var viewport_size := root.get_viewport_rect().size
    var scale_x := viewport_size.x / float(window_size.x)
    var scale_y := viewport_size.y / float(window_size.y)
    var left_inset := float(safe.position.x) * scale_x
    var top_inset := float(safe.position.y) * scale_y
    var right_inset := float(window_size.x - safe.end.x) * scale_x
    var bottom_inset := float(window_size.y - safe.end.y) * scale_y
    margin.offset_left = maxf(margin.offset_left, left_inset + 12.0)
    margin.offset_top = maxf(margin.offset_top, top_inset + 12.0)
    margin.offset_right = minf(margin.offset_right, -right_inset - 12.0)
    margin.offset_bottom = minf(margin.offset_bottom, -bottom_inset - 12.0)

func _style_tree(node: Node) -> void:
    if node is Button:
        _style_button(node as Button)
    elif node is Label:
        _style_label(node as Label)
    for child in node.get_children():
        if child is GameBackdrop:
            continue
        _style_tree(child)

func _style_button(button: Button) -> void:
    var parent_name := button.get_parent().name if button.get_parent() != null else &""
    if parent_name == &"NavBar":
        button.theme_type_variation = (
            &"NavButtonActive" if bool(button.get_meta("active_nav", false)) else &"NavButton")
    elif parent_name == &"ClockBar":
        button.theme_type_variation = &"ClockButton"
    elif button.name == &"BackButton" or button.text.begins_with("BACK"):
        button.theme_type_variation = &"SecondaryButton"
    elif button.custom_minimum_size.y >= 60.0 or button.name in [
            &"StartButton", &"ContinueButton", &"DevelopButton", &"ReleaseButton"]:
        button.theme_type_variation = &"PrimaryButton"

func _style_label(label: Label) -> void:
    var node_name := String(label.name)
    if node_name in ["Title", "CompanyLabel"] or node_name.ends_with("Title"):
        label.theme_type_variation = &"ScreenTitle"
    elif node_name in ["WarningLabel", "ErrorLabel"]:
        label.theme_type_variation = &"DangerLabel"
    elif label.get_parent() != null and label.get_parent().name == &"ClockBar":
        label.theme_type_variation = &"ClockLabel"
    elif node_name in ["DateLabel", "VersionLabel", "HintLabel"]:
        label.theme_type_variation = &"MutedLabel"

func _fit_management_screen(root: Control) -> void:
    var margin := root.get_node_or_null("Margin") as MarginContainer
    if margin == null:
        return
    if not margin.has_meta("portrait_offsets"):
        margin.set_meta("portrait_offsets", Vector2(margin.offset_left, margin.offset_right))
    var original: Vector2 = margin.get_meta("portrait_offsets")
    if root.get_viewport_rect().size.x > 700:
        margin.anchor_left = 0.5
        margin.anchor_right = 0.5
        margin.offset_left = -260
        margin.offset_right = 260
    else:
        margin.anchor_left = 0.0
        margin.anchor_right = 1.0
        margin.offset_left = original.x
        margin.offset_right = original.y
    var paper := root.get_node_or_null("ManagementPaper") as Panel
    if paper != null:
        paper.anchor_left = margin.anchor_left
        paper.anchor_right = margin.anchor_right
        paper.anchor_top = 0.0
        paper.anchor_bottom = 1.0
        paper.offset_left = margin.offset_left - 12
        paper.offset_right = margin.offset_right + 12
        paper.offset_top = maxf(8, margin.offset_top - 12)
        paper.offset_bottom = minf(-8, margin.offset_bottom + 12)

func _add_studio_context(root: Control) -> void:
    if root.name in ["StudioScreen", "MainMenuScreen", "NewCompanyScreen", "BootScreen", "GameOverScreen"]:
        return
    if not SaveManager.has_active_company or root.get_node_or_null("Margin") == null:
        return
    var room := TextureRect.new()
    room.texture = OfficeArtwork.texture(GameState.office_id)
    room.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    room.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    room.name = "StudioContext"
    room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    room.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(room)
    root.move_child(room, 1)
    var shade := ColorRect.new()
    shade.name = "StudioShade"
    shade.color = Color(0.03, 0.09, 0.10, 0.6)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(shade)
    root.move_child(shade, 2)
    var paper := Panel.new()
    paper.name = "ManagementPaper"
    paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
    paper.add_theme_stylebox_override("panel", _box(PAPER, PANEL_EDGE, 16, 2))
    root.add_child(paper)
    root.move_child(paper, 3)

