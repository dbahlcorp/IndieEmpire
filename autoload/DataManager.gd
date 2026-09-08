extends Node

var genres: Array = []
var themes: Array = []
var platforms: Array = []
var sizes: Array = []
var difficulties: Array = []
var contracts: Array = []
var publishers: Array = []
var training_courses: Array = []
var employee_roles: Array = []
var offices: Array = []
var employee_traits: Array = []
var office_customizations: Array = []
var studio_events: Array = []
var game_features: Array = []
## Specialization tracks within each of the eight skills -- e.g. programming
## splits into Engine, Gameplay, Tools and AI. Recorded now so a save already
## has somewhere to put a choice; the actual "choose a focus" moment (an
## employee experienced enough in a skill to specialize within it) is an
## M4/M5 system, not this one. See Employee.specialization_id.
var specializations: Array = []
## Chosen once, at studio creation. Purely a founder's starting skill
## profile -- see EmployeeManager.create_founder() -- with no bearing on
## seniority, promotion or specialization later.
var founder_backgrounds: Array = []
## Name pools for generated candidates -- see EmployeeManager._generated_name().
## Flat lists of strings rather than id-keyed objects, kept in their own files
## so a locale swap later is a data change, not a code change.
var first_names: Array = []
var last_names: Array = []
## How rare a labor-market candidate is: common/skilled/exceptional/star.
## Drives both a stat bonus and a salary premium -- see
## LaborMarketManager.refresh_market() and EmployeeManager.generate_candidate().
var candidate_rarities: Array = []
## Year -> multiplier breakpoints, ascending by year, linearly interpolated
## by InflationSimulator. Approximate and fictionalized, not a real price
## index -- see InflationSimulator.
var inflation: Array = []

func _ready() -> void:
    genres = _load_json_array("res://data/genres.json")
    themes = _load_json_array("res://data/themes.json")
    platforms = _load_json_array("res://data/platforms.json")
    sizes = _load_json_array("res://data/game_sizes.json")
    difficulties = _load_json_array("res://data/difficulties.json")
    contracts = _load_json_array("res://data/contracts.json")
    publishers = _load_json_array("res://data/publishers.json")
    training_courses = _load_json_array("res://data/training.json")
    employee_roles = _load_json_array("res://data/employee_roles.json")
    offices = _load_json_array("res://data/offices.json")
    employee_traits = _load_json_array("res://data/employee_traits.json")
    office_customizations = _load_json_array("res://data/office_customizations.json")
    studio_events = _load_json_array("res://data/studio_events.json")
    game_features = _load_json_array("res://data/game_features.json")
    specializations = _load_json_array("res://data/specializations.json")
    founder_backgrounds = _load_json_array("res://data/founder_backgrounds.json")
    inflation = _load_json_array("res://data/inflation.json")
    first_names = _load_json_array("res://data/first_names.json")
    last_names = _load_json_array("res://data/last_names.json")
    candidate_rarities = _load_json_array("res://data/candidate_rarities.json")

func _load_json_array(path: String) -> Array:
    if not FileAccess.file_exists(path):
        push_error("Missing data file: %s" % path)
        return []

    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Could not open data file %s (error %d)" % [path, FileAccess.get_open_error()])
        return []

    var parsed = JSON.parse_string(file.get_as_text())

    if parsed is Array:
        return parsed

    push_error("Expected JSON array in %s" % path)
    return []

func get_genre(id: String) -> Dictionary:
    return _find_by_id(genres, id)

func get_theme(id: String) -> Dictionary:
    return _find_by_id(themes, id)

func get_platform(id: String) -> Dictionary:
    return _find_by_id(platforms, id)

func get_size(id: String) -> Dictionary:
    return _find_by_id(sizes, id)

func get_difficulty(id: String) -> Dictionary:
    return _find_by_id(difficulties, id)

func get_contract_template(id: String) -> Dictionary:
    return _find_by_id(contracts, id)

func get_publisher(id: String) -> Dictionary:
    return _find_by_id(publishers, id)

func get_training_course(id: String) -> Dictionary:
    return _find_by_id(training_courses, id)

func get_employee_role(id: String) -> Dictionary:
    return _find_by_id(employee_roles, id)

func get_office(id: String) -> Dictionary:
    return _find_by_id(offices, id)

func get_employee_trait(id: String) -> Dictionary:
    return _find_by_id(employee_traits, id)

func get_office_customization(id: String) -> Dictionary:
    return _find_by_id(office_customizations, id)

func get_studio_event(id: String) -> Dictionary:
    return _find_by_id(studio_events, id)

func get_game_feature(id: String) -> Dictionary:
    return _find_by_id(game_features, id)

func get_specialization(id: String) -> Dictionary:
    return _find_by_id(specializations, id)

func get_founder_background(id: String) -> Dictionary:
    return _find_by_id(founder_backgrounds, id)

func get_candidate_rarity(id: String) -> Dictionary:
    return _find_by_id(candidate_rarities, id)

func specializations_for_skill(skill: String) -> Array:
    var found: Array = []
    for entry in specializations:
        if str(entry.get("skill", "")) == skill:
            found.append(entry)
    return found

func display_name(items: Array, id: String) -> String:
    var item := _find_by_id(items, id)
    return str(item.get("name", id))

func _find_by_id(items: Array, id: String) -> Dictionary:
    for item in items:
        if item.get("id", "") == id:
            return item
    return {}
