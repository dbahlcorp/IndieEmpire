extends Control

## Mobile career scrapbook: summary first, progressively disclosed history.

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var back_button: Button = $Margin/VBox/BackButton

var _finance_metric := "revenue"
var _finance_period := 5
var _show_full_timeline := false
var _show_all_franchises := false

func _ready() -> void:
    GameClock.enter_menu()
    back_button.pressed.connect(_on_back)
    _build()

func _build() -> void:
    UiBuilder.clear(list)
    list.add_child(UiBuilder.section_header(
        "Career overview", "The story your studio has built so far."))
    list.add_child(UiBuilder.stat_grid(CompanyStats.overview(),
        3 if get_viewport_rect().size.x >= 840 else 2))

    if GameState.released_games.is_empty():
        list.add_child(UiBuilder.divider())
        var empty := UiBuilder.empty_state("No games yet",
            "Your studio hasn't released anything yet. Ship your first game to begin building a career history.")
        list.add_child(empty["panel"])
        return

    _records()
    _finance_chart()
    _timeline()
    _franchises()
    _awards()

func _records() -> void:
    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.section_header("Records", "The releases that define your studio."))
    var best_seller := CompanyStats.best_selling()
    var highest := CompanyStats.highest_rated()
    var loss := CompanyStats.biggest_loss()
    var cards: Array = []
    if best_seller != null:
        cards.append({"icon": "sales", "label": "Best seller",
            "value": "%s\n%s copies" % [best_seller.title, Format.count(best_seller.lifetime_sales)]})
    if highest != null:
        cards.append({"icon": "best_game", "label": "Highest rated",
            "value": "%s\n%.1f" % [highest.title, highest.review_score]})
    if loss != null:
        cards.append({"icon": "warning", "label": "Biggest flop",
            "value": "%s\n%s$%s" % [loss.title, "-" if loss.profit() < 0 else "+",
                Format.count(absi(loss.profit()))]})
    list.add_child(UiBuilder.stat_grid(cards, 1))

func _finance_chart() -> void:
    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.section_header("Company history",
        "Follow revenue or profit without a spreadsheet."))

    var metric_row := HBoxContainer.new()
    metric_row.add_theme_constant_override("separation", 8)
    for entry in [["revenue", "REVENUE"], ["profit", "PROFIT"]]:
        var button := UiBuilder.button(entry[1])
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.disabled = _finance_metric == entry[0]
        button.pressed.connect(_set_metric.bind(entry[0]))
        metric_row.add_child(button)
    list.add_child(metric_row)

    var period_row := HBoxContainer.new()
    period_row.add_theme_constant_override("separation", 6)
    for entry in [[1, "1Y"], [5, "5Y"], [10, "10Y"], [0, "ALL"]]:
        var button := UiBuilder.button(entry[1])
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.disabled = _finance_period == entry[0]
        button.pressed.connect(_set_period.bind(entry[0]))
        period_row.add_child(button)
    list.add_child(period_row)

    var history := FinanceManager.annual_history()
    if _finance_period > 0 and history.size() > _finance_period:
        history = history.slice(history.size() - _finance_period)
    var points: Array = []
    for row in history:
        points.append({
            "label": str(row["year"]),
            "value": row["income"] if _finance_metric == "revenue" else row["net"],
        })
    var chart := CareerChart.new().configure(points,
        "Revenue" if _finance_metric == "revenue" else "Profit", true)
    list.add_child(chart)
    var summary := UiBuilder.label(chart.concise_summary(), 13)
    summary.theme_type_variation = &"MutedLabel"
    list.add_child(summary)
    var details := UiBuilder.collapsible_section("READ EVERY YEAR")
    details["body"].add_child(UiBuilder.label(chart.text_summary(), 13))
    list.add_child(details["panel"])

func _timeline() -> void:
    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.section_header("Game history", "Every release is part of the studio's story."))
    var games := GameState.released_games.duplicate()
    games.sort_custom(func(a: GameProject, b: GameProject) -> bool:
        if a.release_year != b.release_year:
            return a.release_year < b.release_year
        if a.release_month != b.release_month:
            return a.release_month < b.release_month
        return a.release_week < b.release_week)
    var shown := games
    if not _show_full_timeline and games.size() > 20:
        shown = games.slice(games.size() - 20)
        list.add_child(UiBuilder.label("Showing the latest 20 of %d releases." % games.size(), 13, true))
    var current_year := -1
    for game: GameProject in shown:
        if game.release_year != current_year:
            current_year = game.release_year
            list.add_child(UiBuilder.heading(str(current_year)))
        var body := "%.1f review  ·  %s copies  ·  %s$%s" % [
            game.review_score, Format.count(game.lifetime_sales),
            "+" if game.profit() >= 0 else "-", Format.count(absi(game.profit()))]
        list.add_child(UiBuilder.info_card(game.title, body,
            "best_game" if game.review_score >= 8.0 else "games"))
    if games.size() > 20:
        var toggle := UiBuilder.button("SHOW RECENT 20" if _show_full_timeline else "SHOW FULL CAREER")
        toggle.pressed.connect(func():
            _show_full_timeline = not _show_full_timeline
            _build())
        list.add_child(toggle)

func _franchises() -> void:
    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.section_header("Franchises", "The health and value of your studio's IP."))
    if GameState.franchises.is_empty():
        list.add_child(UiBuilder.info_card("No franchises",
            "Release an original game to begin building an IP.", "games"))
        return
    var ordered := GameState.franchises.duplicate()
    ordered.sort_custom(func(a: Franchise, b: Franchise) -> bool:
        return a.lifetime_revenue() > b.lifetime_revenue())
    var shown := ordered if _show_all_franchises or ordered.size() <= 10 else ordered.slice(0, 10)
    if shown.size() < ordered.size():
        list.add_child(UiBuilder.label("Showing the 10 most valuable of %d franchises." % ordered.size(), 13, true))
    for franchise: Franchise in shown:
        var best_title := "—"
        var best_score := -1.0
        for game: GameProject in franchise.entries():
            if game.review_score > best_score:
                best_score = game.review_score
                best_title = game.title
        var body := "%d games  ·  %s copies  ·  $%s\nAverage %.1f  ·  Best: %s\nFan interest %s  ·  Fatigue %s" % [
            franchise.entry_count(), Format.count(franchise.lifetime_units()),
            Format.count(franchise.lifetime_revenue()), franchise.average_review(), best_title,
            FranchiseSimulator.fan_interest_label(franchise.fan_interest),
            FranchiseSimulator.fatigue_label(franchise.fatigue)]
        var card := UiBuilder.action_card(franchise.name, body, "VIEW FRANCHISE", "projects")
        card["action"].pressed.connect(_open_franchise.bind(franchise.id))
        list.add_child(card["panel"])
    if ordered.size() > 10:
        var toggle := UiBuilder.button("SHOW TOP 10" if _show_all_franchises else "SHOW ALL FRANCHISES")
        toggle.pressed.connect(func():
            _show_all_franchises = not _show_all_franchises
            _build())
        list.add_child(toggle)

func _awards() -> void:
    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.section_header("Awards", "Nominations and wins across your career."))
    if GameState.award_ceremonies.is_empty():
        list.add_child(UiBuilder.info_card("No awards yet",
            "Your studio hasn't received an industry nomination yet.", "success"))
        return
    list.add_child(UiBuilder.stat_grid([
        {"icon": "success", "label": "Nominations", "value": str(CompanyStats.total_award_nominations())},
        {"icon": "best_game", "label": "Awards won", "value": str(CompanyStats.total_awards_won())},
        {"icon": "success", "label": "Game of the Year", "value": str(CompanyStats.goty_wins())},
    ], 1))
    var ceremonies := GameState.award_ceremonies.duplicate()
    ceremonies.reverse()
    for ceremony in ceremonies:
        var year := int(ceremony.get("year", 0))
        var categories: Array = ceremony.get("categories", [])
        var open_button := UiBuilder.button("%d CEREMONY  ·  %d AWARD%s" % [
            year + 1, categories.size(), "" if categories.size() == 1 else "S"])
        open_button.pressed.connect(_open_ceremony.bind(year))
        list.add_child(open_button)

func _set_metric(metric: String) -> void:
    _finance_metric = metric
    _build()

func _set_period(period: int) -> void:
    _finance_period = period
    _build()

func _open_franchise(series_id: String) -> void:
    ScreenRouter.open_franchise(series_id, "res://scenes/company/RecordsScreen.tscn")
    get_tree().change_scene_to_file("res://scenes/studio/FranchiseDetailScreen.tscn")

func _open_ceremony(year: int) -> void:
    ScreenRouter.open_awards_ceremony(year, "res://scenes/company/RecordsScreen.tscn")
    get_tree().change_scene_to_file("res://scenes/company/AwardsCeremonyScreen.tscn")

func _on_back() -> void:
    get_tree().change_scene_to_file("res://scenes/company/CompanyScreen.tscn")
