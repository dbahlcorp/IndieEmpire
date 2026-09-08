extends Control

## Office progression: compare the current workspace with every larger option
## and pay a one-time move-in cost to expand capacity.

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List

func _ready() -> void:
    GameClock.enter_gameplay(false)
    EventBus.week_ticked.connect(func(_y, _m, _w): _build())
    _build()

func _build() -> void:
    UiBuilder.clear(list)
    var current := OfficeManager.current_office()
    list.add_child(UiBuilder.label(GameState.company_name.to_upper(), 20, true))
    list.add_child(UiBuilder.heading(str(current.get("name", "Office")).to_upper()))
    list.add_child(OfficeArtwork.view(GameState.office_id, 205))
    var facts := GridContainer.new()
    facts.columns = 2
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
    list.add_child(UiBuilder.heading("TEAM"))
    for employee in EmployeeManager.active_employees():
        var card := PanelContainer.new()
        var stack := VBoxContainer.new()
        stack.add_child(UiBuilder.employee_header(employee, EmployeeManager.job_title(employee)))
        var person := UiBuilder.button("VIEW PROFILE")
        person.pressed.connect(_open_employee.bind(employee.id))
        stack.add_child(person)
        card.add_child(stack)
        list.add_child(card)

    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("MONTHLY COST"))
    var expenses := EmployeeManager.monthly_expenses()
    list.add_child(UiBuilder.status_row("payroll", "Payroll\n$%s" %
        Format.exact(int(expenses["salaries"])), 15))
    list.add_child(UiBuilder.status_row("rent", "Rent\n$%s" %
        Format.exact(int(expenses["rent"])), 15))
    list.add_child(UiBuilder.status_row("utilities", "Utilities\n$%s" %
        Format.exact(int(expenses["utilities"])), 15))
    list.add_child(UiBuilder.status_row("skills", "Software\n$%s" %
        Format.exact(int(expenses["software"])), 15))
    list.add_child(UiBuilder.label("TOTAL\n$%s" % Format.exact(int(expenses["total"])), 22, true))

    _workstation_section()
    _customization_shop()

    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("EXPAND"))

    for office in DataManager.offices:
        if str(office.get("id", "")) == GameState.office_id:
            continue
        if int(office.get("tier", 0)) <= int(current.get("tier", 0)):
            continue
        list.add_child(UiBuilder.divider())
        list.add_child(UiBuilder.heading(str(office.get("name", "Office")).to_upper()))
        list.add_child(OfficeArtwork.view(str(office.get("id", "bedroom")), 185))
        list.add_child(UiBuilder.label(OfficeManager.description(office), 15))
        var move_cost := OfficeManager.move_in_cost(office)
        list.add_child(UiBuilder.label("Move-in cost    $%s" % Format.exact(move_cost), 15))
        var is_next := int(office.get("tier", 0)) == int(current.get("tier", 0)) + 1
        var button := UiBuilder.major_button(
            "MOVE FOR $%s" % Format.exact(move_cost) if is_next else "LOCKED — MOVE IN ORDER"
        )
        button.disabled = not OfficeManager.can_move_to(str(office.get("id", "")))
        button.pressed.connect(_move.bind(str(office.get("id", ""))))
        list.add_child(button)

    if int(current.get("tier", 0)) >= _highest_tier():
        list.add_child(UiBuilder.divider())
        list.add_child(UiBuilder.label("This is the best office currently available.", 15, true))

func _workstation_section() -> void:
    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("WORKSTATIONS"))
    list.add_child(UiBuilder.label(
        "Every employee wants a machine of their own. Basic just about does the "
        + "job; Standard and Pro pay off in the disciplines that lean on hardware. "
        + "Buy or upgrade one for a specific person from their profile.", 12))

    var headcount := EmployeeManager.active_employees().size()
    var missing := OfficeManager.unequipped_employees()
    list.add_child(UiBuilder.label(
        "%d of %d employees equipped" % [headcount - missing.size(), headcount], 14, true))

    if missing.is_empty():
        return

    var cost := EquipmentSimulator.cost("basic") * missing.size()
    var button := UiBuilder.major_button(
        "EQUIP THE REST WITH BASIC -- $%s" % Format.exact(cost))
    button.disabled = not FinanceManager.can_afford(cost)
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
    list.add_child(UiBuilder.heading("CUSTOMIZE OFFICE"))
    list.add_child(UiBuilder.label(
        "Buy a style pack, apply the complete remodel, or mix its pieces in the room editor.", 13, true))
    for item in OfficeCustomizationManager.catalog():
        var id := str(item.get("id", ""))
        var panel := PanelContainer.new()
        var stack := VBoxContainer.new()
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
        elif OfficeCustomizationManager.is_owned(id):
            button = UiBuilder.button("APPLY FULL REMODEL")
            button.pressed.connect(_equip_customization.bind(id))
        elif str(item.get("purchase_type", "cash")) == "cash":
            var price := FinanceManager.expense(int(item.get("price", 0)))
            button = UiBuilder.major_button("BUY  $%s" % Format.exact(price))
            button.disabled = not OfficeCustomizationManager.can_buy(id)
            button.pressed.connect(_buy_customization.bind(id))
        else:
            button = UiBuilder.button("PREMIUM — COMING LATER")
            button.disabled = true
        stack.add_child(button)
        panel.add_child(stack)
        list.add_child(panel)
    _room_editor()

func _room_editor() -> void:
    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("ROOM EDITOR"))
    list.add_child(UiBuilder.label(
        "Every part can use a different owned style. Changes apply immediately.", 13, true))
    var owned := GameState.owned_office_customizations.duplicate()
    for category in OfficeCustomizationManager.CATEGORIES:
        var category_id := str(category["id"])
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        var title := UiBuilder.label(str(category["name"]), 14)
        title.custom_minimum_size = Vector2(128, 0)
        title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        row.add_child(title)
        var category_icon := TextureRect.new()
        category_icon.texture = UiIcons.texture("remodel_%s" % category_id)
        category_icon.custom_minimum_size = Vector2(24, 24)
        category_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        category_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        row.add_child(category_icon)
        var choice := OptionButton.new()
        choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        choice.custom_minimum_size = Vector2(0, UiBuilder.TAP_HEIGHT)
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
        row.add_child(choice)
        list.add_child(row)

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
