class_name OfficeFloorView
extends Control

## A tiny physical office simulation rendered over the room illustration.
## Employees own a desk anchor, walk through the open-floor hub, take short
## breaks, and return to a seated work pose. This is presentation-only: it reads
## employee/project state but never changes the management simulation.

const ROOM_RENDERER := preload("res://scripts/ui/StudioRoomRenderer.gd")
const WALK_SPEED := 0.115
const ARRIVAL_DISTANCE := 0.008
const BODY_COLORS := [
    Color("#e47f43"), Color("#438da0"), Color("#6f9b6a"),
    Color("#b65c63"), Color("#765f9e"), Color("#d39a3d")
]
const SKIN_COLORS := [
    Color("#f3c89d"), Color("#daa176"), Color("#b97855"), Color("#704431")
]
const HAIR_COLORS := [
    Color("#3a2922"), Color("#6d442a"), Color("#b67635"), Color("#d4b07a")
]
const MAX_WORK_BUBBLES := 18
const WORK_OUTPUT_COLORS := {
    "code": Color("#42a5c6"),
    "design": Color("#f0a542"),
    "art": Color("#df6f91"),
    "story": Color("#9a79c9"),
    "audio": Color("#55ad7a"),
    "qa": Color("#d95a52"),
    "plan": Color("#70899b"),
    "polish": Color("#e2bd48"),
    "research": Color("#7c72d8"),
    "training": Color("#5f9c68")
}
const ACTIVITY_COLORS := {
    "idle": Color("#84929a"), "working": Color("#42a5c6"),
    "training": Color("#5f9c68"), "researching": Color("#7c72d8"),
    "crunching": Color("#e06c52")
}
const REACTION_COLORS := {
    "happy": Color("#63b878"),
    "idea": Color("#efbd48"),
    "chat": Color("#58a8c7"),
    "stress": Color("#d85b52"),
    "worry": Color("#d67d48"),
    "star": Color("#bd83d0"),
    "cheer": Color("#e26b91")
}

var floor_plan: Dictionary = {}
var office_id := "bedroom"
var office_texture: Texture2D
var workstation_textures: Dictionary = {}
var foreground_texture: Texture2D
var atmosphere_texture: Texture2D
var actors: Array[Dictionary] = []
var work_bubbles: Array[Dictionary] = []
var elapsed := 0.0
# The first people the room ever shows are already at work; anyone who appears
# after that (a new hire, someone back from leave) walks in through the door.
var _populated := false
var _state_sync_timer := 0.0
var _state_signature := ""

func _ready() -> void:
    # Retain textures for the canvas draw commands between frames.
    for tier in ["basic", "standard", "pro"]:
        workstation_textures[tier] = EquipmentSimulator.art_texture(tier)
    clip_contents = true
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    resized.connect(queue_redraw)
    EventBus.employee_hired.connect(func(_employee): rebuild())
    EventBus.employee_departed.connect(func(_employee): rebuild())
    EventBus.employee_laid_off.connect(func(_employee): rebuild())
    EventBus.employee_workstation_equipped.connect(func(_employee, _tier_id): queue_redraw())
    EventBus.training_started.connect(func(_employee, _course_id): rebuild())
    EventBus.training_completed.connect(func(_employee, _skill, _gain): rebuild())
    EventBus.research_started.connect(func(_id, _name): rebuild())
    EventBus.research_completed.connect(func(_id, _name): rebuild())
    EventBus.office_moved.connect(func(office): set_office(str(office.get("id", "bedroom"))))
    EventBus.week_ticked.connect(_on_week_ticked)
    EventBus.game_started.connect(_on_game_started)
    EventBus.preproduction_completed.connect(_on_preproduction_completed)
    EventBus.project_schedule_slipped.connect(_on_project_schedule_slipped)
    EventBus.game_released.connect(_on_game_released)
    EventBus.employee_burnt_out.connect(func(employee): _react_employee(employee, "stress", 3.4))
    EventBus.employee_skill_level_up.connect(
        func(employee, _skill, _level): _react_employee(employee, "star", 2.8))
    OfficeCustomizationManager.customization_changed.connect(func(_id): queue_redraw())
    SaveManager.game_loaded.connect(_on_game_loaded)
    set_office(GameState.office_id)

func _on_game_loaded() -> void:
    _populated = false
    actors.clear()
    work_bubbles.clear()
    set_office(GameState.office_id)
    rebuild()

func set_office(value: String) -> void:
    var resolved := value if OfficeLayout.LAYOUTS.has(value) else "bedroom"
    if resolved == office_id and office_texture != null and not actors.is_empty():
        return
    var moved := resolved != office_id
    office_id = resolved
    floor_plan = OfficeLayout.get_layout(office_id)
    office_texture = OfficeArtwork.texture(office_id)
    foreground_texture = null # The old full-room mask hid walking employees.
    atmosphere_texture = OfficeArtwork.atmosphere_texture(office_id)
    if moved and _populated:
        actors.clear()
    rebuild()

func rebuild() -> void:
    var first_population := not _populated
    var previous: Dictionary = {}
    for existing in actors:
        previous[(existing["employee"] as Employee).id] = existing
    actors.clear()
    var layout := OfficeLayout.get_layout(office_id)
    var desks: Array = layout.get("desks", [])
    var employees := EmployeeManager.active_employees()
    for index in mini(employees.size(), desks.size()):
        var employee: Employee = employees[index]
        var visual_state := activity_state_for(employee)
        if visual_state == "on_leave":
            continue
        if previous.has(employee.id):
            var existing: Dictionary = previous[employee.id]
            if existing["desk"] == desks[index]:
                existing["employee"] = employee
                existing["activity"] = visual_state
                existing["desk_index"] = index
                actors.append(existing)
                continue
        var rng := RandomNumberGenerator.new()
        rng.seed = employee.portrait_seed if employee.portrait_seed != 0 else absi(hash(employee.id))
        var actor := {
            "employee": employee,
            "desk": desks[index],
            "desk_index": index,
            "activity": visual_state,
            "position": desks[index] if first_population else layout["entrance"],
            "route": [],
            "state": "walking",
            "arrival_state": "seated",
            "timer": 0.0,
            "facing": -1.0,
            "body": BODY_COLORS[rng.randi_range(0, BODY_COLORS.size() - 1)],
            "skin": SKIN_COLORS[rng.randi_range(0, SKIN_COLORS.size() - 1)],
            "hair": HAIR_COLORS[rng.randi_range(0, HAIR_COLORS.size() - 1)],
            "sheet": OfficeCharacterArt.sheet_for_employee(employee),
            "social_frame": 1,
            "output_timer": rng.randf_range(0.35, 1.6),
            "output_sequence": 0,
            "interaction": "",
            "interaction_partner": "",
            "reaction": "",
            "reaction_timer": 0.0,
            "rng": rng
        }
        actors.append(actor)
        if first_population:
            _arrive(actor)
        else:
            _route_actor(actor, desks[index], "seated")
    _populated = _populated or not actors.is_empty()
    _state_signature = state_signature()
    queue_redraw()

func _on_week_ticked(_year: int, _month: int, _week: int) -> void:
    _sync_availability()
    # The weekly burst coincides with real simulation output. Ambient bubbles
    # between ticks keep slow speed settings readable without inventing a
    # different kind of work.
    for actor in actors:
        if actor["state"] == "seated" and _employee_is_working(actor["employee"]):
            _spawn_work_bubble(actor, true)
        _show_condition_reaction(actor)

func _on_game_started(project: GameProject) -> void:
    _react_team(project.team_id, "idea", 2.5)

func _on_preproduction_completed(project: GameProject, _modifier: float,
        _flaw_label: String) -> void:
    _react_team(project.team_id, "idea", 2.8)

func _on_project_schedule_slipped(project: GameProject, _weeks: int, _causes: Array) -> void:
    _react_team(project.team_id, "worry", 3.2)

func _on_game_released(project: GameProject) -> void:
    _celebrate(project.team_id)

func _react_team(team_id: String, reaction: String, duration: float) -> void:
    for actor in actors:
        var employee := actor["employee"] as Employee
        if employee != null and employee.assigned_team == team_id:
            _set_reaction(actor, reaction, duration)

func _react_employee(employee: Employee, reaction: String, duration: float) -> void:
    if employee == null:
        return
    for actor in actors:
        if (actor["employee"] as Employee).id == employee.id:
            _set_reaction(actor, reaction, duration)
            return

func _set_reaction(actor: Dictionary, reaction: String, duration: float) -> void:
    actor["reaction"] = reaction
    actor["reaction_timer"] = duration
    queue_redraw()

static func condition_reaction(employee: Employee) -> String:
    if employee == null:
        return ""
    if employee.stress >= 75 or employee.burnout >= 70:
        return "stress"
    if employee.morale <= 35:
        return "worry"
    if employee.morale >= 82 and employee.stress <= 45:
        return "happy"
    return ""

func _show_condition_reaction(actor: Dictionary) -> void:
    var reaction := condition_reaction(actor["employee"])
    if reaction.is_empty():
        return
    var rng: RandomNumberGenerator = actor["rng"]
    # Conditions are persistent, but the visual remains an occasional human
    # reaction instead of a permanent warning badge over somebody's head.
    if rng.randf() <= 0.48:
        _set_reaction(actor, reaction, rng.randf_range(1.8, 2.8))

func _sync_availability() -> void:
    var visible_ids: Array[String] = []
    for actor in actors:
        visible_ids.append((actor["employee"] as Employee).id)
    var expected_ids: Array[String] = []
    var employees := EmployeeManager.active_employees()
    for index in mini(employees.size(), OfficeLayout.desk_count(office_id)):
        if activity_state_for(employees[index]) != "on_leave":
            expected_ids.append(employees[index].id)
    if visible_ids != expected_ids:
        rebuild()
func _process(delta: float) -> void:
    if GameClock.paused:
        return
    elapsed += delta
    _state_sync_timer -= delta
    if _state_sync_timer <= 0.0:
        _state_sync_timer = 0.5
        var current_signature := state_signature()
        if current_signature != _state_signature:
            rebuild()
    for actor in actors:
        _advance_reaction(actor, delta)
        _advance_actor(actor, delta)
        _advance_actor_output(actor, delta)
    _advance_work_bubbles(delta)
    queue_redraw()

func _advance_reaction(actor: Dictionary, delta: float) -> void:
    if str(actor.get("reaction", "")).is_empty():
        return
    actor["reaction_timer"] = float(actor.get("reaction_timer", 0.0)) - delta
    if float(actor["reaction_timer"]) <= 0.0:
        actor["reaction"] = ""
        actor["reaction_timer"] = 0.0

func _advance_actor_output(actor: Dictionary, delta: float) -> void:
    if actor["state"] != "seated" or not _employee_is_visibly_active(actor["employee"]):
        return
    actor["output_timer"] = float(actor.get("output_timer", 0.0)) - delta
    if float(actor["output_timer"]) > 0.0:
        return
    _spawn_work_bubble(actor)
    var rng: RandomNumberGenerator = actor["rng"]
    actor["output_timer"] = rng.randf_range(1.45, 2.75)

func _advance_work_bubbles(delta: float) -> void:
    for index in range(work_bubbles.size() - 1, -1, -1):
        var bubble := work_bubbles[index]
        bubble["age"] = float(bubble.get("age", 0.0)) + delta
        if float(bubble["age"]) >= float(bubble.get("duration", 2.2)):
            work_bubbles.remove_at(index)

func _spawn_work_bubble(actor: Dictionary, weekly_burst: bool = false) -> void:
    var context := _work_context(actor["employee"], int(actor.get("output_sequence", 0)))
    if context.is_empty():
        return
    actor["output_sequence"] = int(actor.get("output_sequence", 0)) + 1
    var rng: RandomNumberGenerator = actor["rng"]
    var actor_index := actors.find(actor)
    var lane := (-34.0 if actor_index % 2 == 0 else 34.0) if actors.size() > 1 else 0.0
    work_bubbles.append({
        "origin": actor["position"],
        "kind": str(context.get("kind", "plan")),
        "age": 0.0,
        "duration": 2.6 if weekly_burst else 2.15,
        "drift": rng.randf_range(-10.0, 10.0),
        "lane": lane,
        "scale": 1.12 if weekly_burst else 1.0
    })
    while work_bubbles.size() > MAX_WORK_BUBBLES:
        work_bubbles.pop_front()

func _work_context(employee: Employee, sequence: int = 0) -> Dictionary:
    if employee == null:
        return {}
    if ResearchManager.is_researching(employee.id):
        return {"kind": "research"}
    if employee.is_training():
        return {"kind": "training"}
    for project in GameState.active_projects:
        var roles: Array[String] = []
        for role_id in project.role_assignments:
            if str(project.role_assignments[role_id]) == employee.id:
                roles.append(str(role_id))
        if roles.is_empty():
            continue
        roles.sort()
        var role_id := roles[posmod(sequence, roles.size())]
        return {
            "project": project,
            "role": role_id,
            "kind": output_kind(project.current_phase(), role_id)
        }
    return {}

static func output_kind(phase: String, role_id: String) -> String:
    # Planning and finishing visibly change the nature of the same person's
    # work; production uses their assigned discipline directly.
    if phase == "pre_production":
        return {
            "lead_programmer": "code", "game_designer": "design",
            "artist": "art", "writer": "story", "audio_designer": "audio",
            "qa_tester": "plan", "producer": "plan"
        }.get(role_id, "plan")
    if phase == "polish":
        return {
            "lead_programmer": "code", "game_designer": "polish",
            "artist": "polish", "writer": "story", "audio_designer": "audio",
            "qa_tester": "qa", "producer": "polish"
        }.get(role_id, "polish")
    return {
        "lead_programmer": "code", "game_designer": "design",
        "artist": "art", "writer": "story", "audio_designer": "audio",
        "qa_tester": "qa", "producer": "plan"
    }.get(role_id, "plan")

func _advance_actor(actor: Dictionary, delta: float) -> void:
    if actor["state"] == "walking":
        var route: Array = actor["route"]
        if route.is_empty():
            _arrive(actor)
            return
        var position: Vector2 = actor["position"]
        var target: Vector2 = route[0]
        var difference := target - position
        if difference.length() <= ARRIVAL_DISTANCE:
            actor["position"] = target
            route.pop_front()
            if route.is_empty():
                _arrive(actor)
            return
        actor["facing"] = signf(difference.x) if absf(difference.x) > 0.002 else actor["facing"]
        actor["position"] = position.move_toward(target, WALK_SPEED * delta)
        return

    actor["timer"] = float(actor["timer"]) - delta
    if float(actor["timer"]) > 0.0:
        return

    var rng: RandomNumberGenerator = actor["rng"]
    if actor["state"] == "seated":
        _show_condition_reaction(actor)
        if _employee_is_working(actor["employee"]) and rng.randf() <= 0.28:
            if _try_start_collaboration(actor):
                return
        # Busy staff still stretch their legs occasionally; idle staff roam more.
        var break_chance := 0.24 if _employee_is_working(actor["employee"]) else 0.62
        if rng.randf() <= break_chance:
            if _try_join_conversation(actor):
                return
            var social: Array = OfficeLayout.get_layout(office_id).get("social", [])
            actor["interaction"] = "coffee" if rng.randf() <= 0.58 else "break"
            _route_actor(actor, social[rng.randi_range(0, social.size() - 1)], "social")
        else:
            actor["timer"] = rng.randf_range(5.0, 10.0)
    else:
        _end_interaction(actor)
        _route_actor(actor, actor["desk"], "seated")

func _try_start_collaboration(actor: Dictionary) -> bool:
    var employee := actor["employee"] as Employee
    var candidates: Array[Dictionary] = []
    for coworker in actors:
        if coworker == actor or coworker["state"] != "seated":
            continue
        if not str(coworker.get("interaction_partner", "")).is_empty():
            continue
        if _share_active_project(employee, coworker["employee"]):
            candidates.append(coworker)
    if candidates.is_empty():
        return false
    var rng: RandomNumberGenerator = actor["rng"]
    var partner := candidates[rng.randi_range(0, candidates.size() - 1)]
    var partner_employee := partner["employee"] as Employee
    actor["interaction"] = "collaborate"
    actor["interaction_partner"] = partner_employee.id
    partner["interaction_partner"] = employee.id
    var partner_desk := partner["desk"] as Vector2
    var side := -1.0 if partner_desk.x > 0.52 else 1.0
    var destination := partner_desk + Vector2(0.052 * side, 0.018)
    destination.x = clampf(destination.x, 0.08, 0.92)
    destination.y = clampf(destination.y, 0.12, 0.88)
    _route_actor(actor, destination, "collaborating")
    return true

func _try_join_conversation(actor: Dictionary) -> bool:
    var employee := actor["employee"] as Employee
    for coworker in actors:
        if coworker == actor or coworker["state"] not in ["social", "chatting"]:
            continue
        if not str(coworker.get("interaction_partner", "")).is_empty():
            continue
        var coworker_employee := coworker["employee"] as Employee
        actor["interaction"] = "chat"
        actor["interaction_partner"] = coworker_employee.id
        coworker["interaction"] = "chat"
        coworker["interaction_partner"] = employee.id
        coworker["state"] = "chatting"
        coworker["timer"] = maxf(float(coworker["timer"]), 3.2)
        _set_reaction(coworker, "chat", 2.4)
        var destination := (coworker["position"] as Vector2) + Vector2(0.046, 0.008)
        destination.x = clampf(destination.x, 0.08, 0.92)
        _route_actor(actor, destination, "chatting")
        return true
    return false

func _share_active_project(first: Employee, second: Employee) -> bool:
    if first == null or second == null:
        return false
    for project in GameState.active_projects:
        var assigned := project.role_assignments.values()
        if first.id in assigned and second.id in assigned:
            return true
    return false

func _end_interaction(actor: Dictionary) -> void:
    var partner_id := str(actor.get("interaction_partner", ""))
    actor["interaction"] = ""
    actor["interaction_partner"] = ""
    if partner_id.is_empty():
        return
    for coworker in actors:
        if (coworker["employee"] as Employee).id != partner_id:
            continue
        if str(coworker.get("interaction_partner", "")) == (
                actor["employee"] as Employee).id:
            coworker["interaction_partner"] = ""
            coworker["interaction"] = ""
            if coworker["state"] == "chatting":
                coworker["state"] = "social"
        return

func _route_actor(actor: Dictionary, destination: Vector2, arrival_state: String) -> void:
    actor["route"] = OfficeLayout.route(actor["position"], destination, floor_plan)
    actor["state"] = "walking"
    actor["arrival_state"] = arrival_state
func _arrive(actor: Dictionary) -> void:
    var rng: RandomNumberGenerator = actor["rng"]
    actor["state"] = actor["arrival_state"]
    if actor["state"] == "seated":
        actor["interaction"] = ""
        actor["interaction_partner"] = ""
        actor["timer"] = rng.randf_range(6.0, 13.0)
    elif actor["state"] == "collaborating":
        actor["timer"] = rng.randf_range(2.8, 4.4)
        _set_reaction(actor, "idea", 2.2)
        _spawn_work_bubble(actor, true)
        var partner := _actor_for_employee(str(actor.get("interaction_partner", "")))
        if not partner.is_empty():
            _set_reaction(partner, "happy", 2.2)
            # Let the coworker's next normal output answer the visitor instead
            # of stacking two full-size bubbles on the same desk at once.
            partner["output_timer"] = minf(float(partner.get("output_timer", 0.5)), 0.5)
    elif actor["state"] == "chatting":
        actor["social_frame"] = rng.randi_range(1, 2)
        actor["timer"] = rng.randf_range(3.0, 4.8)
        _set_reaction(actor, "chat", 2.4)
    else:
        actor["social_frame"] = rng.randi_range(1, 2)
        actor["timer"] = rng.randf_range(2.5, 5.0)

func _actor_for_employee(employee_id: String) -> Dictionary:
    for actor in actors:
        if (actor["employee"] as Employee).id == employee_id:
            return actor
    return {}

func _celebrate(team_id: String = "") -> void:
    for actor in actors:
        var employee := actor["employee"] as Employee
        if not team_id.is_empty() and employee.assigned_team != team_id:
            continue
        _end_interaction(actor)
        actor["route"] = []
        actor["state"] = "celebrating"
        actor["timer"] = 2.8
        _set_reaction(actor, "cheer", 2.8)

func _employee_is_working(employee: Employee) -> bool:
    if ResearchManager.is_researching(employee.id) or EngineManager.is_building(employee.id):
        return true
    if TeamManager.workload_percent(employee.id) > 0:
        return true
    var team := TeamManager.find_team(employee.assigned_team)
    if team != null and not team.project_id.is_empty():
        return true
    var contract := ContractManager.active_contract()
    return contract != null and contract.team_id == employee.assigned_team

func _employee_is_visibly_active(employee: Employee) -> bool:
    return employee != null and (employee.is_training() or _employee_is_working(employee))

func activity_state_for(employee: Employee) -> String:
    if employee == null:
        return "idle"
    if employee.time_off_weeks > 0 or employee.burnout_leave_weeks > 0:
        return "on_leave"
    if employee.is_training():
        return "training"
    if ResearchManager.is_researching(employee.id):
        return "researching"
    if _employee_is_working(employee):
        if MoraleManager.is_crunching(employee.assigned_team):
            return "crunching"
        return "working"
    return "idle"

func state_signature() -> String:
    ## A cheap snapshot lets direct UI actions (assignment/crunch/leave) become
    ## visible promptly even when no dedicated presentation signal exists.
    var parts: Array[String] = [GameState.office_id]
    for employee in EmployeeManager.active_employees():
        parts.append("%s:%s:%s:%s" % [employee.id, activity_state_for(employee),
            employee.workstation_tier, employee.assigned_team])
    return "|".join(parts)

func _draw() -> void:
    if floor_plan.is_empty() or size.x <= 0.0 or size.y <= 0.0:
        return
    var art_rect := _art_rect()
    ROOM_RENDERER.floor_and_walls(self, art_rect, floor_plan)
    # Lighting and customization sit under every depth-sorted object. A room-
    # sized texture drawn after this point can make a walking person disappear.
    if atmosphere_texture != null:
        draw_texture_rect(atmosphere_texture, art_rect, false)
    var current_era := EraVisuals.texture_for_year(TimeManager.current_year)
    if current_era != null:
        draw_texture_rect(current_era, art_rect, false)
    var drawables: Array[Dictionary] = []
    for prop in floor_plan["props"]:
        drawables.append({"kind": "furniture", "item": prop, "depth": OfficeLayout.project(Vector2(prop["cell"]) + Vector2(0.5, 0.5), floor_plan["dimensions"]).y})
    for feature in floor_plan.get("features", []):
        ROOM_RENDERER.office_feature(self, art_rect, feature)
    var desk_cells: Array = floor_plan["desk_cells"]
    var employees := EmployeeManager.active_employees()
    for index in desk_cells.size():
        var cell: Vector2i = desk_cells[index]
        var texture: Texture2D = null
        if index < employees.size():
            texture = workstation_textures.get(employees[index].workstation_tier) as Texture2D
        drawables.append({"kind": "furniture", "item": {"kind": "desk", "cell": cell}, "texture": texture,
            "depth": OfficeLayout.project(Vector2(cell) + Vector2(0.5, 0.5), floor_plan["dimensions"]).y})
    for actor in actors:
        drawables.append({"kind": "person", "actor": actor, "depth": (actor["position"] as Vector2).y})
    drawables.sort_custom(func(a, b): return float(a["depth"]) < float(b["depth"]))
    for item in drawables:
        if item["kind"] == "person":
            _draw_actor_shadow(item["actor"], art_rect)
            _draw_actor(item["actor"], art_rect)
        else:
            ROOM_RENDERER.furniture(self, art_rect, floor_plan, item["item"], item.get("texture"))
    _draw_work_bubbles(art_rect)
    _draw_reactions(art_rect)
    _draw_activity_badges(art_rect)

func _draw_activity_badges(art_rect: Rect2) -> void:
    var room_scale := maxf(art_rect.size.y / 512.0, 0.28)
    for actor in actors:
        var activity := str(actor.get("activity", "idle"))
        var color: Color = ACTIVITY_COLORS.get(activity, Color("#84929a"))
        var feet := art_rect.position + (actor["position"] as Vector2) * art_rect.size
        var center := feet + Vector2(0, -68.0) * room_scale
        var radius := 6.0 * room_scale
        if activity == "crunching":
            radius *= 1.0 + sin(elapsed * 6.0) * 0.16
        draw_circle(center, radius + maxf(room_scale, 1.0), Color(0.08, 0.09, 0.10, 0.55))
        draw_circle(center, radius, color)
func _draw_reactions(art_rect: Rect2) -> void:
    var room_scale := maxf(art_rect.size.y / 512.0, 0.28)
    for actor_index in actors.size():
        var actor := actors[actor_index]
        var reaction := str(actor.get("reaction", ""))
        if reaction.is_empty():
            continue
        var remaining := float(actor.get("reaction_timer", 0.0))
        var alpha := minf(remaining / 0.32, 1.0)
        var feet := art_rect.position + (actor["position"] as Vector2) * art_rect.size
        var radius := 23.0 * room_scale
        var pulse := 1.0 + sin(elapsed * 7.0) * 0.045
        var side := -1.0 if actor_index % 2 == 0 else 1.0
        var center := feet + Vector2(46.0 * side, -82.0) * room_scale
        var color: Color = REACTION_COLORS.get(reaction, Color("#70899b"))
        color.a = alpha
        draw_circle(center + Vector2(1.5, 2.2) * room_scale, radius * pulse,
            Color(0.05, 0.07, 0.08, 0.20 * alpha))
        draw_circle(center, radius * pulse, Color(1.0, 0.98, 0.91, 0.96 * alpha))
        draw_arc(center, radius * pulse, 0.0, TAU, 22, color,
            maxf(2.8 * room_scale, 1.1), true)
        _draw_reaction_icon(reaction, center, radius * 0.62, color)

func _draw_reaction_icon(reaction: String, center: Vector2, extent: float,
        color: Color) -> void:
    var width := maxf(extent * 0.21, 1.15)
    match reaction:
        "happy":
            draw_circle(center + Vector2(-extent * 0.30, -extent * 0.20),
                extent * 0.10, color)
            draw_circle(center + Vector2(extent * 0.30, -extent * 0.20),
                extent * 0.10, color)
            draw_arc(center + Vector2(0, -extent * 0.06), extent * 0.47,
                0.20, PI - 0.20, 12, color, width, true)
        "idea":
            draw_circle(center + Vector2(0, -extent * 0.12), extent * 0.43,
                color, false, width, true)
            draw_line(center + Vector2(-extent * 0.20, extent * 0.40),
                center + Vector2(extent * 0.20, extent * 0.40), color, width, true)
            draw_line(center + Vector2(-extent * 0.14, extent * 0.62),
                center + Vector2(extent * 0.14, extent * 0.62), color, width, true)
        "chat":
            for x in [-0.42, 0.0, 0.42]:
                draw_circle(center + Vector2(extent * x, 0), extent * 0.13, color)
        "stress":
            draw_line(center + Vector2(0, -extent * 0.62),
                center + Vector2(0, extent * 0.18), color, width * 1.25, true)
            draw_circle(center + Vector2(0, extent * 0.55), extent * 0.13, color)
        "worry":
            draw_polyline(PackedVector2Array([
                center + Vector2(-extent * 0.55, -extent * 0.32),
                center + Vector2(-extent * 0.16, -extent * 0.62),
                center + Vector2(extent * 0.04, -extent * 0.12),
                center + Vector2(extent * 0.50, -extent * 0.40)]), color, width, true)
            draw_line(center + Vector2(-extent * 0.42, extent * 0.45),
                center + Vector2(extent * 0.42, extent * 0.45), color, width, true)
        "star":
            var points := PackedVector2Array()
            for index in 11:
                var radius := extent * (0.68 if index % 2 == 0 else 0.30)
                var angle := -PI * 0.5 + float(index) * PI / 5.0
                points.append(center + Vector2.from_angle(angle) * radius)
            draw_colored_polygon(points, color)
        _:
            draw_circle(center + Vector2(-extent * 0.24, -extent * 0.05),
                extent * 0.28, color)
            draw_circle(center + Vector2(extent * 0.24, -extent * 0.05),
                extent * 0.28, color)
            draw_colored_polygon(PackedVector2Array([
                center + Vector2(-extent * 0.48, 0),
                center + Vector2(extent * 0.48, 0),
                center + Vector2(0, extent * 0.68)]), color)

func _draw_work_bubbles(art_rect: Rect2) -> void:
    var room_scale := maxf(art_rect.size.y / 512.0, 0.28)
    for bubble in work_bubbles:
        var duration := float(bubble.get("duration", 2.2))
        var t := clampf(float(bubble.get("age", 0.0)) / duration, 0.0, 1.0)
        var alpha := minf(t / 0.10, 1.0) * minf((1.0 - t) / 0.24, 1.0)
        var origin := art_rect.position + (bubble["origin"] as Vector2) * art_rect.size
        # The room is reduced to roughly 170 px tall on phone screens. This
        # deliberately stays large enough for its icon to read at that scale.
        var radius := 29.0 * room_scale * float(bubble.get("scale", 1.0))
        var center := origin + Vector2(
            (float(bubble.get("lane", 0.0))
                + float(bubble.get("drift", 0.0)) * sin(t * PI)) * room_scale,
            (-66.0 - t * 58.0) * room_scale)
        draw_circle(center + Vector2(1.5, 2.5) * room_scale, radius + 2.0 * room_scale,
            Color(0.05, 0.07, 0.08, 0.22 * alpha))
        var color: Color = WORK_OUTPUT_COLORS.get(str(bubble["kind"]), Color("#70899b"))
        color.a = alpha
        draw_circle(center, radius, color)
        draw_arc(center, radius, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.88 * alpha),
            maxf(1.25 * room_scale, 1.0), true)
        _draw_output_icon(str(bubble["kind"]), center, radius * 0.62,
            Color(1.0, 1.0, 1.0, alpha))
        # Two tiny trailing dots make the output read as a thought/work bubble
        # rather than a notification badge.
        draw_circle(center + Vector2(-radius * 0.55, radius * 1.38), radius * 0.24,
            Color(color.r, color.g, color.b, alpha * 0.72))
        draw_circle(center + Vector2(-radius * 0.82, radius * 1.92), radius * 0.13,
            Color(color.r, color.g, color.b, alpha * 0.48))

func _draw_output_icon(kind: String, center: Vector2, extent: float, color: Color) -> void:
    var width := maxf(extent * 0.20, 1.25)
    match kind:
        "code":
            draw_polyline(PackedVector2Array([
                center + Vector2(-extent * 0.20, -extent * 0.46),
                center + Vector2(-extent * 0.62, 0.0),
                center + Vector2(-extent * 0.20, extent * 0.46)]), color, width, true)
            draw_polyline(PackedVector2Array([
                center + Vector2(extent * 0.20, -extent * 0.46),
                center + Vector2(extent * 0.62, 0.0),
                center + Vector2(extent * 0.20, extent * 0.46)]), color, width, true)
        "design":
            var diamond := PackedVector2Array([
                center + Vector2(0, -extent * 0.65), center + Vector2(extent * 0.62, 0),
                center + Vector2(0, extent * 0.65), center + Vector2(-extent * 0.62, 0),
                center + Vector2(0, -extent * 0.65)])
            draw_polyline(diamond, color, width, true)
            draw_circle(center, extent * 0.14, color)
        "art":
            draw_circle(center + Vector2(-extent * 0.30, extent * 0.18), extent * 0.24, color)
            draw_circle(center + Vector2(0, -extent * 0.28), extent * 0.24, color)
            draw_circle(center + Vector2(extent * 0.32, extent * 0.20), extent * 0.24, color)
        "story":
            for offset in [-0.42, 0.0, 0.42]:
                draw_line(center + Vector2(-extent * 0.58, extent * offset),
                    center + Vector2(extent * (0.30 if offset == 0.42 else 0.58), extent * offset),
                    color, width, true)
        "audio":
            draw_polyline(PackedVector2Array([
                center + Vector2(-extent * 0.65, 0), center + Vector2(-extent * 0.38, 0),
                center + Vector2(-extent * 0.16, -extent * 0.48),
                center + Vector2(extent * 0.12, extent * 0.48),
                center + Vector2(extent * 0.34, -extent * 0.30),
                center + Vector2(extent * 0.60, 0)]), color, width, true)
        "qa":
            draw_polyline(PackedVector2Array([
                center + Vector2(-extent * 0.58, 0),
                center + Vector2(-extent * 0.12, extent * 0.46),
                center + Vector2(extent * 0.62, -extent * 0.48)]), color, width, true)
        "polish":
            for angle in 8:
                var direction := Vector2.from_angle(float(angle) * TAU / 8.0)
                draw_line(center + direction * extent * 0.18,
                    center + direction * extent * (0.72 if angle % 2 == 0 else 0.48),
                    color, width, true)
            draw_circle(center, extent * 0.18, color)
        _:
            draw_rect(Rect2(center - Vector2(extent * 0.48, extent * 0.58),
                Vector2(extent * 0.96, extent * 1.16)), color, false, width)
            draw_line(center + Vector2(-extent * 0.28, -extent * 0.20),
                center + Vector2(extent * 0.28, -extent * 0.20), color, width, true)
            draw_line(center + Vector2(-extent * 0.28, extent * 0.20),
                center + Vector2(extent * 0.18, extent * 0.20), color, width, true)
func _draw_customization_accent(art_rect: Rect2) -> void:
    var overlay := OfficeCustomizationManager.overlay_texture()
    if overlay == null:
        return
    draw_texture_rect(overlay, art_rect, false)

func _draw_mixed_remodel(art_rect: Rect2) -> void:
    OfficeCustomizationManager.validate_remodel()
    var has_remodel := false
    for category in OfficeCustomizationManager.CATEGORIES:
        if OfficeCustomizationManager.style_id_for(str(category["id"])) != "classic":
            has_remodel = true
            break
    if not has_remodel:
        return
    if _draw_authored_mixed_remodel(art_rect):
        return
    var layout := OfficeLayout.get_layout(office_id)
    var floor_color := OfficeCustomizationManager.component_color("flooring")
    floor_color.a = 0.78
    var center := art_rect.position + art_rect.size * Vector2(0.51, 0.77)
    var rug_size := art_rect.size * Vector2(0.22, 0.105)
    var rug := PackedVector2Array([
        center + Vector2(-rug_size.x, 0), center + Vector2(0, -rug_size.y),
        center + Vector2(rug_size.x, 0), center + Vector2(0, rug_size.y)
    ])
    draw_colored_polygon(rug, floor_color)
    draw_polyline(PackedVector2Array([rug[0], rug[1], rug[2], rug[3], rug[0]]),
        floor_color.darkened(0.35), 2.0)

    var desk_color := OfficeCustomizationManager.component_color("desks")
    var seat_color := OfficeCustomizationManager.component_color("seating")
    var computer_color := OfficeCustomizationManager.component_color("computers")
    for point in layout.get("desks", []):
        var anchor := art_rect.position + (point as Vector2) * art_rect.size
        draw_set_transform(anchor + Vector2(0, -8), -0.18, Vector2(1.0, 0.45))
        draw_rect(Rect2(-18, -7, 36, 14), desk_color, true)
        draw_rect(Rect2(-18, -7, 36, 14), desk_color.darkened(0.35), false, 2)
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
        draw_circle(anchor + Vector2(0, 7), 8, seat_color)
        draw_arc(anchor + Vector2(0, 7), 8, 0, TAU, 20, seat_color.darkened(0.4), 2)
        draw_rect(Rect2(anchor + Vector2(-7, -20), Vector2(14, 10)),
            computer_color.darkened(0.25), true)
        draw_rect(Rect2(anchor + Vector2(-5, -18), Vector2(10, 6)),
            computer_color.lightened(0.35), true)

    var light_color := OfficeCustomizationManager.component_color("lighting")
    light_color.a = 0.13
    draw_circle(art_rect.position + art_rect.size * Vector2(0.25, 0.20),
        art_rect.size.y * 0.18, light_color)
    draw_circle(art_rect.position + art_rect.size * Vector2(0.75, 0.20),
        art_rect.size.y * 0.18, light_color)

    var storage_color := OfficeCustomizationManager.component_color("storage")
    var cabinet := Rect2(art_rect.position + art_rect.size * Vector2(0.84, 0.38),
        art_rect.size * Vector2(0.07, 0.26))
    draw_rect(cabinet, storage_color, true)
    draw_rect(cabinet, storage_color.darkened(0.45), false, 3)
    for shelf in [0.33, 0.66]:
        draw_line(Vector2(cabinet.position.x, cabinet.position.y + cabinet.size.y * shelf),
            Vector2(cabinet.end.x, cabinet.position.y + cabinet.size.y * shelf),
            storage_color.darkened(0.4), 2)

    var lounge_color := OfficeCustomizationManager.component_color("lounge")
    var sofa := Rect2(art_rect.position + art_rect.size * Vector2(0.62, 0.70),
        art_rect.size * Vector2(0.16, 0.065))
    draw_rect(sofa, lounge_color, true)
    draw_rect(sofa, lounge_color.darkened(0.4), false, 3)
    draw_line(sofa.position + Vector2(sofa.size.x * 0.5, 0),
        sofa.position + Vector2(sofa.size.x * 0.5, sofa.size.y),
        lounge_color.darkened(0.25), 2)

    var plant_color := OfficeCustomizationManager.component_color("plants")
    var plant_base := art_rect.position + art_rect.size * Vector2(0.11, 0.74)
    draw_rect(Rect2(plant_base + Vector2(-12, 0), Vector2(24, 25)),
        plant_color.darkened(0.2), true)
    for offset in [Vector2(-13, -18), Vector2(0, -32), Vector2(14, -18)]:
        draw_circle(plant_base + offset, 11, plant_color)

    var decor_color := OfficeCustomizationManager.component_color("decor")
    for x in [0.38, 0.56]:
        var frame := Rect2(art_rect.position + art_rect.size * Vector2(x, 0.11),
            art_rect.size * Vector2(0.11, 0.12))
        draw_rect(frame, Color("#fff7df"), true)
        draw_rect(frame, decor_color.darkened(0.35), false, 3)
        draw_circle(frame.get_center(), 9, decor_color)

func _draw_authored_mixed_remodel(art_rect: Rect2) -> bool:
    var found := false
    var layout := OfficeLayout.get_layout(office_id)
    for category_id in ["walls", "flooring", "lighting", "storage", "lounge", "plants", "decor"]:
        var texture := OfficeCustomizationManager.component_texture(category_id)
        if texture == null:
            continue
        found = true
        var target := _component_rect(category_id, art_rect)
        draw_texture_rect(texture, target, false)
    for point in layout.get("desks", []):
        var anchor := art_rect.position + (point as Vector2) * art_rect.size
        # Workstation hardware is drawn separately per employee so a Basic,
        # Standard, and Pro purchase is visible instead of being hidden under
        # the room theme's generic computer prop.
        for category_id in ["desks", "seating"]:
            var texture := OfficeCustomizationManager.component_texture(category_id)
            if texture == null:
                continue
            found = true
            var extent := art_rect.size.y * (0.17 if category_id == "desks" else 0.12)
            var offset_y := -extent * 0.30
            draw_texture_rect(texture,
                Rect2(anchor + Vector2(-extent * 0.5, offset_y), Vector2(extent, extent)), false)
    return found

func _draw_workstation_upgrades(art_rect: Rect2) -> void:
    # Each visible employee owns the machine at their assigned desk.  Keeping
    # these on the furniture layer makes an upgrade immediately show up in the
    # office while actors can still sit naturally in front of it.
    for actor in actors:
        var employee := actor["employee"] as Employee
        if employee == null or employee.workstation_tier.is_empty():
            continue
        var texture := workstation_textures.get(employee.workstation_tier) as Texture2D
        if texture == null:
            continue
        var anchor := art_rect.position + (actor["desk"] as Vector2) * art_rect.size
        var extent := art_rect.size.y * 0.135
        if OfficeCustomizationManager.style_id_for("computers") != "classic":
            var accent := OfficeCustomizationManager.component_color("computers")
            accent.a = 0.44
            draw_set_transform(anchor + Vector2(0, -extent * 0.06), -0.16, Vector2(1.0, 0.42))
            draw_circle(Vector2.ZERO, extent * 0.35, accent)
            draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
        draw_texture_rect(texture, Rect2(
            anchor + Vector2(-extent * 0.5, -extent * 0.72),
            Vector2(extent, extent)), false)

func _component_rect(category_id: String, art_rect: Rect2) -> Rect2:
    var normalized: Rect2 = {
        "walls": Rect2(0.12, 0.03, 0.76, 0.54),
        "flooring": Rect2(0.29, 0.57, 0.43, 0.35),
        "lighting": Rect2(0.35, 0.02, 0.30, 0.36),
        "storage": Rect2(0.75, 0.31, 0.22, 0.47),
        "lounge": Rect2(0.55, 0.58, 0.33, 0.34),
        "plants": Rect2(0.02, 0.45, 0.27, 0.44),
        "decor": Rect2(0.35, 0.05, 0.30, 0.35)
    }.get(category_id, Rect2(0.25, 0.25, 0.5, 0.5))
    return Rect2(art_rect.position + normalized.position * art_rect.size,
        normalized.size * art_rect.size)

func _art_rect() -> Rect2:
    var texture_size := office_texture.get_size()
    var scale := minf(size.x / texture_size.x, size.y / texture_size.y)
    var drawn_size := texture_size * scale
    return Rect2((size - drawn_size) * 0.5, drawn_size)

func _draw_actor(actor: Dictionary, art_rect: Rect2) -> void:
    var normalized: Vector2 = actor["position"]
    var feet := art_rect.position + normalized * art_rect.size
    var dimensions: Vector2i = floor_plan["dimensions"]
    var scale := art_rect.size.y * 2.5 / float(dimensions.x + dimensions.y) / 92.0
    var sprite_size := 92.0 * scale
    var bob := 0.0
    if actor["state"] == "walking":
        bob = absf(sin(elapsed * 10.0)) * 2.3 * scale
    elif actor["state"] == "seated" and _employee_is_visibly_active(actor["employee"]):
        bob = sin(elapsed * 3.5) * 0.8 * scale
    feet.y -= bob

    var row := 3
    var column := 0
    match str(actor["state"]):
        "walking":
            row = 0 if float(actor["facing"]) < 0.0 else 1
            column = int(floor(elapsed * 8.0)) % 4
        "seated":
            row = 2
            column = int(floor(elapsed * 4.0)) % 4 if _employee_is_visibly_active(actor["employee"]) else 0
        "social":
            row = 3
            column = int(actor["social_frame"])
        "chatting":
            row = 3
            column = 1 + int(floor(elapsed * 2.0)) % 2
        "collaborating":
            row = 3
            column = 2
        "celebrating":
            row = 3
            column = 3

    var destination := Rect2(
        feet - Vector2(sprite_size * 0.5, sprite_size * 0.92),
        Vector2(sprite_size, sprite_size)
    )
    draw_texture_rect_region(
        actor["sheet"] as Texture2D,
        destination,
        OfficeCharacterArt.frame_region(column, row)
    )
    if str(actor.get("interaction", "")) == "coffee" and actor["state"] == "social":
        var cup := feet + Vector2(sprite_size * 0.28, -sprite_size * 0.50)
        draw_rect(Rect2(cup - Vector2(3.8, 3.4) * scale, Vector2(7.6, 7.0) * scale),
            Color("#f6ead1"), true)
        draw_arc(cup + Vector2(4.0, 0.0) * scale, 3.1 * scale,
            -PI * 0.5, PI * 0.5, 7, Color("#8a6045"), maxf(scale, 1.0), true)
        draw_line(cup + Vector2(-1.5, -5.0) * scale,
            cup + Vector2(0.5, -8.0) * scale, Color(1.0, 1.0, 1.0, 0.70),
            maxf(scale, 1.0), true)

func _draw_actor_shadow(actor: Dictionary, art_rect: Rect2) -> void:
    var normalized: Vector2 = actor["position"]
    var feet := art_rect.position + normalized * art_rect.size
    var dimensions: Vector2i = floor_plan["dimensions"]
    var scale := art_rect.size.y * 2.5 / float(dimensions.x + dimensions.y) / 92.0
    var radius := (11.0 if actor["state"] == "seated" else 14.0) * scale
    var alpha := 0.14 if actor["state"] == "walking" else 0.18
    draw_set_transform(feet + Vector2(0.0, -1.5 * scale), 0.0, Vector2(1.0, 0.34))
    draw_circle(Vector2.ZERO, radius, Color(0.10, 0.075, 0.055, alpha))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


