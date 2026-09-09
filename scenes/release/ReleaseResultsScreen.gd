extends Control

## PA.7 release presentation. A staged reveal of a launch that has *already
## happened*: the review, the critic cards, early player response, week-one
## sales and the impact on cash / fans / reputation, ending on a headline
## verdict and a plain-language account of why it landed that way.
##
## Presentation only. Every value shown is read off `released_game`, which
## PublishingScreen finished computing before this scene loaded. Nothing here
## calls a simulator that mutates -- ReleasePresentationTest pins that.

@onready var main_scroll: ScrollContainer = $Margin/Scroll
@onready var heading_label: Label = $Margin/Scroll/VBox/Heading
@onready var skip_button: Button = $Margin/Scroll/VBox/SkipButton
@onready var title_label: Label = $Margin/Scroll/VBox/TitleLabel
@onready var reveal_status_label: Label = $Margin/Scroll/VBox/RevealStatusLabel
@onready var score_label: Label = $Margin/Scroll/VBox/ScoreLabel
@onready var critics_container: VBoxContainer = $Margin/Scroll/VBox/CriticsContainer
@onready var response_label: Label = $Margin/Scroll/VBox/ResponseLabel
@onready var sales_header: Label = $Margin/Scroll/VBox/SalesHeader
@onready var sales_scroll: ScrollContainer = $Margin/Scroll/VBox/SalesScroll
@onready var sales_list: Label = $Margin/Scroll/VBox/SalesScroll/SalesList
@onready var impact_container: VBoxContainer = $Margin/Scroll/VBox/ImpactContainer
@onready var banner_panel: PanelContainer = $Margin/Scroll/VBox/BannerPanel
@onready var banner_label: Label = $Margin/Scroll/VBox/BannerPanel/BannerBox/BannerTitle
@onready var banner_sub: Label = $Margin/Scroll/VBox/BannerPanel/BannerBox/BannerSub
@onready var reasons_container: VBoxContainer = $Margin/Scroll/VBox/ReasonsContainer
@onready var totals_label: Label = $Margin/Scroll/VBox/TotalsLabel
@onready var continue_button: Button = $Margin/Scroll/VBox/ContinueButton

const CRITIC_REVEAL_SECONDS := 0.60
const BETWEEN_REVIEWS_SECONDS := 0.15
## Base seconds for the non-critic beats, before pacing.
const PHASE_SECONDS := {
    "launch": 0.55,
    "waiting": 0.35,
    "overall": 0.90,
    "response": 0.70,
    "sales": 0.70,
    "impact": 0.95,
}

var released_game: GameProject
var _cover: GameCoverArt
var _sales_chart: SalesChart
var _critic_cards: Array[Dictionary] = []
var _impact_rows: Array[Dictionary] = []
var _reveal_phase := "idle"
var _reveal_elapsed := 0.0
var _reveal_index := 0
var _reveal_complete := false
## 1.0 first time, faster once the player has seen a reveal, near-instant with
## Reduce Motion on.
var _pace := 1.0
var _instant := false

func _ready() -> void:
    if GameState.released_games.is_empty():
        get_tree().change_scene_to_file.call_deferred("res://scenes/studio/StudioScreen.tscn")
        return

    released_game = ScreenRouter.selected_game()
    if released_game == null:
        released_game = GameState.released_games.back()

    _instant = Settings.reduced_motion
    _pace = 0.02 if _instant else (0.55 if Settings.seen_release_reveal else 1.0)

    _cover = GameCoverArt.new().configure(released_game)
    _cover.custom_minimum_size = Vector2(82, 106)
    var cover_center := CenterContainer.new()
    cover_center.add_child(_cover)
    var vbox := $Margin/Scroll/VBox
    vbox.add_child(cover_center)
    vbox.move_child(cover_center, title_label.get_index() + 1)

    _sales_chart = SalesChart.new()
    _sales_chart.custom_minimum_size.y = 130
    vbox.add_child(_sales_chart)
    vbox.move_child(_sales_chart, sales_header.get_index() + 1)
    _sales_chart.visible = false

    skip_button.visible = Settings.seen_release_reveal and not _instant
    skip_button.pressed.connect(_skip_to_end)
    continue_button.pressed.connect(_on_continue_pressed)
    EventBus.week_ticked.connect(_on_week)
    # Reviews are a presentation moment, not simulation time. Even toggling
    # the clock controls cannot let launch-week sales run under the reveal.
    GameClock.enter_menu()
    _prepare_reveal()

func _process(delta: float) -> void:
    _advance_reveal(delta)

func _unhandled_input(event: InputEvent) -> void:
    if _reveal_complete:
        return
    var tapped: bool = (
        (event is InputEventMouseButton and event.pressed)
        or (event is InputEventScreenTouch and event.pressed)
        or event.is_action_pressed("ui_accept"))
    if tapped:
        _hurry()
        get_viewport().set_input_as_handled()

# --- Weekly ticks while the player lingers -----------------------------

func _on_week(_year: int, _month: int, _week: int) -> void:
    if released_game != null and not released_game.sales_active:
        GameClock.pause_for_decision("sales finished")
    if _reveal_complete:
        _refresh_after_reveal()

# --- Setting the stage -------------------------------------------------

func _prepare_reveal() -> void:
    UiBuilder.clear(critics_container)
    UiBuilder.clear(impact_container)
    UiBuilder.clear(reasons_container)
    _critic_cards.clear()

    heading_label.text = "LAUNCH DAY"
    title_label.text = released_game.title
    reveal_status_label.text = "%s is out now" % released_game.title
    score_label.text = "— / 10"
    score_label.modulate = Color(1, 1, 1, 0.42)
    score_label.scale = Vector2.ONE

    for critic in released_game.critic_reviews:
        var card := _critic_card(str(critic.get("outlet", "Critic")))
        card["target"] = float(critic.get("score", 0.0))
        _critic_cards.append(card)

    _impact_rows.assign(ReleaseSummarySimulator.impact_rows(released_game))

    response_label.visible = false
    sales_header.visible = false
    sales_scroll.visible = false
    impact_container.visible = false
    banner_panel.visible = false
    reasons_container.visible = false
    totals_label.visible = false
    continue_button.disabled = true
    continue_button.text = "…"

    _reveal_index = 0
    _reveal_elapsed = 0.0
    _reveal_complete = false
    _reveal_phase = "launch"

func _critic_card(outlet: String) -> Dictionary:
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(0, 58)
    card.modulate = Color(1, 1, 1, 0.22)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    var copy := VBoxContainer.new()
    copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    copy.add_child(UiBuilder.label(outlet.to_upper(), 14))
    var verdict_label := UiBuilder.label("WAITING...", 11)
    verdict_label.modulate = Color(1, 1, 1, 0.66)
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

# --- The reveal state machine ----------------------------------------

func _dur(phase: String) -> float:
    return maxf(float(PHASE_SECONDS.get(phase, 0.4)) * _pace, 0.0)

func _advance_reveal(delta: float) -> void:
    if _reveal_complete or _reveal_phase == "idle":
        return
    _reveal_elapsed += delta
    match _reveal_phase:
        "launch":
            if _reveal_elapsed >= _dur("launch"):
                _enter_phase("waiting" if not _critic_cards.is_empty() else "overall")
        "waiting":
            if _reveal_elapsed >= _dur("waiting"):
                _begin_critic()
        "critic":
            _animate_current_critic()
        "between":
            if _reveal_elapsed >= BETWEEN_REVIEWS_SECONDS * _pace:
                if _reveal_index < _critic_cards.size():
                    _begin_critic()
                else:
                    _begin_overall()
        "overall":
            _animate_overall()
        "response":
            if _reveal_elapsed >= _dur("response"):
                _enter_phase("sales")
                _reveal_sales()
        "sales":
            if _reveal_elapsed >= _dur("sales"):
                _enter_phase("impact")
                _begin_impact()
        "impact":
            _animate_impact()

func _enter_phase(phase: String) -> void:
    _reveal_phase = phase
    _reveal_elapsed = 0.0

func _hurry() -> void:
    ## A tap finishes the current beat immediately; walk through with repeated
    ## taps, or use SKIP.
    match _reveal_phase:
        "critic":
            _finish_current_critic()
        "overall":
            _finish_overall()
        "impact":
            _finish_impact()
    _reveal_elapsed = 9999.0

func _skip_to_end() -> void:
    if _reveal_complete:
        return
    for i in _critic_cards.size():
        _reveal_index = i
        _finish_current_critic()
    _reveal_index = _critic_cards.size()
    _finish_overall()
    _reveal_sales()
    _begin_impact()
    _finish_impact()

# --- Critic cards ---------------------------------------------------

func _begin_critic() -> void:
    _enter_phase("critic")
    var card: PanelContainer = _critic_cards[_reveal_index]["panel"]
    card.pivot_offset = card.size * 0.5
    reveal_status_label.text = "REVIEW %d OF %d" % [_reveal_index + 1, _critic_cards.size()]

func _animate_current_critic() -> void:
    var data := _critic_cards[_reveal_index]
    var card := data["panel"] as PanelContainer
    var label := data["score_label"] as Label
    var target := float(data["target"])
    var t := 1.0 if _instant else clampf(_reveal_elapsed / (CRITIC_REVEAL_SECONDS * _pace), 0.0, 1.0)
    var eased := 1.0 - pow(1.0 - t, 3.0)
    label.text = "%.1f" % (target * eased)
    card.modulate = Color(1, 1, 1, lerpf(0.22, 1.0, eased))
    card.scale = Vector2.ONE if _instant else Vector2.ONE * lerpf(0.94, 1.0, eased)
    if t < 1.0:
        return
    _finish_current_critic()

func _finish_current_critic() -> void:
    if _reveal_index >= _critic_cards.size():
        return
    var data := _critic_cards[_reveal_index]
    var label := data["score_label"] as Label
    var target := float(data["target"])
    if str(label.text).contains("—") or float(label.text) < target - 0.001 or float(label.text) > target + 0.001:
        label.text = "%.1f" % target
        label.add_theme_color_override("font_color", score_color(target))
        (data["verdict_label"] as Label).text = verdict_for(target)
        (data["panel"] as PanelContainer).modulate = Color.WHITE
        (data["panel"] as PanelContainer).scale = Vector2.ONE
    _reveal_index += 1
    _enter_phase("between")

# --- Average score -----------------------------------------------

func _begin_overall() -> void:
    _enter_phase("overall")
    score_label.modulate = Color.WHITE
    score_label.pivot_offset = score_label.size * 0.5
    reveal_status_label.text = "AVERAGE SCORE"

func _animate_overall() -> void:
    var t := 1.0 if _instant else clampf(_reveal_elapsed / _dur("overall"), 0.0, 1.0)
    var eased := 1.0 - pow(1.0 - t, 4.0)
    score_label.text = "%.1f / 10" % (released_game.review_score * eased)
    score_label.scale = Vector2.ONE if _instant else Vector2.ONE * (1.0 + sin(t * PI) * 0.16)
    if t < 1.0:
        return
    _finish_overall()

func _finish_overall() -> void:
    score_label.text = "%.1f / 10" % released_game.review_score
    score_label.scale = Vector2.ONE
    score_label.add_theme_color_override("font_color", score_color(released_game.review_score))
    reveal_status_label.text = "INITIAL PLAYER RESPONSE"
    response_label.visible = true
    response_label.text = ReleaseSummarySimulator.initial_response(released_game)
    AudioManager.review_reveal(released_game.review_score)
    _enter_phase("response")
    _scroll_home()

# --- Week-one sales --------------------------------------------------

func _reveal_sales() -> void:
    reveal_status_label.text = "WEEK ONE"
    var week_one := released_game.weekly_sales[0] if not released_game.weekly_sales.is_empty() else 0
    sales_header.visible = true
    sales_header.text = "%s copies sold in week one" % Format.exact(week_one)
    _sales_chart.visible = true
    _sales_chart.configure(released_game.weekly_sales, not _instant)
    sales_scroll.visible = true
    sales_list.text = _sales_chart.text_summary()
    if _reveal_phase != "impact":
        _enter_phase("sales")

# --- Impact --------------------------------------------------------

func _begin_impact() -> void:
    reveal_status_label.text = "THE IMPACT"
    impact_container.visible = true
    UiBuilder.clear(impact_container)
    for row in _impact_rows:
        var line := HBoxContainer.new()
        line.add_theme_constant_override("separation", 12)
        var name_label := UiBuilder.label(str(row["label"]), 15)
        name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var value_label := UiBuilder.label("", 17)
        value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        value_label.add_theme_color_override("font_color",
            ReleaseSummarySimulator.tone_color(str(row.get("tone", "flat"))))
        line.add_child(name_label)
        line.add_child(value_label)
        impact_container.add_child(line)
        row["node"] = value_label
    if _reveal_phase != "impact":
        _enter_phase("impact")

func _animate_impact() -> void:
    var t := 1.0 if _instant else clampf(_reveal_elapsed / _dur("impact"), 0.0, 1.0)
    var shown := int(ceil(t * float(_impact_rows.size())))
    for i in _impact_rows.size():
        var label := _impact_rows[i].get("node") as Label
        if label != null:
            label.text = str(_impact_rows[i]["text"]) if i < shown else ""
    if t < 1.0:
        return
    _finish_impact()

func _finish_impact() -> void:
    for row in _impact_rows:
        var label := row.get("node") as Label
        if label != null:
            label.text = str(row["text"])
    _finish_reveal()

# --- Landing --------------------------------------------------------

func _finish_reveal() -> void:
    if _reveal_complete:
        return
    _reveal_complete = true
    _reveal_phase = "complete"

    score_label.text = "%.1f / 10" % released_game.review_score
    score_label.scale = Vector2.ONE
    score_label.add_theme_color_override("font_color", score_color(released_game.review_score))
    response_label.visible = true
    response_label.text = ReleaseSummarySimulator.initial_response(released_game)
    sales_header.visible = true
    _sales_chart.visible = true
    _sales_chart.configure(released_game.weekly_sales, false)
    sales_scroll.visible = true
    sales_list.text = _sales_chart.text_summary()
    impact_container.visible = true
    for row in _impact_rows:
        var label := row.get("node") as Label
        if label != null:
            label.text = str(row["text"])

    var verdict := ReleaseSummarySimulator.verdict(released_game)
    banner_panel.visible = true
    banner_label.text = str(verdict["title"])
    banner_label.add_theme_color_override("font_color",
        ReleaseSummarySimulator.tone_color(str(verdict["tone"])))
    banner_sub.text = str(verdict["subtitle"])
    reveal_status_label.text = str(verdict["title"])

    _build_reasons()
    reasons_container.visible = true
    totals_label.visible = true
    _refresh_after_reveal()

    continue_button.disabled = false
    continue_button.text = "START SALES" if released_game.sales_active else "CONTINUE"
    skip_button.visible = false
    _scroll_home()
    Settings.mark_release_reveal_seen()
    SaveManager.autosave()
    TutorialManager.offer("reviews", score_label)

func _build_reasons() -> void:
    UiBuilder.clear(reasons_container)
    var strengths: Array = released_game.went_well if released_game.postmortem_reviewed \
        else ReleaseSummarySimulator.strengths(released_game)
    var weaknesses: Array = released_game.went_poorly if released_game.postmortem_reviewed \
        else ReleaseSummarySimulator.weaknesses(released_game)

    reasons_container.add_child(UiBuilder.heading("WHAT CARRIED IT"))
    reasons_container.add_child(UiBuilder.label(
        _bullets(strengths, "•"), 14))
    reasons_container.add_child(UiBuilder.heading("WHAT HELD IT BACK"))
    reasons_container.add_child(UiBuilder.label(
        _bullets(weaknesses, "•"), 14))

func _bullets(items: Array, marker: String) -> String:
    if items.is_empty():
        return "Nothing stood out."
    var text := ""
    for item in items:
        text += "%s %s\n" % [marker, str(item)]
    return text.strip_edges()

func _refresh_after_reveal() -> void:
    totals_label.text = "Lifetime %s copies  ·  $%s     Cash $%s" % [
        Format.exact(released_game.lifetime_sales),
        Format.exact(released_game.lifetime_revenue),
        Format.exact(GameState.cash)]
    if _sales_chart != null and _sales_chart.visible:
        _sales_chart.configure(released_game.weekly_sales, false)
        sales_list.text = _sales_chart.text_summary()

func _scroll_home() -> void:
    main_scroll.scroll_vertical = 0
    main_scroll.set_deferred("scroll_vertical", 0)

# --- Verdict words (shared with tests) -----------------------------

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

func _on_continue_pressed() -> void:
    if not released_game.sales_active and not released_game.postmortem_reviewed:
        ScreenRouter.open_game(released_game.id, "res://scenes/studio/StudioScreen.tscn")
        get_tree().change_scene_to_file("res://scenes/release/PostmortemScreen.tscn")
        return
    if released_game.sales_active:
        GameClock.enter_gameplay()
    get_tree().change_scene_to_file("res://scenes/studio/StudioScreen.tscn")
