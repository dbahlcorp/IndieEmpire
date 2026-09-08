extends TestCase

func run() -> void:
    section("CEO appearance")
    GameState.start_company("Look Test", "Alex Morgan", "normal", "she", 2)
    var founder := EmployeeManager.founder()
    if not check_not_null(founder, "a CEO was created"):
        return
    check_equal(founder.appearance_index, 2, "the selected appearance reaches the CEO")
    check_equal(founder.pronoun_id, "she", "the selected pronouns reach the CEO")
    check_equal(founder.display_name(), "Alex Morgan", "the selected name reaches the CEO")
    check(OfficeCharacterArt.sheet_for_employee(founder) == OfficeCharacterArt.SHEETS[2],
        "the office uses the selected animation sheet")

    var restored := Employee.from_dict(founder.to_dict())
    check_equal(restored.appearance_index, 2, "the appearance survives serialization")
    restored.appearance_index = 1
    check(OfficeCharacterArt.sheet_for_employee(restored) == OfficeCharacterArt.SHEETS[1],
        "changing the appearance changes every animation")

    var legacy := Employee.new()
    legacy.portrait_seed = 7
    check_not_null(OfficeCharacterArt.sheet_for_employee(legacy),
        "employees from older saves retain a deterministic appearance")
