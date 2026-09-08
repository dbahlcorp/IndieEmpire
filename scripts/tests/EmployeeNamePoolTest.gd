extends TestCase

## Generated candidate names come from data/first_names.json and
## data/last_names.json (DataManager.first_names / last_names), not a
## hardcoded list in code -- so new names, or a future locale, are a data
## change. See EmployeeManager._generated_name().

func run() -> void:
    _pools_are_loaded()
    _generated_names_come_from_the_pools()
    _an_explicit_name_bypasses_the_pools()

func _pools_are_loaded() -> void:
    section("the name pools loaded from data")
    check_not_empty(DataManager.first_names, "first names are loaded")
    check_not_empty(DataManager.last_names, "last names are loaded")

func _generated_names_come_from_the_pools() -> void:
    section("a generated candidate is named from the pools")
    for seed_value in [1, 2, 3, 4, 5]:
        var candidate := EmployeeManager.generate_candidate("programmer", "mid", "", seed_value)
        if not check_not_null(candidate, "a candidate was generated"):
            continue
        check_in(candidate.first_name, DataManager.first_names,
            "first name '%s' is one of the authored pool" % candidate.first_name)
        check_in(candidate.last_name, DataManager.last_names,
            "last name '%s' is one of the authored pool" % candidate.last_name)

func _an_explicit_name_bypasses_the_pools() -> void:
    section("a name typed in by hand is used as-is")
    var founder := EmployeeManager.generate_candidate("producer", "mid", "Zara Okafor", 7)
    if not check_not_null(founder, "the named candidate was generated"):
        return
    check_equal(founder.first_name, "Zara", "the given first name is kept")
    check_equal(founder.last_name, "Okafor", "and the given last name, even though neither is in the pools")
