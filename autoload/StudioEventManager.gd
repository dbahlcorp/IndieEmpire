extends Node

## Small studio events -- an employee asking for something, a workstation
## dying -- raised one at a time from authored data. The player is given a
## choice; ignoring it long enough is itself an answer.
##
## New events are added to data/studio_events.json, not here.

## Roughly one event every four months of play.
const WEEKLY_EVENT_CHANCE := 0.06
## Weeks the player has to answer before the default choice is taken for them.
const ANSWER_WEEKS := 4
## However many efficiency penalties stack, a week's work is never worth less
## than half.
const MIN_DEV_EFFICIENCY := 0.5

# --- The weekly tick --------------------------------------------------------

func process_week() -> void:
    _age_effects()

    if not GameState.pending_studio_event.is_empty():
        _age_pending()
        return

    if GameState.bankrupt or not SaveManager.has_active_company:
        return
    if randf() >= WEEKLY_EVENT_CHANCE:
        return
    _raise_one()

func _age_effects() -> void:
    var still: Array = []
    for effect in GameState.studio_event_effects:
        effect["weeks_left"] = int(effect.get("weeks_left", 0)) - 1
        if int(effect["weeks_left"]) > 0:
            still.append(effect)
    GameState.studio_event_effects = still

func _age_pending() -> void:
    var pending: Dictionary = GameState.pending_studio_event
    pending["weeks_left"] = int(pending.get("weeks_left", ANSWER_WEEKS)) - 1
    if int(pending["weeks_left"]) <= 0:
        var event := pending_event()
        resolve(StudioEventSimulator.default_choice_index(event), true)

# --- Raising ---------------------------------------------------------------

func _raise_one() -> void:
    var candidates := _eligible_events()
    if candidates.is_empty():
        return

    var event := _weighted_pick(candidates)
    var employee: Employee = null
    if str(event.get("type", "")) == "employee":
        var subjects := eligible_subjects(event)
        if subjects.is_empty():
            return
        employee = subjects[randi() % subjects.size()]

    raise_event(str(event["id"]), employee)

func raise_event(event_id: String, employee: Employee = null) -> bool:
    ## Put an event in front of the player. Used by the weekly roll and by
    ## tests and debug tools; it does not re-check eligibility.
    var event := DataManager.get_studio_event(event_id)
    if event.is_empty() or has_pending():
        return false

    GameState.pending_studio_event = {
        "event_id": event_id,
        "employee_id": employee.id if employee != null else "",
        "weeks_left": ANSWER_WEEKS
    }
    GameClock.pause_for_decision("studio event")
    EventBus.studio_event_raised.emit(event_id)
    EventBus.notify(str(event.get("title", "STUDIO EVENT")),
        StudioEventSimulator.fill(str(event.get("body", "")), employee), true)
    return true

func _eligible_events() -> Array:
    var result: Array = []
    for event in DataManager.studio_events:
        if _on_cooldown(str(event.get("id", ""))):
            continue
        if str(event.get("type", "")) == "employee":
            if not eligible_subjects(event).is_empty():
                result.append(event)
        elif StudioEventSimulator.conditions_met(event.get("conditions", []), null):
            result.append(event)
    return result

func eligible_subjects(event: Dictionary) -> Array:
    ## Active, non-founder employees this event could be about.
    var roles: Array = event.get("roles", [])
    var conditions: Array = event.get("conditions", [])
    var result: Array = []
    for employee in EmployeeManager.active_employees():
        if employee.is_founder():
            continue
        if not roles.is_empty() and employee.role not in roles:
            continue
        if StudioEventSimulator.conditions_met(conditions, employee):
            result.append(employee)
    return result

func _on_cooldown(event_id: String) -> bool:
    if not GameState.studio_event_cooldowns.has(event_id):
        return false
    var event := DataManager.get_studio_event(event_id)
    var cooldown := int(event.get("cooldown_weeks", 0))
    var since := TimeManager.absolute_week() - int(GameState.studio_event_cooldowns[event_id])
    return since < cooldown

func _weighted_pick(events: Array) -> Dictionary:
    var total := 0
    for event in events:
        total += maxi(int(event.get("weight", 1)), 1)
    var roll := randi() % maxi(total, 1)
    var running := 0
    for event in events:
        running += maxi(int(event.get("weight", 1)), 1)
        if roll < running:
            return event
    return events[events.size() - 1]

# --- Answering -----------------------------------------------------------

func pending() -> Dictionary:
    return GameState.pending_studio_event

func has_pending() -> bool:
    return not GameState.pending_studio_event.is_empty()

func pending_event() -> Dictionary:
    return DataManager.get_studio_event(str(GameState.pending_studio_event.get("event_id", "")))

func pending_employee() -> Employee:
    var id := str(GameState.pending_studio_event.get("employee_id", ""))
    return EmployeeManager.find_employee(id) if not id.is_empty() else null

func can_afford_choice(choice_index: int) -> bool:
    var event := pending_event()
    var choices: Array = event.get("choices", [])
    if choice_index < 0 or choice_index >= choices.size():
        return false
    return FinanceManager.can_afford(StudioEventSimulator.choice_cost(choices[choice_index]))

func resolve(choice_index: int, forced: bool = false) -> Dictionary:
    ## Apply one choice. `forced` is the default choice taken when the player
    ## let the clock run out -- it never fails on affordability.
    if not has_pending():
        return {"ok": false, "reason": "nothing pending"}

    var event := pending_event()
    var employee := pending_employee()
    var choices: Array = event.get("choices", [])
    if choice_index < 0 or choice_index >= choices.size():
        return {"ok": false, "reason": "no such choice"}

    var choice: Dictionary = choices[choice_index]
    var cost := StudioEventSimulator.choice_cost(choice)
    if cost > 0:
        if forced:
            FinanceManager.force_spend(cost, Ledger.Kind.OTHER,
                "%s (%s)" % [event.get("title", "Studio event"), choice.get("label", "")])
        elif not FinanceManager.spend(cost, Ledger.Kind.OTHER,
                "%s (%s)" % [event.get("title", "Studio event"), choice.get("label", "")]):
            return {"ok": false, "reason": "unaffordable"}

    _apply_effects(choice.get("effects", []), employee)

    GameState.studio_event_cooldowns[str(event["id"])] = TimeManager.absolute_week()
    GameState.pending_studio_event = {}

    var outcome := StudioEventSimulator.fill(str(choice.get("outcome", "")), employee)
    EventBus.studio_event_resolved.emit(str(event["id"]), choice_index, outcome)
    SaveManager.autosave()
    return {"ok": true, "outcome": outcome}

func _apply_effects(effects: Array, employee: Employee) -> void:
    for effect in effects:
        if effect.get("chance") != null and randf() >= float(effect["chance"]):
            continue
        match str(effect.get("kind", "")):
            "skill_xp":
                if employee != null:
                    EmployeeManager.award_skill_experience(
                        employee, str(effect.get("skill", "")), int(effect.get("amount", 0)))
            "morale":
                _apply_morale(str(effect.get("target", "employee")),
                    int(effect.get("amount", 0)), employee)
            "team_chemistry":
                if employee != null:
                    var team := TeamManager.find_team(employee.assigned_team)
                    if team != null:
                        team.chemistry = clampf(
                            team.chemistry + float(effect.get("amount", 0.0)), 0.0, 100.0)
            "cash":
                var amount := int(effect.get("amount", 0))
                if amount > 0:
                    FinanceManager.earn(amount, Ledger.Kind.OTHER, "Studio event")
                elif amount < 0:
                    FinanceManager.force_spend(-amount, Ledger.Kind.OTHER, "Studio event")
            "reputation":
                GameState.add_consumer_reputation(float(effect.get("amount", 0.0)))
            "culture":
                CultureManager.shift(str(effect.get("id", "")),
                    float(effect.get("amount", 0.0)), "A studio event")
            "dev_efficiency":
                GameState.studio_event_effects.append({
                    "kind": "dev_efficiency",
                    "amount": float(effect.get("amount", 0.0)),
                    "weeks_left": maxi(int(effect.get("weeks", 1)), 1)
                })

func _apply_morale(target: String, amount: int, employee: Employee) -> void:
    if amount == 0:
        return
    if target == "employee":
        if employee != null:
            employee.morale = clampi(employee.morale + amount, 0, 100)
        return
    for other in EmployeeManager.active_employees():
        if target == "team" and employee != null and other.assigned_team != employee.assigned_team:
            continue
        other.morale = clampi(other.morale + amount, 0, 100)

# --- Consequences the rest of the sim reads --------------------------------

func development_efficiency_multiplier() -> float:
    var multiplier := 1.0
    for effect in GameState.studio_event_effects:
        if str(effect.get("kind", "")) == "dev_efficiency":
            multiplier *= 1.0 + float(effect.get("amount", 0.0))
    return maxf(multiplier, MIN_DEV_EFFICIENCY)

func active_effect_summary() -> String:
    ## One line for the studio screen while a penalty is running.
    for effect in GameState.studio_event_effects:
        if str(effect.get("kind", "")) == "dev_efficiency":
            return "Equipment trouble: development %+d%% for %d more week%s" % [
                int(round(float(effect.get("amount", 0.0)) * 100.0)),
                int(effect.get("weeks_left", 0)),
                "" if int(effect.get("weeks_left", 0)) == 1 else "s"]
    return ""
