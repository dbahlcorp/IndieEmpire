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
    var identity_key := franchise_id if not franchise_id.is_empty() else game_title
    var series_seed := absi(identity_key.hash())
    var accent := _franchise_colour(series_seed) if not franchise_id.is_empty() else IdentityArtwork.theme_colour(theme_id)
    var dark := accent.darkened(0.28)
    var edition_seed := absi((game_title + platform_id + str(era_year)).hash())

    var shell := StyleBoxFlat.new()
    shell.bg_color = dark
    shell.border_color = ink
    shell.set_border_width_all(2)
    shell.set_corner_radius_all(8)
    draw_style_box(shell, rect.grow(-1.0))

    var art_rect := Rect2(5, 5, size.x - 10, size.y - 10)
    draw_rect(art_rect, accent)
    var era := EraVisuals.id_for_year(era_year)
    _draw_era_language(art_rect, era, cream, dark, edition_seed)
    var archetype := _preferred_archetype(series_seed)
    _draw_composition(art_rect.grow(-4.0), archetype, accent, dark, cream, series_seed, edition_seed)

    var title_at_top := archetype in ["poster", "action_diagonal", "character_focus"] and era != "era_1980s"
    var title_height := clampf(size.y * 0.27, 34.0, 67.0)
    var title_rect := Rect2(8, 9 if title_at_top else size.y - title_height - 8, size.x - 16, title_height)
    draw_rect(title_rect, _alpha(dark if title_at_top else cream, 0.92))
    _draw_title(title_rect.grow(-4.0), game_title.strip_edges().to_upper(), cream if title_at_top else ink)
    _draw_identity_marks(title_rect, title_at_top, cream)

func _alpha(colour: Color, value: float) -> Color:
    var result := colour
    result.a = value
    return result

func _preferred_archetype(seed: int) -> String:
    if not franchise_id.is_empty():
        var series_archetypes := ["hero_object", "landscape", "symbolic", "editorial", "poster"]
        return series_archetypes[seed % series_archetypes.size()]
    var preferred: Array[String] = []
    if genre_id in ["action", "shooter", "fighting", "battle_royale", "racing"]:
        preferred = ["action_diagonal", "hero_object", "poster"]
    elif genre_id in ["adventure", "rpg", "sandbox", "simulation"]:
        preferred = ["landscape", "character_focus", "hero_object"]
    elif genre_id in ["strategy", "puzzle", "neural_sim"]:
        preferred = ["symbolic", "editorial", "landscape"]
    elif genre_id in ["horror", "immersive_vr"]:
        preferred = ["poster", "character_focus", "symbolic"]
    else:
        preferred = ["hero_object", "landscape", "editorial"]
    return preferred[seed % preferred.size()]

func _franchise_colour(seed: int) -> Color:
    var colours := [
        Color("#4f91a2"), Color("#7866a6"), Color("#b94e48"),
        Color("#4f956f"), Color("#d07b49"), Color("#5d7896"),
    ]
    return colours[seed % colours.size()]

func _draw_era_language(rect: Rect2, era: String, cream: Color, dark: Color, seed: int) -> void:
    if era == "era_1980s":
        for index in 5:
            var x := rect.position.x + 6.0 + index * rect.size.x / 5.0
            draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), _alpha(cream, 0.16), 2.0)
        draw_rect(rect.grow(-3.0), _alpha(cream, 0.5), false, 3.0)
    elif era == "era_1990s":
        draw_rect(rect.grow(-5.0), _alpha(cream, 0.46), false, 4.0)
        draw_line(rect.position + Vector2(4, 8), rect.position + Vector2(rect.size.x - 4, 8), _alpha(cream, 0.45), 5.0)
        draw_line(rect.position + Vector2(4, 16), rect.position + Vector2(rect.size.x * 0.65, 16), _alpha(cream, 0.28), 3.0)
    elif era == "era_2000s":
        draw_colored_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.get_center()]), _alpha(cream, 0.18))
        draw_colored_polygon(PackedVector2Array([rect.position, Vector2(rect.position.x, rect.end.y), rect.get_center()]), _alpha(dark, 0.22))
    elif era == "era_2010s":
        for index in 4:
            draw_arc(rect.get_center(), 10.0 + index * 14.0, PI, TAU, 18, _alpha(cream, 0.18), 4.0)
    elif seed % 2 == 0:
        draw_circle(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.42, _alpha(cream, 0.12))
    else:
        for index in 5:
            var y := rect.position.y + index * rect.size.y / 4.0
            draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y - 16.0), _alpha(cream, 0.18), 7.0)

func _draw_composition(rect: Rect2, archetype: String, accent: Color, dark: Color, cream: Color, series_seed: int, edition_seed: int) -> void:
    var theme_art := IdentityArtwork.theme_texture(theme_id)
    var genre_art := IdentityArtwork.genre_texture(genre_id)
    match archetype:
        "hero_object":
            draw_circle(rect.get_center() + Vector2(0, -8), rect.size.x * 0.33, _alpha(cream, 0.2))
            _draw_texture(theme_art, Rect2(rect.get_center() - Vector2(rect.size.x * 0.29, rect.size.x * 0.38), Vector2.ONE * rect.size.x * 0.58))
        "character_focus":
            var head := rect.get_center() + Vector2(0, -rect.size.y * 0.19)
            draw_circle(head, rect.size.x * 0.17, dark)
            draw_colored_polygon(PackedVector2Array([Vector2(rect.position.x + 12, rect.end.y - 12), Vector2(rect.end.x - 12, rect.end.y - 12), head + Vector2(rect.size.x * 0.24, rect.size.y * 0.18), head + Vector2(-rect.size.x * 0.24, rect.size.y * 0.18)]), _alpha(dark, 0.9))
            _draw_texture(theme_art, Rect2(head - Vector2.ONE * rect.size.x * 0.12, Vector2.ONE * rect.size.x * 0.24))
        "landscape":
            var horizon := rect.position.y + rect.size.y * 0.55
            draw_colored_polygon(PackedVector2Array([Vector2(rect.position.x, horizon), Vector2(rect.position.x + rect.size.x * 0.32, horizon - rect.size.y * 0.23), Vector2(rect.position.x + rect.size.x * 0.52, horizon - rect.size.y * 0.07), Vector2(rect.position.x + rect.size.x * 0.72, horizon - rect.size.y * 0.28), Vector2(rect.end.x, horizon), rect.end, Vector2(rect.position.x, rect.end.y)]), dark)
            draw_circle(rect.position + Vector2(rect.size.x * 0.72, rect.size.y * 0.24), rect.size.x * 0.11, _alpha(cream, 0.75))
            _draw_texture(theme_art, Rect2(rect.position + Vector2(12, rect.size.y * 0.34), Vector2.ONE * rect.size.x * 0.34))
        "action_diagonal":
            draw_colored_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y)]), _alpha(cream, 0.24))
            draw_line(rect.position + Vector2(-10, rect.size.y * 0.8), rect.position + Vector2(rect.size.x + 10, rect.size.y * 0.18), dark, maxf(9.0, rect.size.x * 0.1))
            _draw_texture(genre_art, Rect2(rect.position + Vector2(rect.size.x * 0.35, rect.size.y * 0.25), Vector2.ONE * rect.size.x * 0.48))
        "symbolic":
            for index in 3:
                draw_arc(rect.get_center(), rect.size.x * (0.18 + index * 0.12), 0, TAU, 24, _alpha(cream, 0.2), 3.0)
            _draw_texture(theme_art, Rect2(rect.get_center() - Vector2.ONE * rect.size.x * 0.28, Vector2.ONE * rect.size.x * 0.56))
        "editorial":
            draw_rect(Rect2(rect.position, Vector2(rect.size.x * 0.38, rect.size.y)), _alpha(dark, 0.72))
            draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.45, rect.size.y * 0.18), Vector2(rect.size.x * 0.46, 5)), _alpha(cream, 0.55))
            draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.45, rect.size.y * 0.27), Vector2(rect.size.x * 0.33, 5)), _alpha(cream, 0.38))
            _draw_texture(theme_art, Rect2(rect.position + Vector2(rect.size.x * 0.08, rect.size.y * 0.32), Vector2.ONE * rect.size.x * 0.36))
        "poster":
            var center := rect.get_center()
            for index in 10:
                var angle := TAU * float(index) / 10.0 + float(series_seed % 9) * 0.03
                draw_line(center, center + Vector2.from_angle(angle) * rect.size.y, _alpha(cream, 0.12), rect.size.x * 0.08)
            _draw_texture(theme_art, Rect2(center - Vector2.ONE * rect.size.x * 0.3, Vector2.ONE * rect.size.x * 0.6))
    if edition_seed % 3 == 0:
        draw_line(rect.position + Vector2(8, rect.end.y - rect.position.y - 13), rect.end - Vector2(8, 13), _alpha(cream, 0.35), 3.0)

func _draw_texture(texture: Texture2D, rect: Rect2) -> void:
    if texture != null:
        draw_texture_rect(texture, rect, false)

func _draw_title(rect: Rect2, title: String, colour: Color) -> void:
    var font := ThemeDB.fallback_font
    var font_size := int(clampf(rect.size.y * 0.28, 9.0, 18.0))
    var lines := _fit_title_lines(title, font, font_size, rect.size.x, 3)
    while lines.size() > 2 and font_size > 9:
        font_size -= 1
        lines = _fit_title_lines(title, font, font_size, rect.size.x, 3)
    var line_height := font.get_height(font_size) + 1.0
    var y := rect.position.y + (rect.size.y - line_height * lines.size()) * 0.5 + font.get_ascent(font_size)
    for line in lines:
        draw_string(font, Vector2(rect.position.x, y), line, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, colour)
        y += line_height

func _fit_title_lines(title: String, font: Font, font_size: int, max_width: float, max_lines: int) -> Array[String]:
    var result: Array[String] = []
    var current := ""
    for word in title.split(" ", false):
        var candidate := str(word) if current.is_empty() else current + " " + str(word)
        if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width or current.is_empty():
            current = candidate
        else:
            result.append(current)
            current = str(word)
    if not current.is_empty():
        result.append(current)
    if result.size() > max_lines:
        var last := " ".join(result.slice(max_lines - 1))
        result.resize(max_lines)
        result[max_lines - 1] = _ellipsize(last, font, font_size, max_width)
    for index in result.size():
        result[index] = _ellipsize(result[index], font, font_size, max_width)
    return result

func _ellipsize(text: String, font: Font, font_size: int, max_width: float) -> String:
    var fitted := text
    while fitted.length() > 1 and font.get_string_size(fitted, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_width:
        fitted = fitted.left(-1)
    if fitted != text:
        while fitted.length() > 1 and font.get_string_size(fitted + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_width:
            fitted = fitted.left(-1)
        fitted += "…"
    return fitted

func _draw_identity_marks(title_rect: Rect2, title_at_top: bool, cream: Color) -> void:
    var mark_y := size.y - 29.0 if title_at_top else 9.0
    var mark_bg := Color("#fff7df")
    draw_circle(Vector2(18, mark_y + 10), 12, _alpha(mark_bg, 0.88))
    _draw_texture(IdentityArtwork.genre_texture(genre_id), Rect2(8, mark_y, 20, 20))
    draw_rect(Rect2(size.x - 39, mark_y - 1, 31, 22), _alpha(mark_bg, 0.88))
    _draw_texture(IdentityArtwork.platform_texture(platform_id), Rect2(size.x - 36, mark_y, 27, 20))

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
