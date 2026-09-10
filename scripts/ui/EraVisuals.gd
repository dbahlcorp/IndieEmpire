class_name EraVisuals
extends RefCounted

const ERAS := [
    {"id": "era_1980s", "from": -9999, "to": 1989, "label": "HOMEBREW 1980s"},
    {"id": "era_1990s", "from": 1990, "to": 1999, "label": "MULTIMEDIA 1990s"},
    {"id": "era_2000s", "from": 2000, "to": 2009, "label": "ONLINE 2000s"},
    {"id": "era_2010s", "from": 2010, "to": 2019, "label": "MOBILE 2010s"},
    {"id": "era_2020s", "from": 2020, "to": 9999, "label": "MODERN 2020s"},
]

static func era_for_year(year: int) -> Dictionary:
    for era in ERAS:
        if year >= int(era["from"]) and year <= int(era["to"]):
            return era
    return ERAS[0]

static func id_for_year(year: int) -> String:
    return str(era_for_year(year)["id"])

static func label_for_year(year: int) -> String:
    return str(era_for_year(year)["label"])

static func texture_for_year(year: int) -> Texture2D:
    return AssetCatalog.texture("eras", id_for_year(year))
