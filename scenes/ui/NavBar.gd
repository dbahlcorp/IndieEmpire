extends HBoxContainer

## Bottom navigation shared by every main screen. Buttons are built in code so
## adding a tab does not mean editing five scene files.

const TABS := [
    {"id": "studio", "label": "Studio", "scene": "res://scenes/studio/StudioScreen.tscn"},
    {"id": "games", "label": "Games", "scene": "res://scenes/studio/GamesScreen.tscn"},
    {"id": "market", "label": "Market", "scene": "res://scenes/market/MarketScreen.tscn"},
    {"id": "staff", "label": "Staff", "scene": "res://scenes/company/StaffScreen.tscn"},
    {"id": "company", "label": "Company", "scene": "res://scenes/company/CompanyScreen.tscn"}
]

func _ready() -> void:
    add_theme_constant_override("separation", 4)

    var current := ""
    if get_tree().current_scene != null:
        current = get_tree().current_scene.scene_file_path

    for tab in TABS:
        if not TutorialManager.system_visible(str(tab["id"])):
            continue
        var button := Button.new()
        button.text = ""
        button.tooltip_text = str(tab["label"])
        button.custom_minimum_size = Vector2(0, 58)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var active := current == str(tab["scene"])
        button.set_meta("active_nav", active)
        button.disabled = active
        button.pressed.connect(_go.bind(str(tab["scene"])))
        add_child(button)
        _add_button_contents(button, str(tab["id"]), str(tab["label"]))
        _add_badge(button, _badge_count(str(tab["id"])))
        if str(tab["id"]) == "market":
            TutorialManager.offer("market", button)
        elif str(tab["id"]) == "staff":
            TutorialManager.offer("first_hire", button)

func _add_button_contents(button: Button, icon_id: String, label_text: String) -> void:
    var stack := VBoxContainer.new()
    stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
    stack.add_theme_constant_override("separation", 0)
    stack.alignment = BoxContainer.ALIGNMENT_CENTER
    button.add_child(stack)

    var icon_center := CenterContainer.new()
    icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    icon_center.custom_minimum_size = Vector2(0, 25)
    stack.add_child(icon_center)
    var icon := TextureRect.new()
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    icon.texture = UiIcons.texture(icon_id)
    icon.custom_minimum_size = Vector2(21, 21)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon_center.add_child(icon)

    var label := Label.new()
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.text = label_text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 10)
    label.add_theme_color_override("font_color", Color("#fff7df"))
    stack.add_child(label)

func _badge_count(tab_id: String) -> int:
    match tab_id:
        "studio":
            return GameState.active_projects.size() + (1 if ContractManager.has_active_contract() else 0)
        "games":
            return GameState.pending_postmortems().size()
        "staff":
            return RetentionManager.requests().size() + RetentionManager.leaving().size()
        _:
            return 0

func _add_badge(button: Button, count: int) -> void:
    if count <= 0:
        return
    var badge := Label.new()
    badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
    badge.text = "9+" if count > 9 else str(count)
    badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    button.add_child(badge)
    badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    badge.offset_left = -23.0
    badge.offset_top = 3.0
    badge.offset_right = -3.0
    badge.offset_bottom = 23.0
    badge.add_theme_font_size_override("font_size", 10)
    badge.add_theme_color_override("font_color", Color.WHITE)
    var bubble := StyleBoxFlat.new()
    bubble.bg_color = Color("#e98d48")
    bubble.border_color = Color("#fff7df")
    bubble.set_border_width_all(1)
    bubble.set_corner_radius_all(10)
    badge.add_theme_stylebox_override("normal", bubble)

func _go(scene_path: String) -> void:
    get_tree().change_scene_to_file(scene_path)
