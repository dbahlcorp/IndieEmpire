class_name InflationSimulator
extends RefCounted

## Wages and rent both drift upward over the decades, so a 1985 salary and a
## 2020 salary read as different eras rather than the same numbers forever.
## The curve is a handful of year -> multiplier breakpoints authored in
## data/inflation.json (DataManager.inflation) and linearly interpolated
## between them -- approximate and fictionalized, not a real price index.

static func multiplier_for_year(year: int) -> float:
    var breakpoints: Array = DataManager.inflation
    if breakpoints.is_empty():
        return 1.0

    var first: Dictionary = breakpoints[0]
    if year <= int(first.get("year", 1985)):
        return float(first.get("multiplier", 1.0))

    var last: Dictionary = breakpoints[breakpoints.size() - 1]
    if year >= int(last.get("year", 2020)):
        return _extrapolate(breakpoints, year)

    for i in range(breakpoints.size() - 1):
        var a: Dictionary = breakpoints[i]
        var b: Dictionary = breakpoints[i + 1]
        var year_b := int(b.get("year", 0))
        if year <= year_b:
            var year_a := int(a.get("year", 0))
            var t := float(year - year_a) / float(maxi(year_b - year_a, 1))
            return lerpf(float(a.get("multiplier", 1.0)), float(b.get("multiplier", 1.0)), t)

    return float(last.get("multiplier", 1.0))

static func _extrapolate(breakpoints: Array, year: int) -> float:
    ## Past the authored curve, keep drifting at the final segment's rate
    ## rather than freezing the economy at the last breakpoint forever.
    if breakpoints.size() < 2:
        return float(breakpoints[breakpoints.size() - 1].get("multiplier", 1.0))
    var second_last: Dictionary = breakpoints[breakpoints.size() - 2]
    var last: Dictionary = breakpoints[breakpoints.size() - 1]
    var year_a := int(second_last.get("year", 2010))
    var mult_a := float(second_last.get("multiplier", 1.0))
    var year_b := int(last.get("year", 2020))
    var mult_b := float(last.get("multiplier", 1.0))
    var slope := (mult_b - mult_a) / float(maxi(year_b - year_a, 1))
    return mult_b + slope * float(year - year_b)
