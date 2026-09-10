class_name AssetCatalog
extends RefCounted

## Manifest-backed visual lookup. All authored identity art resolves here so a
## missing catalog item degrades to a family fallback instead of a broken image.

const MANIFEST_PATH := "res://data/asset_manifest.json"
static var _manifest: Dictionary = {}
static var _textures: Dictionary = {}

static func reload() -> void:
    _manifest.clear()
    _textures.clear()
    if not FileAccess.file_exists(MANIFEST_PATH):
        push_error("Asset manifest is missing: %s" % MANIFEST_PATH)
        return
    var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        _manifest = parsed
    else:
        push_error("Asset manifest is not valid JSON: %s" % MANIFEST_PATH)

static func manifest() -> Dictionary:
    if _manifest.is_empty():
        reload()
    return _manifest

static func family(family_id: String) -> Dictionary:
    var families: Dictionary = manifest().get("families", {})
    return families.get(family_id, {}) as Dictionary

static func path(family_id: String, asset_id: String) -> String:
    var result := str(family(family_id).get(asset_id, ""))
    if result.is_empty():
        result = str(manifest().get("fallbacks", {}).get(family_id, ""))
    return result

static func texture(family_id: String, asset_id: String) -> Texture2D:
    var resource_path := path(family_id, asset_id)
    if resource_path.is_empty():
        return null
    if not _textures.has(resource_path):
        _textures[resource_path] = load(resource_path)
    return _textures[resource_path] as Texture2D

static func missing_files() -> Array[String]:
    var missing: Array[String] = []
    var seen: Dictionary = {}
    var families: Dictionary = manifest().get("families", {})
    for entries in families.values():
        for resource_path in (entries as Dictionary).values():
            var value := str(resource_path)
            if not seen.has(value) and not ResourceLoader.exists(value):
                seen[value] = true
                missing.append(value)
    var fallbacks: Dictionary = manifest().get("fallbacks", {})
    for resource_path in fallbacks.values():
        var value := str(resource_path)
        if not seen.has(value) and not ResourceLoader.exists(value):
            seen[value] = true
            missing.append(value)
    return missing
