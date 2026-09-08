extends Node

## Owns which content the studio has access to, and announces new arrivals.

func is_genre_unlocked(id: String) -> bool:
    return GameState.unlocked_genres.has(id)

func is_theme_unlocked(id: String) -> bool:
    return GameState.unlocked_themes.has(id)

func is_size_unlocked(id: String) -> bool:
    return GameState.unlocked_sizes.has(id)

func _meets(entry: Dictionary) -> bool:
    var year_ok := TimeManager.current_year >= int(entry.get("unlock_year", 1985))
    var games_ok := GameState.released_games.size() >= int(entry.get("unlock_games", 0))
    return year_ok and games_ok

func refresh(announce: bool = true) -> Array:
    var unlocked: Array = []

    for genre in DataManager.genres:
        var id := str(genre.get("id", ""))
        if not is_genre_unlocked(id) and _meets(genre):
            GameState.unlocked_genres.append(id)
            var name := str(genre.get("name", id))
            unlocked.append({"kind": "genre", "id": id, "name": name})
            if announce:
                EventBus.genre_unlocked.emit(id, name)

    for theme in DataManager.themes:
        var id := str(theme.get("id", ""))
        if not is_theme_unlocked(id) and _meets(theme):
            GameState.unlocked_themes.append(id)
            var name := str(theme.get("name", id))
            unlocked.append({"kind": "theme", "id": id, "name": name})
            if announce:
                EventBus.theme_unlocked.emit(id, name)

    for size in DataManager.sizes:
        var id := str(size.get("id", ""))
        if not is_size_unlocked(id) and _meets(size):
            GameState.unlocked_sizes.append(id)
            var name := str(size.get("name", id))
            unlocked.append({"kind": "size", "id": id, "name": name})
            if announce:
                EventBus.size_unlocked.emit(id, name)

    for platform in DataManager.platforms:
        var id := str(platform.get("id", ""))
        if PlatformManager.is_on_sale(platform) and not GameState.known_platforms.has(id):
            GameState.known_platforms.append(id)

    return unlocked
