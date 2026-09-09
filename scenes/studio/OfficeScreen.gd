extends Control

## Office progression: compare the current workspace with every larger option
## and pay a one-time move-in cost to expand capacity.

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List

func _ready() -> void:
    GameClock.enter_gameplay(false)
    EventBus.week_ticked.connect(func(_y, _m, _w): _build())
    _build()
    TutorialManager.offer("office_growth", list)

func _build() -> void:
    UiBuilder.clear(list)
    var current := OfficeManager.current_office()
    list.add_child(UiBuilder.label(GameState.company_name.to_upper(), 20, true))
    list.add_child(UiBuilder.heading(str(current.get("name", "Office")).to_upper()))
    list.add_child(OfficeArtwork.view(GameState.office_id, 205))
    var facts := GridContainer.new()
    facts.columns = _columns(4)
    facts.add_theme_constant_override("h_separation", 8)
    facts.add_theme_constant_override("v_separation", 8)
    facts.add_child(UiBuilder.stat_card("capacity", "Capacity", "%d / %d" % [
        OfficeManager.headcount(), OfficeManager.capacity()]))
    facts.add_child(UiBuilder.stat_card("rent", "Monthly rent", "$%s" %
        Format.exact(OfficeManager.monthly_rent(current))))
    facts.add_child(UiBuilder.stat_card("comfort", "Comfort",
        _quality_stars(str(current.get("comfort", "Poor")))))
    facts.add_child(UiBuilder.stat_card("prestige", "Prestige",
        _quality_stars(str(current.get("prestige", "None")))))
    list.add_child(facts)

    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.section_header(
        "Team in this office", "Open a profile to manage workload, training, and equipment."))
    var team_grid := GridContainer.new()
    team_grid.columns = 1
    team_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for employee in EmployeeManager.active_employees():
        var card := PanelContainer.new()
        card.theme_type_variation = &"ElevatedPanel"
        card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var stack := VBoxContainer.new()
        stack.add_child(UiBuilder.employee_header(employee, EmployeeManager.job_title(employee)))
        var person := UiBuilder.button("VIEW PROFILE")
        person.tooltip_text = "Open skills, workload, morale, and equipment"
        person.pressed.connect(_open_employee.bind(employee.id))
        stack.add_child(person)
        card.add_child(stack)
        team_grid.add_child(card)
    list.add_child(team_grid)

    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.section_header(
        "Monthly cost", "The recurring operating cost of this office and its team."))
    var expenses := EmployeeManager.monthly_expenses()
    list.add_child(UiBuilder.stat_grid([
        {"icon": "payroll", "label": "Payroll", "value":
            Format.money_exact(int(expenses["salaries"]))},
        {"icon": "rent", "label": "Rent", "value":
            Format.money_exact(int(expenses["rent"]))},
        {"icon": "utilities", "label": "Utilities", "value":
            Format.money_exact(int(expenses["utilities"]))},
        {"icon": "skills", "label": "Software", "value":
            Format.money_exact(int(expenses["software"]))}
    ], _columns(4)))
    list.add_child(UiBuilder.info_card(
        "Total %s / month" % Format.money_exact(int(expenses["total"])),
        "These costs are paid automatically as simulation time advances.", "cash"))

    _workstation_section()
    _customization_shop()

    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.section_header(
        "Expand", "Larger offices unlock more headcount and stronger working conditions."))

    var office_grid := GridContainer.new()
    office_grid.columns = 1
    office_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for office in DataManager.offices:
        if str(office.get("id", "")) == GameState.office_id:
            continue
        if int(office.get("tier", 0)) <= int(current.get("tier", 0)):
            continue
        var office_panel := PanelContainer.new()
        office_panel.theme_type_variation = &"ElevatedPanel"
        office_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var office_stack := VBoxContainer.new()
        office_stack.add_child(UiBuilder.heading(str(office.get("name", "Office")).to_upper()))
        office_stack.add_child(OfficeArtwork.view(str(office.get("id", "bedroom")), 185))
        office_stack.add_child(UiBuilder.label(OfficeManager.description(office), 15))
        var move_cost := OfficeManager.move_in_cost(office)
        office_stack.add_child(UiBuilder.stat_grid([
            {"icon": "capacity", "label": "Capacity", "value": str(office.get("capacity", 1))},
            {"icon": "cash", "label": "Move-in", "value": Format.money_exact(move_cost)}
        ], 2))
        var is_next := int(office.get("tier", 0)) == int(current.get("tier", 0)) + 1
        var button := UiBuilder.major_button(
            "MOVE FOR $%s" % Format.exact(move_cost) if is_next else "LOCKED — MOVE IN ORDER"
        )
        button.disabled = not OfficeManager.can_move_to(str(office.get("id", "")))
        button.tooltip_text = (
            "Move the studio into this office"
            if not button.disabled else "Offices must be unlocked in order and paid for in cash")
        button.pressed.connect(_move.bind(str(office.get("id", ""))))
        office_stack.add_child(button)
        office_panel.add_child(office_stack)
        office_grid.add_child(office_panel)
    if office_grid.get_child_count() > 0:
        list.add_child(office_grid)

    if int(current.get("tier", 0)) >= _highest_tier():
        list.add_child(UiBuilder.divider())
        list.add_child(UiBuilder.label("This is the best office currently available.", 15, true))

func _workstation_section() -> void:
    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.section_header(
        "Workstations",
        "Better hardware improves the disciplines that lean on it; upgrades remain employee-specific."))

    var headcount := EmployeeManager.active_employees().size()
    var missing := OfficeManager.unequipped_employees()
    var equipped := headcount - missing.size()
    var panel := UiBuilder.info_card(
        "%d of %d employees equipped" % [equipped, headcount],
        "Everyone has a workstation." if missing.is_empty()
        else "%d employee%s still need basic hardware." % [
            missing.size(), "" if missing.size() == 1 else "s"],
        "skills")
    panel.theme_type_variation = &"PositivePanel" if missing.is_empty() else &"WarningPanel"
    list.add_child(panel)

    if missing.is_empty():
        return

    var cost := EquipmentSimulator.cost("basic") * missing.size()
    var button := UiBuilder.major_button(
        "EQUIP THE REST WITH BASIC -- $%s" % Format.exact(cost))
    button.disabled = not FinanceManager.can_afford(cost)
    button.tooltip_text = (
        "Buy basic workstations for every unequipped employee"
        if not button.disabled else "The studio cannot afford these workstations")
    button.pressed.connect(_equip_everyone_missing_one)
    list.add_child(button)

func _equip_everyone_missing_one() -> void:
    if bool(OfficeManager.equip_everyone_missing_one("basic").get("ok", false)):
        _build()

func _move(office_id: String) -> void:
    if OfficeManager.move_to(office_id):
        _build()

func _highest_tier() -> int:
    var result := 0
    for office in DataManager.offices:
        result = maxi(result, int(office.get("tier", 0)))
    return result

func _open_employee(employee_id: String) -> void:
    ScreenRouter.open_employee(employee_id, scene_file_path)
    get_tree().change_scene_to_file("res://scenes/company/EmployeeScreen.tscn")

func _quality_stars(label_text: String) -> String:
    var score: int = {"None": 0, "Poor": 1, "Minimal": 1, "Basic": 2,
        "Low": 2, "Average": 3, "Good": 4, "Excellent": 5}.get(label_text, 0)
    return "★".repeat(score) + "☆".repeat(5 - score)

func _customization_shop() -> void:
    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.section_header(
        "Customize office",
        "Buy a style pack, apply a complete remodel, or mix owned pieces in the room editor."))
    var catalog_grid := GridContainer.new()
    catalog_grid.columns = 1
    catalog_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for item in OfficeCustomizationManager.catalog():
        var id := str(item.get("id", ""))
        var panel := PanelContainer.new()
        panel.theme_type_variation = &"ElevatedPanel"
        panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        panel.custom_minimum_size = Vector2(300, 0)
        var stack := VBoxContainer.new()
        stack.add_theme_constant_override("separation", 9)
        var swatch := ColorRect.new()
        swatch.color = Color(str(item.get("accent", "#e98d48")))
        swatch.custom_minimum_size = Vector2(0, 12)
        swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
        stack.add_child(swatch)
        var preview_path := str(item.get("painted_sheet", item.get("overlay", "")))
        if not preview_path.is_empty():
            var preview := TextureRect.new()
            preview.texture = load(preview_path) as Texture2D
            preview.custom_minimum_size = Vector2(0, 104)
            preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
            preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
            preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
            stack.add_child(preview)
        stack.add_child(UiBuilder.label("%s\n%s" % [
            str(item.get("name", "Theme")).to_upper(),
            str(item.get("description", ""))], 14))
        var button: Button
        if GameState.equipped_office_customization == id:
            button = UiBuilder.button("FULL REMODEL APPLIED")
            button.disabled = true
            button.tooltip_text = "This complete style is currently applied"
        elif OfficeCustomizationManager.is_owned(id):
            button = UiBuilder.button("APPLY FULL REMODEL")
            button.tooltip_text = "Apply every component from this owned style pack"
            button.pressed.connect(_equip_customization.bind(id))
        elif str(item.get("purchase_type", "cash")) == "cash":
            var price := FinanceManager.expense(int(item.get("price", 0)))
            button = UiBuilder.major_button("BUY  $%s" % Format.exact(price))
            button.disabled = not OfficeCustomizationManager.can_buy(id)
            button.tooltip_text = (
                "Purchase this permanent office style pack"
                if not button.disabled else "The studio cannot afford this style pack")
            button.pressed.connect(_buy_customization.bind(id))
        else:
            button = UiBuilder.button("PREMIUM — COMING LATER")
            button.disabled = true
            button.tooltip_text = "This optional cosmetic pack is not available yet"
        stack.add_child(button)
        panel.add_child(stack)
        catalog_grid.add_child(panel)
    list.add_child(catalog_grid)
    _room_editor()

func _room_editor() -> void:
    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.section_header(
        "Room editor", "Each office component can use a different owned style. Changes apply immediately."))
    var owned := GameState.owned_office_customizations.duplicate()
    var editor_grid := GridContainer.new()
    editor_grid.columns = 1
    editor_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for category in OfficeCustomizationManager.CATEGORIES:
        var category_id := str(category["id"])
        var category_panel := PanelContainer.new()
        category_panel.theme_type_variation = &"ElevatedPanel"
        category_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var category_stack := VBoxContainer.new()
        category_stack.add_child(UiBuilder.status_row(
            "remodel_%s" % category_id, str(category["name"]).to_upper(), 14))
        var choice := OptionButton.new()
        choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        choice.custom_minimum_size = Vector2(0, UiBuilder.TAP_HEIGHT)
        choice.tooltip_text = "Choose an owned style for %s" % str(category["name"]).to_lower()
        var selected_index := 0
        for index in owned.size():
            var style_id := str(owned[index])
            choice.add_item(str(DataManager.get_office_customization(style_id).get("name", style_id)))
            choice.set_item_metadata(index, style_id)
            var component := OfficeCustomizationManager.component_texture_for(style_id, category_id)
            if component != null:
                choice.set_item_icon(index, component)
            if style_id == OfficeCustomizationManager.style_id_for(category_id):
                selected_index = index
        choice.select(selected_index)
        choice.item_selected.connect(_on_component_selected.bind(category_id, choice))
        category_stack.add_child(choice)
        category_panel.add_child(category_stack)
        editor_grid.add_child(category_panel)
    list.add_child(editor_grid)

func _columns(wide_count: int) -> int:
    return min(2, wide_count)

func _buy_customization(id: String) -> void:
    if OfficeCustomizationManager.buy(id):
        _build()

func _equip_customization(id: String) -> void:
    if OfficeCustomizationManager.equip(id):
        _build()

func _on_component_selected(index: int, category_id: String, choice: OptionButton) -> void:
    var style_id := str(choice.get_item_metadata(index))
    if OfficeCustomizationManager.set_component(category_id, style_id):
        _build()
