extends Control

## PA.11 -- the short annual ceremony/result presentation. A restrained readout
## of one year's Game Awards: every category that formed, its nominees with the
## winner marked, and the one-off prestige the night brought the studio.
##
## Presentation only: AwardsManager has already built and applied the ceremony
## by the time this screen loads. Opening it just marks the year seen.

@onready var heading: Label = $Margin/VBox/Heading
@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var back_button: Button = $Margin/VBox/BackButton

func _ready() -> void:
    GameClock.enter_menu()
    back_button.pressed.connect(_on_back)
    _build()

func _ceremony() -> Dictionary:
    if ScreenRouter.selected_ceremony_year > 0:
        return GameState.find_ceremony(ScreenRouter.selected_ceremony_year)
    return AwardsManager.latest_ceremony()

func _build() -> void:
    UiBuilder.clear(list)
    var ceremony := _ceremony()
    if ceremony.is_empty():
        heading.text = "GAME AWARDS"
        list.add_child(UiBuilder.label("No awards ceremony has been held yet.", 16, true))
        return

    var release_year := int(ceremony.get("year", 0))
    heading.text = "%d GAME AWARDS" % (release_year + 1)
    AwardsManager.mark_seen(release_year)

    var stage := TextureRect.new()
    stage.texture = AssetCatalog.texture("award_presentation", "ceremony")
    stage.custom_minimum_size = Vector2(0, 112)
    stage.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    stage.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    list.add_child(stage)
    if not Settings.reduced_motion:
        stage.modulate.a = 0.0
        stage.scale = Vector2(0.96, 0.96)
        stage.pivot_offset = Vector2(190, 56)
        var reveal := create_tween().set_parallel(true)
        reveal.tween_property(stage, "modulate:a", 1.0, 0.45)
        reveal.tween_property(stage, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)

    list.add_child(UiBuilder.label(
        "The annual industry ceremony, honouring games released in %d." % release_year,
        13, true))
    list.add_child(UiBuilder.company_identity_row("Representing the studio on awards night", 48))

    var winner_ids := {}
    for category in ceremony.get("categories", []):
        winner_ids[str(category.get("winner_id", ""))] = true
        list.add_child(UiBuilder.divider())
        var award_id := str(category.get("award_id", ""))
        list.add_child(UiBuilder.identity_row(IdentityArtwork.award_texture(award_id),
            str(category.get("name", "")).to_upper(), Vector2(62, 62), 18))
        var winner_id := str(category.get("winner_id", ""))
        var text := ""
        for nominee in category.get("nominees", []):
            var is_winner := str(nominee.get("game_id", "")) == winner_id
            text += "%s %s\n" % ["WINNER  " if is_winner else "nominee ", str(nominee.get("title", ""))]
        var result_row := HBoxContainer.new()
        result_row.add_theme_constant_override("separation", 12)
        var winner_badge := TextureRect.new()
        winner_badge.texture = AssetCatalog.texture("award_presentation", "winner")
        winner_badge.custom_minimum_size = Vector2(36, 36)
        winner_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        winner_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        result_row.add_child(winner_badge)
        var winner_game := GameState.find_game(winner_id)
        if winner_game != null:
            var cover := GameCoverArt.new().configure(winner_game)
            cover.custom_minimum_size = Vector2(64, 84)
            result_row.add_child(cover)
        var nominee_copy := UiBuilder.label(text.strip_edges(), 15)
        nominee_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        result_row.add_child(nominee_copy)
        list.add_child(result_row)

    for winner_id in winner_ids:
        var game := GameState.find_game(str(winner_id))
        if game == null:
            continue
        var view := UiBuilder.button("VIEW %s" % game.title.to_upper())
        view.pressed.connect(_open_game.bind(game.id))
        list.add_child(view)

    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("WHAT THE NIGHT BROUGHT"))
    list.add_child(UiBuilder.label(_rewards_text(ceremony.get("rewards", {})), 14))

func _rewards_text(rewards: Dictionary) -> String:
    var lines: Array[String] = []
    var wins := int(rewards.get("wins", 0))
    var noms := int(rewards.get("nominations", 0))
    lines.append("%d award%s from %d nomination%s" % [
        wins, "" if wins == 1 else "s", noms, "" if noms == 1 else "s"])
    var reputation := float(rewards.get("reputation", 0.0))
    if reputation > 0.0:
        lines.append("Consumer reputation   +%.1f" % reputation)
    var employer := float(rewards.get("employer_reputation", 0.0))
    if employer > 0.0:
        lines.append("Recruiting reputation  +%.1f" % employer)
    var fans := int(rewards.get("fans", 0))
    if fans > 0:
        lines.append("Fans                  +%s" % Format.count(fans))
    var morale := int(rewards.get("morale", 0))
    if morale > 0:
        lines.append("Team morale            +%d across the studio" % morale)
    lines.append("")
    lines.append("Awards are prestige, not profit: no cash prize and no lasting quality bonus.")
    return "\n".join(lines)

func _open_game(game_id: String) -> void:
    ScreenRouter.open_game(game_id, "res://scenes/company/AwardsCeremonyScreen.tscn")
    get_tree().change_scene_to_file("res://scenes/studio/GameDetailScreen.tscn")

func _on_back() -> void:
    var destination := ScreenRouter.awards_return_scene
    ScreenRouter.selected_ceremony_year = 0
    ScreenRouter.awards_return_scene = "res://scenes/company/RecordsScreen.tscn"
    get_tree().change_scene_to_file(destination)
