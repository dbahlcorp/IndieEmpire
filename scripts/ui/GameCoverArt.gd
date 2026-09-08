class_name GameCoverArt
extends Control

## Deterministic, original cover artwork assembled from a project's stable IDs.
## The same game always gets the same cover after saving and loading.

var game_title := "UNTITLED"
var theme_id := "space"
var genre_id := "action"
var platform_id := "microstar_64"

func _init() -> void:
    custom_minimum_size = Vector2(86, 112)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    resized.connect(queue_redraw)

func configure(project: GameProject) -> GameCoverArt:
    game_title = project.title
    theme_id = project.theme_id
    genre_id = project.genre_id
    platform_id = project.platform_id
    tooltip_text = "%s cover" % project.title
    queue_redraw()
    return self

func configure_preview(title: String, selected_theme: String, selected_genre: String, selected_platform: String) -> GameCoverArt:
    game_title = title if not title.strip_edges().is_empty() else "NEW GAME"
    theme_id = selected_theme
    genre_id = selected_genre
    platform_id = selected_platform
    queue_redraw()
    return self

func _draw() -> void:
    var rect := Rect2(Vector2.ZERO, size)
    if rect.size.x < 8.0 or rect.size.y < 8.0:
        return

    var ink := Color("#315f65")
    var cream := Color("#f7e7bf")
    var accent := IdentityArtwork.theme_colour(theme_id)
    var dark := accent.darkened(0.28)
    var seed := absi((game_title + theme_id + genre_id + platform_id).hash())

    var shell := StyleBoxFlat.new()
    shell.bg_color = dark
    shell.border_color = ink
    shell.set_border_width_all(2)
    shell.set_corner_radius_all(8)
    draw_style_box(shell, rect.grow(-1.0))

    var art_rect := Rect2(5, 5, size.x - 10, size.y * 0.66)
    draw_rect(art_rect, accent)
    if seed % 3 == 0:
        draw_colored_polygon(PackedVector2Array([
            art_rect.position,
            Vector2(art_rect.end.x, art_rect.position.y),
            Vector2(art_rect.position.x, art_rect.end.y),
        ]), _alpha(cream, 0.22))
    elif seed % 3 == 1:
        var radius := minf(art_rect.size.x, art_rect.size.y) * 0.32
        draw_circle(art_rect.get_center(), radius, _alpha(cream, 0.22))
        draw_circle(art_rect.get_center(), radius * 0.48, _alpha(dark, 0.4))
    else:
        for index in 4:
            var y := art_rect.position.y + 8.0 + index * art_rect.size.y / 4.0
            draw_line(Vector2(art_rect.position.x, y), Vector2(art_rect.end.x, y - 12.0), _alpha(cream, 0.22), 7.0)

    var icon := IdentityArtwork.genre_texture(genre_id)
    if icon != null:
        var icon_size := minf(size.x * 0.48, art_rect.size.y * 0.58)
        var icon_rect := Rect2(art_rect.get_center() - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size)
        draw_texture_rect(icon, icon_rect, false)

    var footer_y := art_rect.end.y
    draw_rect(Rect2(5, footer_y, size.x - 10, size.y - footer_y - 5), cream)
    var font := ThemeDB.fallback_font
    var display := game_title.strip_edges().to_upper()
    if display.length() > 16:
        display = display.left(15) + "…"
    draw_string(font, Vector2(9, footer_y + 17), display, HORIZONTAL_ALIGNMENT_CENTER, size.x - 18, 11, ink)

    var theme_badge := IdentityArtwork.theme_texture(theme_id)
    if theme_badge != null:
        draw_texture_rect(theme_badge, Rect2(9, size.y - 28, 20, 20), false)
    var platform := IdentityArtwork.platform_texture(platform_id)
    if platform != null:
        draw_texture_rect(platform, Rect2(size.x - 36, size.y - 29, 27, 21), false)

func _alpha(colour: Color, value: float) -> Color:
    var result := colour
    result.a = value
    return result
