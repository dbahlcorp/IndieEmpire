extends Control

## The full page for one game: reviews, the week-by-week sales run, the money it
## made or lost, and exactly how it was built.

@onready var heading: Label = $Margin/VBox/Heading
@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var back_button: Button = $Margin/VBox/BackButton

var game: GameProject

func _ready() -> void:
    GameClock.enter_menu()
    game = ScreenRouter.selected_game()
    back_button.pressed.connect(_on_back_pressed)

    if game == null:
        heading.text = "GAME"
        list.add_child(UiBuilder.label("That game could not be found.", 16, true))
        return

    heading.text = game.title.to_upper()
    _build()

func _build() -> void:
    UiBuilder.clear(list)

    var cover := GameCoverArt.new().configure(game)
    cover.custom_minimum_size = Vector2(128, 168)
    var cover_center := CenterContainer.new()
    cover_center.add_child(cover)
    list.add_child(cover_center)

    list.add_child(UiBuilder.label("%s %s\n%s" % [
        DataManager.display_name(DataManager.themes, game.theme_id),
        DataManager.display_name(DataManager.genres, game.genre_id),
        DataManager.display_name(DataManager.platforms, game.platform_id)
    ], 16, true))
    list.add_child(UiBuilder.label("Released %s" % game.release_date_label(), 14, true))
    if not game.engine_id.is_empty():
        list.add_child(UiBuilder.label("Built with %s" % EngineManager.engine_name(game.engine_id), 14, true))
    if not game.feature_ids.is_empty():
        list.add_child(UiBuilder.label(
            "FEATURES\n%s" % FeatureSimulator.feature_names(game.feature_ids).replace(", ", "\n"),
            14, true))
    list.add_child(UiBuilder.divider())

    _verdict()
    _reviews()
    _sales()
    _money()
    _development()

func _verdict() -> void:
    var verdict := ReleaseSummarySimulator.verdict(game)
    list.add_child(UiBuilder.heading("RELEASE"))
    var banner := UiBuilder.label(str(verdict["title"]), 20)
    banner.add_theme_color_override("font_color",
        ReleaseSummarySimulator.tone_color(str(verdict["tone"])))
    list.add_child(banner)
    list.add_child(UiBuilder.label(str(verdict["subtitle"]), 14, true))

    var strengths: Array = game.went_well if game.postmortem_reviewed \
        else ReleaseSummarySimulator.strengths(game)
    var weaknesses: Array = game.went_poorly if game.postmortem_reviewed \
        else ReleaseSummarySimulator.weaknesses(game)
    if not strengths.is_empty():
        list.add_child(UiBuilder.label("WHAT CARRIED IT\n%s" % _bullet_list(strengths), 14))
    if not weaknesses.is_empty():
        list.add_child(UiBuilder.label("WHAT HELD IT BACK\n%s" % _bullet_list(weaknesses), 14))
    list.add_child(UiBuilder.divider())

func _bullet_list(items: Array) -> String:
    var text := ""
    for item in items:
        text += "• %s\n" % str(item)
    return text.strip_edges()

func _reviews() -> void:
    list.add_child(UiBuilder.heading("REVIEWS"))
    list.add_child(UiBuilder.label("Average  %.1f" % game.review_score, 22))

    var text := ""
    for review in game.critic_reviews:
        text += "%-18s %.1f\n" % [str(review.get("outlet", "")), float(review.get("score", 0.0))]
    if not text.is_empty():
        list.add_child(UiBuilder.label(text.strip_edges(), 14))
    list.add_child(UiBuilder.divider())

func _sales() -> void:
    list.add_child(UiBuilder.heading("SALES"))

    var chart := SalesChart.new()
    chart.custom_minimum_size = Vector2(0, 132)
    chart.configure(game.weekly_sales, false)
    list.add_child(chart)
    list.add_child(UiBuilder.label(chart.text_summary(), 13))

    list.add_child(UiBuilder.label("Lifetime  %s\nRevenue   $%s\nFans gained  %s" % [
        Format.exact(game.lifetime_sales),
        Format.exact(game.lifetime_revenue),
        Format.exact(game.fans_gained)
    ], 16))
    list.add_child(UiBuilder.divider())

func _money() -> void:
    list.add_child(UiBuilder.heading("PUBLISHING"))
    var terms := "%s
You kept %s of revenue" % [
        PublishingManager.publisher_name(game),
        PublishingSimulator.share_label(game.developer_share)]
    if game.advance > 0:
        terms += "
Advance %s" % Format.money_exact(game.advance)
    if game.publisher_revenue > 0:
        terms += "
Publisher took %s" % Format.money_exact(game.publisher_revenue)
    list.add_child(UiBuilder.label(terms, 14))
    list.add_child(UiBuilder.divider())

    list.add_child(UiBuilder.heading("PROFIT"))

    var text := ""
    for row in FinanceManager.profit_breakdown(game):
        var amount := int(row["amount"])
        var sign_text := "+" if amount >= 0 else "-"
        text += "%-14s %s$%s\n" % [
            str(row["label"]), sign_text, Format.exact(absi(amount))
        ]
    list.add_child(UiBuilder.label(text.strip_edges(), 15))
    list.add_child(UiBuilder.divider())

func _development() -> void:
    list.add_child(UiBuilder.heading("DEVELOPMENT"))
    var lead := EmployeeManager.find_any_employee(game.lead_employee_id)
    if lead != null:
        list.add_child(UiBuilder.label("Project lead   %s (Leadership %d)" % [
            lead.display_name(), lead.leadership], 14, true))
    list.add_child(UiBuilder.label(
        "Started       %s\nCompleted     %s\nDevelopment   %d weeks\nPolish        %d weeks\nBugs created  %d\nBugs fixed    %d\nLaunch bugs   %d" % [
            game.start_date_label(),
            game.completion_date_label(),
            game.development_weeks,
            game.polish_weeks,
            game.bugs_created,
            game.bugs_fixed,
            game.bugs
        ], 14))

    list.add_child(UiBuilder.label(
        "Gameplay    %5.0f\nTechnology  %5.0f\nPerformance %5.0f\nGraphics    %5.0f\nStory       %5.0f\nNarrative   %5.0f\nSound       %5.0f\nInnovation  %5.0f\nPolish      %5.0f\nBalance     %5.0f" % [
            game.gameplay, game.technology, game.performance, game.graphics,
            game.story, game.narrative_quality, game.sound, game.innovation,
            game.polish, game.balance
        ], 14))

    if game.postmortem_reviewed:
        list.add_child(UiBuilder.divider())
        var button := UiBuilder.button("VIEW POSTMORTEM")
        button.pressed.connect(_open_postmortem)
        list.add_child(button)

func _open_postmortem() -> void:
    ScreenRouter.open_game(game.id, "res://scenes/studio/GameDetailScreen.tscn")
    get_tree().change_scene_to_file("res://scenes/release/PostmortemScreen.tscn")

func _on_back_pressed() -> void:
    get_tree().change_scene_to_file(ScreenRouter.return_scene)
