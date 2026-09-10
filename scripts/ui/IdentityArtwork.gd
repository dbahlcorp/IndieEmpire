class_name IdentityArtwork
extends RefCounted

## Stable artwork lookup for game and market identity. Paths live in the asset
## manifest; these helpers preserve the compact API used throughout the UI.

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

static var _generated: Dictionary = {}

static func platform_texture(id: String) -> Texture2D:
    return AssetCatalog.texture("platforms", id)

static func genre_texture(id: String) -> Texture2D:
    return AssetCatalog.texture("genres", id)

static func theme_texture(id: String) -> Texture2D:
    return AssetCatalog.texture("themes", id)

static func technology_texture(id: String) -> Texture2D:
    return AssetCatalog.texture("technologies", id)

static func feature_texture(id: String) -> Texture2D:
    return AssetCatalog.texture("features", id)

static func award_texture(id: String) -> Texture2D:
    return AssetCatalog.texture("awards", id)

static func size_texture(id: String) -> Texture2D:
    var letters := {"small": "S", "medium": "M", "large": "L", "aaa": "XL"}
    var colours := {"small": "6d9a75", "medium": "d09355", "large": "b85f5f", "aaa": "7a6bb0"}
    return _badge_texture("size:%s" % id, str(letters.get(id, id.left(2).to_upper())), str(colours.get(id, "607d80")), "f7e7bf")

static func theme_colour(id: String) -> Color:
    return Color("#%s" % str(THEME_COLOURS.get(id, "607d80")))

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
