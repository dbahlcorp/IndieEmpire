class_name OfficeArtwork
extends RefCounted

## Keeps presentation assets keyed to the same stable office ids used by saves.
## Screens ask for an id and never need to know a texture's filename.

## The two largest floors reuse the Large Studio Floor art for now --
## bespoke pieces are still to be drawn. Mapped explicitly rather than
## left to the fallback, which would render a 20-desk campus as a bedroom.
const PATHS := {
    "bedroom": "res://assets/offices/bedroom.png",
    "shared_workspace": "res://assets/offices/shared_workspace.png",
    "small_office": "res://assets/offices/small_office.png",
    "professional_studio": "res://assets/offices/professional_studio.png",
    "large_studio_floor": "res://assets/offices/large_studio_floor.png",
    "studio_building": "res://assets/offices/large_studio_floor.png",
    "campus": "res://assets/offices/large_studio_floor.png"
}

const FOREGROUND_PATHS := {
    "bedroom": "res://assets/offices/foreground/bedroom_foreground.png",
    "shared_workspace": "res://assets/offices/foreground/shared_workspace_foreground.png",
    "small_office": "res://assets/offices/foreground/small_office_foreground.png",
    "professional_studio": "res://assets/offices/foreground/professional_studio_foreground.png",
    "large_studio_floor": "res://assets/offices/foreground/large_studio_floor_foreground.png",
    "studio_building": "res://assets/offices/foreground/large_studio_floor_foreground.png",
    "campus": "res://assets/offices/foreground/large_studio_floor_foreground.png"
}

const ATMOSPHERE_PATHS := {
    "bedroom": "res://assets/offices/atmosphere/bedroom_atmosphere.png",
    "shared_workspace": "res://assets/offices/atmosphere/shared_workspace_atmosphere.png",
    "small_office": "res://assets/offices/atmosphere/small_office_atmosphere.png",
    "professional_studio": "res://assets/offices/atmosphere/professional_studio_atmosphere.png",
    "large_studio_floor": "res://assets/offices/atmosphere/large_studio_floor_atmosphere.png",
    "studio_building": "res://assets/offices/atmosphere/large_studio_floor_atmosphere.png",
    "campus": "res://assets/offices/atmosphere/large_studio_floor_atmosphere.png"
}

static func texture(office_id: String) -> Texture2D:
    var path := str(PATHS.get(office_id, PATHS["bedroom"]))
    return load(path) as Texture2D

static func foreground_texture(office_id: String) -> Texture2D:
    var path := str(FOREGROUND_PATHS.get(office_id, FOREGROUND_PATHS["bedroom"]))
    return load(path) as Texture2D

static func atmosphere_texture(office_id: String) -> Texture2D:
    var path := str(ATMOSPHERE_PATHS.get(office_id, ATMOSPHERE_PATHS["bedroom"]))
    return load(path) as Texture2D

static func view(office_id: String, height: int = 190) -> Control:
    var root := Control.new()
    root.name = "OfficeArtwork"
    root.custom_minimum_size = Vector2(0, height)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var art := TextureRect.new()
    art.texture = texture(office_id)
    art.modulate = OfficeCustomizationManager.art_tint()
    art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(art)
    var overlay_texture := OfficeCustomizationManager.overlay_texture()
    if overlay_texture != null:
        var overlay := TextureRect.new()
        overlay.texture = overlay_texture
        overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
        root.add_child(overlay)
    return root
