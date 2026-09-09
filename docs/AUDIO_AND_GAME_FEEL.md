# PA.8 — Audio & Game Feel

The persistent `AudioManager` owns three mix layers: music, office ambience,
and a bounded eight-voice SFX pool. It listens to EventBus facts and never
changes simulation state or balance.

Feedback covers button taps, navigation, cash changes, research completion,
technology unlocks, hiring, promotions, resignations, releases, review reveals
and verdicts, sales milestones, award nominations/wins, warnings, financial
crisis, and bankruptcy. Award signals are intentionally presentation-ready;
they do not add an awards simulation.

Music state is derived from the current screen with financial danger taking
priority. Award events can temporarily override it. All current states share
one original placeholder loop, and changing between them does not restart the
stream. Replacement tracks must be original or appropriately licensed.

Settings persist independent Master, Music, SFX, and Office Ambience volumes,
plus optional subtle haptics. Haptics use `Input.vibrate_handheld` only on iOS
and only for major confirmation, review reveal, or major achievement profiles.

iOS uses the Ambient audio session with mix-with-others enabled. This respects
the silent switch and avoids interrupting audio the player already has running.
