extends Control

## The contract board. Paid work for other companies: reliable money, no
## catalogue, no fans. What you fall back on between games.

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var back_button: Button = $Margin/VBox/BackButton

var _confirm: ConfirmationDialog

func _ready() -> void:
    GameClock.enter_menu()
    back_button.pressed.connect(_on_back)

    _confirm = ConfirmationDialog.new()
    _confirm.title = "Abandon contract?"
    _confirm.dialog_text = "The client is left with nothing and your standing suffers."
    _confirm.ok_button_text = "ABANDON"
    _confirm.confirmed.connect(_on_abandon_confirmed)
    add_child(_confirm)

    _refresh()

func _refresh() -> void:
    UiBuilder.clear(list)

    var active := ContractManager.active_contract()
    if active != null:
        _show_active(active)
    else:
        _show_offers()

    _show_history()

func _show_active(contract: Contract) -> void:
    list.add_child(UiBuilder.heading("IN PROGRESS"))
    list.add_child(UiBuilder.label("%s\nfor %s" % [contract.name, contract.client], 17))
    list.add_child(UiBuilder.label(contract.brief, 14))

    var bar := ProgressBar.new()
    bar.custom_minimum_size = Vector2(0, 26)
    bar.value = contract.progress_percent()
    list.add_child(bar)

    var weekly := ContractManager.weekly_output()
    var remaining := maxf(float(contract.work) - contract.work_done, 0.0)
    var needed := ContractSimulator.expected_weeks(int(ceil(remaining)), weekly)
    var left := contract.weeks_remaining()

    var pace := "on schedule" if needed <= left else "BEHIND SCHEDULE"
    list.add_child(UiBuilder.label(
        "%.0f%% done   %s on delivery\n%d week%s left of %d   about %d week%s of work remaining" % [
            contract.progress_percent(), Format.money_exact(contract.payout),
            left, "" if left == 1 else "s", contract.deadline_weeks,
            needed, "" if needed == 1 else "s"], 15))
    list.add_child(UiBuilder.label(pace, 15))

    var abandon := UiBuilder.button("ABANDON CONTRACT")
    abandon.pressed.connect(func(): _confirm.popup_centered())
    list.add_child(abandon)
    list.add_child(UiBuilder.divider())

func _show_offers() -> void:
    list.add_child(UiBuilder.heading("AVAILABLE WORK"))

    var offers := ContractManager.offers()
    if offers.is_empty():
        list.add_child(UiBuilder.label("Nothing on the board right now.", 15))
        list.add_child(UiBuilder.divider())
        return

    var can_take := ContractManager.can_accept()
    if not can_take:
        list.add_child(UiBuilder.label(
            "Your team is busy building a game. Finish or abandon it to take contract work.", 14))

    for contract in offers:
        var weekly := ContractSimulator.weekly_work(
            TeamManager.working_members("team_a"), OfficeManager.productivity())
        var weeks := ContractSimulator.expected_weeks(contract.work, weekly)

        list.add_child(UiBuilder.label("%s\nfor %s" % [contract.name, contract.client], 17))
        list.add_child(UiBuilder.label(contract.brief, 14))
        list.add_child(UiBuilder.label(
            "Pays %s   Deadline %d weeks\nYour team would need about %d week%s" % [
                Format.money_exact(contract.payout), contract.deadline_weeks,
                weeks, "" if weeks == 1 else "s"], 15))

        var take := UiBuilder.button("TAKE THIS CONTRACT")
        take.disabled = not can_take or weeks > contract.deadline_weeks * 2
        take.pressed.connect(_on_accept.bind(contract))
        list.add_child(take)
        list.add_child(UiBuilder.divider())

func _show_history() -> void:
    if GameState.completed_contracts.is_empty():
        return

    list.add_child(UiBuilder.heading("PAST WORK"))
    list.add_child(UiBuilder.label("Delivered %d   Lost %d   Earned %s" % [
        ContractManager.completed_count(), ContractManager.failed_count(),
        Format.money_exact(ContractManager.total_contract_income())], 15))

    var text := ""
    var recent := GameState.completed_contracts.slice(
        maxi(GameState.completed_contracts.size() - 8, 0))
    recent.reverse()
    for contract in recent:
        var outcome := Format.money_exact(contract.payout) if contract.status == "completed" else "lost"
        text += "%-26s %s\n" % [contract.name, outcome]
    list.add_child(UiBuilder.label(text.strip_edges(), 13))

func _on_accept(contract: Contract) -> void:
    if ContractManager.accept(contract):
        _refresh()

func _on_abandon_confirmed() -> void:
    ContractManager.abandon()
    _refresh()

func _on_back() -> void:
    get_tree().change_scene_to_file("res://scenes/studio/StudioScreen.tscn")
