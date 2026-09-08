extends Control

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List

func _ready() -> void:
    GameClock.enter_gameplay(false)
    EventBus.week_ticked.connect(func(_y, _m, _w): _refresh())
    _refresh()

func _refresh() -> void:
    UiBuilder.clear(list)

    if GameState.news.is_empty():
        list.add_child(UiBuilder.label("No news yet.", 16, true))
        return

    for item in GameState.news:
        var date := TimeManager.format_date(
            int(item.get("year", 0)), int(item.get("month", 1)), int(item.get("week", 1)))
        list.add_child(UiBuilder.label("%s - %s" % [date, str(item.get("category", ""))], 12))
        list.add_child(UiBuilder.label(str(item.get("headline", "")), 17))
        list.add_child(UiBuilder.label(str(item.get("body", "")), 14))
        list.add_child(UiBuilder.divider())
