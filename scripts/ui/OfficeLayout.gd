class_name OfficeLayout
extends RefCounted

## Normalized physical anchors authored against the 3:2 office illustrations.
## Every tier has one desk per capacity slot, an entrance, a clear central hub,
## and a few break destinations. Actors route via the hub so they do not cut
## directly across desk clusters.

const LAYOUTS := {
    "bedroom": {
        "entrance": Vector2(0.82, 0.83),
        "hub": Vector2(0.56, 0.72),
        "desks": [Vector2(0.39, 0.62)],
        "social": [Vector2(0.56, 0.73), Vector2(0.31, 0.53)]
    },
    "shared_workspace": {
        "entrance": Vector2(0.84, 0.82),
        "hub": Vector2(0.56, 0.70),
        "desks": [
            Vector2(0.31, 0.64), Vector2(0.45, 0.55), Vector2(0.73, 0.68)
        ],
        "social": [Vector2(0.55, 0.74), Vector2(0.78, 0.54), Vector2(0.35, 0.49)]
    },
    "small_office": {
        "entrance": Vector2(0.83, 0.83),
        "hub": Vector2(0.53, 0.69),
        "desks": [
            Vector2(0.18, 0.67), Vector2(0.31, 0.75), Vector2(0.42, 0.49),
            Vector2(0.68, 0.79), Vector2(0.87, 0.68)
        ],
        "social": [Vector2(0.52, 0.57), Vector2(0.75, 0.46), Vector2(0.54, 0.72)]
    },
    "professional_studio": {
        "entrance": Vector2(0.88, 0.84),
        "hub": Vector2(0.54, 0.64),
        "desks": [
            Vector2(0.25, 0.49), Vector2(0.34, 0.49),
            Vector2(0.18, 0.65), Vector2(0.28, 0.66),
            Vector2(0.39, 0.77), Vector2(0.53, 0.86),
            Vector2(0.66, 0.68), Vector2(0.77, 0.64)
        ],
        "social": [Vector2(0.54, 0.58), Vector2(0.46, 0.59), Vector2(0.72, 0.39)]
    },
    "large_studio_floor": {
        "entrance": Vector2(0.88, 0.84),
        "hub": Vector2(0.54, 0.58),
        "desks": [
            Vector2(0.25, 0.43), Vector2(0.32, 0.43),
            Vector2(0.20, 0.61), Vector2(0.29, 0.61),
            Vector2(0.37, 0.70), Vector2(0.46, 0.70),
            Vector2(0.54, 0.72), Vector2(0.62, 0.72),
            Vector2(0.68, 0.59), Vector2(0.76, 0.59),
            Vector2(0.32, 0.74), Vector2(0.58, 0.78)
        ],
        "social": [
            Vector2(0.50, 0.51), Vector2(0.59, 0.51),
            Vector2(0.79, 0.39), Vector2(0.77, 0.73)
        ]
    },
    # The two largest floors share the Large Studio Floor artwork until their
    # own is drawn, so their desks stay inside the same room and simply pack
    # tighter -- sixteen and twenty seats where twelve used to be.
    "studio_building": {
        "entrance": Vector2(0.88, 0.84),
        "hub": Vector2(0.54, 0.58),
        "desks": [
            Vector2(0.21, 0.41), Vector2(0.28, 0.41), Vector2(0.35, 0.41),
            Vector2(0.18, 0.57), Vector2(0.25, 0.57), Vector2(0.32, 0.57),
            Vector2(0.40, 0.68), Vector2(0.47, 0.68), Vector2(0.54, 0.68),
            Vector2(0.61, 0.70), Vector2(0.68, 0.70),
            Vector2(0.70, 0.56), Vector2(0.77, 0.56),
            Vector2(0.30, 0.75), Vector2(0.44, 0.79), Vector2(0.58, 0.79)
        ],
        "social": [
            Vector2(0.50, 0.50), Vector2(0.58, 0.50),
            Vector2(0.80, 0.38), Vector2(0.78, 0.72)
        ]
    },
    "campus": {
        "entrance": Vector2(0.88, 0.84),
        "hub": Vector2(0.54, 0.57),
        "desks": [
            Vector2(0.18, 0.39), Vector2(0.25, 0.39), Vector2(0.32, 0.39), Vector2(0.39, 0.39),
            Vector2(0.16, 0.54), Vector2(0.23, 0.54), Vector2(0.30, 0.54), Vector2(0.37, 0.54),
            Vector2(0.42, 0.66), Vector2(0.49, 0.66), Vector2(0.56, 0.66), Vector2(0.63, 0.66),
            Vector2(0.66, 0.54), Vector2(0.73, 0.54), Vector2(0.80, 0.54),
            Vector2(0.26, 0.72), Vector2(0.33, 0.72),
            Vector2(0.45, 0.79), Vector2(0.56, 0.79), Vector2(0.67, 0.79)
        ],
        "social": [
            Vector2(0.49, 0.49), Vector2(0.57, 0.49),
            Vector2(0.82, 0.38), Vector2(0.79, 0.71)
        ]
    }
}

static func get_layout(office_id: String) -> Dictionary:
    return LAYOUTS.get(office_id, LAYOUTS["bedroom"])

static func desk_count(office_id: String) -> int:
    return (get_layout(office_id).get("desks", []) as Array).size()

