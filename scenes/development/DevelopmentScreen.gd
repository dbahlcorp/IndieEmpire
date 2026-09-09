extends Control

## A live view of a project building itself. Time advances automatically while
## the player directs each phase, manages constraints, and chooses when to ship.

@onready var title_label: Label = $Margin/Shell/Scroll/VBox/TitleLabel
@onready var phase_label: Label = $Margin/Shell/Scroll/VBox/PhaseLabel
@onready var decision_container: VBoxContainer = $Margin/Shell/Scroll/VBox/DecisionContainer
@onready var team_label: Label = $Margin/Shell/Scroll/VBox/TeamLabel
@onready var bottleneck_container: VBoxContainer = $Margin/Shell/Scroll/VBox/BottleneckContainer
@onready var stats_label: Label = $Margin/Shell/Scroll/VBox/StatsLabel
@onready var bugs_label: Label = $Margin/Shell/Scroll/VBox/BugsLabel
@onready var cash_label: Label = $Margin/Shell/Scroll/VBox/CashLabel
@onready var budget_container: VBoxContainer = $Margin/Shell/Scroll/VBox/BudgetContainer
@onready var deadline_container: VBoxContainer = $Margin/Shell/Scroll/VBox/DeadlineContainer
@onready var status_label: Label = $Margin/Shell/Scroll/VBox/StatusLabel
@onready var polish_button: Button = $Margin/Shell/Scroll/VBox/PolishButton
@onready var release_button: Button = $Margin/Shell/ReleaseButton
@onready var abandon_button: Button = $Margin/Shell/Scroll/VBox/AbandonButton
@onready var abandon_confirm: ConfirmationDialog = $AbandonConfirm

const BUDGET_STEP := 5000

var project: GameProject
var _announced_complete := false
var _last_phase := ""

func _ready() -> void:
    project = GameState.current_project
    if project == null:
        get_tree().change_scene_to_file.call_deferred("res://scenes/studio/StudioScreen.tscn")
        return
    _last_phase = project.current_phase()

    polish_button.pressed.connect(_on_polish_toggled)
    release_button.pressed.connect(_on_release_pressed)
    abandon_button.pressed.connect(_on_abandon_pressed)
    abandon_confirm.confirmed.connect(_on_abandon_confirmed)

    EventBus.week_ticked.connect(_on_week)
    EventBus.project_schedule_slipped.connect(_on_schedule_slipped)
    GameClock.state_changed.connect(_refresh)

    GameClock.enter_gameplay()
    _refresh()
    TutorialManager.offer("development", phase_label)

func _on_week(_year: int, _month: int, _week: int) -> void:
    if project == null:
        return

    var current_phase := project.current_phase()
    if _last_phase == "pre_production" and current_phase == "production":
        GameClock.pause_for_decision("production focus")
        EventBus.notify("PRODUCTION BEGINS", "Choose what the team should prioritise", true)
    _last_phase = current_phase

    # Reaching 100% is a decision point, so the clock stops and says why.
    if project.development_progress >= 100.0 and not project.polishing and not _announced_complete:
        _announced_complete = true
        GameClock.pause_for_decision("project complete")
        EventBus.notify("%s IS READY" % project.title.to_upper(), "Ship it, or keep polishing", true)

    _refresh()

func _on_schedule_slipped(slipped_project: GameProject, weeks: int, causes: Array) -> void:
    ## ProjectManager checks -- and pauses the clock for -- every active
    ## project regardless of which screen is open. This only adds the rich,
    ## mock-up-shaped panel on top, when the player happens to already be
    ## looking at the exact project that slipped.
    if project == null or slipped_project == null or slipped_project.id != project.id:
        return
    var lines: Array[String] = []
    for cause in causes:
        lines.append("• %s" % str(cause))
    var dialog := AcceptDialog.new()
    dialog.title = "PROJECT DELAY"
    dialog.dialog_text = "%s is now projected to finish %d week%s late.\n\nCauses:\n%s" % [
        project.title, weeks, "" if weeks == 1 else "s", "\n".join(lines)
    ]
    add_child(dialog)
    dialog.popup_centered()

func _refresh() -> void:
    if project == null:
        return

    var size_name := DataManager.display_name(DataManager.sizes, project.size_id)
    var platform_name := DataManager.display_name(DataManager.platforms, project.platform_id)
    title_label.text = "%s\n%s - %s" % [project.title, size_name, platform_name]
    if not project.engine_id.is_empty():
        title_label.text += "\nEngine: %s" % EngineManager.engine_name(project.engine_id)
    if not project.feature_ids.is_empty():
        var names: Array[String] = []
        for id in project.feature_ids:
            names.append(FeatureSimulator.display_name(DataManager.get_game_feature(id)))
        title_label.text += "\nFeatures: %s" % ", ".join(names)
    phase_label.text = _phase_text()
    %PlanBar.value = project.preproduction_progress
    %BuildBar.value = project.development_progress
    %PolishBar.value = DevelopmentSimulator.polish_percent(project)
    _build_focus_section()
    team_label.text = _team_text()
    _build_bottleneck_section()

    var stats_format := (
        "Gameplay %.0f   Technology %.0f\n"
        + "Graphics %.0f   Story %.0f\n"
        + "Sound %.0f   Innovation %.0f\n"
        + "Performance %.0f   Narrative %.0f\n"
        + "Polish %.0f   Balance %.0f"
    )
    stats_label.text = stats_format % [
        project.gameplay, project.technology, project.graphics, project.story,
        project.sound, project.innovation, project.performance,
        project.narrative_quality, project.polish, project.balance
    ]

    bugs_label.text = _bugs_text()
    cash_label.text = "Cash %s   Spent %s   %s per week" % [
        Format.display(GameState.cash),
        Format.display(project.development_cost),
        Format.display(_weekly_cost())
    ]
    _build_budget_section()
    _build_deadline_section()

    var done := project.development_progress >= 100.0
    release_button.disabled = not done
    polish_button.disabled = not done
    polish_button.text = "STOP POLISHING" if project.polishing else "POLISH / FIX BUGS"
    status_label.text = _status(done)

func _build_focus_section() -> void:
    UiBuilder.clear(decision_container)
    var phase := project.current_phase()
    if phase == "released":
        return

    decision_container.add_child(UiBuilder.heading("CURRENT FOCUS"))
    var phase_name: String = {
        "pre_production": "PLAN",
        "production": "BUILD",
        "polish": "FINISH"
    }.get(phase, phase.to_upper())
    decision_container.add_child(UiBuilder.label(
        "%s PHASE\nDirect the team while this phase is active." % phase_name, 13, true))

    var choice := OptionButton.new()
    choice.custom_minimum_size = Vector2(0, UiBuilder.TAP_HEIGHT)
    choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var selected_id := project.focus_id(phase)
    for option in DevelopmentFocusSimulator.options_for(phase):
        choice.add_item(str(option.get("name", "Balanced")))
        var index := choice.item_count - 1
        var focus_id := str(option.get("id", DevelopmentFocusSimulator.DEFAULT_ID))
        choice.set_item_metadata(index, focus_id)
        if focus_id == selected_id:
            choice.select(index)
    choice.item_selected.connect(_on_focus_selected.bind(choice, phase))
    decision_container.add_child(choice)

    var profile := DevelopmentFocusSimulator.choice(project, phase)
    decision_container.add_child(UiBuilder.label(str(profile.get("description", "")), 13, true))

    var history: Array[String] = []
    for completed_phase in ["pre_production", "production", "polish"]:
        if project.focus_choices.has(completed_phase):
            history.append("%s: %s" % [
                {"pre_production": "Plan", "production": "Build", "polish": "Finish"}[
                    completed_phase],
                DevelopmentFocusSimulator.name_of(
                    completed_phase, project.focus_id(completed_phase))])
    if not history.is_empty():
        decision_container.add_child(UiBuilder.label("  •  ".join(history), 11, true))

func _on_focus_selected(index: int, choice: OptionButton, phase: String) -> void:
    var focus_id := str(choice.get_item_metadata(index))
    if project.current_phase() != phase or not project.set_focus(phase, focus_id):
        return
    SaveManager.autosave()
    _refresh()

func _build_budget_section() -> void:
    ## Optional. Nothing in the simulation enforces it -- purely a
    ## self-imposed number the player can hold the project to, tycoon-style.
    UiBuilder.clear(budget_container)
    if project.released:
        return

    if project.budget_target <= 0:
        var enable := UiBuilder.button("SET A BUDGET TARGET (OPTIONAL)")
        enable.pressed.connect(func():
            var suggested := project.development_cost + BUDGET_STEP * 4
            var remaining := DevelopmentSimulator.estimate_remaining(project)
            if not remaining.is_empty():
                var mid := (int(remaining.get("cost_min", 0)) + int(remaining.get("cost_max", 0))) / 2
                suggested = project.development_cost + mid
            project.budget_target = maxi(
                int(round(float(suggested) / float(BUDGET_STEP))) * BUDGET_STEP, BUDGET_STEP)
            _refresh())
        budget_container.add_child(enable)
        return

    var percent := float(project.development_cost) / float(project.budget_target) * 100.0
    budget_container.add_child(UiBuilder.heading("PROJECT BUDGET"))
    # Wages sit outside the budget on purpose -- they are paid through payroll,
    # not out of this project's budget -- but they are most of what the game
    # really costs, so the player should not first meet them in the postmortem.
    budget_container.add_child(UiBuilder.label(
        "Target\n%s\n\nCurrent Spend\n%s\n\nWages So Far\n%s\n\n%s\n%d%%" % [
            Format.money_exact(project.budget_target), Format.money_exact(project.development_cost),
            Format.money_exact(project.labour_cost),
            UiBuilder.meter(percent), int(round(percent))
        ], 14, true))

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    var minus := UiBuilder.button("-")
    minus.custom_minimum_size.x = 58
    minus.disabled = project.budget_target <= BUDGET_STEP
    minus.pressed.connect(func():
        project.budget_target = maxi(project.budget_target - BUDGET_STEP, BUDGET_STEP)
        _refresh())
    row.add_child(minus)
    var plus := UiBuilder.button("+")
    plus.custom_minimum_size.x = 58
    plus.pressed.connect(func():
        project.budget_target += BUDGET_STEP
        _refresh())
    row.add_child(plus)
    var clear := UiBuilder.button("CLEAR")
    clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    clear.pressed.connect(func():
        project.budget_target = 0
        _refresh())
    row.add_child(clear)
    budget_container.add_child(row)

    var remaining := DevelopmentSimulator.estimate_remaining(project)
    if not remaining.is_empty():
        var projected_max := project.development_cost + int(remaining.get("cost_max", 0))
        var over := projected_max - project.budget_target
        if over > 0:
            budget_container.add_child(UiBuilder.label(
                "BUDGET WARNING\nProject is expected to exceed\nits target budget by %s." % [
                    Format.money_exact(over)], 13, true))

func _build_deadline_section() -> void:
    ## Optional target release date. Nothing enforces it -- see
    ## DeadlineSimulator -- until the player picks one of the decisions
    ## offered here once it is actually projected to slip.
    UiBuilder.clear(deadline_container)
    if project.released:
        return

    if not project.has_deadline():
        var enable := UiBuilder.button("SET A TARGET RELEASE DATE (OPTIONAL)")
        enable.pressed.connect(func():
            var index := DeadlineSimulator.estimated_completion_index(project)
            if index < 0:
                index = TimeManager.absolute_week() + 8
            var date := TimeManager.date_from_week_index(index)
            project.deadline_year = date["year"]
            project.deadline_month = date["month"]
            project.deadline_week = date["week"]
            _refresh())
        deadline_container.add_child(enable)
        return

    deadline_container.add_child(UiBuilder.heading("DEADLINE"))
    deadline_container.add_child(UiBuilder.label(
        "Target Release\n%s\n\nEstimated Completion\n%s" % [
            project.deadline_label(), DeadlineSimulator.estimated_completion_label(project)
        ], 14, true))

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    var minus := UiBuilder.button("-")
    minus.custom_minimum_size.x = 58
    minus.pressed.connect(func():
        _shift_deadline(-1)
        _refresh())
    row.add_child(minus)
    var plus := UiBuilder.button("+")
    plus.custom_minimum_size.x = 58
    plus.pressed.connect(func():
        _shift_deadline(1)
        _refresh())
    row.add_child(plus)
    var clear := UiBuilder.button("CLEAR")
    clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    clear.pressed.connect(func():
        project.clear_deadline()
        _refresh())
    row.add_child(clear)
    deadline_container.add_child(row)

    var delay := DeadlineSimulator.projected_delay_weeks(project)
    if delay > 0:
        deadline_container.add_child(UiBuilder.label(
            "⚠ PROJECTED DELAY\n%d week%s" % [delay, "" if delay == 1 else "s"], 16, true))
        _build_deadline_decisions()

func _shift_deadline(months: int) -> void:
    ## Keeps whatever week-of-month the target already sits on -- set either
    ## by the initial forecast or by DELAY RELEASE -- rather than flattening
    ## it back to the first week and quietly losing up to three weeks of
    ## precision against the real schedule maths.
    var index := (
        TimeManager.week_index(project.deadline_year, project.deadline_month, project.deadline_week)
        + months * TimeManager.WEEKS_PER_MONTH
    )
    index = maxi(index, TimeManager.absolute_week())
    var date := TimeManager.date_from_week_index(index)
    project.deadline_year = date["year"]
    project.deadline_month = date["month"]
    project.deadline_week = date["week"]

func _build_deadline_decisions() -> void:
    ## Beautiful management decisions: cut scope, staff up, crunch, or admit
    ## the date and push it back. Only shown once a delay is actually
    ## projected -- see _build_deadline_section().
    deadline_container.add_child(UiBuilder.label("MANAGEMENT DECISIONS", 12, true))

    for feature_variant in project.feature_ids.duplicate():
        var feature_id := str(feature_variant)
        var feature_name := FeatureSimulator.display_name(DataManager.get_game_feature(feature_id))
        var cut := UiBuilder.button("REDUCE SCOPE: CUT %s" % feature_name.to_upper())
        cut.pressed.connect(_on_reduce_scope_pressed.bind(feature_id, feature_name))
        deadline_container.add_child(cut)

    var add_staff := UiBuilder.button("ADD STAFF")
    add_staff.pressed.connect(func():
        get_tree().change_scene_to_file("res://scenes/company/HiringScreen.tscn"))
    deadline_container.add_child(add_staff)

    var crunching := not project.team_id.is_empty() and MoraleManager.is_crunching(project.team_id)
    var crunch := UiBuilder.button("STOP CRUNCHING" if crunching else "CRUNCH")
    crunch.disabled = project.team_id.is_empty()
    crunch.pressed.connect(_on_deadline_crunch_pressed)
    deadline_container.add_child(crunch)

    var delay_release := UiBuilder.button("DELAY RELEASE")
    delay_release.pressed.connect(_on_delay_release_pressed)
    deadline_container.add_child(delay_release)

func _on_reduce_scope_pressed(feature_id: String, feature_name: String) -> void:
    var dialog := ConfirmationDialog.new()
    dialog.title = "Cut a feature?"
    dialog.ok_button_text = "CUT IT"
    dialog.dialog_text = (
        "%s comes out of the build. The effort it added comes off what's\nleft, and it earns no more quality from here -- whatever it already\nbanked stays." % feature_name)
    dialog.confirmed.connect(func():
        DevelopmentSimulator.drop_feature(project, feature_id)
        EventBus.notify("SCOPE REDUCED", "%s was cut from %s" % [feature_name, project.title])
        SaveManager.autosave()
        _refresh())
    add_child(dialog)
    dialog.popup_centered()

func _on_deadline_crunch_pressed() -> void:
    if project.team_id.is_empty():
        return
    if MoraleManager.is_crunching(project.team_id):
        MoraleManager.set_crunch(project.team_id, false)
        _refresh()
        return

    var dialog := ConfirmationDialog.new()
    dialog.title = "Enable crunch?"
    dialog.ok_button_text = "CRUNCH"
    var text := "The team will work late until you stop it.\n\n"
    for effect in MoraleManager.crunch_effects():
        text += "%-20s %s\n" % [str(effect["label"]), str(effect["value"])]
    dialog.dialog_text = text
    dialog.confirmed.connect(func():
        MoraleManager.set_crunch(project.team_id, true)
        _refresh())
    add_child(dialog)
    dialog.popup_centered()

func _on_delay_release_pressed() -> void:
    ## Admits the forecast: the target moves out to match the current
    ## worst-case estimate, rather than staying broken every week until the
    ## player deals with it.
    var index := DeadlineSimulator.estimated_completion_index(project)
    if index < 0:
        return
    var date := TimeManager.date_from_week_index(index)
    project.deadline_year = date["year"]
    project.deadline_month = date["month"]
    project.deadline_week = date["week"]
    EventBus.notify("RELEASE DELAYED", "%s now targets %s" % [project.title, project.deadline_label()])
    SaveManager.autosave()
    _refresh()

func _phase_text() -> String:
    ## Three phases, three bars. Different disciplines carry each one --
    ## design and writing drive pre-production, the whole team drives
    ## production, QA/artists/designers/programmers carry polish.
    var polish_percent := DevelopmentSimulator.polish_percent(project)
    var text := "PLAN %d%%   ·   BUILD %d%%   ·   POLISH %d%%" % [
        int(round(project.preproduction_progress)),
        int(round(project.development_progress)), int(round(polish_percent))]
    # Only known once pre-production has actually finished.
    var flaw := project.preproduction_flaw_label()
    if project.preproduction_progress >= 100.0 and not flaw.is_empty():
        var sign := "+" if project.production_efficiency_modifier >= 0.0 else ""
        text += "\n\n%s\nProduction efficiency %s%d%%" % [
            flaw, sign, int(round(project.production_efficiency_modifier * 100.0))]

    return text

func _bugs_text() -> String:
    ## The true count is never shown here -- only what QA has actually found,
    ## and how much that number can be trusted.
    var testing := float(DevelopmentSimulator.staff_effects(project).get("testing", 0.35))
    var rate := QASimulator.discovery_rate(testing, project.polishing)
    return "Known bugs %d   QA Confidence: %s   Week %d" % [
        project.known_bugs, QASimulator.confidence_label(rate), project.total_weeks()
    ]

func _weekly_cost() -> int:
    if project.polishing:
        return DevelopmentSimulator.get_polish_cost(project)
    return DevelopmentSimulator.get_weekly_cost(project)

func _team_text() -> String:
    var team := TeamManager.find_team(project.team_id)
    var lines: Array[String] = [team.name if team != null else "Development Team"]
    var effects := DevelopmentSimulator.staff_effects(project)
    if team != null:
        lines.append("Chemistry %.0f%% %s   Effective output %.1fx" % [
            team.chemistry, TeamManager.chemistry_label(team.chemistry),
            float(effects.get("effective_team_output", 1.0))
        ])
    if bool(effects.get("understaffed", false)):
        var scope_speed := float(effects.get("scope_speed", 1.0))
        lines.append("UNDERSTAFFED for this scope\nDevelopment speed %d%%" % [
            int(round((scope_speed - 1.0) * 100.0))
        ])
    elif bool(effects.get("overstaffed", false)):
        var size := DataManager.get_size(project.size_id)
        var ideal_max := int(size.get("max_useful_staff", 1))
        var headcount := TeamManager.working_members(project.team_id).size()
        lines.append("OVERSTAFFED for this scope\nCoordination overhead %s\nDevelopment cost %s" % [
            ScopeSimulator.coordination_overhead_label(headcount, ideal_max),
            ScopeSimulator.cost_overhead_label(headcount, ideal_max)
        ])
    var lead := EmployeeManager.find_employee(project.lead_employee_id)
    if lead != null:
        lines.append("\nPROJECT LEAD\n\n%s\nLeadership: %d" % [
            lead.display_name(), lead.leadership])

    var contributions: Dictionary = effects.get("role_contributions", {})
    for role in TeamManager.PROJECT_ROLES:
        var employee_id := str(project.role_assignments.get(role["id"], ""))
        var employee := EmployeeManager.find_employee(employee_id)
        if employee != null:
            var load := TeamManager.workload_percent(employee.id)
            var contribution: Dictionary = contributions.get(role["id"], {})
            var effectiveness := int(round(float(contribution.get("effectiveness", 0.0)) * 100.0))
            lines.append("%s: %s — %d%% output, %d%% load" % [
                role["name"], employee.display_name(), effectiveness, load
            ])
    return "\n".join(lines)

func _build_bottleneck_section() -> void:
    ## Reads the same role_contributions the team text already lists role by
    ## role -- see BottleneckSimulator -- and calls out the one discipline
    ## actually holding the project back, instead of leaving the player to
    ## spot it in a wall of per-role numbers.
    UiBuilder.clear(bottleneck_container)
    if project.released:
        return

    var found := BottleneckSimulator.find(project)
    if found.is_empty():
        return

    bottleneck_container.add_child(UiBuilder.heading("BOTTLENECK"))
    bottleneck_container.add_child(UiBuilder.label(str(found.get("role_name", "")), 15, true))
    bottleneck_container.add_child(UiBuilder.label(
        "Required Output\n%s\n\nAvailable\n%s" % [
            UiBuilder.meter(float(found.get("required", 1.0)) * 100.0),
            UiBuilder.meter(float(found.get("available", 0.0)) * 100.0)
        ], 14, true))
    bottleneck_container.add_child(UiBuilder.label(
        "Recommendation:\n%s" % str(found.get("recommendation", "")), 13, true))
    TutorialManager.context("bottleneck", bottleneck_container)

func _status(done: bool) -> String:
    if FinanceManager.is_in_trouble():
        return "OVERDRAWN - %d week%s to recover" % [
            FinanceManager.weeks_of_grace_left(),
            "" if FinanceManager.weeks_of_grace_left() == 1 else "s"]
    if not done:
        if GameClock.paused:
            return "Development paused"
        if project.current_phase() == "pre_production":
            return "In pre-production..."
        return "In development..."
    if project.polishing:
        return "Polishing. Bugs are being fixed."
    return "Ready to ship."

func _on_polish_toggled() -> void:
    project.polishing = not project.polishing
    if project.polishing:
        GameClock.set_paused(false)
    _refresh()

func _on_abandon_pressed() -> void:
    GameClock.set_paused(true)
    abandon_confirm.popup_centered()

func _on_abandon_confirmed() -> void:
    GameState.abandon_project()
    SaveManager.autosave()
    get_tree().change_scene_to_file("res://scenes/studio/StudioScreen.tscn")

func _on_release_pressed() -> void:
    # Who sells it is the last decision before it ships.
    project.polishing = false
    get_tree().change_scene_to_file("res://scenes/release/PublishingScreen.tscn")

