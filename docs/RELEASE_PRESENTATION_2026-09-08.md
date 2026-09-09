# PA.7 — Release, Reviews & Sales Presentation (2026-09-08)

Presentation-only pass. The review and sales **simulation is untouched** —
`ReviewSimulator`, `SalesSimulator`, `SalesManager` and `PublishingManager`
are exactly as the recent balance work left them. One new pure helper
(`ReleaseSummarySimulator`), one new self-drawn control (`SalesChart`), a
reworked results screen, and a fuller Game Detail page.

## The sequence

`ReleaseResultsScreen` (reached from `PublishingScreen` after the deal is
signed and `SalesManager.release()` has run the launch week) now plays a
staged reveal:

```
LAUNCH DAY  →  critic cards, one at a time  →  AVERAGE SCORE
  →  INITIAL PLAYER RESPONSE  →  WEEK ONE sales + chart
  →  THE IMPACT (revenue / fans / reputation)  →  headline verdict + why
```

- **Pacing.** First viewing runs ~7s of animation. `Settings.seen_release_reveal`
  is set on the first full watch; after that the reveal paces itself ~2x
  faster and shows a **SKIP** button. A tap anywhere (`_hurry()`) finishes
  the current beat — repeated taps walk straight through.
- **Reduce Motion.** New `Settings.reduced_motion` (toggle under Settings →
  Display). When on, every beat lands instantly, no eased interpolation, no
  scale pulsing, chart draws at full height immediately. Both flags live in
  `Settings` (player-scoped), not the save.

## Headline verdict — `ReleaseSummarySimulator.verdict()`

Returns `{tone, title, subtitle}`, picking the single strongest banner:

| Hits | Flops |
|---|---|
| `1M COPIES` / `100K COPIES` / `10K COPIES` | `SALES COLLAPSE` |
| `RECORD LAUNCH` (best launch week yet) | `COMMERCIAL FAILURE` (finished, unprofitable) |
| `CRITICAL ACCLAIM` (9.0+) | `TECHNICAL PROBLEMS` (12+ bugs) |
| `STUDIO BEST` (studio's highest score) | `POOR RECEPTION` (< 5.0) |
| `BREAKOUT HIT` (word of mouth, rising) | `MIXED REVIEWS` (5.0–6.4) |
| `STRONG REVIEWS` (8.0+) | — |

`tone` (`triumph`/`strong`/`neutral`/`weak`/`failure`) drives colour and
weight. The copy explains, never shames — "did not earn back what it cost to
make", not "you failed".

## Explainability — `strengths()` / `weaknesses()`

Plain-language, at most four each, concrete standouts first. Strengths:
excellent quality fields, strong theme/genre fit, platform audience fit,
experienced genre team, clean launch, polish time, genre demand. Weaknesses:
launch bugs, **outdated graphics technology** (weak presentation *and* better
graphics tech has been available unresearched for 3+ years), **declining
platform** (`PlatformManager.stage`), poor fit, crowded genre, thin genre
experience, rushed release, weak quality fields.

After a postmortem the screen shows `went_well` / `went_poorly` instead — the
same section, fuller detail once the sales run is over.

## Sales graph — `SalesChart`

A `Control` with a custom `_draw()` bar chart (peak week highlighted), a
0.5s grow-in (skipped under Reduce Motion), and `text_summary()` for a
readable equivalent. Used on the results screen and Game Detail.

## Game History

`GameDetailScreen` (Games list → a game) gained a RELEASE section: the
verdict banner, the strengths/weaknesses summary, and the `SalesChart`
replacing the old text-only week list. This is the "revisit the complete
release information" path.

## Purity

`ReleaseResultsScreen` and `ReleaseSummarySimulator` read `released_game` and
world getters only. `ReleaseSummaryTest` and `ReleasePresentationTest` both
snapshot every simulation field (review, weekly/lifetime sales & revenue,
fans gained, reputation gained, bugs, company cash/fans/reputation, catalogue
size) before and after driving the full reveal and assert nothing moved.

## Tests

- `ReleaseSummaryTest` (39) — verdict priorities, record/studio-best against
  the catalogue, strengths/weaknesses content, milestone banners, response
  line, impact rows, and a no-mutation pass.
- `ReleasePresentationTest` (64) — beats reveal in order; SKIP and tap both
  fast-forward; Reduce Motion lands instantly; simulation unchanged;
  save/reload mid-reveal and after; the release is revisitable from history.
- `ReviewRevealTest` — verdict words and the critic reveal itself, updated
  for the new node layout and sequence.
