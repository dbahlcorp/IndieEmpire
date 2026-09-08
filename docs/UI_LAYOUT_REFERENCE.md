# Studio and development layout — September 8, 2026

Reference: [Game Dev Tycoon screenshots](https://www.mobygames.com/game/82820/game-dev-tycoon/screenshots/),
including the mobile studio screenshot. The reference places the office in the
center, project progress above it, and compact company status around the edges.

Indie Empire adapts that hierarchy to its existing portrait viewport and retains
its painted office art, animated workforce, parchment background, teal controls
and gold primary actions. No reference artwork was copied into the game.

- Studio: fixed clock, company name, compact cash/audience/overhead display;
  project cards above an enlarged office; grouped Office, Teams, Contracts and
  Finances actions; sales and exact runway information below.
- Each project card opens its own team's project and keeps keyboard focus during
  weekly refresh. Planning/build progress and ready-to-ship state are visible.
- Development: persistent clock, release action and navigation; compact phase
  figures and real progress bars above the larger room; direction, bottlenecks,
  budgets and other details in the scrolling content area.
- Both screens retain reachable primary actions and navigation when content
  exceeds the available height. The original Studio overflow is resolved.
- Workstation textures remain alive between canvas draw calls, eliminating white
  rectangles in equipped offices. The news icon is tinted for the light clock bar.

Validation: CashRunwayTest (23), OfficeFloorTest (97), EquipmentTest (54),
DevelopmentPhaseTest (101), PhaseD (66), and the rendered layout probe (25) passed.
The layout probe covers bedroom and ten-person studios at 430 × 932, scroll reach,
project-card bindings/focus and development controls. Desktop activation failed
with `foreground window did not report a process id`; visual verification used
Godot's own viewport renders instead. Full manual interaction was not repeated.

Renders and logs: [artifacts/ui-layout-2026-09-08](../artifacts/ui-layout-2026-09-08/).
These UI changes do not resolve the separate M3 economic-balance or career
acceptance gaps recorded in the September 7 report.
