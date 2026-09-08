extends Control

## Why everybody feels the way they do, and what can be done about it.

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var back_button: Button = $Margin/VBox/BackButton

func _ready() -> void:
    GameClock.enter_menu()
    back_button.pressed.connect(_on_back)
    _refresh()

func _refresh() -> void:
    UiBuilder.clear(list)

    var burning := MoraleManager.at_burnout_risk()
    if not burning.is_empty():
        list.add_child(UiBuilder.heading("BURNOUT RISK"))
        for employee in burning:
            var weeks := MoraleSimulator.weeks_until_burnout(employee)
            var when := "about %d week%s away" % [weeks, "" if weeks == 1 else "s"] if weeks > 0 else ""
            list.add_child(UiBuilder.label("%s  %s  %s" % [
                employee.display_name(),
                MoraleSimulator.burnout_risk_label(employee), when], 15))
        list.add_child(UiBuilder.label(
            "Give them time off, cut their workload, or stop crunching.", 13))
        list.add_child(UiBuilder.divider())

    var signed_off := MoraleManager.burnout_leave()
    if not signed_off.is_empty():
        list.add_child(UiBuilder.heading("SIGNED OFF"))
        for employee in signed_off:
            list.add_child(UiBuilder.label("%s - %d week%s away from development" % [
                employee.display_name(), employee.burnout_leave_weeks,
                "" if employee.burnout_leave_weeks == 1 else "s"], 15))
        list.add_child(UiBuilder.divider())

    var struggling := MoraleManager.at_risk()
    if not struggling.is_empty():
        list.add_child(UiBuilder.heading("NEEDS ATTENTION"))
        var names: Array[String] = []
        for employee in struggling:
            names.append(employee.display_name())
        list.add_child(UiBuilder.label(", ".join(names), 15))
        list.add_child(UiBuilder.divider())

    for employee in EmployeeManager.active_employees():
        _person(employee)

func _person(employee: Employee) -> void:
    list.add_child(UiBuilder.employee_header(employee, EmployeeManager.job_title(employee)))
    list.add_child(UiBuilder.status_row(
        "morale", "Morale  %s %3d%%  %s" % [
            UiBuilder.meter(employee.morale), employee.morale,
            MoraleSimulator.morale_label(employee.morale)], 14))
    list.add_child(UiBuilder.status_row(
        "stress", "Stress  %s %3d%%  %s" % [
            UiBuilder.meter(employee.stress), employee.stress,
            MoraleSimulator.stress_label(employee.stress)], 14))
    list.add_child(UiBuilder.status_row(
        "energy", "Energy  %s %3d%%" % [
            UiBuilder.meter(employee.energy), employee.energy], 14))

    var risk := MoraleSimulator.burnout_risk_label(employee)
    if risk != "NONE":
        var weeks := MoraleSimulator.weeks_until_burnout(employee)
        var detail := "BURNOUT RISK  %s" % risk
        if weeks > 0:
            detail += "   about %d week%s away" % [weeks, "" if weeks == 1 else "s"]
        list.add_child(UiBuilder.label(detail, 15))

    list.add_child(UiBuilder.label("Pay  %s" % MoraleSimulator.salary_label(employee), 13))

    if employee.is_away():
        var reason := TrainingManager.summary(employee)
        if employee.time_off_weeks > 0:
            reason = "On leave - %d week%s left" % [
                employee.time_off_weeks, "" if employee.time_off_weeks == 1 else "s"]
        list.add_child(UiBuilder.label(reason, 13))
    else:
        var text := ""
        for influence in MoraleManager.influences_for(employee):
            text += "%-28s morale %+d  stress %+d\n" % [
                influence["cause"], int(influence["morale"]), int(influence["stress"])]
        list.add_child(UiBuilder.label(text.strip_edges(), 12))

    var permitted := MoraleManager.can_give_time_off(employee)
    var leave := UiBuilder.button("SEND ON LEAVE")
    leave.disabled = not bool(permitted.get("ok", false))
    if leave.disabled and not employee.is_away():
        list.add_child(UiBuilder.label(str(permitted.get("reason", "")), 13))
    leave.pressed.connect(_on_leave_pressed.bind(employee))
    list.add_child(leave)
    list.add_child(UiBuilder.divider())

func _on_leave_pressed(employee: Employee) -> void:
    var dialog := ConfirmationDialog.new()
    dialog.title = "Send on leave?"
    dialog.ok_button_text = "SEND"
    var text := "%s rests and recovers, but does no work.

" % employee.display_name()
    for effect in MoraleManager.time_off_effects():
        text += "%-12s %s
" % [str(effect["label"]), str(effect["value"])]
    dialog.dialog_text = text
    dialog.confirmed.connect(func():
        MoraleManager.give_time_off(employee)
        _refresh())
    add_child(dialog)
    dialog.popup_centered()

func _on_back() -> void:
    get_tree().change_scene_to_file("res://scenes/studio/TeamsScreen.tscn")
