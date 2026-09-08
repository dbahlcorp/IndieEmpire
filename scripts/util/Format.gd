class_name Format
extends RefCounted

## Two ways to show a number: compact for dashboards, exact for the books.
## Financial detail pages always use the exact form.

const THOUSAND := 1000.0
const MILLION := 1000000.0
const BILLION := 1000000000.0

static func exact(value: int) -> String:
    var sign_prefix := "-" if value < 0 else ""
    var text := str(absi(value))
    var out := ""
    while text.length() > 3:
        out = "," + text.substr(text.length() - 3, 3) + out
        text = text.substr(0, text.length() - 3)
    return sign_prefix + text + out

static func compact(value: int) -> String:
    var sign_prefix := "-" if value < 0 else ""
    var size := absi(value)

    if size < 10000:
        return sign_prefix + exact(size)
    if size < MILLION:
        return "%s%s" % [sign_prefix, _trim(float(size) / THOUSAND, "K")]
    if size < BILLION:
        return "%s%s" % [sign_prefix, _trim(float(size) / MILLION, "M")]
    return "%s%s" % [sign_prefix, _trim(float(size) / BILLION, "B")]

static func _trim(value: float, suffix: String) -> String:
    ## One decimal, but never a pointless ".0".
    var text := "%.1f" % value
    if text.ends_with(".0"):
        text = text.substr(0, text.length() - 2)
    return text + suffix

static func money(value: int) -> String:
    return "$%s" % compact(value)

static func money_exact(value: int) -> String:
    return "$%s" % exact(value)

## Setting-aware helpers. Dashboards call these; financial pages call the
## explicit exact/money_exact forms so the books always read precisely.
static func count(value: int) -> String:
    return compact(value) if Settings.compact_numbers else exact(value)

static func display(value: int) -> String:
    return money(value) if Settings.compact_numbers else money_exact(value)

static func signed_money(value: int) -> String:
    var sign_text := "+" if value >= 0 else "-"
    return "%s$%s" % [sign_text, exact(absi(value))]

static func runway_label(months: float) -> String:
    ## Shared phrasing for a cash-runway estimate, wherever it's shown.
    if is_inf(months):
        return "No burn"
    if months <= 0.0:
        return "Overdrawn"
    return "%.1f months" % months
