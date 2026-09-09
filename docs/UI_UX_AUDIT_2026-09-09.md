# IndieEmpire UI/UX audit — September 9, 2026

## Architecture

- The game is scene-based. Management screens are `Control` roots composed
  from containers and build most repeating content in GDScript.
- `VisualTheme` owns the global Godot `Theme`, studio-context backdrop,
  safe-area handling and responsive management-page measure.
- `UiBuilder` owns lightweight reusable controls. Screens call managers
  directly for player actions; cross-system feedback arrives through
  `EventBus`.
- `StudioScreen` is the office-centric play surface. `OfficeFloorView`
  reads simulation state to render staff activity without owning simulation.
- `ScreenRouter` carries transient selection/draft state. `GameState`,
  managers and `SaveManager` remain the source of truth.

## Dependency points preserved

- Time controls call `GameClock`; no second timer or speed state exists.
- Create/greenlight calls the existing project draft and simulator flow.
- Project, team, employee, research, finance, release and sales actions still
  route through their existing managers.
- UI cards read only persisted `GameProject` and employee fields.
- Notifications listen to `EventBus.notification_requested`.
- Office employee animation remains a presentation of manager state only.

## Findings

1. The existing office renderer and release reveal were already strong and
   should be evolved, not replaced.
2. Clock speed was hidden behind a cycle button, so the selected speed and
   available choices were not simultaneously readable.
3. The office menu was useful, but frequent destinations needed a compact
   contextual rail to reduce full-menu navigation.
4. Shared styling existed, but lacked semantic positive/warning/danger cards,
   tooltip styling, reusable empty states, and desktop-width layouts.
5. Games, team assignments, company and research relied heavily on long text
   blocks. Their values were accurate but difficult to scan.
6. Notifications used a generic dark overlay visual unrelated to the warm
   teal/parchment game identity.
7. The create-game flow was mechanically complete but needed a visible stage
   model and clearer decision language.
8. Responsive tests covered phones and a 1280×800 desktop, but wide management
   pages did not use the space available at common PC resolutions.

## Implemented response

- Expanded the shared theme with elevated and semantic panels, stronger value
  hierarchy, tooltip/dialog styling and reduced-motion-aware transitions.
- Added reusable section headers, stat grids, info cards, status chips and
  polished empty states.
- Rebuilt the clock as Pause plus explicit 1×, 2× and 4× choices.
- Added a compact office action rail while retaining the complete Studio Menu.
- Reworked Games into an active/released responsive portfolio, including real
  sales trend states and a functional empty-state action.
- Reworked Teams and Research into responsive cards with visible status,
  warnings, requirements and supported actions.
- Added a project metric grid to active development and a stat-led analytics
  summary to game detail.
- Added a stage strip and contextual tooltips to game creation.
- Restyled and repositioned notifications as warm, semantic, stacked toasts.
- Kept narrow screens at the tested 520 px readable measure while selected
  management screens opt into a 920 px desktop canvas.

## Intentionally unchanged

- Simulation formulas, economy, unlock conditions and persistence schema.
- Existing release/review reveal state machine, which already provides staged
  critic cards, skip/continue and reduced-motion behavior.
- Existing office character/activity renderer and original project artwork.
- Unsupported analytics are not invented; charts only use recorded weekly
  sales data.

## Validation

- Godot 4.7.2 editor import completed with no script or scene parse errors.
- The real boot scene ran under the Windows OpenGL compatibility renderer
  with no project runtime errors.
- Mobile layout: 184 checks passed.
- Project setup and greenlight: 50 checks passed.
- Development phases: 101 checks passed.
- Release presentation: 64 checks passed.
- Research: 126 checks passed.
- Office activity: 264 checks passed.
- Employee management: 132 checks passed.
- Real-time clock and screen smoke coverage: 68 checks passed.
- Sequential career save/reload: 56 and 40 checks passed.
- Rendered snapshots cover 1280×720, 1600×900, 1920×1080 and 2560×1440,
  plus Games, Teams, Research and Create Game at 1600×900.
