class_name GameCoverArt
extends Control

## Deterministic, original cover artwork assembled from a project's stable IDs.
## The same game always gets the same cover after saving and loading.

var game_title := "UNTITLED"
var theme_id := "space"
var genre_id := "action"
var platform_id := "microstar_64"
var franchise_id := ""
var era_year := 1985

func _init() -> void:
    custom_minimum_size = Vector2(86, 112)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    resized.connect(queue_redraw)

func configure(project: GameProject) -> GameCoverArt:
    game_title = project.title
    theme_id = project.theme_id
    genre_id = project.genre_id
    platform_id = project.platform_id
    franchise_id = project.series_id
    era_year = project.release_year if project.release_year > 0 else project.start_year
    tooltip_text = "%s cover" % project.title
    queue_redraw()
    return self

func configure_preview(title: String, selected_theme: String, selected_genre: String, selected_platform: String) -> GameCoverArt:
    game_title = title if not title.strip_edges().is_empty() else "NEW GAME"
    theme_id = selected_theme
    genre_id = selected_genre
    platform_id = selected_platform
    franchise_id = ""
    era_year = TimeManager.current_year
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
    var identity_key := franchise_id if not franchise_id.is_empty() else game_title
    var seed := absi((identity_key + theme_id + genre_id + platform_id).hash())

    var shell := StyleBoxFlat.new()
    shell.bg_color = dark
    shell.border_color = ink
    shell.set_border_width_all(2)
    shell.set_corner_radius_all(8)
    draw_style_box(shell, rect.grow(-1.0))

    var art_rect := Rect2(5, 5, size.x - 10, size.y * 0.66)
    draw_rect(art_rect, accent)
    var era := EraVisuals.id_for_year(era_year)
    if era == "era_1980s":
        for index in 5:
            var x := art_rect.position.x + 6.0 + index * art_rect.size.x / 5.0
            draw_line(Vector2(x, art_rect.position.y), Vector2(x, art_rect.end.y), _alpha(cream, 0.16), 2.0)
    elif era == "era_1990s":
        draw_rect(art_rect.grow(-5), _alpha(cream, 0.45), false, 4.0)
        draw_line(art_rect.position + Vector2(4, 8), art_rect.position + Vector2(art_rect.size.x - 4, 8), _alpha(cream, 0.4), 5.0)
    elif era == "era_2000s":
        draw_colored_polygon(PackedVector2Array([art_rect.position, Vector2(art_rect.end.x, art_rect.position.y), art_rect.get_center()]), _alpha(cream, 0.18))
        draw_colored_polygon(PackedVector2Array([art_rect.position, Vector2(art_rect.position.x, art_rect.end.y), art_rect.get_center()]), _alpha(dark, 0.22))
    elif era == "era_2010s":
        for index in 3:
            draw_arc(art_rect.get_center(), 9.0 + index * 10.0, PI, TAU, 18, _alpha(cream, 0.22), 4.0)
    elif seed % 3 == 0:
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
    var lines := _title_lines(game_title.strip_edges().to_upper(), 14)
    for index in lines.size():
        draw_string(font, Vector2(9, footer_y + 14 + index * 11), lines[index], HORIZONTAL_ALIGNMENT_CENTER, size.x - 18, 10, ink)

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

func _title_lines(title: String, limit: int) -> Array[String]:
    var result: Array[String] = []
    if title.length() <= limit:
        result.append(title)
        return result
    var words := title.split(" ", false)
    var first := ""
    var second := ""
    for word in words:
        var candidate := str(word) if first.is_empty() else first + " " + str(word)
        if candidate.length() <= limit or first.is_empty():
            first = candidate
        else:
            second = str(word) if second.is_empty() else second + " " + str(word)
    if second.length() > limit:
        second = second.left(limit - 1) + "…"
    if not second.is_empty():
        result.append(first.left(limit))
        result.append(second)
    else:
        result.append(first.left(limit - 1) + "…")
    return result
