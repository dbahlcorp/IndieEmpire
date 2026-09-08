extends TestCase

## Effective contribution: a legible read on what morale, stress and workload
## are doing to somebody's real output right now. Deliberately a separate,
## simplified read for the player -- not the deep project-simulation maths in
## ProjectStaffSimulator.effects(), which also weighs attributes, experience,
## equipment and traits.

func run() -> void:
    _morale_multiplier()
    _stress_multiplier()
    _workload_shares_the_engine_curve()
    _composes_the_three()
    _a_healthy_performer()
    _the_same_performer_overworked()

func _person(skill_value: int = 72) -> Employee:
    var employee := Employee.new()
    employee.id = "test_employee"
    employee.programming = skill_value
    return employee

func _morale_multiplier() -> void:
    section("morale: 80 is the baseline everything else is judged against")
    check_approx(ContributionSimulator.morale_multiplier(80), 1.0, "80 is neutral")
    check_approx(ContributionSimulator.morale_multiplier(85), 1.05,
        "85 is a genuine, visible bonus")
    check_greater(ContributionSimulator.morale_multiplier(100),
        ContributionSimulator.morale_multiplier(80), "better morale is worth more")
    check_less(ContributionSimulator.morale_multiplier(0),
        ContributionSimulator.morale_multiplier(80), "and worse morale is worth less")

func _stress_multiplier() -> void:
    section("stress: unremarkable low, a real cost once it climbs")
    check_approx(ContributionSimulator.stress_multiplier(20), 0.98,
        "mild stress barely registers")
    check_approx(ContributionSimulator.stress_multiplier(75), 0.82,
        "heavy stress is a real tax")
    check_approx(ContributionSimulator.stress_multiplier(0), 1.0,
        "no stress at all costs nothing")
    check_less(ContributionSimulator.stress_multiplier(90),
        ContributionSimulator.stress_multiplier(75), "and it keeps getting worse")

func _workload_shares_the_engine_curve() -> void:
    section("workload reuses the same curve the real project simulation runs on")
    check_approx(ContributionSimulator.effective_contribution(_person(), "programming", 80)["workload"],
        ProjectStaffSimulator.workload_multiplier(80), "same function, not a lookalike")
    check_approx(ContributionSimulator.effective_contribution(_person(), "programming", 135)["workload"],
        ProjectStaffSimulator.workload_multiplier(135), "at an overloaded figure too")

func _composes_the_three() -> void:
    section("the total is exactly skill times the three multipliers, nothing hidden")
    var employee := _person(72)
    employee.morale = 85
    employee.stress = 20
    var result := ContributionSimulator.effective_contribution(employee, "programming", 80)
    check_equal(str(result["skill"]), "programming", "it knows which skill")
    check_equal(int(result["base"]), 72, "and the raw value")
    check_approx(float(result["total"]),
        float(result["base"]) * float(result["morale"]) * float(result["stress"])
            * float(result["workload"]),
        "base x morale x stress x workload")

func _a_healthy_performer() -> void:
    section("Maya, well-rested and not overloaded -- the mock-up, reproduced exactly")
    var maya := _person(72)
    maya.morale = 85
    maya.stress = 20
    var result := ContributionSimulator.effective_contribution(maya, "programming", 80)

    check_approx(float(result["morale"]), 1.05, "x1.05 morale")
    check_approx(float(result["stress"]), 0.98, "x0.98 stress")
    check_approx(float(result["workload"]), 1.00, "x1.00 workload")
    check_equal(int(round(float(result["total"]))), 74, "= ~74, as in the mock-up")
    check_greater(float(result["total"]), float(result["base"]),
        "good conditions are worth more than the raw number")

func _the_same_performer_overworked() -> void:
    section("the same person, run into the ground, is worth less than their raw skill")
    var rested := _person(72)
    rested.morale = 85
    rested.stress = 20
    var rested_result := ContributionSimulator.effective_contribution(rested, "programming", 80)

    var overworked := _person(72)
    overworked.morale = 75
    overworked.stress = 75
    var overworked_result := ContributionSimulator.effective_contribution(
        overworked, "programming", 135)

    check_less(float(overworked_result["total"]), float(overworked_result["base"]),
        "overworked output falls below the raw skill (%.1f vs %d)" % [
            overworked_result["total"], overworked_result["base"]])
    check_less(float(overworked_result["total"]), float(rested_result["total"]),
        "the same 72 programmer is worth noticeably less overworked (%.1f vs %.1f)" % [
            overworked_result["total"], rested_result["total"]])
