extends Control

## Send somebody on a course. They keep drawing a salary and do no work while
## they are away, which is the whole decision.

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var back_button: Button = $Margin/VBox/BackButton

var _selected: Employee = null
var _selected_skill := "programming"

func _ready() -> void:
    GameClock.enter_menu()
    back_button.pressed.connect(_on_back)
    _refresh()

func _refresh() -> void:
    UiBuilder.clear(list)
    _show_in_training()
    _show_people()
    if _selected != null:
        _show_courses()

func _show_in_training() -> void:
    var away := TrainingManager.trainees()
    if away.is_empty():
        return

    list.add_child(UiBuilder.heading("AWAY ON A COURSE"))
    for employee in away:
        list.add_child(UiBuilder.label("%s\n%s" % [
            employee.display_name(), TrainingManager.summary(employee)], 15))
        var cancel := UiBuilder.button("BRING %s BACK" % employee.first_name.to_upper())
        cancel.pressed.connect(_on_cancel.bind(employee))
        list.add_child(cancel)
    list.add_child(UiBuilder.label("The fee is not refunded.", 13))
    list.add_child(UiBuilder.divider())

func _show_people() -> void:
    list.add_child(UiBuilder.heading("WHO IS GOING?"))

    var available := 0
    for employee in EmployeeManager.active_employees():
        if employee.is_training():
            continue
        available += 1

        var busy := TeamManager.employee_has_active_role(employee.id)
        var label := "%s\n%s" % [employee.display_name(), EmployeeManager.job_title(employee)]
        if employee.has_specialized():
            label += "\n%s" % str(employee.specialization().get("name", ""))
        if busy:
            label += "   (on a project)"

        var button := UiBuilder.button(label, 62)
        button.disabled = busy
        button.pressed.connect(_on_select.bind(employee))
        list.add_child(button)

    if available == 0:
        list.add_child(UiBuilder.label("Everyone is already on a course.", 15))
    list.add_child(UiBuilder.divider())

func _show_courses() -> void:
    list.add_child(UiBuilder.heading("COURSES FOR %s" % _selected.display_name().to_upper()))

    for course in TrainingManager.courses():
        var course_id := str(course.get("id", ""))
        var open_ended := TrainingSimulator.is_open_ended(course)
        var skill := TrainingSimulator.skill_of(course, _selected_skill)

        var band := TrainingSimulator.expected_gain(course, _selected, skill)
        var cost := int(course.get("cost", 0))
        var weeks := int(course.get("weeks", 1))

        list.add_child(UiBuilder.label(str(course.get("name", "Course")), 17))
        list.add_child(UiBuilder.label(str(course.get("description", "")), 13))
        list.add_child(UiBuilder.label("Cost %s   Duration %d week%s\n%s %s   (now %d)\n%s" % [
            Format.money_exact(cost), weeks, "" if weeks == 1 else "s",
            skill.capitalize(), TrainingSimulator.gain_label(band),
            int(_selected.get(skill)),
            TrainingSimulator.value_label(course, _selected, skill)], 15))

        var specialization_id := str(course.get("specialization", ""))
        if not specialization_id.is_empty():
            var specialization := DataManager.get_specialization(specialization_id)
            var already := _selected.specialization_id == specialization_id
            list.add_child(UiBuilder.label(
                "Specializes in %s%s" % [
                    str(specialization.get("name", "")),
                    " (already %s's focus)" % _selected.they() if already else ""
                ], 13))

        if open_ended:
            list.add_child(_skill_picker())

        var permitted := TrainingManager.can_enrol(_selected, course_id, _selected_skill)
        var send := UiBuilder.button("SEND TO TRAINING")
        send.disabled = not bool(permitted.get("ok", false))
        if send.disabled:
            list.add_child(UiBuilder.label(str(permitted.get("reason", "")), 13))
        send.pressed.connect(_on_enrol.bind(course_id))
        list.add_child(send)
        list.add_child(UiBuilder.divider())

func _skill_picker() -> OptionButton:
    var picker := OptionButton.new()
    picker.custom_minimum_size = Vector2(0, 52)
    for skill in EmployeeManager.SKILL_FIELDS:
        picker.add_item("%s (%d)" % [str(skill).capitalize(), int(_selected.get(skill))])
        picker.set_item_metadata(picker.item_count - 1, skill)
        if skill == _selected_skill:
            picker.select(picker.item_count - 1)
    picker.item_selected.connect(_on_skill_chosen.bind(picker))
    return picker

func _on_skill_chosen(_index: int, picker: OptionButton) -> void:
    _selected_skill = str(picker.get_item_metadata(picker.selected))
    _refresh()

func _on_select(employee: Employee) -> void:
    _selected = employee
    _refresh()

func _on_enrol(course_id: String) -> void:
    if TrainingManager.enrol(_selected, course_id, _selected_skill):
        _selected = null
        _refresh()

func _on_cancel(employee: Employee) -> void:
    TrainingManager.cancel(employee)
    _refresh()

func _on_back() -> void:
    get_tree().change_scene_to_file("res://scenes/studio/TeamsScreen.tscn")
