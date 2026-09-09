extends Node

## Owns office progression and headcount capacity. Comfort and productivity are
## authored now so condition and output systems can consume them later.

func current_office() -> Dictionary:
    var office := DataManager.get_office(GameState.office_id)
    return office if not office.is_empty() else DataManager.get_office("bedroom")

func capacity() -> int:
    return int(current_office().get("capacity", 1))

func headcount() -> int:
    return EmployeeManager.active_employees().size()

func remaining_capacity() -> int:
    return maxi(capacity() - headcount(), 0)

func has_capacity(amount: int = 1) -> bool:
    return headcount() + amount <= capacity()

func can_move_to(office_id: String) -> bool:
    var target := DataManager.get_office(office_id)
    if target.is_empty() or office_id == GameState.office_id:
        return false
    # M3 offices form a readable ladder; a profitable studio cannot jump from
    # the bedroom directly to the final floor.
    if int(target.get("tier", 0)) != int(current_office().get("tier", 0)) + 1:
        return false
    if int(target.get("capacity", 1)) < headcount():
        return false
    return FinanceManager.can_afford(move_in_cost(target))

func move_in_cost(office: Dictionary = {}) -> int:
    ## Drifts with the times, exactly as rent and salaries do. Without this a
    ## 2050 studio bought a campus at 1985 prices while paying 2050 wages in it,
    ## and the largest offices stopped being a decision late on.
    var target := office if not office.is_empty() else current_office()
    var inflated := float(target.get("move_in_cost", 0)) * InflationSimulator.multiplier_for_year(
        TimeManager.current_year)
    return FinanceManager.expense(int(round(inflated)))

func move_to(office_id: String) -> bool:
    if not can_move_to(office_id):
        return false
    var target := DataManager.get_office(office_id)
    var cost := move_in_cost(target)
    if not FinanceManager.spend(cost, Ledger.Kind.OFFICE_MOVE,
        "Move to %s" % target.get("name", "office")):
        return false
    GameState.office_id = office_id
    sync_office_quality()
    EventBus.office_moved.emit(target)
    EventBus.notify("NEW OFFICE", "The studio moved into %s" % target.get("name", "a new office"), true)
    SaveManager.autosave()
    return true

func cheaper_office() -> Dictionary:
    ## The office one tier down, or {} if already at the bottom. The ladder is
    ## walked one rung at a time downward, exactly as it is upward.
    var current_tier := int(current_office().get("tier", 0))
    if current_tier <= 0:
        return {}
    for office in DataManager.offices:
        if int(office.get("tier", -1)) == current_tier - 1:
            return office
    return {}

func can_downgrade() -> bool:
    var target := cheaper_office()
    if target.is_empty():
        return false
    # A smaller office cannot hold more people than it has desks.
    return int(target.get("capacity", 0)) >= headcount()

func downgrade_cost(target: Dictionary = {}) -> int:
    ## Moving *out* is cheap next to moving up -- a deposit and a van, a small
    ## fraction of what the smaller place would cost to move into fresh.
    var office := target if not target.is_empty() else cheaper_office()
    if office.is_empty():
        return 0
    var inflated := float(office.get("move_in_cost", 0)) * 0.15 * InflationSimulator.multiplier_for_year(
        TimeManager.current_year)
    return FinanceManager.expense(int(round(inflated)))

func downgrade() -> Dictionary:
    ## A crisis lever: give up space to cut rent now. Forced through even when
    ## cash is tight -- that is the whole point of it.
    if not can_downgrade():
        return {"ok": false, "reason": "The next office down cannot hold the current team."}
    var target := cheaper_office()
    var cost := downgrade_cost(target)
    var rent_before := monthly_rent()
    if cost > 0:
        FinanceManager.force_spend(cost, Ledger.Kind.OFFICE_MOVE,
            "Move to %s" % target.get("name", "a smaller office"))
    GameState.office_id = str(target.get("id", GameState.office_id))
    sync_office_quality()
    OfficeCustomizationManager.validate_remodel()
    EventBus.office_moved.emit(target)
    EventBus.notify("DOWNSIZED",
        "The studio moved into %s to cut costs" % target.get("name", "a smaller office"), true)
    SaveManager.autosave()
    return {
        "ok": true,
        "cost": cost,
        "rent_saved": maxi(rent_before - monthly_rent(), 0),
        "office": str(target.get("name", "")),
    }

func sync_office_quality() -> void:
    GameState.office_quality = int(current_office().get("quality", 0))

func monthly_rent(office: Dictionary = {}) -> int:
    ## Rent drifts with the times same as salaries do, so a decades-long
    ## playthrough does not end up paying 1985 rent forever. See InflationSimulator.
    var target := office if not office.is_empty() else current_office()
    var inflated := float(target.get("rent", 0)) * InflationSimulator.multiplier_for_year(
        TimeManager.current_year)
    return FinanceManager.expense(int(round(inflated)))

# --- Workstations ----------------------------------------------------------
## One machine per employee, bought once, from three coarse tiers. See
## EquipmentSimulator for what each tier is worth and what none costs you.

func productivity() -> int:
    return int(current_office().get("productivity", 0))

func recruiting_quality() -> int:
    return int(current_office().get("quality", GameState.office_quality))

func unequipped_employees() -> Array[Employee]:
    var result: Array[Employee] = []
    for employee in EmployeeManager.active_employees():
        if employee.workstation_tier.is_empty():
            result.append(employee)
    return result

func can_equip(employee: Employee, tier_id: String) -> bool:
    if employee == null or not employee.is_active() or not EquipmentSimulator.is_known_tier(tier_id):
        return false
    if employee.workstation_tier == tier_id:
        return false
    return FinanceManager.can_afford(EquipmentSimulator.cost(tier_id))

func equip_workstation(employee: Employee, tier_id: String) -> bool:
    if not can_equip(employee, tier_id):
        return false
    var cost := EquipmentSimulator.cost(tier_id)
    if not FinanceManager.spend(cost, Ledger.Kind.EQUIPMENT,
            "%s workstation for %s" % [EquipmentSimulator.name_of(tier_id), employee.display_name()]):
        return false
    employee.workstation_tier = tier_id
    EventBus.employee_workstation_equipped.emit(employee, tier_id)
    SaveManager.autosave()
    return true

func equip_everyone_missing_one(tier_id: String = "basic") -> Dictionary:
    ## Buys the same tier for every employee who has nothing yet, all at once
    ## or not at all -- the cost shown before confirming is the cost charged.
    var missing := unequipped_employees()
    if missing.is_empty() or not EquipmentSimulator.is_known_tier(tier_id):
        return {"ok": false, "reason": "everyone is already equipped"}
    var total := EquipmentSimulator.cost(tier_id) * missing.size()
    if not FinanceManager.spend(total, Ledger.Kind.EQUIPMENT,
            "%s workstations for %d people" % [EquipmentSimulator.name_of(tier_id), missing.size()]):
        return {"ok": false, "reason": "unaffordable", "cost": total}
    for employee in missing:
        employee.workstation_tier = tier_id
        EventBus.employee_workstation_equipped.emit(employee, tier_id)
    SaveManager.autosave()
    return {"ok": true, "count": missing.size(), "cost": total}

func description(office: Dictionary) -> String:
    return "Capacity        %d\nRent            $%s / month\nComfort         %s\nPrestige        %s\nProductivity    +%d%%\nExpansion slots %d" % [
        int(office.get("capacity", 1)),
        Format.exact(monthly_rent(office)),
        str(office.get("comfort", "Poor")),
        str(office.get("prestige", "None")),
        int(office.get("productivity", 0)),
        int(office.get("expansion_slots", 0))
    ]
