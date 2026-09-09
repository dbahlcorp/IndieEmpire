extends Control

## What went well, what went badly, and what the studio now knows.

@onready var heading: Label = $Margin/VBox/Heading
@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var back_button: Button = $Margin/VBox/BackButton

var game: GameProject

func _ready() -> void:
    GameClock.enter_menu()
    game = ScreenRouter.selected_game()
    back_button.pressed.connect(_on_back_pressed)

    if game == null:
        list.add_child(UiBuilder.label("No project to analyse.", 16, true))
        return

    # Analysing is what awards the experience, so it happens once, here.
    PostmortemSimulator.analyse(game)
    SaveManager.autosave()

    heading.text = "POSTMORTEM"
    _build()
    TutorialManager.queue_step("research")
    TutorialManager.offer("research", list)

func _build() -> void:
    UiBuilder.clear(list)

    list.add_child(UiBuilder.label(game.title.to_upper(), 22, true))
    list.add_child(UiBuilder.label("%.1f / 10  -  %s copies  -  $%s" % [
        game.review_score,
        Format.exact(game.lifetime_sales),
        Format.exact(game.lifetime_revenue)
    ], 14, true))
    list.add_child(UiBuilder.divider())

    _franchise_section()

    list.add_child(UiBuilder.heading("DEVELOPMENT DIRECTION"))
    list.add_child(UiBuilder.label(_development_direction(), 15))
    list.add_child(UiBuilder.divider())

    list.add_child(UiBuilder.heading("WHAT WENT WELL"))
    list.add_child(UiBuilder.label(_bullets(game.went_well, "+"), 15))

    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("WHAT WENT POORLY"))
    list.add_child(UiBuilder.label(_bullets(game.went_poorly, "!"), 15))

    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("LESSONS LEARNED"))
    var lessons := ""
    for lesson in game.lessons:
        lessons += lesson + "\n\n"
    list.add_child(UiBuilder.label(lessons.strip_edges(), 15))

func _franchise_section() -> void:
    if not game.is_sequel():
        return
    var franchise := GameState.franchise_for_game(game)
    if franchise == null:
        return
    list.add_child(UiBuilder.heading("FRANCHISE"))
    list.add_child(UiBuilder.label(
        FranchiseSimulator.postmortem_note(game, franchise), 15))
    list.add_child(UiBuilder.label(
        "The series now stands at: fan interest %s, fatigue %s, reputation %s." % [
            FranchiseSimulator.fan_interest_label(franchise.fan_interest),
            FranchiseSimulator.fatigue_label(franchise.fatigue),
            FranchiseSimulator.reputation_label(franchise.reputation)], 13))
    list.add_child(UiBuilder.divider())

func _development_direction() -> String:
    var lines: Array[String] = []
    for phase in ["pre_production", "production", "polish"]:
        var phase_name: String = {
            "pre_production": "PLAN",
            "production": "BUILD",
            "polish": "FINISH"
        }[phase]
        lines.append("%s\n%s" % [
            phase_name,
            DevelopmentFocusSimulator.name_of(phase, game.focus_id(phase))
        ])
    return "\n\n".join(lines)

func _bullets(lines: Array[String], marker: String) -> String:
    if lines.is_empty():
        return "Nothing of note."
    var text := ""
    for line in lines:
        text += "%s %s\n" % [marker, line]
    return text.strip_edges()

func _on_back_pressed() -> void:
    get_tree().change_scene_to_file(ScreenRouter.return_scene)
