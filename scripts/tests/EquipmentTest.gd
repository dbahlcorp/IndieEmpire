extends TestCase

## Workstations: one machine per employee, bought once, from three tiers.
## No workstation is a real handicap, not a missed bonus; better tiers pay
## off in the disciplines that lean on hardware.

func run() -> void:
    _the_tiers()
    _no_workstation_penalty()
    _buying_one()
    _cannot_afford_it()
    _switching_tiers()
    _feeds_contribution_by_skill()
    _feeds_morale()
    _bulk_equip()
    _persistence()
    _unknown_tier_is_sanitised()

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(300_000, Ledger.Kind.OTHER, "seed")
    OfficeManager.move_to("shared_workspace")

func _person(role: String = "programmer") -> Employee:
    var candidate := EmployeeManager.generate_candidate(role, "mid")
    GameState.labor_candidates.append(candidate)
    LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)
    return candidate

func _the_tiers() -> void:
    section("three tiers, each strictly dearer, none of them free")
    check_equal(EquipmentSimulator.TIERS.size(), 3, "Basic, Standard, Pro")
    check(EquipmentSimulator.is_known_tier("basic"), "basic is real")
    check(EquipmentSimulator.is_known_tier("pro"), "pro is real")
    check(not EquipmentSimulator.is_known_tier("bedroom"), "and garbage is not")

    check_greater(float(EquipmentSimulator.cost("basic")), 0.0,
        "even the cheapest workstation costs something")
    check_greater(EquipmentSimulator.cost("standard"), EquipmentSimulator.cost("basic"),
        "Standard costs more than Basic")
    check_greater(EquipmentSimulator.cost("pro"), EquipmentSimulator.cost("standard"),
        "Pro costs more still")

    var art_paths := {}
    for tier in EquipmentSimulator.TIERS:
        var tier_id := str(tier["id"])
        var art_path := EquipmentSimulator.art_path(tier_id)
        check(not art_path.is_empty() and ResourceLoader.exists(art_path),
            "%s has a visible workstation asset" % tier_id)
        art_paths[art_path] = true
    check_equal(art_paths.size(), EquipmentSimulator.TIERS.size(),
        "every tier uses different art")

    check_empty(EquipmentSimulator.skill_bonus_lines("basic"),
        "Basic is the unremarkable baseline -- no named bonuses")
    check_equal(EquipmentSimulator.skill_bonus_percent("pro", "programming"), 4,
        "Pro's programming bonus matches the mock-up")
    check_equal(EquipmentSimulator.skill_bonus_percent("pro", "art"), 6,
        "and its art bonus")
    check_equal(EquipmentSimulator.skill_bonus_percent("pro", "design"), 0,
        "design is not a hardware-bound discipline, so no bonus there")

func _no_workstation_penalty() -> void:
    section("nothing beats having no computer at all")
    var basic := EquipmentSimulator.contribution_multiplier("basic", "programming")
    var none := EquipmentSimulator.contribution_multiplier("", "programming")
    check_less(none, basic, "unequipped is worse than the cheapest real option")
    check_approx(none, 1.0 - float(EquipmentSimulator.NO_WORKSTATION_PENALTY) / 100.0,
        "by exactly the authored penalty")
    check_approx(basic, 1.0, "Basic itself is neutral -- \"Normal\" productivity")
    check_greater(EquipmentSimulator.contribution_multiplier("pro", "art"), basic,
        "and Pro is a real step up")

func _buying_one() -> void:
    section("buying somebody a workstation")
    _company()
    var person := _person()
    check_empty(person.workstation_tier, "a fresh hire has nothing yet")

    var cash_before := GameState.cash
    var cost := EquipmentSimulator.cost("pro")
    var reported: Array = []
    var catcher := func(_e, tier): reported.append(tier)
    EventBus.employee_workstation_equipped.connect(catcher)

    check(OfficeManager.can_equip(person, "pro"), "the studio can afford it")
    check(OfficeManager.equip_workstation(person, "pro"), "and the purchase goes through")
    check_equal(person.workstation_tier, "pro", "they are equipped now")
    check_equal(GameState.cash, cash_before - cost, "paid in full, upfront")
    check_equal(reported, ["pro"], "the purchase was announced")
    EventBus.employee_workstation_equipped.disconnect(catcher)

    var equipment_line := false
    for entry in GameState.ledger:
        if int(entry.get("kind", -1)) == Ledger.Kind.EQUIPMENT:
            equipment_line = true
    check(equipment_line, "and written to the books as equipment")

func _cannot_afford_it() -> void:
    section("a workstation you cannot pay for is offered but refused")
    _company()
    var person := _person()
    GameState.cash = 100
    check(not OfficeManager.can_equip(person, "basic"), "even Basic is out of reach")
    check(not OfficeManager.equip_workstation(person, "basic"), "and the purchase refuses")
    check_empty(person.workstation_tier, "they are still unequipped")

func _switching_tiers() -> void:
    section("upgrading somebody who already has a machine")
    _company()
    var person := _person()
    GameState.cash = 50_000
    OfficeManager.equip_workstation(person, "basic")
    check(not OfficeManager.can_equip(person, "basic"), "buying the same tier again is a no-op")

    var cash_before := GameState.cash
    check(OfficeManager.equip_workstation(person, "pro"), "upgrading to Pro goes through")
    check_equal(person.workstation_tier, "pro", "they are on Pro now")
    check_equal(GameState.cash, cash_before - EquipmentSimulator.cost("pro"),
        "the full Pro price is charged -- no trade-in for the old Basic machine")

func _feeds_contribution_by_skill() -> void:
    section("equipment reaches the actual project maths, discipline by discipline")
    _company()
    var coder := _person("programmer")
    coder.programming = 70
    var designer := _person("designer")
    designer.design = 70

    var assignments := {"lead_programmer": coder.id, "game_designer": designer.id}
    var loads := {coder.id: 100, designer.id: 100}
    var team: Array[Employee] = [coder, designer]

    GameState.cash = 50_000
    OfficeManager.equip_workstation(coder, "basic")
    OfficeManager.equip_workstation(designer, "basic")
    var before := ProjectStaffSimulator.effects(assignments, team, loads, 0, 50.0, 8, 1)
    OfficeManager.equip_workstation(coder, "pro")
    OfficeManager.equip_workstation(designer, "pro")
    var after := ProjectStaffSimulator.effects(assignments, team, loads, 0, 50.0, 8, 1)

    check_greater(
        float(after["role_contributions"]["lead_programmer"]["effectiveness"]),
        float(before["role_contributions"]["lead_programmer"]["effectiveness"]),
        "a Pro machine measurably helps the programmer")
    check_approx(
        float(after["role_contributions"]["game_designer"]["effectiveness"]),
        float(before["role_contributions"]["game_designer"]["effectiveness"]),
        "but does nothing for the designer -- design is not what Pro is for")

func _feeds_morale() -> void:
    section("and how somebody feels about their own desk")
    _company()
    var founder := EmployeeManager.founder()
    var person := _person()

    var unequipped := _named(person, {"workload": 50, "workstation_tier": ""},
        "No workstation of their own")
    check_less(float(unequipped.get("morale", 0)), 0.0, "going without costs morale")

    var founder_context := MoraleSimulator.weekly_influences(founder, {"workload": 50, "workstation_tier": ""})
    var founder_named := false
    for influence in founder_context:
        if str(influence["cause"]) == "No workstation of their own":
            founder_named = true
    check(not founder_named, "but the founder chose the bedroom life -- no complaint from them")

    var standard := _named(person, {"workload": 50, "workstation_tier": "standard"}, "Decent workstation")
    check_greater(float(standard.get("morale", 0)), 0.0, "Standard is a small lift")
    var pro := _named(person, {"workload": 50, "workstation_tier": "pro"}, "Top-tier workstation")
    check_greater(float(pro.get("morale", 0)), float(standard.get("morale", 0)), "Pro more so")

func _bulk_equip() -> void:
    section("equipping everyone who is still missing one")
    _company()
    OfficeManager.move_to("small_office")
    GameState.cash = 50_000
    OfficeManager.equip_workstation(EmployeeManager.founder(), "basic")
    var a := _person("programmer")
    var b := _person("artist")
    var c := _person("designer")
    check_equal(OfficeManager.unequipped_employees().size(), 3,
        "the three new hires have nothing yet")

    var cash_before := GameState.cash
    var expected_cost := EquipmentSimulator.cost("basic") * 3
    var result := OfficeManager.equip_everyone_missing_one("basic")
    check(bool(result.get("ok")), "the bulk buy goes through")
    check_equal(int(result.get("count")), 3, "for all three people")
    check_equal(GameState.cash, cash_before - expected_cost, "charged once, for the lot")
    for person in [a, b, c]:
        check_equal(person.workstation_tier, "basic", "%s is equipped" % person.display_name())
    check(OfficeManager.unequipped_employees().is_empty(), "nobody is left without one")

    var again := OfficeManager.equip_everyone_missing_one("basic")
    check(not bool(again.get("ok")), "and there is nothing left to buy")

func _persistence() -> void:
    section("a workstation is remembered")
    _company()
    var person := _person()
    GameState.cash = 50_000
    OfficeManager.equip_workstation(person, "pro")

    var restored := Employee.from_dict(person.to_dict())
    check_equal(restored.workstation_tier, "pro", "survives a round trip")

    check(SaveManager.save_game("save_equipment"), "saved")
    GameState.reset_company()
    check(SaveManager.load_game("save_equipment"), "loaded")
    var reloaded := EmployeeManager.find_employee(person.id)
    if check_not_null(reloaded, "the employee came back"):
        check_equal(reloaded.workstation_tier, "pro", "with their workstation intact")
    SaveManager.delete_save("save_equipment")

func _unknown_tier_is_sanitised() -> void:
    section("a hand-edited or stale tier id is dropped rather than trusted")
    var data := Employee.new().to_dict()
    data["workstation_tier"] = "quantum_computer"
    var restored := Employee.from_dict(data)
    check_empty(restored.workstation_tier, "an unrecognised tier resets to unequipped")

func _named(employee: Employee, context: Dictionary, cause: String) -> Dictionary:
    for influence in MoraleSimulator.weekly_influences(employee, context):
        if str(influence["cause"]) == cause:
            return influence
    check(false, "expected an influence named '%s'" % cause)
    return {}
