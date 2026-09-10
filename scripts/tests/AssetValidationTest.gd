extends TestCase

## Run with:
## godot --headless --path . res://scripts/tests/AssetValidationTest.tscn

func run() -> void:
    section("manifest contract")
    var manifest := AssetCatalog.manifest()
    check_equal(int(manifest.get("schema_version", 0)), 1, "supported schema")
    check_empty(AssetCatalog.missing_files(), "every manifest path resolves")
    _manifest_integrity(manifest)
    _family_matches("genres", DataManager.genres)
    _family_matches("themes", DataManager.themes)
    _family_matches("platforms", DataManager.platforms)
    _family_matches("technologies", DataManager.technologies)
    _family_matches("features", DataManager.game_features)
    _family_matches("awards", DataManager.awards)

    section("fallbacks")
    for family_id in ["genres", "themes", "platforms", "technologies", "features", "ui", "statuses", "awards", "empty_states", "eras", "milestones", "award_presentation"]:
        var fallback := str(manifest.get("fallbacks", {}).get(family_id, ""))
        check(not fallback.is_empty() and ResourceLoader.exists(fallback), "%s fallback loads" % family_id)
        check_not_null(AssetCatalog.texture(family_id, "__unknown_asset__"), "%s unknown id returns art" % family_id)

    section("year-driven eras")
    check_equal(EraVisuals.id_for_year(1985), "era_1980s", "1985 uses the homebrew pack")
    check_equal(EraVisuals.id_for_year(1990), "era_1990s", "1990 enters multimedia")
    check_equal(EraVisuals.id_for_year(2000), "era_2000s", "2000 enters online")
    check_equal(EraVisuals.id_for_year(2010), "era_2010s", "2010 enters mobile")
    check_equal(EraVisuals.id_for_year(2020), "era_2020s", "2020 enters modern")

    section("portrait states")
    var employee := Employee.new()
    employee.morale = 50
    employee.stress = 20
    employee.energy = 20
    check_equal(ModularPortraitArt.expression(employee), "tired", "low energy reads as tired")
    employee.morale = 95
    employee.stress = 15
    employee.energy = 90
    check_equal(ModularPortraitArt.expression(employee), "excited", "high healthy morale reads as excited")

func _manifest_integrity(manifest: Dictionary) -> void:
    var seen_ids: Dictionary = {}
    var supported := ["svg", "png", "webp"]
    for family_id in manifest.get("families", {}):
        var entries: Dictionary = manifest["families"][family_id]
        for asset_id in entries:
            var qualified := "%s/%s" % [family_id, asset_id]
            check(not seen_ids.has(qualified), "%s is not duplicated" % qualified)
            seen_ids[qualified] = true
            var resource_path := str(entries[asset_id])
            check(resource_path.begins_with("res://"), "%s uses a resource path" % qualified)
            check(resource_path.get_extension().to_lower() in supported, "%s uses a supported format" % qualified)
            var texture := AssetCatalog.texture(str(family_id), str(asset_id))
            if texture != null:
                check(texture.get_width() > 0 and texture.get_height() > 0, "%s has non-zero dimensions" % qualified)
                if str(family_id) == "eras":
                    check_equal(Vector2i(texture.get_width(), texture.get_height()), Vector2i(768, 512),
                        "%s matches the office canvas" % qualified)

func _family_matches(family_id: String, records: Array) -> void:
    var entries := AssetCatalog.family(family_id)
    for record in records:
        var id := str(record.get("id", ""))
        check(entries.has(id), "%s/%s has a manifest mapping" % [family_id, id])
        check_not_null(AssetCatalog.texture(family_id, id), "%s/%s texture loads" % [family_id, id])
