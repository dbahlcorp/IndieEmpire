extends Control

## What your people are asking for, and who is on their way out.

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var back_button: Button = $Margin/VBox/BackButton

func _ready() -> void:
    GameClock.enter_menu()
    back_button.pressed.connect(_on_back)
    _refresh()

func _refresh() -> void:
    UiBuilder.clear(list)
    _show_concerns()
    _show_leavers()
    _show_requests()
    _show_watchlist()

func _show_concerns() -> void:
    ## Nobody walks out without the studio being told why first.
    var concerned := RetentionManager.concerned()
    if concerned.is_empty():
        return

    for employee in concerned:
        list.add_child(UiBuilder.heading("EMPLOYEE CONCERN"))
        list.add_child(UiBuilder.label(
            "%s is unhappy with %s current working conditions." % [
                employee.display_name(), employee.their()], 16))

        var text := "Primary concerns:"
        for concern in RetentionManager.concerns_for(employee):
            text += "\n  - %s" % concern
        list.add_child(UiBuilder.label(text, 14))
        list.add_child(UiBuilder.label(
            "Risk of leaving: %s   Morale %d (%s)" % [
                RetentionSimulator.risk_label(RetentionSimulator.quit_risk(employee)),
                employee.morale, MoraleSimulator.morale_label(employee.morale)], 13))
        list.add_child(UiBuilder.divider())

func _show_leavers() -> void:
    var leavers := RetentionManager.leaving()
    if leavers.is_empty():
        return

    for employee in leavers:
        list.add_child(UiBuilder.label(employee.display_name().to_upper(), 20, true))
        list.add_child(UiBuilder.label("%s submitted %s resignation." % [
            employee.verb("has", "have"), employee.their()], 16, true))
        list.add_child(UiBuilder.label(EmployeeManager.job_title(employee), 13, true))

        if not RetentionManager.can_counter(employee):
            list.add_child(UiBuilder.label(
                "Working %s notice. Leaving in %d week%s." % [
                    employee.their(), employee.notice_weeks,
                    "" if employee.notice_weeks == 1 else "s"], 15, true))
            list.add_child(UiBuilder.label(RetentionManager.loss_summary(employee), 13, true))
            list.add_child(UiBuilder.divider())
            continue

        var wanted := RetentionSimulator.raise_target(employee)
        list.add_child(UiBuilder.label(
            "Current salary:\n$%s/month\n\nRequested salary:\n$%s/month" % [
                Format.exact(employee.salary), Format.exact(wanted)], 16, true))

        # What the studio is about to lose, so the decision has weight.
        list.add_child(UiBuilder.label(RetentionManager.loss_summary(employee), 13, true))

        var chance := RetentionSimulator.retention_chance(wanted, wanted)
        list.add_child(UiBuilder.label(
            "Matching has about a %d%% chance of keeping %s.\n%s %s in %d week%s otherwise." % [
                int(round(chance * 100.0)), employee.them(),
                Pronouns.capitalise(employee.they()),
                employee.verb("leaves", "leave"), employee.notice_weeks,
                "" if employee.notice_weeks == 1 else "s"], 13, true))

        var match_button := UiBuilder.button("MATCH OFFER")
        var increase := maxi(wanted - employee.salary, 0)
        match_button.disabled = not FinanceManager.can_afford(increase)
        if match_button.disabled:
            list.add_child(UiBuilder.label(
                "The studio cannot afford another $%s a month." % Format.exact(increase), 13, true))
        match_button.pressed.connect(func():
            RetentionManager.counter_offer(employee, wanted)
            _refresh())
        list.add_child(match_button)

        var release := UiBuilder.button("LET %s GO" % employee.them().to_upper())
        release.pressed.connect(func():
            RetentionManager.accept_resignation(employee)
            _refresh())
        list.add_child(release)
        list.add_child(UiBuilder.divider())

func _show_requests() -> void:
    list.add_child(UiBuilder.heading("REQUESTS"))

    var requests := RetentionManager.requests()
    if requests.is_empty():
        list.add_child(UiBuilder.label("Nobody is asking for anything.", 15))
        list.add_child(UiBuilder.divider())
        return

    for request in requests:
        var employee := EmployeeManager.find_employee(request.employee_id)
        if employee == null:
            continue

        var title := "A RAISE" if request.kind == StaffRequest.RAISE else "A PROMOTION"
        list.add_child(UiBuilder.label("%s asks for %s" % [employee.display_name(), title], 17))
        list.add_child(UiBuilder.label("%s\n%s" % [
            EmployeeManager.job_title(employee), request.reason], 13))

        var detail := "%s a month, up from %s (+%s)" % [
            Format.money_exact(request.requested_salary),
            Format.money_exact(request.current_salary),
            Format.money_exact(request.monthly_increase())]
        if request.kind == StaffRequest.PROMOTION:
            detail = "%s %s\n%s" % [
                request.new_seniority.capitalize(),
                EmployeeManager.role_name(employee.role), detail]
            var leadership_gain := RetentionSimulator.promotion_leadership_gain(
                request.new_seniority)
            if leadership_gain > 0:
                detail += "\n+%d leadership" % leadership_gain
        list.add_child(UiBuilder.label(detail, 15))

        list.add_child(UiBuilder.label("Morale %d (%s)   Risk of leaving: %s\n%d week%s to answer" % [
            employee.morale, MoraleSimulator.morale_label(employee.morale),
            RetentionSimulator.risk_label(RetentionSimulator.quit_risk(employee)),
            request.weeks_left, "" if request.weeks_left == 1 else "s"], 13))

        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)

        var accept := UiBuilder.button("AGREE")
        accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        accept.disabled = not RetentionManager.can_grant(request)
        accept.pressed.connect(func():
            RetentionManager.grant(request)
            _refresh())
        row.add_child(accept)

        var refuse := UiBuilder.button("REFUSE")
        refuse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        refuse.pressed.connect(func():
            RetentionManager.refuse(request)
            _refresh())
        row.add_child(refuse)

        list.add_child(row)
        list.add_child(UiBuilder.divider())

func _show_watchlist() -> void:
    list.add_child(UiBuilder.heading("HOW SETTLED EVERYONE IS"))

    for employee in EmployeeManager.active_employees():
        if employee.is_founder():
            continue
        var risk := RetentionSimulator.quit_risk(employee)
        list.add_child(UiBuilder.label("%-22s %s\n  morale %d, stress %d, %s" % [
            employee.display_name(), RetentionSimulator.risk_label(risk),
            employee.morale, employee.stress,
            MoraleSimulator.salary_label(employee)], 13))

    if not GameState.departed_employees.is_empty():
        list.add_child(UiBuilder.divider())
        list.add_child(UiBuilder.heading("PEOPLE WHO HAVE LEFT"))
        var text := ""
        for employee in GameState.departed_employees:
            var summary := employee.career_summary()
            text += "%s, %s\n" % [employee.display_name(), EmployeeManager.job_title(employee)]
            var shipped := int(summary["games_shipped"])
            if shipped > 0:
                text += "  %d game%s shipped, avg review %.1f\n" % [
                    shipped, "" if shipped == 1 else "s",
                    float(summary["average_review_score"])]
                var best: String = str(summary["highest_rated_game"])
                if not best.is_empty():
                    text += "  Best: %s (%.1f)\n" % [best, float(summary["highest_review_score"])]
        list.add_child(UiBuilder.label(text.strip_edges(), 13))

func _on_back() -> void:
    get_tree().change_scene_to_file("res://scenes/studio/TeamsScreen.tscn")
