# Difficulty, Settings & Accessibility (PA.14) — 2026-09-09

## Difficulty

Three tiers (`data/difficulties.json`), one shared simulation. A tier is only a
small set of economic/risk scalars applied at well-defined call sites — never a
second copy of any system, and never a change to what content is compatible or
available.

| key | Relaxed | Normal | Hard | read by |
|---|---|---|---|---|
| `starting_cash` | 25000 | 10000 | 7500 | `GameState.reset_company()` |
| `sales_multiplier` | 1.2 | 1.0 | 0.9 | `SalesManager.release()` → `SalesSimulator.base_demand` |
| `expense_multiplier` | 0.8 | 1.0 | 1.15 | `FinanceManager.expense()` |
| `grace_weeks` | 12 | 6 | 3 | `GameState.grace_weeks()` |
| `salary_multiplier` | 0.9 | 1.0 | 1.12 | `EmployeeManager.generate_candidate()` |
| `project_risk_multiplier` | 0.85 | 1.0 | 1.18 | `DevelopmentSimulator.advance_project()` bug risk |

The last two are new this pass. **Normal is the canonical balance target and
every Normal multiplier is exactly 1.0**, so `BalanceProbe` (which plays a
Normal career) is unaffected and no re-measurement was required. An unknown
`difficulty_id` falls back to the Normal-equivalent dict.

`difficulty_id` stays in the company save (v25, unchanged — it was already
there). `DifficultyTest` pins the catalogue shape, the neutral-Normal
property, the ordering, and that each modifier reaches its call site.

## Settings

`autoload/Settings.gd` persists to `user://settings.json`, entirely separate
from `user://saves/` — preferences survive a new company, a wipe or a
bankruptcy. New fields this pass:

- **`default_game_speed`** — the clock speed (index into `GameClock.SPEEDS`) a
  company begins and resumes at. Applied by `GameClock.apply_default_speed()`
  on new-company creation and on load; live changes from the clock bar are not
  written back.
- **`autosave_enabled`** — gates `SaveManager.autosave()` only. Manual slots and
  the lifecycle safety save (`SaveManager.safety_save()`) ignore it, so the
  player is never left with nothing.
- **`text_scale`** — one of `Settings.TEXT_SCALES` (1.0 / 1.15 / 1.3).

Existing fields already covered the rest of the brief: `music_volume`,
`sfx_volume`, `ambience_volume`, `master_volume`, `reduced_motion`,
`onboarding_enabled` (shown as "Tutorials"), `compact_numbers`,
`notifications_enabled`, `haptics_enabled`.

`SettingsScreen` gained a DISPLAY "Text size" selector and a new GAMEPLAY
section (starting game speed, autosave). `SettingsTest` covers round-tripping
every field, clamping, and that each new one takes effect.

## Text scaling

Screens built in code pin their own font sizes through `UiBuilder`, which
bypasses the theme's `default_font_size`. So `UiBuilder.scaled_font()` /
`_scaled_height()` route every size and tap-target height through
`Settings.text_scale`, and `VisualTheme` scales the theme's base and tooltip
sizes for the `.tscn`-authored labels. `Settings.set_text_scale()` rebuilds the
theme live via `VisualTheme.apply_text_scale()`. Tap targets grow with the text
and never fall below the 44 px mobile minimum. A few hand-laid scenes still use
authored sizes — "where practical", per the brief.

## iOS lifecycle

`autoload/AppLifecycle.gd` (new) turns every way iOS can take the app away —
backgrounding (`NOTIFICATION_APPLICATION_PAUSED`), an interruption or the screen
locking (`…_FOCUS_OUT`), a low-memory warning, or the player swiping the app
away (`…_CLOSE_REQUEST` / `…_GO_BACK_REQUEST`) — into one response:

1. pause `GameClock` (so no wall time becomes simulated weeks), and
2. write the autosave slot immediately via `SaveManager.safety_save()`,
   **regardless of the autosave preference**, debounced to ~400 ms.

On the way back the clock stays paused; the player taps play. Coming back after
a kill lands on the Studio via Continue with the autosave intact — an
in-development project resumes from `active_projects`, and a game that had
already shipped (release presentation screens never mutate; the release is
committed before `ReleaseResultsScreen` loads) is still on the market. It sets
`auto_accept_quit` / `quit_on_go_back` to false and calls `get_tree().quit()`
itself after saving.

`LifecycleTest` covers the pause-and-save on suspend with autosave off, the
survival of a running project and a fresh release across a reload, that resume
does not restart the clock, and suspend idempotency.
