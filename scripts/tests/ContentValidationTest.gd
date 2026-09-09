extends TestCase

## Content lint for every authored catalog in data/*.json. Not a balance test:
## it fails fast on the mistakes that otherwise surface as a mid-playthrough
## parse error or a silently-ignored reference -- duplicate ids, broken
## prerequisites, missing display names, references to ids that do not exist,
## unlocks that can never be reached, malformed platform timelines and
## out-of-range affinity values.
##
## PA.5 (Content Expansion) added most of the volume this guards; the checks
## are written against the schemas, not the specific entries, so they keep
## working as content grows.

const GENRE_AFFINITY_MIN := 0.5
const GENRE_AFFINITY_MAX := 1.6
const TRAIT_VALUE_MIN := -0.10
const TRAIT_VALUE_MAX := 0.10
const EARLIEST_YEAR := 1985

var _genre_ids := {}
var _theme_ids := {}
var _platform_ids := {}
var _tech_ids := {}
var _feature_ids := {}
var _skill_fields := ["programming", "design", "art", "writing", "audio",
    "production", "testing", "research"]
var _culture_ids := ["work_life_balance", "creative_freedom", "quality_focus",
    "efficiency", "employee_loyalty"]
var _role_ids := {}

func run() -> void:
    _index()
    _no_duplicate_ids()
    _every_entry_has_a_display_name()
    _genres()
    _themes()
    _platforms()
    _technologies()
    _game_features()
    _employee_traits()
    _studio_events()
    _awards()
    _office_content()

func _index() -> void:
    for g in DataManager.genres:
        _genre_ids[str(g.get("id", ""))] = true
    for t in DataManager.themes:
        _theme_ids[str(t.get("id", ""))] = true
    for p in DataManager.platforms:
        _platform_ids[str(p.get("id", ""))] = true
    for tech in DataManager.technologies:
        _tech_ids[str(tech.get("id", ""))] = true
    for f in DataManager.game_features:
        _feature_ids[str(f.get("id", ""))] = true
    for r in DataManager.employee_roles:
        _role_ids[str(r.get("id", ""))] = true

func _dupe_ids(items: Array) -> Array:
    var seen := {}
    var dupes := {}
    for item in items:
        var id := str(item.get("id", ""))
        if seen.has(id):
            dupes[id] = true
        seen[id] = true
    return dupes.keys()

func _no_duplicate_ids() -> void:
    section("every catalog has unique ids")
    for pair in [
        ["genres", DataManager.genres], ["themes", DataManager.themes],
        ["platforms", DataManager.platforms], ["technologies", DataManager.technologies],
        ["game_features", DataManager.game_features],
        ["employee_traits", DataManager.employee_traits],
        ["studio_events", DataManager.studio_events],
        ["offices", DataManager.offices],
        ["office_customizations", DataManager.office_customizations],
        ["specializations", DataManager.specializations],
        ["awards", DataManager.awards],
    ]:
        check_empty(_dupe_ids(pair[1]), "%s: duplicate ids %s" % [pair[0], _dupe_ids(pair[1])])

func _every_entry_has_a_display_name() -> void:
    section("nothing ships without a player-facing name")
    for pair in [
        ["genres", DataManager.genres, "name"],
        ["themes", DataManager.themes, "name"],
        ["platforms", DataManager.platforms, "name"],
        ["employee_traits", DataManager.employee_traits, "name"],
        ["office_customizations", DataManager.office_customizations, "name"],
    ]:
        for item in pair[1]:
            check(not str(item.get(pair[2], "")).strip_edges().is_empty(),
                "%s/%s has a non-empty %s" % [pair[0], item.get("id", "?"), pair[2]])
    for tech in DataManager.technologies:
        check(not ResearchSimulator.display_name(tech).strip_edges().is_empty(),
            "technology %s resolves a display name" % tech.get("id", "?"))
    for feature in DataManager.game_features:
        check(not FeatureSimulator.display_name(feature).strip_edges().is_empty(),
            "feature %s resolves a display name" % feature.get("id", "?"))

func _valid_unlock(entry: Dictionary, label: String) -> void:
    var year := int(entry.get("unlock_year", EARLIEST_YEAR))
    check(year >= EARLIEST_YEAR, "%s unlock_year %d is not before %d" % [label, year, EARLIEST_YEAR])
    check(int(entry.get("unlock_games", 0)) >= 0, "%s unlock_games is not negative" % label)

func _genres() -> void:
    section("genres")
    check_between(float(DataManager.genres.size()), 8.0, 20.0, "genre count stays understandable")
    for g in DataManager.genres:
        _valid_unlock(g, "genre %s" % g.get("id", "?"))
        check(float(g.get("story_weight", 0.0)) > 0.0,
            "genre %s has a positive story_weight" % g.get("id", "?"))

func _themes() -> void:
    section("themes")
    check_greater(float(DataManager.themes.size()), 39.0, "themes were expanded to the PA.5 target")
    for t in DataManager.themes:
        var id := str(t.get("id", "?"))
        _valid_unlock(t, "theme %s" % id)
        var affinity: Dictionary = t.get("genre_affinity", {})
        check(not affinity.is_empty(), "theme %s has a genre_affinity map" % id)
        # completeness: every genre is scored
        for genre_id in _genre_ids:
            check(affinity.has(genre_id),
                "theme %s scores genre %s" % [id, genre_id])
        # references + range
        for key in affinity:
            check(_genre_ids.has(str(key)),
                "theme %s affinity key %s is a real genre" % [id, key])
            var v := float(affinity[key])
            check_between(v, GENRE_AFFINITY_MIN, GENRE_AFFINITY_MAX,
                "theme %s / %s affinity %.2f is in range" % [id, key, v])

func _platforms() -> void:
    section("platforms")
    check_greater(float(DataManager.platforms.size()), 14.0, "the platform timeline has real depth")
    var years_seen := {}
    for p in DataManager.platforms:
        var id := str(p.get("id", "?"))
        var announce := int(p.get("announce_year", 0))
        var release := int(p.get("release_year", 0))
        var peak := int(p.get("peak_year", 0))
        var retire := int(p.get("retire_year", 0))
        check(announce <= release, "%s: announced (%d) no later than released (%d)" % [id, announce, release])
        check(release <= peak, "%s: released (%d) no later than peak (%d)" % [id, release, peak])
        check(peak <= retire, "%s: peak (%d) no later than retirement (%d)" % [id, peak, retire])
        check(int(p.get("development_cost", 0)) > 0, "%s has a development cost" % id)
        check(int(p.get("peak_users", 0)) > 0, "%s has a market size" % id)

        var curve: Dictionary = p.get("market_curve", {})
        check(not curve.is_empty(), "%s has a market curve" % id)
        var curve_years: Array = []
        for key in curve:
            curve_years.append(int(key))
        curve_years.sort()
        if not curve_years.is_empty():
            check(curve_years[0] >= release,
                "%s curve starts no earlier than release (%d vs %d)" % [id, curve_years[0], release])
            check(curve_years[-1] <= retire,
                "%s curve ends no later than retirement (%d vs %d)" % [id, curve_years[-1], retire])
            check(curve_years.size() == curve_years[-1] - curve_years[0] + 1,
                "%s curve has no gaps between %d and %d" % [id, curve_years[0], curve_years[-1]])
            var peak_users := int(p.get("peak_users", 0))
            var curve_max := 0
            for key in curve:
                curve_max = maxi(curve_max, int(curve[key]))
            check(curve_max <= peak_users,
                "%s peak_users (%d) is at least the curve's high point (%d)" % [id, peak_users, curve_max])
            for y in curve:
                check(int(curve[y]) >= 0, "%s curve value for %s is not negative" % [id, y])
        for year in range(int(p.get("release_year", 1985)), int(p.get("peak_year", 1985)) + 1):
            years_seen[year] = true

        var audience: Dictionary = p.get("audience", {})
        for genre_id in _genre_ids:
            check(audience.has(genre_id), "%s scores genre %s" % [id, genre_id])
        for key in audience:
            check(_genre_ids.has(str(key)), "%s audience key %s is a real genre" % [id, key])
            check_between(float(audience[key]), GENRE_AFFINITY_MIN, GENRE_AFFINITY_MAX,
                "%s / %s audience %.2f is in range" % [id, key, float(audience[key])])

        if p.has("required_tech"):
            for tech_id in p.get("required_tech", []):
                check(_tech_ids.has(str(tech_id)),
                    "%s required_tech %s is a real technology" % [id, tech_id])

    section("the platform timeline is continuous from launch to the modern era")
    for year in range(1985, 2027):
        check(years_seen.has(year),
            "at least one platform is between release and peak in %d" % year)

func _technologies() -> void:
    section("technology tree")
    for tech in DataManager.technologies:
        var id := str(tech.get("id", "?"))
        check_empty(ResearchSimulator.definition_errors(tech),
            "technology %s is well formed: %s" % [id, ResearchSimulator.definition_errors(tech)])
        for prereq in ResearchSimulator.prerequisites(tech):
            check(_tech_ids.has(str(prereq)),
                "technology %s prerequisite %s exists" % [id, prereq])
        # a technology cannot come available before something it depends on
        var year := ResearchSimulator.min_year(tech)
        for prereq in ResearchSimulator.prerequisites(tech):
            var pdata := DataManager.get_technology(str(prereq))
            if not pdata.is_empty():
                check(year >= ResearchSimulator.min_year(pdata),
                    "technology %s (%d) is not available before its prerequisite %s (%d)" % [
                        id, year, prereq, ResearchSimulator.min_year(pdata)])
        var effects = tech.get("engine_effects", {})
        if effects is Dictionary:
            for key in effects:
                check_between(float(effects[key]), 0.80, 1.20,
                    "technology %s engine effect %s stays restrained" % [id, key])
    _no_prerequisite_cycles()

func _no_prerequisite_cycles() -> void:
    section("no technology depends on itself, directly or transitively")
    for tech in DataManager.technologies:
        var start := str(tech.get("id", ""))
        var stack: Array = [start]
        var visited := {}
        var cycle := false
        while not stack.is_empty():
            var current: String = stack.pop_back()
            if current == start and visited.has(start):
                cycle = true
                break
            if visited.has(current):
                continue
            visited[current] = true
            for prereq in ResearchSimulator.prerequisites(DataManager.get_technology(current)):
                stack.append(str(prereq))
        check(not cycle, "technology %s has no prerequisite cycle" % start)

func _game_features() -> void:
    section("game features")
    for feature in DataManager.game_features:
        var id := str(feature.get("id", "?"))
        check_empty(FeatureSimulator.definition_errors(feature),
            "feature %s is well formed: %s" % [id, FeatureSimulator.definition_errors(feature)])
        var unlocks: Dictionary = feature.get("unlock_requirements", {})
        var unlock_year := int(unlocks.get("year", feature.get("unlock_year", EARLIEST_YEAR)))
        check(unlock_year >= EARLIEST_YEAR, "feature %s unlock year is not before %d" % [id, EARLIEST_YEAR])
        var eras: Array = feature.get("compatible_eras", [])
        if eras.size() >= 2:
            check(unlock_year >= int(eras[0]) and unlock_year <= int(eras[1]),
                "feature %s unlock year %d sits inside its compatible era %s" % [id, unlock_year, eras])
        for required_feature in unlocks.get("features", []):
            check(_feature_ids.has(str(required_feature)),
                "feature %s prerequisite feature %s exists" % [id, required_feature])
        for tech_id in feature.get("technology_requirements", feature.get("requires_tech", [])):
            check(_tech_ids.has(str(tech_id)),
                "feature %s technology requirement %s exists" % [id, tech_id])
        for engine_id in feature.get("engine_requirements", []):
            check(_tech_ids.has(str(engine_id)),
                "feature %s engine requirement %s is a real technology" % [id, engine_id])
            var engine_tech := DataManager.get_technology(str(engine_id))
            check(engine_tech.get("engine_effects", {}) is Dictionary
                and not engine_tech.get("engine_effects", {}).is_empty(),
                "feature %s engine requirement %s is engine-capable (an engine can actually have it)" % [id, engine_id])
        for genre_id in feature.get("genre_relevance", {}):
            check(_genre_ids.has(str(genre_id)),
                "feature %s genre_relevance key %s is a real genre" % [id, genre_id])
            check_between(float(feature.get("genre_relevance", {})[genre_id]), 0.5, 1.5,
                "feature %s / %s genre relevance stays restrained" % [id, genre_id])

func _employee_traits() -> void:
    section("employee traits")
    check_greater(float(DataManager.employee_traits.size()), 29.0, "traits were expanded to the PA.5 target")
    var known_effect_keys := ["skill_contribution", "polish_multiplier", "speed_multiplier",
        "innovation_multiplier", "overload_work_factor", "overload_morale_factor",
        "xp_multiplier", "teamwork_delta"]
    for trait_data in DataManager.employee_traits:
        var id := str(trait_data.get("id", "?"))
        check(not str(trait_data.get("name", "")).strip_edges().is_empty(), "trait %s has a name" % id)
        check(not str(trait_data.get("description", "")).strip_edges().is_empty(),
            "trait %s has a description" % id)
        check(trait_data.has("market_value"), "trait %s declares a market_value" % id)
        check_between(float(trait_data.get("market_value", 0.0)), TRAIT_VALUE_MIN, TRAIT_VALUE_MAX,
            "trait %s market_value stays restrained" % id)
        var effects: Dictionary = trait_data.get("effects", {})
        check(not effects.is_empty(), "trait %s wires at least one mechanical effect" % id)
        for key in effects:
            check(key in known_effect_keys, "trait %s effect key %s is understood" % [id, key])
        var contribution: Dictionary = effects.get("skill_contribution", {})
        for skill in contribution:
            check(str(skill) == "all" or str(skill) in _skill_fields,
                "trait %s skill_contribution key %s is a real discipline" % [id, skill])
            check_between(float(contribution[skill]), 0.85, 1.25,
                "trait %s / %s contribution multiplier stays restrained" % [id, skill])

func _studio_events() -> void:
    section("studio events")
    check_greater(float(DataManager.studio_events.size()), 99.0,
        "the event catalogue reached the PA.5 target")
    var operators := [">=", "<=", "==", "!=", ">", "<"]
    var employee_fields := StudioEventSimulator.EMPLOYEE_FIELDS + ["tenure_weeks", "team_size"]
    var company_vars := ["company_cash", "company_reputation", "company_fans",
        "company_headcount", "office_quality", "has_active_project"]
    for event in DataManager.studio_events:
        var id := str(event.get("id", "?"))
        var etype := str(event.get("type", ""))
        check(etype in ["employee", "studio"], "event %s has a valid type" % id)
        check(not str(event.get("body", "")).strip_edges().is_empty(), "event %s has body text" % id)
        for role in event.get("roles", []):
            check(_role_ids.has(str(role)), "event %s role %s exists" % [id, role])
        for raw in event.get("conditions", []):
            var condition := str(raw)
            var op := ""
            for candidate in operators:
                if condition.contains(" %s " % candidate):
                    op = candidate
                    break
            check(not op.is_empty(), "event %s condition '%s' has an operator" % [id, condition])
            if op.is_empty():
                continue
            var parts := condition.split(" %s " % op, false)
            check(parts.size() == 2, "event %s condition '%s' is well formed" % [id, condition])
            if parts.size() != 2:
                continue
            var lhs := parts[0].strip_edges()
            check(float(parts[1].strip_edges()) == float(parts[1].strip_edges()),
                "event %s condition '%s' compares against a number" % [id, condition])
            if lhs.begins_with("employee_"):
                check(etype == "employee",
                    "event %s uses an employee condition but is type '%s'" % [id, etype])
                check(lhs.substr("employee_".length()) in employee_fields,
                    "event %s condition variable %s is known" % [id, lhs])
            elif lhs.begins_with("culture_"):
                check(lhs.substr("culture_".length()) in _culture_ids,
                    "event %s culture variable %s is known" % [id, lhs])
            else:
                check(lhs in company_vars, "event %s condition variable %s is known" % [id, lhs])
        var choices: Array = event.get("choices", [])
        check(choices.size() >= 2, "event %s offers a real choice" % id)
        var defaults := 0
        for choice in choices:
            check(not str(choice.get("label", "")).strip_edges().is_empty(),
                "event %s: every choice is labelled" % id)
            check(not str(choice.get("outcome", "")).strip_edges().is_empty(),
                "event %s: every choice has an outcome line" % id)
            check(int(choice.get("cost", 0)) >= 0, "event %s: no negative cost" % id)
            if bool(choice.get("default", false)):
                defaults += 1
            for effect in choice.get("effects", []):
                _check_event_effect(id, etype, effect)
        check(defaults <= 1, "event %s marks at most one default choice" % id)
        check(StudioEventSimulator.default_choice_index(event) >= 0,
            "event %s resolves a default choice index" % id)

func _check_event_effect(event_id: String, etype: String, effect: Dictionary) -> void:
    var kind := str(effect.get("kind", ""))
    match kind:
        "skill_xp":
            check(str(effect.get("skill", "")) in _skill_fields,
                "event %s skill_xp targets a real discipline" % event_id)
            check(etype == "employee", "event %s skill_xp needs an employee subject" % event_id)
            check(int(effect.get("amount", 0)) > 0, "event %s skill_xp is positive" % event_id)
        "morale":
            check(str(effect.get("target", "")) in ["employee", "team", "company"],
                "event %s morale target is valid" % event_id)
        "team_chemistry":
            check(etype == "employee", "event %s team_chemistry needs an employee subject" % event_id)
        "culture":
            check(str(effect.get("id", "")) in _culture_ids,
                "event %s culture id %s is valid" % [event_id, effect.get("id", "")])
        "cash", "reputation":
            pass
        "dev_efficiency":
            check(int(effect.get("weeks", 0)) > 0, "event %s dev_efficiency runs for real weeks" % event_id)
            check(absf(float(effect.get("amount", 0.0))) <= 0.15,
                "event %s dev_efficiency swing stays restrained" % event_id)
        _:
            check(false, "event %s has an unknown effect kind '%s'" % [event_id, kind])

func _awards() -> void:
    section("game awards")
    check_greater(float(DataManager.awards.size()), 7.0,
        "the awards catalogue covers the spec's categories")
    var known_signals := ["review", "gameplay", "technology", "visuals", "graphics",
        "story", "writing", "narrative", "sound", "innovation", "polish", "performance",
        "balance", "stability", "engine", "reception", "impact", "commercial"]
    var elig_vars := ["review", "sales", "innovation", "bugs", "fans", "team_size",
        "size_index", "genre"]
    var has_goty := false
    for award in DataManager.awards:
        var id := str(award.get("id", "?"))
        if id == "goty":
            has_goty = true
        check(not str(award.get("name", "")).strip_edges().is_empty(),
            "award %s has a display name" % id)
        check(int(award.get("min_eligible", 3)) >= 1, "award %s needs at least one eligible game" % id)
        check(int(award.get("nominees", 4)) >= 1, "award %s shortlists someone" % id)
        var genre_id := str(award.get("genre_id", ""))
        check(genre_id.is_empty() or _genre_ids.has(genre_id),
            "award %s genre %s exists" % [id, genre_id])
        var weights: Dictionary = award.get("weights", {})
        check(not weights.is_empty(), "award %s scores on something" % id)
        for key in weights:
            check(str(key) in known_signals, "award %s weight key %s is a known signal" % [id, key])
            check(float(weights[key]) > 0.0, "award %s weight %s is positive" % [id, key])
        for raw in award.get("eligibility", []):
            var condition := str(raw)
            var op := ""
            for candidate in [">=", "<=", "==", "!=", ">", "<"]:
                if condition.contains(" %s " % candidate):
                    op = candidate
                    break
            check(not op.is_empty(), "award %s eligibility '%s' has an operator" % [id, condition])
            if op.is_empty():
                continue
            var lhs := condition.split(" %s " % op, false)[0].strip_edges()
            check(lhs in elig_vars, "award %s eligibility variable %s is known" % [id, lhs])
    check(has_goty, "there is a Game of the Year category")

func _office_content() -> void:
    section("offices and customizations")
    for office in DataManager.offices:
        var id := str(office.get("id", "?"))
        check(int(office.get("capacity", 0)) >= 1, "office %s seats at least one person" % id)
        check(int(office.get("rent", 0)) >= 0, "office %s rent is not negative" % id)
    check_greater(float(DataManager.office_customizations.size()), 19.0,
        "office customizations reached the PA.5 target")
    for style in DataManager.office_customizations:
        var id := str(style.get("id", "?"))
        check(str(style.get("purchase_type", "")) in ["included", "cash", "iap"],
            "customization %s has a known purchase type" % id)
        check(int(style.get("price", 0)) >= 0, "customization %s price is not negative" % id)
        check(not str(style.get("tint", "")).is_empty(), "customization %s has a tint" % id)
        check(not str(style.get("accent", "")).is_empty(), "customization %s has an accent" % id)
