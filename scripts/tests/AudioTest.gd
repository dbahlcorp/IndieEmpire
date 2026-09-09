extends TestCase

func run() -> void:
    _original_assets_are_playable_loops()
    _ambience_follows_the_office()
    _volume_controls_are_safe()
    _feedback_library_is_complete()
    _music_state_transitions()
    _review_feedback()
    _settings_persist()

func _original_assets_are_playable_loops() -> void:
    section("original audio assets")
    check_not_null(AudioManager.MUSIC_SOURCE, "the studio theme imports")
    check_not_null(AudioManager.AMBIENCE_SOURCE, "the office ambience imports")
    check_approx(AudioManager.MUSIC_SOURCE.get_length(), 40.0,
        "the complete original music loop is present")
    check_approx(AudioManager.AMBIENCE_SOURCE.get_length(), 30.0,
        "the complete ambience loop is present")
    check(AudioManager.MUSIC_SOURCE.stereo, "music is stereo")
    check(AudioManager.AMBIENCE_SOURCE.stereo, "ambience is stereo")
    check_not_null(AudioManager.music_player, "the persistent music player exists")
    check_not_null(AudioManager.ambience_player, "the persistent ambience player exists")
    var music := AudioManager.music_player.stream as AudioStreamWAV
    var ambience := AudioManager.ambience_player.stream as AudioStreamWAV
    check_equal(music.loop_mode, AudioStreamWAV.LOOP_FORWARD, "music loops forward")
    check_equal(ambience.loop_mode, AudioStreamWAV.LOOP_FORWARD, "ambience loops forward")
    check_equal(music.loop_end, int(round(music.get_length() * music.mix_rate)),
        "music loops at its exact final sample")
    check_equal(ambience.loop_end, int(round(ambience.get_length() * ambience.mix_rate)),
        "ambience loops at its exact final sample")

func _ambience_follows_the_office() -> void:
    section("contextual office ambience")
    check(AudioManager.scene_uses_ambience("res://scenes/studio/StudioScreen.tscn"),
        "the studio uses room ambience")
    check(AudioManager.scene_uses_ambience("res://scenes/studio/OfficeScreen.tscn"),
        "the remodel screen uses room ambience")
    check(AudioManager.scene_uses_ambience("res://scenes/development/DevelopmentScreen.tscn"),
        "live development uses room ambience")
    check(not AudioManager.scene_uses_ambience("res://scenes/market/MarketScreen.tscn"),
        "the market does not sound like the office")
    check_less(AudioManager.office_ambience_scale("bedroom"),
        AudioManager.office_ambience_scale("campus"),
        "a campus has a fuller room bed than a bedroom")

func _volume_controls_are_safe() -> void:
    section("audio volume controls")
    var old_music := Settings.music_volume
    var old_master := Settings.master_volume
    var old_sfx := Settings.sfx_volume
    Settings.set_master_volume(2.0)
    var old_ambience := Settings.ambience_volume
    Settings.set_music_volume(2.0)
    Settings.set_sfx_volume(-1.0)
    Settings.set_ambience_volume(-1.0)
    check_equal(Settings.master_volume, 1.0, "master volume clamps at full")
    check_equal(Settings.music_volume, 1.0, "music volume clamps at full")
    check_equal(Settings.sfx_volume, 0.0, "SFX volume clamps at mute")
    check_equal(Settings.ambience_volume, 0.0, "ambience volume clamps at mute")
    check_greater(AudioManager._volume_db(0.8), AudioManager._volume_db(0.2),
        "the mixer converts louder settings to a louder signal")
    Settings.set_music_volume(old_music)
    Settings.set_master_volume(old_master)
    Settings.set_sfx_volume(old_sfx)
    Settings.set_ambience_volume(old_ambience)

func _feedback_library_is_complete() -> void:
    section("event feedback library")
    var expected := [
        "button_tap", "navigation", "money_gain", "money_spent",
        "research_complete", "technology_unlock", "employee_hired",
        "employee_promotion", "employee_resignation", "game_release",
        "review_reveal", "excellent_review", "poor_review", "sales_milestone",
        "award_nomination", "award_win", "warning", "financial_crisis",
        "bankruptcy"
    ]
    check_equal(AudioManager.SFX_SOURCES.size(), expected.size(),
        "every PA.8 feedback category has an asset")
    for id in expected:
        check(AudioManager.SFX_SOURCES.has(id), "%s is routed" % id)
        check_not_null(AudioManager.SFX_SOURCES.get(id), "%s imports" % id)
    check_equal(AudioManager.sfx_players.size(), AudioManager.SFX_POOL_SIZE,
        "overlapping feedback has a bounded player pool")

func _music_state_transitions() -> void:
    section("music states")
    check_equal(AudioManager.music_state_for_scene(
        "res://scenes/menu/MainMenuScreen.tscn"), "main_menu", "menu state")
    check_equal(AudioManager.music_state_for_scene(
        "res://scenes/studio/StudioScreen.tscn"), "studio", "studio state")
    check_equal(AudioManager.music_state_for_scene(
        "res://scenes/development/DevelopmentScreen.tscn"), "development",
        "development state")
    check_equal(AudioManager.music_state_for_scene(
        "res://scenes/release/ReleaseResultsScreen.tscn"), "release_results",
        "results state")
    check_equal(AudioManager.music_state_for_scene(
        "res://scenes/awards/AwardsScreen.tscn"), "awards", "awards state")
    var restarts := AudioManager.music_restart_count
    AudioManager.request_music_state("main_menu")
    AudioManager.request_music_state("studio")
    check_equal(AudioManager.music_restart_count, restarts,
        "states sharing a track do not restart it")
    check(not AudioManager.request_music_state("not_a_state"), "unknown states are rejected")
    var old_cash := GameState.cash
    var old_bankrupt := GameState.bankrupt
    GameState.cash = -1
    GameState.bankrupt = false
    check_equal(AudioManager.update_music_state(""), "financial_danger",
        "negative cash overrides scene music")
    GameState.cash = old_cash
    GameState.bankrupt = old_bankrupt

func _review_feedback() -> void:
    section("review feedback")
    var heard: Array[String] = []
    var listener := func(id: String): heard.append(id)
    AudioManager.sfx_played.connect(listener)
    AudioManager.review_reveal(8.6)
    check("review_reveal" in heard, "review reveal has immediate feedback")
    check("excellent_review" in heard, "excellent reviews add a success sting")
    heard.clear()
    AudioManager.review_reveal(4.2)
    check("poor_review" in heard, "poor reviews add restrained negative feedback")
    AudioManager.sfx_played.disconnect(listener)

func _settings_persist() -> void:
    section("settings persistence")
    var old := {
        "master": Settings.master_volume, "music": Settings.music_volume,
        "sfx": Settings.sfx_volume, "ambience": Settings.ambience_volume,
        "haptics": Settings.haptics_enabled
    }
    Settings.master_volume = 0.31
    Settings.music_volume = 0.42
    Settings.sfx_volume = 0.53
    Settings.ambience_volume = 0.24
    Settings.haptics_enabled = false
    Settings.save_settings()
    Settings.master_volume = 1.0
    Settings.music_volume = 1.0
    Settings.sfx_volume = 1.0
    Settings.ambience_volume = 1.0
    Settings.haptics_enabled = true
    Settings.load_settings()
    check_approx(Settings.master_volume, 0.31, "master persists")
    check_approx(Settings.music_volume, 0.42, "music persists")
    check_approx(Settings.sfx_volume, 0.53, "SFX persists")
    check_approx(Settings.ambience_volume, 0.24, "ambience persists")
    check(not Settings.haptics_enabled, "haptic preference persists")
    Settings.master_volume = old["master"]
    Settings.music_volume = old["music"]
    Settings.sfx_volume = old["sfx"]
    Settings.ambience_volume = old["ambience"]
    Settings.haptics_enabled = old["haptics"]
    Settings.save_settings()
