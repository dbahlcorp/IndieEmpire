extends TestCase

func run() -> void:
    GameState.start_company("Chart House", "Alex", "normal")
    SaveManager.has_active_company = true
    _chart_math_and_text()
    _company_aggregates()
    await _statistics_screen_is_mobile_ready()

func _chart_math_and_text() -> void:
    section("career charts")
    var chart := CareerChart.new().configure([
        {"label": "1985", "value": -1000},
        {"label": "1986", "value": 2000},
        {"label": "1987", "value": 1000},
    ], "Profit", true)
    add_child(chart)
    var mapped := chart.mapped_points(Rect2(0, 0, 200, 100))
    check_equal(chart.point_count(), 3, "all points retained")
    check_equal(mapped.size(), 3, "all points mapped")
    check_approx(mapped[0].x, 0.0, "first point uses the left edge")
    check_approx(mapped[1].x, 100.0, "middle point is centered")
    check_approx(mapped[2].x, 200.0, "last point uses the right edge")
    check(mapped[0].y > mapped[2].y and mapped[2].y > mapped[1].y,
        "signed values map from low to high")
    check(chart.text_summary().contains("1985: -$") and chart.text_summary().contains("1987: $"),
        "text equivalent includes signed values")
    check(chart.concise_summary().contains("High $") and chart.concise_summary().contains("(1986)"),
        "concise summary names the high")
    chart.queue_free()

func _company_aggregates() -> void:
    section("statistics aggregates")
    var hit := GameProject.new()
    hit.title = "Sunrise"
    hit.review_score = 8.8
    hit.lifetime_sales = 50000
    hit.lifetime_revenue = 250000
    hit.development_cost = 100000
    var flop := GameProject.new()
    flop.title = "Rainfall"
    flop.review_score = 5.2
    flop.lifetime_sales = 3000
    flop.lifetime_revenue = 15000
    flop.development_cost = 90000
    GameState.released_games.assign([hit, flop])
    check_equal(CompanyStats.biggest_loss(), flop, "biggest flop is measured by loss")
    GameState.released_games.assign([hit])
    check_equal(CompanyStats.biggest_loss(), null,
        "a profitable catalogue does not invent a biggest flop")
    GameState.released_games.assign([hit, flop])
    check_equal(CompanyStats.overview().size(), 6, "mobile overview has six headline cards")

func _statistics_screen_is_mobile_ready() -> void:
    section("statistics mobile screen")
    GameState.annual_finance = {
        "1985": {"income": 1000, "expenses": 1500},
        "1986": {"income": 4000, "expenses": 2000},
    }
    var viewport := SubViewport.new()
    viewport.size = Vector2i(430, 932)
    add_child(viewport)
    var screen := load("res://scenes/company/RecordsScreen.tscn").instantiate() as Control
    viewport.add_child(screen)
    VisualTheme._style_scene(screen)
    for i in 5:
        await get_tree().process_frame
    check_equal(screen.get_node("Margin/VBox/Heading").text, "STATISTICS", "screen has its player-facing name")
    check(screen.get_node("Margin/VBox/BackButton").size.y >= 48.0, "back action is thumb-sized")
    var chart_count := screen.find_children("*", "CareerChart", true, false).size()
    check_equal(chart_count, 1, "one focused chart is shown at a time")
    var small_buttons := 0
    for button in screen.find_children("*", "Button", true, false):
        if button.visible and button.size.y < 48.0:
            small_buttons += 1
    check_equal(small_buttons, 0, "visible statistics controls are touch-sized")
    screen.queue_free()
    viewport.queue_free()
