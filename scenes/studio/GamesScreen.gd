extends Control

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List

func _ready() -> void:
    GameClock.enter_gameplay(false)
    EventBus.week_ticked.connect(func(_y, _m, _w): _refresh())
    _refresh()

func _refresh() -> void:
    UiBuilder.clear(list)

    if GameState.released_games.is_empty():
        list.add_child(UiBuilder.label("You have not released a game yet.", 16, true))
        return

    var ordered := GameState.released_games.duplicate()
    ordered.reverse()

    for game in ordered:
        list.add_child(_entry(game))
        list.add_child(UiBuilder.divider())

func _entry(game: GameProject) -> Control:
    var theme_name := DataManager.display_name(DataManager.themes, game.theme_id)
    var genre_name := DataManager.display_name(DataManager.genres, game.genre_id)

    var status := "on sale, week %d" % game.weeks_on_market if game.sales_active else "finished"
    var text := "%s\n%s %s\n\n%s  %.1f\n\nReleased %s\nLifetime sales %s\nRevenue $%s\n%s" % [
        game.title.to_upper(),
        theme_name,
        genre_name,
        UiBuilder.score_bar(game.review_score),
        game.review_score,
        game.release_date_label(),
        Format.count(game.lifetime_sales),
        Format.count(game.lifetime_revenue),
        status
    ]

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    var cover := GameCoverArt.new().configure(game)
    cover.custom_minimum_size = Vector2(86, 118)
    row.add_child(cover)

    var button := Button.new()
    button.text = text
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    button.custom_minimum_size = Vector2(0, 150)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.add_theme_font_size_override("font_size", 14)
    button.pressed.connect(_open.bind(game.id))
    row.add_child(button)
    return row

func _open(id: String) -> void:
    ScreenRouter.open_game(id, "res://scenes/studio/GamesScreen.tscn")
    get_tree().change_scene_to_file("res://scenes/studio/GameDetailScreen.tscn")
