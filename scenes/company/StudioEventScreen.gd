extends Control

## One studio event, presented as a choice. The clock is already stopped; the
## player answers here or backs out and the event waits.

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var back_button: Button = $Margin/VBox/BackButton

var _outcome: String = ""

func _ready() -> void:
    GameClock.enter_menu()
    back_button.pressed.connect(_on_back)
    _build()

func _build() -> void:
    UiBuilder.clear(list)

    if not StudioEventManager.has_pending():
        list.add_child(UiBuilder.label("Nothing needs you right now.", 16, true))
        back_button.text = "BACK"
        return

    var event := StudioEventManager.pending_event()
    var employee := StudioEventManager.pending_employee()

    list.add_child(UiBuilder.heading(str(event.get("title", "STUDIO EVENT"))))
    if employee != null:
        list.add_child(UiBuilder.employee_header(
            employee, EmployeeManager.job_title(employee)))
    list.add_child(UiBuilder.label(
        StudioEventSimulator.fill(str(event.get("body", "")), employee), 16))

    if not _outcome.is_empty():
        list.add_child(UiBuilder.divider())
        list.add_child(UiBuilder.label(_outcome, 15, true))
        back_button.text = "CONTINUE"
        return

    var summary := StudioEventManager.active_effect_summary()
    if not summary.is_empty():
        list.add_child(UiBuilder.label(summary, 13))

    list.add_child(UiBuilder.divider())

    var choices: Array = event.get("choices", [])
    for index in choices.size():
        _choice_card(index, choices[index])

    back_button.text = "DECIDE LATER"

func _choice_card(index: int, choice: Dictionary) -> void:
    list.add_child(UiBuilder.label(str(choice.get("label", "OPTION")), 17, true))

    var cost := StudioEventSimulator.choice_cost(choice)
    list.add_child(UiBuilder.label(
        "Cost   %s" % ("Free" if cost == 0 else "$%s" % Format.exact(cost)), 14))

    var benefits: Array = StudioEventSimulator.benefit_lines(choice)
    if not benefits.is_empty():
        var text := "Possible outcome" if _is_negative(choice) else "Possible benefits"
        for line in benefits:
            text += "\n  %s" % str(line)
        list.add_child(UiBuilder.label(text, 13))

    var button := UiBuilder.major_button(str(choice.get("label", "CHOOSE")))
    if not StudioEventManager.can_afford_choice(index):
        button.disabled = true
        button.text = "%s  (can't afford)" % str(choice.get("label", "CHOOSE"))
    button.pressed.connect(_choose.bind(index))
    list.add_child(button)
    list.add_child(UiBuilder.divider())

func _is_negative(choice: Dictionary) -> bool:
    for effect in choice.get("effects", []):
        var kind := str(effect.get("kind", ""))
        var negative_amount := float(effect.get("amount", 0.0)) < 0.0
        if negative_amount and kind in ["dev_efficiency", "team_chemistry", "reputation", "morale"]:
            return true
    return false

func _choose(index: int) -> void:
    var result := StudioEventManager.resolve(index)
    if bool(result.get("ok", false)):
        _outcome = str(result.get("outcome", "Done."))
        if _outcome.strip_edges().is_empty():
            _on_back()
            return
    _build()

func _on_back() -> void:
    get_tree().change_scene_to_file("res://scenes/studio/StudioScreen.tscn")
