extends TestCase

## PA.7 -- the ReleaseResultsScreen sequence: it reveals launch, critics,
## average, player response, week-one sales and impact in order; tap and SKIP
## both fast-forward it; Reduce Motion lands it instantly; and none of it
## touches the numbers the simulation already produced.

const RELEASE_RESULTS := "res://scenes/release/ReleaseResultsScreen.tscn"

func run() -> void:
    await _reveal_runs_in_order()
    await _skip_jumps_straight_to_the_end()
    await _a_tap_fast_forwards_the_current_beat()
    await _reduced_motion_lands_instantly()
    await _presentation_cannot_alter_simulation()
    await _saving_while_the_results_are_open_is_safe()
    await _the_full_release_is_revisitable_from_history()

func _company() -> void:
    GameState.start_company("Presentation Co", "Ada", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    Settings.reduced_motion = false
    Settings.seen_release_reveal = false

func _released_game(id := "pres_game") -> GameProject:
    var game := GameProject.new()
    game.id = id
    game.title = "Nova Drift"
    game.theme_id = "space"
    game.genre_id = "adventure"
    game.platform_id = "microstar_64"
    game.size_id = "small"
    game.released = true
    game.sales_active = true
    game.review_score = 8.3
    game.bugs = 3
    game.polish_weeks = 3
    game.word_of_mouth = 1.08
    game.critic_reviews = [
        {"outlet": "Pixel Monthly", "score": 8.1},
        {"outlet": "GameWorld", "score": 8.7},
        {"outlet": "Joystick Weekly", "score": 7.9},
        {"outlet": "Computer Player", "score": 8.5},
    ]
    game.weekly_sales.assign([2400])
    game.weekly_revenue.assign([31000])
    game.lifetime_sales = 2400
    game.lifetime_revenue = 31000
    game.fans_gained = 420
    game.reputation_gained = 1.6
    for field in ["gameplay", "graphics", "story", "sound", "technology", "innovation", "balance"]:
        game.set(field, 32.0)
    GameState.released_games.append(game)
    ScreenRouter.selected_game_id = game.id
    return game

func _open() -> Control:
    var screen: Control = load(RELEASE_RESULTS).instantiate()
    add_child(screen)
    await get_tree().process_frame
    return screen

func _drive(screen: Control, seconds := 20.0) -> void:
    var step := 0.1
    var elapsed := 0.0
    while elapsed < seconds and not screen._reveal_complete:
        screen._advance_reveal(step)
        elapsed += step

func _reveal_runs_in_order() -> void:
    section("the sequence reveals one beat at a time")
    _company()
    var game := _released_game("order_game")

    var screen := await _open()
    check_equal(screen._reveal_phase, "launch", "it opens on the launch beat")
    check(screen.continue_button.disabled, "the player cannot continue yet")
    check_equal(screen.score_label.text, "— / 10", "the average is concealed")
    check(not screen.sales_scroll.visible, "sales wait for the reviews")
    check(not screen.banner_panel.visible, "the headline verdict waits for the end")

    var phases_seen: Array[String] = []
    var guard := 0
    while not screen._reveal_complete and guard < 600:
        guard += 1
        if not phases_seen.has(screen._reveal_phase):
            phases_seen.append(screen._reveal_phase)
        screen._advance_reveal(0.1)

    check(screen._reveal_complete, "the sequence completes")
    check_equal(screen.score_label.text, "8.3 / 10", "the exact average lands")
    check(phases_seen.has("critic"), "critics were revealed")
    check(phases_seen.has("overall"), "then the average")
    check(phases_seen.has("response"), "then the player response")
    check(phases_seen.has("sales"), "then week-one sales")
    check(phases_seen.has("impact"), "then the impact")
    check_less(float(phases_seen.find("overall")), float(phases_seen.find("sales")),
        "the average is revealed before the sales")
    check_less(float(phases_seen.find("sales")), float(phases_seen.find("impact")),
        "the sales before the impact")

    check(screen.banner_panel.visible, "the headline verdict is shown at the end")
    check(not screen.banner_label.text.is_empty(), "and it has a title")
    check(screen.sales_scroll.visible, "the sales breakdown is shown")
    check(not screen.continue_button.disabled, "and the player can continue")
    check_equal(screen.continue_button.text, "START SALES", "the handoff is explicit")
    for card in screen._critic_cards:
        check(not str((card["score_label"] as Label).text).contains("—"),
            "every critic score was revealed")
    check(Settings.seen_release_reveal, "the first full viewing is remembered")

    screen.queue_free()
    await get_tree().process_frame

func _skip_jumps_straight_to_the_end() -> void:
    section("SKIP shows everything at once")
    _company()
    Settings.seen_release_reveal = true
    _released_game("skip_game")

    var screen := await _open()
    check(screen.skip_button.visible, "SKIP is offered once the player has seen a reveal")
    screen._skip_to_end()

    check(screen._reveal_complete, "the sequence is finished")
    check_equal(screen.score_label.text, "8.3 / 10", "with the correct average")
    check(screen.banner_panel.visible, "the verdict is shown")
    check(screen.sales_scroll.visible, "the sales are shown")
    check(not screen.skip_button.visible, "and SKIP goes away")
    for card in screen._critic_cards:
        check(not str((card["score_label"] as Label).text).contains("—"),
            "every critic score is filled in")
    screen.queue_free()
    await get_tree().process_frame

func _a_tap_fast_forwards_the_current_beat() -> void:
    section("a tap finishes the current beat")
    _company()
    _released_game("tap_game")
    var screen := await _open()

    var guard := 0
    while not screen._reveal_complete and guard < 200:
        guard += 1
        screen._hurry()
        screen._advance_reveal(0.02)

    check(screen._reveal_complete, "repeated taps walk through the whole sequence quickly")
    check_equal(screen.score_label.text, "8.3 / 10", "and still land on the real average")
    screen.queue_free()
    await get_tree().process_frame

func _reduced_motion_lands_instantly() -> void:
    section("Reduce Motion skips the animation")
    _company()
    Settings.reduced_motion = true
    _released_game("rm_game")
    var screen := await _open()
    check(not screen.skip_button.visible, "no SKIP button -- there is nothing to skip")

    for _i in 20:
        screen._advance_reveal(0.016)

    check(screen._reveal_complete, "a handful of frames is enough")
    check_equal(screen.score_label.text, "8.3 / 10", "with everything shown")
    check(screen.banner_panel.visible, "including the verdict")
    Settings.reduced_motion = false
    screen.queue_free()
    await get_tree().process_frame

func _presentation_cannot_alter_simulation() -> void:
    section("the results screen changes nothing")
    _company()
    var game := _released_game("purity_game")
    var snapshot := {
        "review": game.review_score,
        "weekly_sales": game.weekly_sales.duplicate(),
        "weekly_revenue": game.weekly_revenue.duplicate(),
        "lifetime_sales": game.lifetime_sales,
        "lifetime_revenue": game.lifetime_revenue,
        "fans_gained": game.fans_gained,
        "reputation_gained": game.reputation_gained,
        "bugs": game.bugs,
        "cash": GameState.cash,
        "fans": GameState.fans,
        "reputation": GameState.consumer_reputation,
        "released": GameState.released_games.size(),
    }

    var screen := await _open()
    await _drive(screen)
    check(screen._reveal_complete, "the reveal ran to the end")

    check_equal(game.review_score, snapshot["review"], "review score unchanged")
    check_equal(game.weekly_sales, snapshot["weekly_sales"], "weekly sales unchanged")
    check_equal(game.weekly_revenue, snapshot["weekly_revenue"], "weekly revenue unchanged")
    check_equal(game.lifetime_sales, snapshot["lifetime_sales"], "lifetime sales unchanged")
    check_equal(game.lifetime_revenue, snapshot["lifetime_revenue"], "lifetime revenue unchanged")
    check_equal(game.fans_gained, snapshot["fans_gained"], "fans gained unchanged")
    check_equal(game.reputation_gained, snapshot["reputation_gained"], "reputation gained unchanged")
    check_equal(game.bugs, snapshot["bugs"], "bug count unchanged")
    check_equal(GameState.cash, snapshot["cash"], "company cash unchanged")
    check_equal(GameState.fans, snapshot["fans"], "company fans unchanged")
    check_equal(GameState.consumer_reputation, snapshot["reputation"], "company reputation unchanged")
    check_equal(GameState.released_games.size(), snapshot["released"], "no games added or removed")
    screen.queue_free()
    await get_tree().process_frame

func _saving_while_the_results_are_open_is_safe() -> void:
    section("save and reload mid-reveal, and after it")
    _company()
    var game := _released_game("save_game_id")
    var screen := await _open()
    # part-way through
    for _i in 12:
        screen._advance_reveal(0.1)

    check(SaveManager.save_game("save_release_pres"), "saved with the results open")
    GameState.reset_company()
    check(SaveManager.load_game("save_release_pres"), "loaded again")
    var restored := GameState.find_game("save_game_id")
    if check_not_null(restored, "the released game came back"):
        check_equal(restored.review_score, game.review_score, "with its review")
        check_equal(restored.weekly_sales, game.weekly_sales, "and its sales run")
        check_equal(restored.lifetime_revenue, game.lifetime_revenue, "and its revenue")
    screen.queue_free()

    # finish a fresh reveal and save after
    ScreenRouter.selected_game_id = "save_game_id"
    var after := await _open()
    await _drive(after)
    check(after._reveal_complete, "a second viewing completes")
    check(SaveManager.save_game("save_release_pres"), "and saves cleanly afterwards")
    SaveManager.delete_save("save_release_pres")
    after.queue_free()
    await get_tree().process_frame

func _the_full_release_is_revisitable_from_history() -> void:
    section("Game History opens the complete release information")
    _company()
    var game := _released_game("history_game")
    var screen := await _open()
    await _drive(screen)
    screen.queue_free()
    await get_tree().process_frame

    ScreenRouter.open_game(game.id, "res://scenes/studio/GamesScreen.tscn")
    var detail: Control = load("res://scenes/studio/GameDetailScreen.tscn").instantiate()
    add_child(detail)
    await get_tree().process_frame
    await get_tree().process_frame

    var found_chart := _find_node_of_type(detail, "SalesChart")
    check(found_chart != null, "the detail page renders the sales chart")
    var text := _collect_label_text(detail)
    check(text.contains("RELEASE"), "and a release section")
    check(text.to_lower().contains("carried") or text.to_lower().contains("held"),
        "with the strengths / weaknesses summary")
    detail.queue_free()
    await get_tree().process_frame

func _find_node_of_type(node: Node, type_name: String) -> Node:
    if node.get_class() == type_name or (node.get_script() != null and str(node.get_script().resource_path).get_file().get_basename() == type_name):
        return node
    for child in node.get_children():
        var found := _find_node_of_type(child, type_name)
        if found != null:
            return found
    return null

func _collect_label_text(node: Node) -> String:
    var text := ""
    if node is Label:
        text += (node as Label).text + "\n"
    for child in node.get_children():
        text += _collect_label_text(child)
    return text
