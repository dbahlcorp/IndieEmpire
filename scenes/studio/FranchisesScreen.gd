extends Control

## Every IP the studio owns. One row per franchise: entry count, standing, fan
## interest, fatigue and lifetime revenue. Tapping a row opens its full page.

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var back_button: Button = $Margin/VBox/BackButton

func _ready() -> void:
    GameClock.enter_menu()
    back_button.pressed.connect(func():
        get_tree().change_scene_to_file("res://scenes/studio/GamesScreen.tscn"))
    _build()

func _build() -> void:
    UiBuilder.clear(list)

    if GameState.franchises.is_empty():
        list.add_child(UiBuilder.label(
            "No IPs yet. Every original game you ship becomes one.", 16, true))
        return

    var ordered := GameState.franchises.duplicate()
    ordered.sort_custom(func(a: Franchise, b: Franchise) -> bool:
        return a.lifetime_revenue() > b.lifetime_revenue())

    for franchise in ordered:
        list.add_child(_entry(franchise))
        list.add_child(UiBuilder.divider())

func _entry(franchise: Franchise) -> Control:
    var text := "%s\n%d entr%s   ·   avg %.1f\n\nStanding %s\nFan interest %s   Fatigue %s\nLifetime %s copies   ·   $%s" % [
        franchise.name.to_upper(),
        franchise.entry_count(), "y" if franchise.entry_count() == 1 else "ies",
        franchise.average_review(),
        FranchiseSimulator.reputation_label(franchise.reputation),
        FranchiseSimulator.fan_interest_label(franchise.fan_interest),
        FranchiseSimulator.fatigue_label(franchise.fatigue),
        Format.count(franchise.lifetime_units()),
        Format.count(franchise.lifetime_revenue()),
    ]
    var button := Button.new()
    button.text = text
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    button.custom_minimum_size = Vector2(0, 150)
    button.add_theme_font_size_override("font_size", 14)
    button.pressed.connect(func():
        ScreenRouter.open_franchise(franchise.id, "res://scenes/studio/FranchisesScreen.tscn")
        get_tree().change_scene_to_file("res://scenes/studio/FranchiseDetailScreen.tscn"))
    return button
