extends Control

## Who is going to sell this game. Self-publishing keeps everything and reaches
## almost nobody; a publisher opens the market and takes most of the money.

@onready var heading: Label = $Margin/VBox/Heading
@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var back_button: Button = $Margin/VBox/BackButton

var project: GameProject

func _ready() -> void:
    GameClock.enter_menu()
    project = GameState.current_project
    back_button.text = "NOT YET"
    back_button.pressed.connect(_on_back)

    if project == null:
        get_tree().change_scene_to_file.call_deferred("res://scenes/studio/StudioScreen.tscn")
        return

    heading.text = "PUBLISH %s" % project.title.to_upper()
    _build()

func _build() -> void:
    UiBuilder.clear(list)
    list.add_child(UiBuilder.label(
        "Development cost %s. Whoever sells it takes their share of every copy." %
        Format.money_exact(project.total_cost()), 14))
    list.add_child(UiBuilder.label(_launch_stability_text(), 14, true))
    list.add_child(UiBuilder.divider())

    for offer in PublishingManager.offers_for(project):
        _offer(offer)

func _launch_stability_text() -> String:
    ## The last chance to notice a low bug count should not be trusted. Not
    ## the true count -- QA never got to see that, and neither does the
    ## player.
    var testing := float(DevelopmentSimulator.staff_effects(project).get("testing", 0.35))
    var rate := QASimulator.discovery_rate(testing, project.polishing)
    return "Known bugs %d   QA Confidence: %s   Launch Stability: %s" % [
        project.known_bugs,
        QASimulator.confidence_label(rate),
        QASimulator.launch_stability_label(project.known_bugs, rate)
    ]

func _offer(offer: Dictionary) -> void:
    var share := float(offer["developer_share"])
    var advance := int(offer["advance"])
    var reach := float(offer["reach"])

    list.add_child(UiBuilder.label(str(offer["name"]), 17))
    list.add_child(UiBuilder.label(str(offer["blurb"]), 13))

    var terms := "You keep        %s of revenue\n" % PublishingSimulator.share_label(share)
    terms += "Market reach    %.2fx\n" % reach
    if advance > 0:
        terms += "Advance         %s (recouped from your share)" % Format.money_exact(advance)
    else:
        terms += "Advance         None"
    list.add_child(UiBuilder.label(terms, 15))

    var button := UiBuilder.major_button(
        "SELF-PUBLISH" if PublishingSimulator.is_self_published(str(offer["id"])) else "SIGN")
    button.pressed.connect(_on_sign.bind(str(offer["id"])))
    list.add_child(button)
    list.add_child(UiBuilder.divider())

func _on_sign(publisher_id: String) -> void:
    if not PublishingManager.sign_deal(project, publisher_id):
        return
    ReviewSimulator.calculate_review(project)
    project.critic_reviews = ReviewSimulator.critic_scores(project)
    SalesManager.release(project)
    ScreenRouter.selected_game_id = project.id
    SaveManager.autosave()
    get_tree().change_scene_to_file("res://scenes/release/ReleaseResultsScreen.tscn")

func _on_back() -> void:
    get_tree().change_scene_to_file("res://scenes/development/DevelopmentScreen.tscn")
