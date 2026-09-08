extends Control

## What the player is allowed to know about the state of the industry. Never the
## raw multipliers — only the readable version.

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List

func _ready() -> void:
    GameClock.enter_gameplay(false)
    EventBus.week_ticked.connect(func(_y, _m, _w): _refresh())
    _refresh()

func _refresh() -> void:
    UiBuilder.clear(list)

    list.add_child(UiBuilder.heading("GENRES"))
    for genre in MarketManager.unlocked_genres():
        var id := str(genre.get("id", ""))
        var line := "%-2s %s\n   %s" % [
            MarketManager.trend_marker(id),
            genre.get("name", id),
            MarketManager.trend_label(id)
        ]
        var saturation := MarketManager.saturation_label(id)
        if not saturation.is_empty():
            line += " - %s" % saturation
        list.add_child(UiBuilder.identity_row(IdentityArtwork.genre_texture(id), line))

    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("PLATFORMS"))

    for platform in DataManager.platforms:
        if not PlatformManager.is_announced(platform):
            continue

        var users := PlatformManager.install_base(platform)
        var stage := PlatformManager.stage(platform)
        var platform_id := str(platform.get("id", ""))
        var platform_art := IdentityArtwork.platform_texture(platform_id)
        if users <= 0:
            list.add_child(UiBuilder.identity_row(platform_art, "%s\n%s" % [platform.get("name", "?"), stage], Vector2(52, 42)))
            continue

        list.add_child(UiBuilder.identity_row(platform_art, "%s\n%s users %s - %s" % [
            platform.get("name", "?"),
            Format.count(users),
            PlatformManager.trajectory_marker(platform),
            stage
        ], Vector2(52, 42)))

    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("CONSUMERS CURRENTLY FAVOUR"))
    list.add_child(UiBuilder.label(_favourites(), 15))

func _favourites() -> String:
    var ranked := MarketManager.unlocked_genres().duplicate()
    ranked.sort_custom(func(a, b):
        return MarketManager.trend(str(a.get("id", ""))) > MarketManager.trend(str(b.get("id", ""))))

    var text := ""
    for index in mini(3, ranked.size()):
        text += "%s\n" % ranked[index].get("name", "?")
    return text.strip_edges() if not text.is_empty() else "Nothing in particular."
