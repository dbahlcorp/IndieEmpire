extends TestCase

## How the game refers to the people who work for you.

func run() -> void:
    _the_three_sets()
    _agreement()
    _the_founder_chooses()
    _candidates_get_them()
    _a_name_is_not_pronouns()
    _the_sentences()
    _persistence()
    _old_saves()

func _company(pronoun_id: String = "they") -> void:
    GameState.start_company("Nova", "Darren", "normal", pronoun_id)
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(300_000, Ledger.Kind.OTHER, "seed")
    OfficeManager.move_to("shared_workspace")

func _hire() -> Employee:
    var candidate := EmployeeManager.generate_candidate("programmer", "mid")
    GameState.labor_candidates.append(candidate)
    LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)
    return candidate

func _the_three_sets() -> void:
    section("the sets on offer")
    check_equal(Pronouns.SETS.size(), 3, "three to choose from")
    check_equal(Pronouns.label("she"), "She / her", "she/her")
    check_equal(Pronouns.label("he"), "He / him", "he/him")
    check_equal(Pronouns.label("they"), "They / them", "they/them")
    check_equal(Pronouns.DEFAULT, "they", "they/them is the default")

    check_equal(Pronouns.subject("she"), "she", "subject")
    check_equal(Pronouns.object("he"), "him", "object")
    check_equal(Pronouns.possessive("they"), "their", "possessive")
    check_equal(Pronouns.reflexive("she"), "herself", "reflexive")
    check_equal(Pronouns.capitalise("they"), "They", "and they can start a sentence")

    check(Pronouns.is_known("she"), "a known set is recognised")
    check(not Pronouns.is_known("xe"), "an unknown one is not")
    check_equal(Pronouns.label("nonsense"), "They / them", "and unknown falls back to they/them")

func _agreement() -> void:
    section("verbs agree")
    check_equal(Pronouns.verb("she", "has", "have"), "has", "she has")
    check_equal(Pronouns.verb("he", "has", "have"), "has", "he has")
    check_equal(Pronouns.verb("they", "has", "have"), "have", "they have")
    check(not Pronouns.is_plural("she"), "she takes the singular")
    check(Pronouns.is_plural("they"), "they takes the plural")

func _the_founder_chooses() -> void:
    section("the founder's are chosen at the start")
    _company("she")
    var founder := EmployeeManager.founder()
    if not check_not_null(founder, "there is a founder"):
        return
    check_equal(founder.pronoun_id, "she", "the founder got what was picked")
    check_equal(founder.their(), "her", "and reads correctly")

    _company("he")
    check_equal(EmployeeManager.founder().pronoun_id, "he", "another studio, another founder")

    # Anything unrecognised falls back rather than sticking.
    _company("nonsense")
    check_equal(GameState.founder_pronoun_id, "they", "a bad value falls back to they/them")

func _candidates_get_them() -> void:
    section("everybody has them")
    _company()
    var seen := {}
    var all_known := true
    for i in 40:
        var candidate := EmployeeManager.generate_candidate("programmer", "junior")
        if not Pronouns.is_known(candidate.pronoun_id):
            all_known = false
        seen[candidate.pronoun_id] = true
    check(all_known, "every generated candidate has a real set")
    check_greater(float(seen.size()), 1.0,
        "the studio is not all one kind (%d sets across 40 applicants)" % seen.size())

func _a_name_is_not_pronouns() -> void:
    section("a name does not decide them")
    var rng := RandomNumberGenerator.new()
    rng.seed = 12345
    var unisex := {}
    for i in 60:
        unisex[EmployeeManager.pronouns_for("Alex", rng)] = true
    check_greater(float(unisex.size()), 1.0,
        "a unisex name gets whichever set the roll lands on (%d)" % unisex.size())

    # Names that do carry a usual set stay consistent, so the cast reads well.
    check_equal(EmployeeManager.pronouns_for("Maya", rng), "she", "Maya is she/her")
    check_equal(EmployeeManager.pronouns_for("Marcus", rng), "he", "Marcus is he/him")

func _the_sentences() -> void:
    section("the sentences the player reads")
    _company()
    var person := _hire()

    person.pronoun_id = "she"
    check_equal("%s submitted %s resignation." % [person.verb("has", "have"), person.their()],
        "has submitted her resignation.", "she has submitted her resignation")
    check_equal("LET %s GO" % person.them().to_upper(), "LET HER GO", "LET HER GO")

    person.pronoun_id = "he"
    check_equal("%s submitted %s resignation." % [person.verb("has", "have"), person.their()],
        "has submitted his resignation.", "he has submitted his resignation")
    check_equal("LET %s GO" % person.them().to_upper(), "LET HIM GO", "LET HIM GO")

    person.pronoun_id = "they"
    check_equal("%s submitted %s resignation." % [person.verb("has", "have"), person.their()],
        "have submitted their resignation.", "they have submitted their resignation")
    check_equal("LET %s GO" % person.them().to_upper(), "LET THEM GO", "LET THEM GO")

    check_equal("%s %s in 3 weeks." % [
        Pronouns.capitalise(person.they()), person.verb("leaves", "leave")],
        "They leave in 3 weeks.", "and the countdown agrees too")

func _persistence() -> void:
    section("pronouns survive a save")
    _company("she")
    var person := _hire()
    person.pronoun_id = "he"
    var id := person.id

    check(SaveManager.save_game("save_pronouns"), "saved")
    GameState.reset_company()
    check(SaveManager.load_game("save_pronouns"), "loaded")

    check_equal(GameState.founder_pronoun_id, "she", "the founder's came back")
    check_equal(EmployeeManager.founder().pronoun_id, "she", "on the founder themselves")
    var restored := EmployeeManager.find_employee(id)
    if check_not_null(restored, "the employee came back"):
        check_equal(restored.pronoun_id, "he", "with their own set intact")
    SaveManager.delete_save("save_pronouns")

func _old_saves() -> void:
    section("saves written before pronouns existed")
    _company()
    var person := _hire()
    var data := person.to_dict()
    data.erase("pronoun_id")
    var migrated := Employee.from_dict(data)
    check_equal(migrated.pronoun_id, "they", "an employee with no set recorded gets they/them")

    data["pronoun_id"] = "xe"
    check_equal(Employee.from_dict(data).pronoun_id, "they", "and so does an unrecognised one")
