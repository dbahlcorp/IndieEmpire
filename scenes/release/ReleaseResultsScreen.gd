extends Control

@onready var title_label: Label = $Margin/Scroll/VBox/TitleLabel
@onready var main_scroll: ScrollContainer = $Margin/Scroll
@onready var score_label: Label = $Margin/Scroll/VBox/ScoreLabel
@onready var reveal_status_label: Label = $Margin/Scroll/VBox/RevealStatusLabel
@onready var critics_container: VBoxContainer = $Margin/Scroll/VBox/CriticsContainer
@onready var sales_scroll: ScrollContainer = $Margin/Scroll/VBox/SalesScroll
@onready var sales_list: Label = $Margin/Scroll/VBox/SalesScroll/SalesList
@onready var banner_label: Label = $Margin/Scroll/VBox/BannerLabel
@onready var totals_label: Label = $Margin/Scroll/VBox/TotalsLabel
@onready var continue_button: Button = $Margin/Scroll/VBox/ContinueButton

const FIRST_REVIEW_DELAY := 0.38
const CRITIC_REVEAL_SECONDS := 0.68
const BETWEEN_REVIEWS_SECONDS := 0.18
const FINAL_REVEAL_SECONDS := 1.0

var released_game: GameProject
var _cover: GameCoverArt
var _critic_cards: Array[Dictionary] = []
var _reveal_phase := "idle"
var _reveal_elapsed := 0.0
var _reveal_index := 0
var _reveal_complete := false

func _ready() -> void:
    if GameState.released_games.is_empty():
        get_tree().change_scene_to_file.call_deferred("res://scenes/studio/StudioScreen.tscn")
        return

    released_game = ScreenRouter.selected_game()
    if released_game == null:
        released_game = GameState.released_games.back()

    _cover = GameCoverArt.new().configure(released_game)
    _cover.custom_minimum_size = Vector2(82, 106)
    var cover_center := CenterContainer.new()
    cover_center.add_child(_cover)
    $Margin/Scroll/VBox.add_child(cover_center)
    $Margin/Scroll/VBox.move_child(cover_center, 3)

    continue_button.pressed.connect(_on_continue_pressed)
    EventBus.week_ticked.connect(_on_week)
    # Reviews are a presentation moment, not simulation time. Even toggling
    # the clock controls cannot let launch-week sales run under the reveal.
    GameClock.enter_menu()
    _refresh()
    _prepare_reveal()

func _process(delta: float) -> void:
    _advance_reveal(delta)

func _on_week(_year: int, _month: int, _week: int) -> void:
    if released_game != null and not released_game.sales_active:
        # The run is over; stop so the player can read the result.
        GameClock.pause_for_decision("sales finished")
    _refresh()

func _refresh() -> void:
    title_label.text = released_game.title

    sales_list.text = _sales_table()
    banner_label.text = _banner()

    totals_label.text = "Lifetime %s copies · $%s   Cash $%s" % [
        Format.exact(released_game.lifetime_sales),
        Format.exact(released_game.lifetime_revenue),
        Format.exact(GameState.cash)
    ]

func _prepare_reveal() -> void:
    UiBuilder.clear(critics_container)
    _critic_cards.clear()
    score_label.text = "— / 10"
    score_label.modulate = Color(1.0, 1.0, 1.0, 0.42)
    score_label.scale = Vector2.ONE
    reveal_status_label.text = "REVIEWS ARRIVING..."

    for critic in released_game.critic_reviews:
        var card := _critic_card(str(critic.get("outlet", "Critic")))
        card["target"] = float(critic.get("score", 0.0))
        _critic_cards.append(card)

    sales_scroll.visible = false
    banner_label.visible = false
    totals_label.visible = false
    continue_button.disabled = true
    continue_button.text = "REVEALING REVIEWS..."
    _reveal_index = 0
    _reveal_elapsed = 0.0
    _reveal_complete = false
    _reveal_phase = "waiting" if not _critic_cards.is_empty() else "overall"

func _critic_card(outlet: String) -> Dictionary:
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(0, 58)
    card.modulate = Color(1.0, 1.0, 1.0, 0.22)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    var copy := VBoxContainer.new()
    copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var outlet_label := UiBuilder.label(outlet.to_upper(), 14)
    copy.add_child(outlet_label)
    var verdict_label := UiBuilder.label("WAITING...", 11)
    verdict_label.modulate = Color(1.0, 1.0, 1.0, 0.66)
    copy.add_child(verdict_label)
    row.add_child(copy)
    var critic_score := UiBuilder.label("—", 25)
    critic_score.custom_minimum_size.x = 62
    critic_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    critic_score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    row.add_child(critic_score)
    card.add_child(row)
    critics_container.add_child(card)
    return {"panel": card, "score_label": critic_score, "verdict_label": verdict_label}

func _advance_reveal(delta: float) -> void:
    if _reveal_complete or _reveal_phase == "idle":
        return
    _reveal_elapsed += delta
    match _reveal_phase:
        "waiting":
            if _reveal_elapsed >= FIRST_REVIEW_DELAY:
                _begin_critic()
        "critic":
            _animate_current_critic()
        "between":
            if _reveal_elapsed >= BETWEEN_REVIEWS_SECONDS:
                if _reveal_index < _critic_cards.size():
                    _begin_critic()
                else:
                    _begin_overall()
        "overall":
            _animate_overall()

func _begin_critic() -> void:
    _reveal_phase = "critic"
    _reveal_elapsed = 0.0
    var card: PanelContainer = _critic_cards[_reveal_index]["panel"]
    card.pivot_offset = card.size * 0.5
    reveal_status_label.text = "REVIEW %d OF %d" % [
        _reveal_index + 1, _critic_cards.size()]

func _animate_current_critic() -> void:
    var data := _critic_cards[_reveal_index]
    var card := data["panel"] as PanelContainer
    var label := data["score_label"] as Label
    var target := float(data["target"])
    var t := clampf(_reveal_elapsed / CRITIC_REVEAL_SECONDS, 0.0, 1.0)
    var eased := 1.0 - pow(1.0 - t, 3.0)
    label.text = "%.1f" % (target * eased)
    card.modulate = Color(1.0, 1.0, 1.0, lerpf(0.22, 1.0, eased))
    card.scale = Vector2.ONE * lerpf(0.94, 1.0, eased)
    if t < 1.0:
        return
    label.text = "%.1f" % target
    label.add_theme_color_override("font_color", score_color(target))
    (data["verdict_label"] as Label).text = verdict_for(target)
    _reveal_index += 1
    _reveal_elapsed = 0.0
    _reveal_phase = "between"

func _begin_overall() -> void:
    _reveal_phase = "overall"
    _reveal_elapsed = 0.0
    score_label.modulate = Color.WHITE
    score_label.pivot_offset = score_label.size * 0.5
    reveal_status_label.text = "FINAL SCORE"

func _animate_overall() -> void:
    var t := clampf(_reveal_elapsed / FINAL_REVEAL_SECONDS, 0.0, 1.0)
    var eased := 1.0 - pow(1.0 - t, 4.0)
    score_label.text = "%.1f / 10" % (released_game.review_score * eased)
    score_label.scale = Vector2.ONE * (1.0 + sin(t * PI) * 0.16)
    if t < 1.0:
        return
    _finish_reveal()

func _finish_reveal() -> void:
    _reveal_complete = true
    _reveal_phase = "complete"
    score_label.text = "%.1f / 10" % released_game.review_score
    score_label.scale = Vector2.ONE
    score_label.add_theme_color_override("font_color", score_color(released_game.review_score))
    reveal_status_label.text = verdict_for(released_game.review_score)
    sales_scroll.visible = true
    banner_label.visible = true
    totals_label.visible = true
    continue_button.disabled = false
    continue_button.text = "START SALES" if released_game.sales_active else "CONTINUE"
    # Enabling the only action can make a ScrollContainer follow its focus.
    # Keep the actual reveal—the game, cover, and final score—onscreen first.
    main_scroll.scroll_vertical = 0
    main_scroll.set_deferred("scroll_vertical", 0)

static func verdict_for(score: float) -> String:
    if score >= 9.0:
        return "MUST PLAY"
    if score >= 8.0:
        return "EXCELLENT"
    if score >= 7.0:
        return "RECOMMENDED"
    if score >= 6.0:
        return "PROMISING"
    if score >= 5.0:
        return "MIXED"
    return "NOT RECOMMENDED"

static func score_color(score: float) -> Color:
    if score >= 8.0:
        return Color("#58b875")
    if score >= 6.0:
        return Color("#e1b64b")
    return Color("#d76259")


func _sales_table() -> String:
    var lines := ""
    var previous := 0
    for index in released_game.weekly_sales.size():
        var units: int = released_game.weekly_sales[index]
        var arrow := ""
        if index > 0:
            if units > previous:
                arrow = "  ^"
            elif units < previous:
                arrow = "  v"
        lines += "Week %-3d %10s%s\n" % [index + 1, Format.exact(units), arrow]
        previous = units

    lines += "%s\n" % "-".repeat(24)
    lines += "Lifetime %9s" % Format.exact(released_game.lifetime_sales)
    return lines

func _banner() -> String:
    var weeks := released_game.weekly_sales.size()
    if weeks == 0:
        return ""

    var latest: int = released_game.weekly_sales[weeks - 1]

    if weeks >= 2:
        var previous: int = released_game.weekly_sales[weeks - 2]
        if latest > previous:
            return "WORD OF MOUTH\nPlayers are recommending %s." % released_game.title

    if released_game.weekly_sales[0] > 0 and float(latest) < float(released_game.weekly_sales[0]) * 0.25:
        return "Sales have collapsed."

    if not released_game.sales_active:
        return "%s has run its course." % released_game.title

    return "Sales are under way."

func _on_continue_pressed() -> void:
    # A finished sales run is exactly when a postmortem is worth reading.
    if not released_game.sales_active and not released_game.postmortem_reviewed:
        ScreenRouter.open_game(released_game.id, "res://scenes/studio/StudioScreen.tscn")
        get_tree().change_scene_to_file("res://scenes/release/PostmortemScreen.tscn")
        return
    if released_game.sales_active:
        GameClock.enter_gameplay()
    get_tree().change_scene_to_file("res://scenes/studio/StudioScreen.tscn")
