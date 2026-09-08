class_name TestCase
extends Node

## Base class for the project's tests.
##
## `assert()` is the wrong tool here: Godot strips it from release builds, it
## aborts on the first failure so you only ever see one problem at a time, and
## it prints nothing about what was actually wrong. These checks always run,
## report every failure with the offending values, and set a non-zero exit code
## so a failing run cannot be mistaken for a passing one.
##
## Subclass it, override `run()`, and point a .tscn at the script:
##
##     godot --headless --path . res://scripts/tests/MyTest.tscn

var _failures: Array[String] = []
var _passed := 0
var _section := ""

func _ready() -> void:
    var title := test_name()
    print("=== %s ===" % title)
    # `run()` may be a coroutine when a test needs to wait for frames or timers.
    # Awaiting a plain call is harmless, and without this the report would be
    # written before an async test had run a single check.
    await run()
    _report(title)

func run() -> void:
    push_error("A TestCase must override run().")

func test_name() -> String:
    var script: Script = get_script()
    if script == null:
        return "TestCase"
    return str(script.resource_path).get_file().get_basename()

func section(title: String) -> void:
    _section = title
    print("")
    print("-- %s --" % title)

# --- Checks ------------------------------------------------------------
# Every check returns whether it passed, so a caller can bail out of a block
# whose later steps would crash on the bad value.

func check(condition: bool, label: String) -> bool:
    if condition:
        _passed += 1
        return true
    var prefix := "%s: " % _section if not _section.is_empty() else ""
    var entry := prefix + label
    _failures.append(entry)
    printerr("  FAIL %s" % entry)
    return false

func check_equal(actual, expected, label: String) -> bool:
    return check(actual == expected,
        "%s -- expected %s, got %s" % [label, _show(expected), _show(actual)])

func check_not_equal(actual, unwanted, label: String) -> bool:
    return check(actual != unwanted, "%s -- should not have been %s" % [label, _show(unwanted)])

func check_approx(actual: float, expected: float, label: String) -> bool:
    return check(is_equal_approx(actual, expected),
        "%s -- expected %.4f, got %.4f" % [label, expected, actual])

func check_near(actual: float, expected: float, tolerance: float, label: String) -> bool:
    ## For values a simulation produces rather than computes exactly. Anything
    ## averaged over randomised trials lands *near* its expectation, never on
    ## it, so check_approx() is the wrong tool -- it demands float equality and
    ## only passes when something (usually a clamp) has quietly flattened both
    ## sides onto the same number.
    return check(absf(actual - expected) <= tolerance,
        "%s -- %.4f is not within %.4f of %.4f" % [label, actual, tolerance, expected])

func check_greater(actual: float, threshold: float, label: String) -> bool:
    return check(actual > threshold,
        "%s -- %.4f is not greater than %.4f" % [label, actual, threshold])

func check_less(actual: float, threshold: float, label: String) -> bool:
    return check(actual < threshold,
        "%s -- %.4f is not less than %.4f" % [label, actual, threshold])

func check_between(actual: float, low: float, high: float, label: String) -> bool:
    return check(actual >= low and actual <= high,
        "%s -- %.4f is outside %.4f..%.4f" % [label, actual, low, high])

func check_not_null(value, label: String) -> bool:
    return check(value != null, "%s -- was null" % label)

func check_null(value, label: String) -> bool:
    return check(value == null, "%s -- expected null, got %s" % [label, _show(value)])

func check_in(value, allowed: Array, label: String) -> bool:
    return check(value in allowed,
        "%s -- %s is not one of %s" % [label, _show(value), _show(allowed)])

func check_empty(value, label: String) -> bool:
    return check(value.is_empty(), "%s -- was %s" % [label, _show(value)])

func check_not_empty(value, label: String) -> bool:
    return check(not value.is_empty(), "%s -- was empty" % label)

func _show(value) -> String:
    if value is float:
        return "%.4f" % value
    if value is String:
        return "\"%s\"" % value
    return str(value)

# --- Result ------------------------------------------------------------

func _report(title: String) -> void:
    print("")
    if _passed == 0 and _failures.is_empty():
        printerr("%s ran no checks at all -- that is a failing test, not a passing one." % title)
        get_tree().quit(1)
        return

    if _failures.is_empty():
        print("%s PASSED (%d checks)" % [title, _passed])
        get_tree().quit(0)
        return

    printerr("%s FAILED: %d of %d checks" % [title, _failures.size(), _passed + _failures.size()])
    for failure in _failures:
        printerr("  - %s" % failure)
    get_tree().quit(1)
