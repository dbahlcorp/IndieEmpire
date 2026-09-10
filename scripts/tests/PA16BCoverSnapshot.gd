extends Node

## Deterministic 100-cover visual audit. Captures the runtime GameCoverArt at
## 2x its compact list size so both composition and thumbnail behavior can be
## reviewed without mutating simulation state.

# The historical before/after folders are review evidence. A routine regression
# run must never replace either one unless the caller opts into that exact path.
const DEFAULT_OUTPUT_DIR := "res://artifacts/pa16b-covers-current"
const TITLES := [
    "STARFALL", "STARFALL II", "STARFALL III: ECHOES OF ORION",
    "THE LEGENDS OF THE LAST FRONTIER", "NEON TIDE", "IRON HARVEST",
    "CITY OF GLASS", "WILD SIGNAL", "MIDNIGHT ARCHIVE", "TINY KINGDOMS",
]

func _ready() -> void:
    var output_dir := _output_dir()
    var themes := _catalog_ids("res://data/themes.json")
    var genres := _catalog_ids("res://data/genres.json")
    var platforms := _catalog_ids("res://data/platforms.json")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
    var records: Array[Dictionary] = []
    for index in 100:
        var title := str(TITLES[index % TITLES.size()])
        var franchise := ""
        if index % 10 < 3:
            title = str(TITLES[index % 3])
            franchise = "starfall_series"
        var record := {
            "index": index + 1,
            "title": title,
            "theme": str(themes[(index * 7) % themes.size()]),
            "genre": str(genres[(index * 5 + index / 10) % genres.size()]),
            "platform": str(platforms[(index * 3) % platforms.size()]),
            "year": 1985 + (index % 41),
            "franchise": franchise,
        }
        records.append(record)
        await _capture(record, output_dir)
    var index_file := FileAccess.open(output_dir + "/index.json", FileAccess.WRITE)
    index_file.store_string(JSON.stringify(records, "  "))
    print("PA.16B cover audit wrote 100 covers to %s" % ProjectSettings.globalize_path(output_dir))
    get_tree().quit()

func _catalog_ids(path: String) -> Array[String]:
    var file := FileAccess.open(path, FileAccess.READ)
    var rows = JSON.parse_string(file.get_as_text())
    var result: Array[String] = []
    for row in rows:
        result.append(str(row.get("id", "")))
    return result

func _output_dir() -> String:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--output="):
            return argument.trim_prefix("--output=")
    return DEFAULT_OUTPUT_DIR

func _capture(record: Dictionary, output_dir: String) -> void:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(172, 224)
    viewport.disable_3d = true
    viewport.transparent_bg = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child(viewport)
    var cover := GameCoverArt.new()
    cover.size = Vector2(172, 224)
    cover.game_title = str(record["title"])
    cover.theme_id = str(record["theme"])
    cover.genre_id = str(record["genre"])
    cover.platform_id = str(record["platform"])
    cover.franchise_id = str(record["franchise"])
    cover.era_year = int(record["year"])
    viewport.add_child(cover)
    await get_tree().process_frame
    await get_tree().process_frame
    var image := viewport.get_texture().get_image()
    var output := ProjectSettings.globalize_path("%s/cover-%03d.png" % [output_dir, int(record["index"])])
    var error := image.save_png(output)
    if error != OK:
        push_error("Could not save %s: %s" % [output, error_string(error)])
    viewport.queue_free()
    await get_tree().process_frame
