extends Control

## The books. Financial pages always show exact amounts, never compact ones.

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var back_button: Button = $Margin/VBox/BackButton

func _ready() -> void:
    GameClock.enter_menu()
    back_button.pressed.connect(_on_back)
    _build()

func _build() -> void:
    UiBuilder.clear(list)

    list.add_child(UiBuilder.heading("POSITION"))
    list.add_child(UiBuilder.label("Cash          %s\nLifetime revenue  %s\nLifetime costs    %s\nNet             %s" % [
        Format.money_exact(GameState.cash),
        Format.money_exact(CompanyStats.lifetime_revenue()),
        Format.money_exact(CompanyStats.lifetime_costs()),
        Format.money_exact(CompanyStats.lifetime_revenue() - CompanyStats.lifetime_costs())
    ], 15))

    var monthly := EmployeeManager.monthly_expenses()
    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("MONTHLY EXPENSES"))
    list.add_child(UiBuilder.label(
        "Employee salaries  %s\nOffice rent       %s\nUtilities         %s\nSoftware          %s\n\nTOTAL             %s / month" % [
            Format.money_exact(int(monthly["salaries"])),
            Format.money_exact(int(monthly["rent"])),
            Format.money_exact(int(monthly["utilities"])),
            Format.money_exact(int(monthly["software"])),
            Format.money_exact(int(monthly["total"]))
        ], 15
    ))

    if FinanceManager.is_in_trouble():
        list.add_child(UiBuilder.label("OVERDRAWN - %d week%s to recover." % [
            FinanceManager.weeks_of_grace_left(),
            "" if FinanceManager.weeks_of_grace_left() == 1 else "s"
        ], 15))

    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("BY YEAR"))
    var history := FinanceManager.annual_history()
    if history.is_empty():
        list.add_child(UiBuilder.label("No trading yet.", 14))
    else:
        var years_text := "%-6s %12s %12s %12s
" % ["Year", "Income", "Costs", "Net"]
        for row in history:
            years_text += "%-6d %12s %12s %12s
" % [
                int(row["year"]),
                Format.exact(int(row["income"])),
                Format.exact(int(row["expenses"])),
                Format.signed_money(int(row["net"]))
            ]
        list.add_child(UiBuilder.label(years_text.strip_edges(), 13))

    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("PER GAME"))
    if GameState.released_games.is_empty():
        list.add_child(UiBuilder.label("No releases yet.", 14))
    else:
        var text := ""
        for game in GameState.released_games:
            text += "%s\n  cost %s   revenue %s\n  profit %s\n" % [
                game.title,
                Format.money_exact(game.total_cost()),
                Format.money_exact(game.lifetime_revenue),
                Format.signed_money(game.profit())
            ]
        list.add_child(UiBuilder.label(text.strip_edges(), 13))

    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("RECENT TRANSACTIONS"))
    var entries := FinanceManager.recent_transactions(40)
    if entries.is_empty():
        list.add_child(UiBuilder.label("No transactions yet.", 14))
        return

    entries.reverse()
    var ledger_text := ""
    var last_date := ""
    for entry in entries:
        var date := Ledger.date_label(entry)
        if date != last_date:
            ledger_text += "\n%s\n" % date
            last_date = date
        ledger_text += "  %-24s %s\n" % [
            str(entry.get("description", "")), Ledger.amount_label(entry)
        ]
    list.add_child(UiBuilder.label(ledger_text.strip_edges(), 13))

func _on_back() -> void:
    get_tree().change_scene_to_file("res://scenes/company/CompanyScreen.tscn")
