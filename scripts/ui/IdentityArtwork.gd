class_name IdentityArtwork
extends RefCounted

## Stable artwork lookup for game and market identity. External SVGs cover the
## semantic families; generated badges keep the much larger theme list compact.

const PLATFORM_PATHS := {
    "microstar_64": "res://assets/ui/platforms/microstar_64.svg",
    "ibm_compatible": "res://assets/ui/platforms/ibm_compatible.svg",
    "famiclone": "res://assets/ui/platforms/famiclone.svg",
    "pocket_play": "res://assets/ui/platforms/pocket_play.svg",
    "mega16": "res://assets/ui/platforms/mega16.svg",
    "playbox32": "res://assets/ui/platforms/playbox32.svg",
}

const GENRE_PATHS := {
    "action": "res://assets/ui/genres/action.svg",
    "adventure": "res://assets/ui/genres/adventure.svg",
    "rpg": "res://assets/ui/genres/rpg.svg",
    "strategy": "res://assets/ui/genres/strategy.svg",
    "simulation": "res://assets/ui/genres/simulation.svg",
    "puzzle": "res://assets/ui/genres/puzzle.svg",
    "racing": "res://assets/ui/genres/racing.svg",
    "shooter": "res://assets/ui/genres/shooter.svg",
}

const THEME_COLOURS := {
    "space": "596bb3", "fantasy": "7a6bb0", "military": "68785d",
    "horror": "704c63", "pirates": "527e83", "aliens": "6d9a75",
    "western": "b4744e", "detective": "586b78", "history": "9b7655",
    "espionage": "526d68", "cyberpunk": "9c5f91", "robots": "568a98",
    "racing_theme": "c4644d", "sports": "4b8a74", "crime": "625d71",
    "dinosaurs": "74834e", "superheroes": "b75555", "survival": "66734f",
    "post_apocalypse": "927052", "zombies": "65764f", "time_travel": "557fa0",
    "farming": "7e9a55", "city_building": "657f99", "medical": "4e9a91",
    "business": "5e7790",
}

const THEME_INITIALS := {
    "space": "SP", "fantasy": "FA", "military": "MI", "horror": "HO",
    "pirates": "PI", "aliens": "AL", "western": "WE", "detective": "DE",
    "history": "HI", "espionage": "ES", "cyberpunk": "CY", "robots": "RO",
    "racing_theme": "RA", "sports": "ST", "crime": "CR", "dinosaurs": "DI",
    "superheroes": "SU", "survival": "SV", "post_apocalypse": "PA",
    "zombies": "ZO", "time_travel": "TT", "farming": "FM",
    "city_building": "CB", "medical": "MD", "business": "BU",
}

static var _loaded: Dictionary = {}
static var _generated: Dictionary = {}

static func platform_texture(id: String) -> Texture2D:
    return _load_texture(str(PLATFORM_PATHS.get(id, "")))

static func genre_texture(id: String) -> Texture2D:
    return _load_texture(str(GENRE_PATHS.get(id, "")))

static func theme_texture(id: String) -> Texture2D:
    var colour := str(THEME_COLOURS.get(id, "607d80"))
    return _badge_texture("theme:%s" % id, str(THEME_INITIALS.get(id, "??")), colour, "f7e7bf")

static func size_texture(id: String) -> Texture2D:
    var letters := {"small": "S", "medium": "M", "large": "L", "aaa": "XL"}
    var colours := {"small": "6d9a75", "medium": "d09355", "large": "b85f5f", "aaa": "7a6bb0"}
    return _badge_texture("size:%s" % id, str(letters.get(id, id.left(2).to_upper())), str(colours.get(id, "607d80")), "f7e7bf")

static func theme_colour(id: String) -> Color:
    return Color("#%s" % str(THEME_COLOURS.get(id, "607d80")))

static func _load_texture(path: String) -> Texture2D:
    if path.is_empty():
        return null
    if not _loaded.has(path):
        _loaded[path] = load(path)
    return _loaded[path] as Texture2D

static func _badge_texture(key: String, letters: String, fill: String, ink: String) -> Texture2D:
    if _generated.has(key):
        return _generated[key] as Texture2D
    var svg := "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'><rect x='2' y='2' width='28' height='28' rx='8' fill='#%s' stroke='#315f65' stroke-width='2'/><text x='16' y='20.5' text-anchor='middle' font-family='sans-serif' font-size='10' font-weight='700' fill='#%s'>%s</text></svg>" % [fill, ink, letters]
    var image := Image.new()
    var error := image.load_svg_from_string(svg, 2.0)
    if error != OK:
        return null
    var texture := ImageTexture.create_from_image(image)
    _generated[key] = texture
    return texture
