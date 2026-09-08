class_name ContributionSimulator
extends RefCounted

## A legible read on what morale, stress and workload are doing to somebody's
## real output right now -- for the player to actually read at a glance, not
## a restatement of the deep project maths. ProjectStaffSimulator.effects()
## is the real simulation and also weighs attributes, experience, equipment
## and traits; this is deliberately just the three levers the player watches
## and manages directly, so the cost of running someone into the ground is
## visible instead of buried inside a dozen other multipliers.

static func morale_multiplier(morale: int) -> float:
    ## 80 is the baseline used everywhere morale is graded in this game.
    ## Above it is a genuine bonus, below it a genuine cost.
    const BASELINE := 80.0
    const ANCHOR_MORALE := 85.0
    const ANCHOR_MULT := 1.05
    var slope := (ANCHOR_MULT - 1.0) / (ANCHOR_MORALE - BASELINE)
    return clampf(1.0 + (float(morale) - BASELINE) * slope, 0.5, 1.3)

static func stress_multiplier(stress: int) -> float:
    ## Mild stress costs nothing -- it only starts to bite past a real level
    ## of pressure, and bites hard once somebody is at risk of burning out.
    const ANCHOR_STRESS := 20.0
    const ANCHOR_MULT := 0.98
    const HEAVY_STRESS := 75.0
    const HEAVY_MULT := 0.82
    var slope := (HEAVY_MULT - ANCHOR_MULT) / (HEAVY_STRESS - ANCHOR_STRESS)
    return clampf(ANCHOR_MULT + (float(stress) - ANCHOR_STRESS) * slope, 0.4, 1.0)

static func effective_contribution(employee: Employee, skill: String, workload_percent: int) -> Dictionary:
    var base := float(employee.get(skill))
    var morale := morale_multiplier(employee.morale)
    var stress := stress_multiplier(employee.stress)
    # Shares the same overload curve the real project simulation runs on --
    # under 100% is no penalty, and it steepens the same way past it.
    var workload := ProjectStaffSimulator.workload_multiplier(workload_percent)
    return {
        "skill": skill, "base": base,
        "morale": morale, "stress": stress, "workload": workload,
        "total": base * morale * stress * workload
    }
