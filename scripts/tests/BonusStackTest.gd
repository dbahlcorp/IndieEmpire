extends TestCase

## The rules BonusStack exists to enforce. These are cheap, deterministic
## checks on the maths itself -- the balance probe measures what it does to a
## career, this pins down what it promises.

func run() -> void:
    _nothing_is_no_bonus()
    _within_a_category_parts_add_rather_than_multiply()
    _each_category_is_capped_on_its_own()
    _everything_at_once_is_capped_too()
    _penalties_are_not_capped()
    _the_stack_beats_multiplying_at_every_scale()

func _nothing_is_no_bonus() -> void:
    section("an empty stack changes nothing")
    check_approx(BonusStack.combine({}), 1.0, "no parts is no bonus")
    check_approx(BonusStack.combine({BonusStack.TEAM: [1.0, 1.0]}), 1.0,
        "neutral parts are no bonus")

func _within_a_category_parts_add_rather_than_multiply() -> void:
    section("within a category, parts add")
    # Two +4% sources come to +8%, not the +8.16% multiplying them would give.
    # Small on its own; the point is that it stays small as sources pile up.
    var combined := BonusStack.combine({BonusStack.KNOWLEDGE: [1.04, 1.04]})
    check_near(combined, 1.08, 0.0001, "1.04 and 1.04 make +8%%, not +8.16%%")
    check_less(combined, 1.04 * 1.04, "which is strictly less than multiplying them")

func _each_category_is_capped_on_its_own() -> void:
    section("each category has its own ceiling")
    for category in BonusStack.CATEGORY_CAP:
        var cap := float(BonusStack.CATEGORY_CAP[category])
        # Five sources that would multiply to roughly +61%.
        var greedy := BonusStack.combine({category: [1.1, 1.1, 1.1, 1.1, 1.1]})
        check_near(greedy, 1.0 + cap, 0.0001,
            "%s stops at +%.0f%% however many sources pile in" % [category, cap * 100.0])

func _everything_at_once_is_capped_too() -> void:
    section("and everything at once has a ceiling above those")
    var everything := {}
    for category in BonusStack.CATEGORY_CAP:
        everything[category] = [2.0, 2.0]
    var maxed := BonusStack.combine(everything)
    check_near(maxed, 1.0 + BonusStack.TOTAL_CAP, 0.0001,
        "every category maxed comes to +%.0f%%" % (BonusStack.TOTAL_CAP * 100.0))
    # The total cap has to be reachable, or the per-category caps below it are
    # decoration -- a studio that has genuinely invested everywhere should feel
    # the difference against one that has invested in one thing.
    var one_category := BonusStack.combine({BonusStack.TEAM: [2.0]})
    check_greater(maxed, one_category,
        "investing everywhere beats investing in one place (%.2f vs %.2f)"
            % [maxed, one_category])

func _penalties_are_not_capped() -> void:
    section("penalties are not capped -- only the upside is bounded")
    # A category cap of +8% must not become a -8% floor: a studio with no
    # workstations and miserable staff should feel all of it.
    var miserable := BonusStack.combine({BonusStack.FACILITIES: [0.7, 0.7]})
    check_near(miserable, 0.4, 0.0001, "two -30%% sources come to -60%%, uncapped")
    check_less(miserable, 1.0 - float(BonusStack.CATEGORY_CAP[BonusStack.FACILITIES]),
        "which is well past what the positive cap would have allowed")
    # A mixed category nets out before the cap applies, so a penalty really
    # does cancel a bonus rather than being hidden by it.
    check_near(BonusStack.combine({BonusStack.TEAM: [1.2, 0.8]}), 1.0, 0.0001,
        "a +20%% and a -20%% in the same category cancel")

func _the_stack_beats_multiplying_at_every_scale() -> void:
    section("the runaway it exists to stop")
    # The measured maxed-studio case from artifacts/bonus-stack-2026-09-08:
    # thirteen positive systems, each individually reasonable.
    var parts := [1.08, 1.08, 1.08, 1.21, 1.11, 1.25, 1.04, 1.05, 1.20, 1.03, 1.075]
    var multiplied := 1.0
    for part in parts:
        multiplied *= part
    check_greater(multiplied, 2.0,
        "multiplied, eleven small bonuses come to %+.0f%%" % ((multiplied - 1.0) * 100.0))
    # Spread across the categories they actually belong to, the same inputs are
    # bounded by the total cap however they are distributed.
    var spread := BonusStack.combine({
        BonusStack.KNOWLEDGE: [parts[0], parts[1], parts[2]],
        BonusStack.STRATEGY: [parts[3], parts[4]],
        BonusStack.FACILITIES: [parts[5], parts[6]],
        BonusStack.TEAM: [parts[7], parts[8], parts[9], parts[10]]
    })
    check_less(spread, 1.0 + BonusStack.TOTAL_CAP + 0.0001,
        "capped, they come to %+.0f%%" % ((spread - 1.0) * 100.0))
    check_less(spread, multiplied * 0.75,
        "which is a fraction of the runaway (%.2f vs %.2f)" % [spread, multiplied])
