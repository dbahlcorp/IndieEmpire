extends Control

## The full page for one IP: its entries in order with a release timeline,
## per-entry reviews and sales, the franchise's lifetime revenue, and its live
## fan interest and fatigue. A sequel can be started straight from here.

@onready var heading: Label = $Margin/VBox/Heading
@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var back_button: Button = $Margin/VBox/BackButton

var franchise: Franchise

func _ready() -> void:
    GameClock.enter_menu()
    franchise = ScreenRouter.selected_franchise()
    back_button.pressed.connect(func():
        get_tree().change_scene_to_file(ScreenRouter.return_scene))

    if franchise == null:
        heading.text = "FRANCHISE"
        list.add_child(UiBuilder.label("That franchise could not be found.", 16, true))
        return

    heading.text = franchise.name.to_upper()
    _build()

func _build() -> void:
    UiBuilder.clear(list)

    list.add_child(UiBuilder.label("%d entr%s   ·   founded %d" % [
        franchise.entry_count(), "y" if franchise.entry_count() == 1 else "ies",
        franchise.founded_year], 15, true))
    list.add_child(UiBuilder.divider())

    _standing()
    _timeline()
    _actions()

func _standing() -> void:
    list.add_child(UiBuilder.heading("STANDING"))
    list.add_child(UiBuilder.label(
        "Reputation      %s (%.0f)\nFan interest     %s (%.0f)\nFatigue          %s (%.0f)" % [
            FranchiseSimulator.reputation_label(franchise.reputation), franchise.reputation,
            FranchiseSimulator.fan_interest_label(franchise.fan_interest), franchise.fan_interest,
            FranchiseSimulator.fatigue_label(franchise.fatigue), franchise.fatigue], 14))
    list.add_child(UiBuilder.progress_meter("Fan interest", int(round(franchise.fan_interest)), "fans"))
    list.add_child(UiBuilder.progress_meter("Fatigue", int(round(franchise.fatigue)), "stress"))

    var gap := franchise.weeks_since_last_release()
    list.add_child(UiBuilder.label(
        "Last release     %s  (%d week%s ago)" % [
            franchise.last_release_label(), gap, "" if gap == 1 else "s"], 13))
    list.add_child(UiBuilder.label(
        "Average review   %.1f     Best entry   %.1f" % [
            franchise.average_review(), franchise.best_review()], 14))
    list.add_child(UiBuilder.label(
        "Lifetime         %s copies   ·   $%s" % [
            Format.exact(franchise.lifetime_units()),
            Format.exact(franchise.lifetime_revenue())], 15, true))
    list.add_child(UiBuilder.divider())

func _timeline() -> void:
    list.add_child(UiBuilder.heading("TIMELINE"))
    for game in franchise.entries():
        var status := "on sale, week %d" % game.weeks_on_market if game.sales_active else "finished"
        var row := Button.new()
        row.alignment = HORIZONTAL_ALIGNMENT_LEFT
        row.custom_minimum_size = Vector2(0, 118)
        row.add_theme_font_size_override("font_size", 13)
        row.text = "#%d  %s\n%s\n%s  %.1f\n%s copies   ·   $%s   ·   %s" % [
            game.sequel_number, game.title.to_upper(),
            game.release_date_label(),
            UiBuilder.score_bar(game.review_score), game.review_score,
            Format.count(game.lifetime_sales), Format.count(game.lifetime_revenue),
            status]
        row.pressed.connect(func():
            ScreenRouter.open_game(game.id, "res://scenes/studio/FranchiseDetailScreen.tscn")
            get_tree().change_scene_to_file("res://scenes/studio/GameDetailScreen.tscn"))
        list.add_child(row)
    list.add_child(UiBuilder.divider())

func _actions() -> void:
    var latest := franchise.entries()
    var sequel := UiBuilder.button("MAKE A SEQUEL")
    sequel.pressed.connect(func():
        var reference: GameProject = latest[latest.size() - 1] if not latest.is_empty() else null
        ScreenRouter.draft_project = {
            "title": FranchiseManager.suggested_sequel_title(franchise),
            "theme_id": reference.theme_id if reference != null else "",
            "genre_id": reference.genre_id if reference != null else "",
            "platform_id": reference.platform_id if reference != null else "",
            "series_id": franchise.id,
        }
        ScreenRouter.selected_team_id = ""
        get_tree().change_scene_to_file("res://scenes/development/NewGameScreen.tscn"))
    list.add_child(sequel)
