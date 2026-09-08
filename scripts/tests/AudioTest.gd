extends TestCase

func run() -> void:
    _original_assets_are_playable_loops()
    _ambience_follows_the_office()
    _volume_controls_are_safe()

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

func _volume_controls_are_safe() -> void:
    section("audio volume controls")
    var old_music := Settings.music_volume
    var old_ambience := Settings.ambience_volume
    Settings.set_music_volume(2.0)
    Settings.set_ambience_volume(-1.0)
    check_equal(Settings.music_volume, 1.0, "music volume clamps at full")
    check_equal(Settings.ambience_volume, 0.0, "ambience volume clamps at mute")
    check_greater(AudioManager._volume_db(0.8), AudioManager._volume_db(0.2),
        "the mixer converts louder settings to a louder signal")
    Settings.set_music_volume(old_music)
    Settings.set_ambience_volume(old_ambience)
