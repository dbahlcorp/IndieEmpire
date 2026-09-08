extends Node

## Owns platform lifecycle: which hardware exists right now, how big it is, and
## announcing the moments it changes. Curve maths lives in PlatformSimulator.

var _last_year: int = TimeManager.START_YEAR

func sync_year() -> void:
    _last_year = TimeManager.current_year

func install_base(platform: Dictionary, year: int = -1) -> int:
    var wanted := year if year > 0 else TimeManager.current_year
    return PlatformSimulator.install_base(platform, wanted)

func is_on_sale(platform: Dictionary) -> bool:
    return install_base(platform) > 0

func is_announced(platform: Dictionary) -> bool:
    return TimeManager.current_year >= int(platform.get("announce_year", 9999))

func popularity(platform: Dictionary) -> float:
    return PlatformSimulator.popularity(platform, install_base(platform))

func trajectory(platform: Dictionary) -> int:
    return PlatformSimulator.trajectory(
        install_base(platform), install_base(platform, TimeManager.current_year + 1))

func trajectory_marker(platform: Dictionary) -> String:
    ## Derived from the stage so the arrow can never contradict the word next
    ## to it (a platform at its peak used to read "Peak v").
    match stage(platform):
        "Growing":
            return "^"
        "Peak":
            return "="
        "Declining", "Legacy":
            return "v"
        _:
            return "-"

func stage(platform: Dictionary) -> String:
    if not is_announced(platform):
        return "Unannounced"
    return PlatformSimulator.stage(
        platform, TimeManager.current_year, install_base(platform), trajectory(platform))

func available_platforms() -> Array:
    var available: Array = []
    for platform in DataManager.platforms:
        if is_on_sale(platform):
            available.append(platform)
    return available

func process_year_change() -> void:
    var year := TimeManager.current_year
    if year == _last_year:
        return

    var previous := _last_year
    _last_year = year
    EventBus.year_changed.emit(year)

    for platform in DataManager.platforms:
        var id := str(platform.get("id", ""))

        if int(platform.get("announce_year", 9999)) == year:
            EventBus.platform_announced.emit(platform)

        if int(platform.get("release_year", 9999)) == year:
            if not GameState.known_platforms.has(id):
                GameState.known_platforms.append(id)
            EventBus.platform_released.emit(platform)

        if int(platform.get("retire_year", 9999)) == year:
            EventBus.platform_retiring.emit(platform)

        if install_base(platform, previous) > 0 and install_base(platform, year) <= 0:
            EventBus.platform_discontinued.emit(platform)
