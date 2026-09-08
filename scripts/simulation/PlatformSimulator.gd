class_name PlatformSimulator
extends RefCounted

## Pure platform maths against the authored per-year install base curves.

static func install_base(platform: Dictionary, year: int) -> int:
    var curve: Dictionary = platform.get("market_curve", {})
    if curve.has(str(year)):
        return int(curve[str(year)])
    # Outside the authored curve the platform simply is not a market.
    return 0

static func popularity(platform: Dictionary, current_users: int) -> float:
    ## Install base relative to the platform's own best year.
    var peak := maxi(int(platform.get("peak_users", 1)), 1)
    return clampf(float(current_users) / float(peak), 0.0, 1.0)

static func trajectory(current_users: int, next_year_users: int) -> int:
    ## -1 shrinking, 0 flat, 1 growing.
    if next_year_users > int(current_users * 1.05):
        return 1
    if next_year_users < int(current_users * 0.95):
        return -1
    return 0

static func stage(platform: Dictionary, year: int, current_users: int, direction: int) -> String:
    var release_year := int(platform.get("release_year", 0))
    if year < release_year:
        return "Announced"
    if current_users <= 0:
        return "Discontinued"

    var peak_year := int(platform.get("peak_year", release_year))
    if year < peak_year:
        return "Growing"
    if year == peak_year:
        return "Peak"
    if direction < 0:
        return "Declining"
    return "Legacy"
