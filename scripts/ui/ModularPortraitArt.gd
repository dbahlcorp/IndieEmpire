class_name ModularPortraitArt
extends RefCounted

## Deterministic, code-drawn employee portraits. The office sprite chooses a
## broad visual family; the seed composes the close-up modules within it.

const SKIN_TONES: Array[Color] = [
    Color("#f6d2ad"), Color("#e9b887"), Color("#d99662"), Color("#bd7548"),
    Color("#9a5838"), Color("#75402f"), Color("#563128"), Color("#3d251f")
]
const HAIR_COLORS: Array[Color] = [
    Color("#241d20"), Color("#392823"), Color("#57372a"), Color("#7b4930"),
    Color("#a95a2c"), Color("#d18a52"), Color("#b6a49a"), Color("#e7d1a5")
]
const CLOTHING: Array[Dictionary] = [
    {"main": Color("#24727a"), "accent": Color("#df7840"), "shirt": Color("#f4dfb4")},
    {"main": Color("#d69a2f"), "accent": Color("#26717a"), "shirt": Color("#f4e8c8")},
    {"main": Color("#547b96"), "accent": Color("#b84e35"), "shirt": Color("#f1ddbc")},
    {"main": Color("#714462"), "accent": Color("#d19b36"), "shirt": Color("#99bda5")},
    {"main": Color("#b7502c"), "accent": Color("#286570"), "shirt": Color("#f0dfbd")},
    {"main": Color("#536c36"), "accent": Color("#ca5b37"), "shirt": Color("#d5a83e")},
    {"main": Color("#d5a12d"), "accent": Color("#17656d"), "shirt": Color("#f2e6cb")},
    {"main": Color("#3d6076"), "accent": Color("#d07955"), "shirt": Color("#e9c99c")},
    {"main": Color("#67558b"), "accent": Color("#d26745"), "shirt": Color("#317078")},
    {"main": Color("#2e4966"), "accent": Color("#a9524e"), "shirt": Color("#efe0bf")},
    {"main": Color("#66723e"), "accent": Color("#c98232"), "shirt": Color("#d7a43b")},
    {"main": Color("#d9563f"), "accent": Color("#d4a238"), "shirt": Color("#f4e5c8")}
]

# skin choices, hairstyle choices, hair-colour choices, clothing choices and
# facial-hair choices for each physical sprite rig. Nearby variants retain the
# visual bridge without reducing every employee to one baked portrait.
const RIG_FAMILIES: Array[Dictionary] = [
    {"skin": [0, 1], "hair": [0, 8, 11], "color": [0, 1, 2], "clothes": [0, 2], "facial": [0, 1, 2, 3]},
    {"skin": [2, 3], "hair": [2, 3, 10], "color": [0, 1, 2], "clothes": [1, 6], "facial": [0]},
    {"skin": [4, 5], "hair": [4, 11], "color": [0, 1], "clothes": [2, 0], "facial": [0, 1]},
    {"skin": [1, 2], "hair": [3, 8], "color": [0, 1], "clothes": [3, 8], "facial": [0]},
    {"skin": [3, 4], "hair": [0, 8, 11], "color": [0, 1], "clothes": [4, 10], "facial": [1, 2, 3]},
    {"skin": [0, 1], "hair": [2, 10], "color": [4, 5], "clothes": [5, 1], "facial": [0]},
    {"skin": [2, 3], "hair": [5], "color": [0, 1], "clothes": [6, 1], "facial": [0]},
    {"skin": [5, 6], "hair": [6, 4], "color": [6, 1], "clothes": [7, 2], "facial": [0]},
    {"skin": [0, 1], "hair": [7, 8], "color": [7, 6, 5], "clothes": [8, 3], "facial": [0, 1]},
    {"skin": [1, 2], "hair": [8, 0], "color": [0, 6], "clothes": [9, 7], "facial": [0, 1, 2]},
    {"skin": [2, 3], "hair": [11, 2], "color": [0, 1], "clothes": [10, 5], "facial": [0, 2, 3]},
    {"skin": [4, 5], "hair": [9, 6], "color": [0, 1, 2], "clothes": [11, 4], "facial": [0]}
]

const ROLE_COLORS := {
    "programmer": Color("#55b7c1"), "designer": Color("#e0aa3e"),
    "artist": Color("#d86a50"), "writer": Color("#9d78ad"),
    "audio_designer": Color("#68a86f"), "producer": Color("#df8a42"),
    "qa_tester": Color("#7aa4c2"), "generalist": Color("#5f8f87"),
    "founder": Color("#efb34f")
}

static func identity(seed: int, appearance_index: int = -1) -> Dictionary:
    var safe_seed := absi(seed) if seed != 0 else 1
    var rig := clampi(appearance_index, 0, RIG_FAMILIES.size() - 1)
    if appearance_index < 0:
        rig = safe_seed % RIG_FAMILIES.size()
    var family: Dictionary = RIG_FAMILIES[rig]
    var rng := RandomNumberGenerator.new()
    rng.seed = safe_seed * 104729 + rig * 8191
    return {
        "rig": rig,
        "face": rng.randi_range(0, 4),
        "skin": _pick(family["skin"], rng),
        "hair": _pick(family["hair"], rng),
        "hair_color": _pick(family["color"], rng),
        "glasses": rng.randi_range(0, 5),
        "clothing": _pick(family["clothes"], rng),
        "facial_hair": _pick(family["facial"], rng),
        "brow": rng.randi_range(0, 2),
        "eye_spacing": rng.randf_range(0.88, 1.12)
    }

static func signature(modules: Dictionary) -> String:
    return "%d:%d:%d:%d:%d:%d:%d:%d:%0.2f" % [
        int(modules["rig"]), int(modules["face"]), int(modules["skin"]),
        int(modules["hair"]), int(modules["hair_color"]), int(modules["glasses"]),
        int(modules["clothing"]), int(modules["facial_hair"]),
        float(modules["eye_spacing"])
    ]

static func expression(employee: Employee) -> String:
    if employee.stress >= 70:
        return "stressed"
    if employee.energy <= 30:
        return "tired"
    if employee.morale >= 90 and employee.stress <= 25 and employee.energy >= 60:
        return "excited"
    if employee.morale >= 70:
        return "happy"
    if employee.morale < 35:
        return "worried"
    return "neutral"

static func draw(canvas: CanvasItem, rect: Rect2, employee: Employee) -> void:
    var modules := identity(employee.portrait_seed, employee.appearance_index)
    var side := minf(rect.size.x, rect.size.y)
    var origin := rect.position + (rect.size - Vector2(side, side)) * 0.5
    var center := origin + Vector2(side * 0.5, side * 0.48)
    var skin: Color = SKIN_TONES[int(modules["skin"])]
    var hair: Color = HAIR_COLORS[int(modules["hair_color"])]
    var clothes: Dictionary = CLOTHING[int(modules["clothing"])]
    var ink := Color("#273f43")
    var role_color: Color = ROLE_COLORS.get(employee.role, Color("#5f8f87"))

    canvas.draw_circle(origin + Vector2(side * 0.5, side * 0.5), side * 0.47, Color("#f3d69f"))
    canvas.draw_circle(origin + Vector2(side * 0.5, side * 0.5), side * 0.43, Color("#f8e9ca"))
    canvas.draw_arc(origin + Vector2(side * 0.5, side * 0.5), side * 0.47, 0.0, TAU, 48, ink, maxf(1.5, side * 0.022), true)

    _draw_shoulders(canvas, origin, side, clothes, ink, role_color)
    _draw_hair_back(canvas, center, side, int(modules["hair"]), hair, ink)
    canvas.draw_circle(center + Vector2(-side * 0.205, side * 0.015), side * 0.065, skin)
    canvas.draw_circle(center + Vector2(side * 0.205, side * 0.015), side * 0.065, skin)
    var face_points := _face_polygon(center, side, int(modules["face"]))
    canvas.draw_colored_polygon(face_points, skin)
    var face_outline := face_points.duplicate()
    face_outline.append(face_points[0])
    canvas.draw_polyline(face_outline, ink, maxf(1.0, side * 0.014), true)
    _draw_hair_front(canvas, center, side, int(modules["hair"]), hair, ink)
    _draw_features(canvas, center, side, modules, hair, ink, employee)

static func _draw_shoulders(canvas: CanvasItem, origin: Vector2, side: float,
        clothes: Dictionary, ink: Color, role_color: Color) -> void:
    var body := PackedVector2Array([
        origin + Vector2(side * 0.17, side * 0.91), origin + Vector2(side * 0.22, side * 0.73),
        origin + Vector2(side * 0.38, side * 0.66), origin + Vector2(side * 0.62, side * 0.66),
        origin + Vector2(side * 0.78, side * 0.73), origin + Vector2(side * 0.83, side * 0.91)
    ])
    canvas.draw_colored_polygon(body, clothes["main"])
    canvas.draw_polyline(body, ink, maxf(1.0, side * 0.014), true)
    var shirt := PackedVector2Array([
        origin + Vector2(side * 0.39, side * 0.67), origin + Vector2(side * 0.50, side * 0.82),
        origin + Vector2(side * 0.61, side * 0.67)
    ])
    canvas.draw_colored_polygon(shirt, clothes["shirt"])
    canvas.draw_line(origin + Vector2(side * 0.28, side * 0.75),
        origin + Vector2(side * 0.22, side * 0.88), clothes["accent"], side * 0.025, true)
    canvas.draw_circle(origin + Vector2(side * 0.72, side * 0.77), side * 0.035, role_color)
    canvas.draw_arc(origin + Vector2(side * 0.72, side * 0.77), side * 0.035,
        0.0, TAU, 20, ink, maxf(1.0, side * 0.01), true)

static func _face_polygon(center: Vector2, side: float, shape: int) -> PackedVector2Array:
    var widths := [0.205, 0.225, 0.195, 0.215, 0.205]
    var heights := [0.255, 0.235, 0.27, 0.25, 0.245]
    var jaw := [0.82, 0.9, 0.72, 0.76, 0.86]
    var points := PackedVector2Array()
    for index in 20:
        var angle := -PI * 0.5 + TAU * float(index) / 20.0
        var lower: float = float(jaw[shape]) if sin(angle) > 0.35 else 1.0
        points.append(center + Vector2(cos(angle) * side * widths[shape] * lower,
            sin(angle) * side * heights[shape]))
    return points

static func _draw_hair_back(canvas: CanvasItem, center: Vector2, side: float,
        style: int, color: Color, ink: Color) -> void:
    if style in [2, 3, 6, 9, 10]:
        canvas.draw_circle(center + Vector2(0, side * 0.015), side * 0.245, ink)
        canvas.draw_circle(center + Vector2(0, side * 0.025), side * 0.225, color)
    if style == 9:
        canvas.draw_circle(center + Vector2(side * 0.02, -side * 0.27), side * 0.105, ink)
        canvas.draw_circle(center + Vector2(side * 0.02, -side * 0.27), side * 0.087, color)
    elif style == 10:
        canvas.draw_circle(center + Vector2(side * 0.225, -side * 0.04), side * 0.105, ink)
        canvas.draw_circle(center + Vector2(side * 0.225, -side * 0.04), side * 0.087, color)
    elif style == 6:
        for offset in [-0.18, -0.12, -0.06, 0.0, 0.06, 0.12, 0.18]:
            canvas.draw_line(center + Vector2(side * offset, -side * 0.08),
                center + Vector2(side * offset * 1.2, side * 0.27), ink, side * 0.035, true)
            canvas.draw_line(center + Vector2(side * offset, -side * 0.08),
                center + Vector2(side * offset * 1.2, side * 0.27), color, side * 0.022, true)
    elif style == 5:
        var scarf := PackedVector2Array([
            center + Vector2(-side * 0.25, -side * 0.08), center + Vector2(-side * 0.21, side * 0.29),
            center + Vector2(side * 0.20, side * 0.29), center + Vector2(side * 0.25, -side * 0.08)
        ])
        canvas.draw_colored_polygon(scarf, ink)
        canvas.draw_circle(center + Vector2(0, -side * 0.05), side * 0.25, ink)
        canvas.draw_circle(center + Vector2(0, -side * 0.05), side * 0.23, color)

static func _draw_hair_front(canvas: CanvasItem, center: Vector2, side: float,
        style: int, color: Color, ink: Color) -> void:
    if style == 5:
        canvas.draw_arc(center, side * 0.225, PI, TAU, 24, color, side * 0.055, true)
        return
    if style in [2, 4, 11]:
        for index in range(-3, 4):
            var radius := side * (0.065 if style != 4 else 0.058)
            var pos := center + Vector2(side * index * 0.058,
                -side * (0.205 + 0.02 * abs(index)))
            canvas.draw_circle(pos, radius + side * 0.012, ink)
            canvas.draw_circle(pos, radius, color)
        return
    if style == 7:
        var top := PackedVector2Array([
            center + Vector2(-side * 0.19, -side * 0.15), center + Vector2(-side * 0.05, -side * 0.29),
            center + Vector2(side * 0.21, -side * 0.22), center + Vector2(side * 0.08, -side * 0.08)
        ])
        canvas.draw_colored_polygon(top, color)
        canvas.draw_polyline(top, ink, side * 0.018, true)
        canvas.draw_line(center + Vector2(-side * 0.2, -side * 0.12),
            center + Vector2(-side * 0.2, side * 0.08), ink, side * 0.02, true)
        return
    var fringe := PackedVector2Array([
        center + Vector2(-side * 0.22, -side * 0.08), center + Vector2(-side * 0.17, -side * 0.22),
        center + Vector2(-side * 0.03, -side * 0.28), center + Vector2(side * 0.18, -side * 0.21),
        center + Vector2(side * 0.22, -side * 0.07), center + Vector2(side * 0.07, -side * 0.13),
        center + Vector2(-side * 0.04, -side * 0.08)
    ])
    canvas.draw_colored_polygon(fringe, color)
    canvas.draw_polyline(fringe, ink, maxf(1.0, side * 0.015), true)

static func _draw_features(canvas: CanvasItem, center: Vector2, side: float,
        modules: Dictionary, hair: Color, ink: Color, employee: Employee) -> void:
    var spacing := side * 0.085 * float(modules["eye_spacing"])
    var eye_y := center.y - side * 0.015
    var current_expression := expression(employee)
    var stressed := current_expression == "stressed"
    var happy := current_expression in ["happy", "excited"]
    var excited := current_expression == "excited"
    var tired := current_expression == "tired"
    var low := current_expression == "worried"
    var brow_tilt := side * (0.022 if stressed else -0.018 if excited else -0.008 if happy else 0.0)
    for direction in [-1.0, 1.0]:
        var eye := Vector2(center.x + spacing * direction, eye_y)
        if tired:
            canvas.draw_line(eye - Vector2(side * 0.03, 0), eye + Vector2(side * 0.03, side * 0.008),
                ink, maxf(1.4, side * 0.018), true)
        else:
            canvas.draw_circle(eye, side * 0.032, Color.WHITE)
            canvas.draw_circle(eye + Vector2(direction * side * 0.004, 0), side * 0.016, ink)
        canvas.draw_line(eye + Vector2(-side * 0.035, -side * 0.055 - brow_tilt * direction),
            eye + Vector2(side * 0.035, -side * 0.055 + brow_tilt * direction),
            hair.darkened(0.18), maxf(1.2, side * 0.018), true)

    _draw_glasses(canvas, center, side, spacing, int(modules["glasses"]), ink)
    canvas.draw_line(center + Vector2(0, side * 0.015), center + Vector2(-side * 0.012, side * 0.07),
        Color(ink.r, ink.g, ink.b, 0.55), maxf(1.0, side * 0.009), true)
    _draw_facial_hair(canvas, center, side, int(modules["facial_hair"]), hair)

    var mouth_y := center.y + side * 0.13
    if excited:
        canvas.draw_arc(Vector2(center.x, mouth_y - side * 0.035), side * 0.077,
            0.12, PI - 0.12, 16, ink, maxf(1.6, side * 0.02), true)
        canvas.draw_circle(center + Vector2(-side * 0.24, -side * 0.16), side * 0.018, Color("#f0b34f"))
        canvas.draw_circle(center + Vector2(side * 0.24, -side * 0.18), side * 0.018, Color("#f0b34f"))
    elif happy:
        canvas.draw_arc(Vector2(center.x, mouth_y - side * 0.025), side * 0.065,
            0.18, PI - 0.18, 14, ink, maxf(1.4, side * 0.018), true)
    elif low:
        canvas.draw_arc(Vector2(center.x, mouth_y + side * 0.05), side * 0.055,
            PI + 0.2, TAU - 0.2, 14, ink, maxf(1.4, side * 0.018), true)
    elif stressed:
        canvas.draw_line(Vector2(center.x - side * 0.05, mouth_y),
            Vector2(center.x + side * 0.05, mouth_y - side * 0.012), ink,
            maxf(1.4, side * 0.018), true)
    elif tired:
        canvas.draw_line(Vector2(center.x - side * 0.045, mouth_y),
            Vector2(center.x + side * 0.045, mouth_y), ink, maxf(1.3, side * 0.016), true)
    else:
        canvas.draw_arc(Vector2(center.x, mouth_y - side * 0.015), side * 0.045,
            0.25, PI - 0.25, 12, ink, maxf(1.2, side * 0.015), true)

static func _draw_glasses(canvas: CanvasItem, center: Vector2, side: float,
        spacing: float, style: int, ink: Color) -> void:
    if style == 0:
        return
    var color := Color("#315f65") if style % 2 == 0 else Color("#8b5d35")
    var radius := side * (0.052 if style in [1, 4] else 0.047)
    for direction in [-1.0, 1.0]:
        var lens := Vector2(center.x + spacing * direction, center.y - side * 0.015)
        if style in [2, 5]:
            var rect := Rect2(lens - Vector2(radius, radius * 0.78), Vector2(radius * 2.0, radius * 1.56))
            canvas.draw_polyline(PackedVector2Array([
                rect.position, rect.position + Vector2(rect.size.x, 0), rect.end,
                rect.position + Vector2(0, rect.size.y), rect.position
            ]), color, maxf(1.2, side * 0.015), true)
        else:
            canvas.draw_arc(lens, radius, 0.0, TAU, 20, color, maxf(1.2, side * 0.015), true)
    canvas.draw_line(Vector2(center.x - spacing + radius, center.y - side * 0.015),
        Vector2(center.x + spacing - radius, center.y - side * 0.015), color,
        maxf(1.0, side * 0.012), true)

static func _draw_facial_hair(canvas: CanvasItem, center: Vector2, side: float,
        style: int, color: Color) -> void:
    if style == 0:
        return
    if style in [1, 3]:
        canvas.draw_arc(center + Vector2(-side * 0.035, side * 0.105), side * 0.04,
            0.1, PI - 0.1, 10, color, side * 0.025, true)
        canvas.draw_arc(center + Vector2(side * 0.035, side * 0.105), side * 0.04,
            0.1, PI - 0.1, 10, color, side * 0.025, true)
    if style == 2:
        canvas.draw_colored_polygon(PackedVector2Array([
            center + Vector2(-side * 0.025, side * 0.14),
            center + Vector2(side * 0.025, side * 0.14),
            center + Vector2(0, side * 0.205)
        ]), color)
    elif style == 3:
        canvas.draw_arc(center + Vector2(0, side * 0.09), side * 0.155,
            0.25, PI - 0.25, 18, color, side * 0.055, true)

static func _pick(options: Array, rng: RandomNumberGenerator):
    return options[rng.randi_range(0, options.size() - 1)]
