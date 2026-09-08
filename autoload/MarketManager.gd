extends Node

## Owns genre trend and saturation state. Drift maths lives in TrendSimulator,
## demand maths in MarketSimulator.

func seed_trends() -> void:
    GameState.genre_trends.clear()
    GameState.genre_saturation.clear()
    for genre in DataManager.genres:
        GameState.genre_trends[str(genre.get("id", ""))] = TrendSimulator.starting_trend()
    GameState.weeks_until_trend_shift = TrendSimulator.PERIOD_WEEKS

func trend(genre_id: String) -> float:
    if not GameState.genre_trends.has(genre_id):
        return 1.0
    return float(GameState.genre_trends[genre_id])

func saturation(genre_id: String) -> float:
    return float(GameState.genre_saturation.get(genre_id, 0.0))

func demand_for(genre_id: String) -> float:
    return MarketSimulator.demand(trend(genre_id), saturation(genre_id))

func trend_label(genre_id: String) -> String:
    return TrendSimulator.label(trend(genre_id))

func trend_marker(genre_id: String) -> String:
    return TrendSimulator.marker(trend(genre_id))

func saturation_label(genre_id: String) -> String:
    return MarketSimulator.saturation_label(saturation(genre_id))

func register_release(genre_id: String, size_id: String = "small") -> void:
    var size := DataManager.get_size(size_id)
    var weight := float(size.get("sales_multiplier", 1.0))
    GameState.genre_saturation[genre_id] = MarketSimulator.add_saturation(saturation(genre_id), weight)

func process_week() -> void:
    for genre_id in GameState.genre_saturation.keys():
        var decayed := MarketSimulator.decay_saturation(float(GameState.genre_saturation[genre_id]))
        if decayed < 0.01:
            GameState.genre_saturation.erase(genre_id)
        else:
            GameState.genre_saturation[genre_id] = decayed

    GameState.weeks_until_trend_shift -= 1
    if GameState.weeks_until_trend_shift > 0:
        return

    GameState.weeks_until_trend_shift = TrendSimulator.PERIOD_WEEKS
    _shift_trends()

func _shift_trends() -> void:
    var risen := ""
    var fallen := ""
    var best := 0.0
    var worst := 0.0

    for genre in DataManager.genres:
        var id := str(genre.get("id", ""))
        if not UnlockManager.is_genre_unlocked(id):
            continue

        var before := trend(id)
        var after := TrendSimulator.drift(before)
        GameState.genre_trends[id] = after
        EventBus.genre_trend_changed.emit(id, before, after)

        var delta := after - before
        if delta > best:
            best = delta
            risen = str(genre.get("name", ""))
        if delta < worst:
            worst = delta
            fallen = str(genre.get("name", ""))

    NewsManager.post_trend_shift(risen, best, fallen, worst)

func unlocked_genres() -> Array:
    var result: Array = []
    for genre in DataManager.genres:
        if UnlockManager.is_genre_unlocked(str(genre.get("id", ""))):
            result.append(genre)
    return result

func unlocked_themes() -> Array:
    var result: Array = []
    for theme in DataManager.themes:
        if UnlockManager.is_theme_unlocked(str(theme.get("id", ""))):
            result.append(theme)
    return result

func unlocked_sizes() -> Array:
    var result: Array = []
    for size in DataManager.sizes:
        if UnlockManager.is_size_unlocked(str(size.get("id", ""))):
            result.append(size)
    return result
