extends TestCase

## The verdict words, and the staged critic reveal at the heart of the
## release-results screen. The wider PA.7 sequence -- launch beat, player
## response, sales, impact, skip, reduced motion, save/load, history -- is
## covered by ReleasePresentationTest; this keeps the critic reveal itself
## honest.

const RELEASE_RESULTS := preload("res://scenes/release/ReleaseResultsScreen.gd")

func run() -> void:
    _verdicts_match_scores()
    await _screen_reveals_reviews_in_order()

func _verdicts_match_scores() -> void:
    section("review verdicts")
    check_equal(RELEASE_RESULTS.verdict_for(9.2), "MUST PLAY", "nine is exceptional")
    check_equal(RELEASE_RESULTS.verdict_for(8.1), "EXCELLENT", "eight is excellent")
    check_equal(RELEASE_RESULTS.verdict_for(7.0), "RECOMMENDED", "seven is recommended")
    check_equal(RELEASE_RESULTS.verdict_for(5.4), "MIXED", "five is mixed")
    check_equal(RELEASE_RESULTS.verdict_for(4.9), "NOT RECOMMENDED", "low scores are honest")

func _screen_reveals_reviews_in_order() -> void:
    section("animated review reveal")
    GameState.start_company("Review Test", "Ada", "normal")
    SaveManager.has_active_company = true
    Settings.reduced_motion = false
    Settings.seen_release_reveal = false

    var game := GameProject.new()
    game.id = "review_reveal"
    game.title = "Starfall II"
    game.theme_id = "fantasy"
    game.genre_id = "adventure"
    game.platform_id = "microstar_64"
    game.size_id = "small"
    game.review_score = 8.4
    game.critic_reviews = [
        {"outlet": "Pixel Monthly", "score": 8.1},
        {"outlet": "GameWorld", "score": 8.7},
        {"outlet": "Joystick Weekly", "score": 7.9},
        {"outlet": "Computer Player", "score": 8.8}
    ]
    game.sales_active = true
    game.weekly_sales.assign([1800])
    game.weekly_revenue.assign([24000])
    game.lifetime_sales = 1800
    game.lifetime_revenue = 24000
    game.fans_gained = 260
    game.reputation_gained = 1.4
    GameState.released_games.append(game)
    ScreenRouter.selected_game_id = game.id

    var screen = load("res://scenes/release/ReleaseResultsScreen.tscn").instantiate()
    add_child(screen)
    await get_tree().process_frame
    check_equal(screen._critic_cards.size(), 4, "all four outlets have reserved cards")
    check(screen.continue_button.disabled, "the player cannot continue before the reveal finishes")
    check_equal(screen.score_label.text, "— / 10", "the final score begins concealed")
    check(not screen.sales_scroll.visible, "sales information waits for the reviews")

    var guard := 0
    var critics_before_score := true
    while not screen._reveal_complete and guard < 800:
        guard += 1
        if screen._reveal_phase == "overall" and str(screen.score_label.text).begins_with("—"):
            pass
        if screen._reveal_phase == "critic":
            critics_before_score = critics_before_score and str(screen.score_label.text).begins_with("—")
        screen._advance_reveal(0.05)

    check(screen._reveal_complete, "the staged animation completes")
    check(critics_before_score, "the average stays hidden until the critics are done")
    check_equal(screen.score_label.text, "8.4 / 10", "the exact average lands")
    check(not screen.continue_button.disabled, "the player can continue afterward")
    check_equal(screen.continue_button.text, "START SALES", "the handoff is explicit")
    check(screen.sales_scroll.visible, "sales information appears after the score")
    check(screen.banner_panel.visible, "a headline verdict is shown")
    for card in screen._critic_cards:
        check(not str((card["score_label"] as Label).text).contains("—"),
            "every critic score was revealed")
    screen.queue_free()
    await get_tree().process_frame
