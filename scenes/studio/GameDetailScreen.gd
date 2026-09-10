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

    var hero := PanelContainer.new()
    hero.theme_type_variation = &"ElevatedPanel"
    var hero_row := HBoxContainer.new()
    hero_row.add_theme_constant_override("separation", 18)
    var cover := GameCoverArt.new().configure(game)
    cover.custom_minimum_size = Vector2(128, 168)
    hero_row.add_child(cover)
    var identity := VBoxContainer.new()
    identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    identity.alignment = BoxContainer.ALIGNMENT_CENTER
    identity.add_child(UiBuilder.label("%s · %s" % [
        DataManager.display_name(DataManager.themes, game.theme_id),
        DataManager.display_name(DataManager.genres, game.genre_id)], 17))
    identity.add_child(UiBuilder.label("%s\nReleased %s" % [
        DataManager.display_name(DataManager.platforms, game.platform_id)
        , game.release_date_label()], 14))
    var lifecycle := "CONCEPT  →  DEVELOPMENT  →  LAUNCH  →  "
    lifecycle += "ON SALE" if game.sales_active else "END OF LIFE"
    identity.add_child(UiBuilder.status_chip(
        lifecycle, "positive" if game.sales_active else "info"))
    if not game.engine_id.is_empty():
        identity.add_child(UiBuilder.label(
            "Built with %s" % EngineManager.engine_name(game.engine_id), 13))
    hero_row.add_child(identity)
    hero.add_child(hero_row)
    list.add_child(hero)

    list.add_child(UiBuilder.stat_grid([
        {"icon": "reputation", "label": "Review score", "value": "%.1f / 10" % game.review_score},
        {"icon": "sales", "label": "Units sold", "value": Format.count(game.lifetime_sales)},
        {"icon": "cash", "label": "Revenue", "value": Format.money(game.lifetime_revenue)},
        {"icon": "cash", "label": "Profit", "value": Format.money(game.profit())},
        {"icon": "cash", "label": "Development cost", "value": Format.money(game.total_cost())},
        {"icon": "fans", "label": "Fans gained", "value": Format.count(game.fans_gained)}
    ], 3 if get_viewport_rect().size.x >= 760 else 2))
    if not game.feature_ids.is_empty():
        list.add_child(UiBuilder.section_header("Features", "The shipped game's player-facing identity."))
        for feature_id in game.feature_ids:
            var feature := DataManager.get_game_feature(str(feature_id))
            list.add_child(UiBuilder.identity_row(
                IdentityArtwork.feature_texture(str(feature_id)),
                FeatureSimulator.display_name(feature), Vector2(34, 34), 14))
    if not game.engine_id.is_empty():
        list.add_child(UiBuilder.engine_identity_row(
            EngineManager.engine_name(game.engine_id), game.engine_id, "Engine used for this release"))
    list.add_child(UiBuilder.divider())

    _verdict()
    _franchise()
    _awards()
    _reviews()
    _sales()
    _money()
    _development()
    _actions()

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

func _franchise() -> void:
    var franchise := GameState.franchise_for_game(game)
    if franchise == null:
        return
    list.add_child(UiBuilder.heading("FRANCHISE"))
    list.add_child(UiBuilder.label("%s — entry %d of %d" % [
        franchise.name, game.sequel_number, franchise.entry_count()], 15, true))
    list.add_child(UiBuilder.label(
        "Standing %s   Fan interest %s   Fatigue %s" % [
            FranchiseSimulator.reputation_label(franchise.reputation),
            FranchiseSimulator.fan_interest_label(franchise.fan_interest),
            FranchiseSimulator.fatigue_label(franchise.fatigue)], 13))
    var view := UiBuilder.button("VIEW FRANCHISE")
    view.pressed.connect(func():
        ScreenRouter.open_franchise(franchise.id, "res://scenes/studio/GameDetailScreen.tscn")
        get_tree().change_scene_to_file("res://scenes/studio/FranchiseDetailScreen.tscn"))
    list.add_child(view)
    list.add_child(UiBuilder.divider())

func _awards() -> void:
    var entries := CompanyStats.awards_for_game(game.id)
    if entries.is_empty():
        return
    list.add_child(UiBuilder.heading("AWARDS"))
    var text := ""
    for entry in entries:
        var verb := "Won" if bool(entry["won"]) else "Nominated"
        text += "%s — %s (%d)\n" % [str(entry["name"]), verb, int(entry["year"]) + 1]
    list.add_child(UiBuilder.label(text.strip_edges(), 15))
    list.add_child(UiBuilder.divider())

func _actions() -> void:
    list.add_child(UiBuilder.divider())
    var sequel := UiBuilder.button("MAKE A SEQUEL")
    sequel.pressed.connect(_start_sequel)
    list.add_child(sequel)

func _start_sequel() -> void:
    var franchise := GameState.franchise_for_game(game)
    var series_id := franchise.id if franchise != null else game.series_id
    ScreenRouter.draft_project = {
        "title": FranchiseManager.suggested_sequel_title(franchise) if franchise != null else "%s 2" % game.title,
        "theme_id": game.theme_id,
        "genre_id": game.genre_id,
        "platform_id": game.platform_id,
        "series_id": series_id,
    }
    ScreenRouter.selected_team_id = ""
    get_tree().change_scene_to_file("res://scenes/development/NewGameScreen.tscn")

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
