extends Control

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List

var _confirming_layoff: bool = false

func _ready() -> void:
    GameClock.enter_gameplay(false)
    _build()

func _build() -> void:
    UiBuilder.clear(list)
    var employee := ScreenRouter.selected_employee()
    if employee == null:
        list.add_child(UiBuilder.label("Employee profile unavailable.", 16, true))
        return
    list.add_child(UiBuilder.employee_header(employee, EmployeeManager.job_title(employee), 104))
    list.add_child(UiBuilder.divider())

    list.add_child(UiBuilder.status_row("skills", "CORE SKILLS", 16))
    list.add_child(UiBuilder.label(
        "Programming    %d\nDesign             %d\nArt                    %d\nWriting              %d\nAudio                %d\nProduction       %d\nTesting             %d\nResearch          %d" % [
        employee.programming, employee.design, employee.art, employee.writing,
        employee.audio, employee.production, employee.testing, employee.research], 14))

    list.add_child(UiBuilder.status_row("attributes", "WORK STYLE", 16))
    list.add_child(UiBuilder.label(
        "Creativity        %d\nSpeed              %d\nQuality             %d\nTeamwork       %d\nAdaptability   %d\nLeadership      %d" % [
        employee.creativity, employee.speed, employee.quality, employee.teamwork,
        employee.adaptability, employee.leadership], 14))

    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.progress_meter("Morale", employee.morale, "morale"))
    list.add_child(UiBuilder.progress_meter("Stress", employee.stress, "stress"))
    list.add_child(UiBuilder.progress_meter("Energy", employee.energy, "energy"))

    _contribution_section(employee)

    list.add_child(UiBuilder.divider())
    var history := _project_history(employee)
    list.add_child(UiBuilder.status_row("cash", "Salary\n%s" % (
        "Founder" if employee.is_founder() else "$%s/month" % Format.exact(employee.salary)), 15))
    list.add_child(UiBuilder.status_row("experience", "Experience\n%s" %
        _tenure_label(employee), 15))
    list.add_child(UiBuilder.status_row("projects", "Projects\n%d" % history.size(), 15))
    list.add_child(UiBuilder.status_row("best_game", "Best Game\n%s" %
        _best_game(history), 15))

    if not employee.trait_ids.is_empty():
        list.add_child(UiBuilder.divider())
        list.add_child(UiBuilder.status_row("traits", "TRAITS", 16))
        for trait_id in employee.trait_ids:
            var trait_panel := PanelContainer.new()
            trait_panel.add_child(UiBuilder.label("%s\n%s" % [
                EmployeeManager.trait_name(trait_id).to_upper(),
                EmployeeManager.trait_description(trait_id)], 13))
            list.add_child(trait_panel)

    _workstation_section(employee)
    _layoff_section(employee)

func _contribution_section(employee: Employee) -> void:
    ## Not the whole simulation -- attributes, experience, equipment and
    ## traits all matter too, see ProjectStaffSimulator.effects() -- but the
    ## three levers the player actually watches and manages week to week.
    var skill := RetentionManager.best_skill(employee)
    var workload := TeamManager.workload_percent(employee.id)
    var contribution := ContributionSimulator.effective_contribution(employee, skill, workload)

    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.status_row("skills", "EFFECTIVE CONTRIBUTION", 16))
    list.add_child(UiBuilder.label(
        "%s %d\n  x %.2f morale\n  x %.2f stress\n  x %.2f workload (%d%%)\n= ~%d" % [
            str(skill).capitalize(), int(contribution["base"]),
            float(contribution["morale"]), float(contribution["stress"]),
            float(contribution["workload"]), workload,
            int(round(float(contribution["total"])))], 14))
    if workload > 100 and float(contribution["total"]) < float(contribution["base"]):
        list.add_child(UiBuilder.label(
            "Overworked. Their best skill is being wasted, not spent.", 13, true))

func _workstation_section(employee: Employee) -> void:
    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.status_row("remodel_computers", "WORKSTATION", 16))

    var current := employee.workstation_tier
    list.add_child(UiBuilder.label(
        "Currently\n%s" % (EquipmentSimulator.name_of(current) if not current.is_empty()
            else "None -- working at a real disadvantage"), 14))

    for tier in EquipmentSimulator.TIERS:
        var tier_id := str(tier["id"])
        var panel := PanelContainer.new()
        var stack := VBoxContainer.new()
        var label := str(tier["name"]).to_upper()
        var preview := TextureRect.new()
        preview.texture = EquipmentSimulator.art_texture(tier_id)
        preview.custom_minimum_size = Vector2(0, 148)
        preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
        stack.add_child(preview)
        stack.add_child(UiBuilder.label("%s WORKSTATION\n\nCost\n$%s" % [
            label, Format.exact(EquipmentSimulator.cost(tier_id))], 14, true))

        var bonus_lines: Array = EquipmentSimulator.skill_bonus_lines(tier_id)
        if bonus_lines.is_empty():
            stack.add_child(UiBuilder.label("Productivity\nNormal", 13))
        else:
            var text := ""
            for bonus in bonus_lines:
                text += "%s\n+%d%%\n" % [str(bonus["skill"]), int(bonus["percent"])]
            stack.add_child(UiBuilder.label(text.strip_edges(), 13))

        if current == tier_id:
            var owned := UiBuilder.button("EQUIPPED")
            owned.disabled = true
            stack.add_child(owned)
        else:
            var buy := UiBuilder.button("BUY FOR $%s" % Format.exact(EquipmentSimulator.cost(tier_id)))
            buy.disabled = not OfficeManager.can_equip(employee, tier_id)
            buy.pressed.connect(_buy_workstation.bind(employee, tier_id))
            stack.add_child(buy)

        panel.add_child(stack)
        list.add_child(panel)

func _buy_workstation(employee: Employee, tier_id: String) -> void:
    if OfficeManager.equip_workstation(employee, tier_id):
        _build()

func _layoff_section(employee: Employee) -> void:
    if not RetentionManager.can_lay_off(employee):
        return

    list.add_child(UiBuilder.divider())
    if not _confirming_layoff:
        var start := UiBuilder.button("TERMINATE EMPLOYMENT")
        start.pressed.connect(func():
            _confirming_layoff = true
            _build())
        list.add_child(start)
        return

    var severance := RetentionSimulator.severance(employee)
    var on_team := not employee.assigned_team.is_empty()
    list.add_child(UiBuilder.label("TERMINATE EMPLOYMENT", 16, true))
    list.add_child(UiBuilder.label("%s\n\nSeverance   $%s\n\nMorale impact\n  %s: -%d\n  Company: -%d" % [
        employee.display_name(), Format.exact(severance),
        "Team" if on_team else "No team", RetentionSimulator.LAYOFF_TEAM_MORALE,
        RetentionSimulator.LAYOFF_COMPANY_MORALE], 14))

    var upcoming := RetentionManager.recent_layoff_count() + 1
    if upcoming >= RetentionSimulator.MASS_LAYOFF_THRESHOLD:
        list.add_child(UiBuilder.label(("This would be layoff %d in a year. Cuts on "
            + "this scale hurt the studio's reputation as an employer.") % upcoming, 13, true))

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    var confirm := UiBuilder.button("CONFIRM")
    confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    confirm.pressed.connect(func():
        RetentionManager.lay_off(employee)
        _confirming_layoff = false
        get_tree().change_scene_to_file(ScreenRouter.return_scene))
    row.add_child(confirm)
    var cancel := UiBuilder.button("CANCEL")
    cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cancel.pressed.connect(func():
        _confirming_layoff = false
        _build())
    row.add_child(cancel)
    list.add_child(row)

func _project_history(employee: Employee) -> Array[GameProject]:
    var result: Array[GameProject] = []
    for game in GameState.released_games:
        if employee.id in game.credited_employee_ids or employee.id == game.lead_employee_id:
            result.append(game)
    return result

func _best_game(games: Array[GameProject]) -> String:
    if games.is_empty():
        return "None yet"
    var best := games[0]
    for game in games:
        if game.review_score > best.review_score:
            best = game
    return "%s  ·  %.1f" % [best.title, best.review_score]

func _tenure_label(employee: Employee) -> String:
    var months := maxi((TimeManager.current_year - employee.hire_year) * 12 +
        TimeManager.current_month - employee.hire_month, 0)
    if months < 12:
        return "%d month%s" % [months, "" if months == 1 else "s"]
    var years := int(months / 12)
    return "%d year%s" % [years, "" if years == 1 else "s"]

func _on_back_pressed() -> void:
    get_tree().change_scene_to_file(ScreenRouter.return_scene)
