class_name EmployeeTraitSimulator
extends RefCounted

## Pure trait maths. A trait is an authored entry in data/employee_traits.json
## with a structured `effects` block; this file is the one place that reads
## that block and turns an employee's list of traits into the numbers the
## rest of the simulation multiplies in. No state, no manager -- the callers
## (ProjectStaffSimulator, MoraleSimulator, TrainingSimulator,
## EmployeeValueSimulator, TeamManager, EmployeeManager) already own the
## behaviour; they just stopped hardcoding trait ids one by one.
##
## Effect keys understood here:
##   skill_contribution: {<skill>: mult, "all": mult}  -- per-discipline output
##   polish_multiplier / speed_multiplier / innovation_multiplier  -- project modifiers
##   overload_work_factor   -- scales the >100% workload excess on real output
##   overload_morale_factor -- scales that excess on the morale hit
##   xp_multiplier          -- experience and training gain
##   teamwork_delta         -- flat points into a team's chemistry target
## and, alongside `effects`, a top-level `market_value` float.
##
## Aggregation rule: multipliers compose (product), deltas add. Missing keys
## are the identity (1.0 / 0.0), so a trait only moves the levers it names and
## a plain employee is untouched.

static func effects_of(trait_id: String) -> Dictionary:
    return DataManager.get_employee_trait(trait_id).get("effects", {})

static func _product(employee: Employee, key: String) -> float:
    var total := 1.0
    if employee == null:
        return total
    for trait_id in employee.trait_ids:
        var effects := effects_of(str(trait_id))
        if effects.has(key):
            total *= float(effects[key])
    return total

static func _sum(employee: Employee, key: String) -> float:
    var total := 0.0
    if employee == null:
        return total
    for trait_id in employee.trait_ids:
        var effects := effects_of(str(trait_id))
        if effects.has(key):
            total += float(effects[key])
    return total

static func skill_contribution_multiplier(employee: Employee, skill: String) -> float:
    var total := 1.0
    if employee == null:
        return total
    for trait_id in employee.trait_ids:
        var contribution: Dictionary = effects_of(str(trait_id)).get("skill_contribution", {})
        if contribution.has("all"):
            total *= float(contribution["all"])
        if contribution.has(skill):
            total *= float(contribution[skill])
    return total

static func polish_multiplier(employee: Employee) -> float:
    return _product(employee, "polish_multiplier")

static func speed_multiplier(employee: Employee) -> float:
    return _product(employee, "speed_multiplier")

static func innovation_multiplier(employee: Employee) -> float:
    return _product(employee, "innovation_multiplier")

static func overload_work_factor(employee: Employee) -> float:
    return _product(employee, "overload_work_factor")

static func overload_morale_factor(employee: Employee) -> float:
    return _product(employee, "overload_morale_factor")

static func xp_multiplier(employee: Employee) -> float:
    return _product(employee, "xp_multiplier")

static func teamwork_delta(employee: Employee) -> float:
    return _sum(employee, "teamwork_delta")

static func market_value_sum(employee: Employee) -> float:
    ## The additive contribution of every trait to EmployeeValueSimulator's
    ## multiplier, before that function's own clamp.
    var total := 0.0
    if employee == null:
        return total
    for trait_id in employee.trait_ids:
        total += float(DataManager.get_employee_trait(str(trait_id)).get("market_value", 0.0))
    return total

static func generated_pool() -> Array:
    ## Trait ids an ordinary generated candidate may roll. A trait opts out
    ## with "generated": false; the founder-choice screen still offers it.
    var pool: Array = []
    for entry in DataManager.employee_traits:
        if bool(entry.get("generated", true)):
            pool.append(str(entry.get("id", "")))
    if pool.is_empty():
        pool.append("perfectionist")
    return pool
