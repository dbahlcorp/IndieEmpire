# Studio and development layout — September 8, 2026

## Mobile audit of the full-screen studio

The revision below was verified at 430 × 932 and 1280 × 800 only, and both
checks asked whether each control was *on screen* — never whether two of them
were on top of each other. Two bugs got through.

**The company figures were drawn through the project cards on every phone.**
`_layout_surface()` placed the project cards at a hardcoded y=216 in portrait
while the company HUD started at y=80 and stands 211 tall — 75 pixels of
overlap, on every portrait device. Wide screens were fine because the cards sit
in the other column there. The cards now stack below the HUD's measured height.

**A portrait tablet got a 659-pixel measure.** `_fit_management_screen()`
centred management screens at 520 logical pixels only past `> 700` wide, so a
1536 × 2048 iPad — 699 logical pixels — fell through to the fill branch and got
a line length wider than the wide branch would ever have allowed. It now
centres as soon as the viewport can hold the full measure plus its gutters,
with no threshold to fall between.

**`StudioRoomRenderer` had a load-order-dependent parse error.** A shelf colour
came from indexing an untyped array literal, which `:=` cannot infer a type
from; whether that is an error depends on the order the compiler reaches the
script, so it built from the editor and failed when a test loaded it first. The
palette is a named constant now.

The property the surface layout leans on is worth stating: because the stretch
aspect is `expand`, the logical viewport is scaled by whichever axis is
tightest, so **every device gets at least the authored 430 × 932 to lay out in**.
Nothing can be crushed, only stretched — which is why the layout can size
against fixed pixel numbers at all.

`scripts/tests/MobileLayoutTest.gd` now walks eight device profiles — iPhone SE,
iPhone 15 Pro, Pixel 8, a 21:9 Android, a portrait iPad, a foldable inner
screen, a landscape phone and the desktop default — computing each one's logical
viewport from the project's own stretch settings and checking that the floating
controls stay on screen, stay apart, and stay thumb-sized (≥44 px). 184 checks.
Renders are in [mobile-2026-09-08](../artifacts/mobile-2026-09-08/).

One thing the audit found and did not change: the desktop default of 1280 × 800
is a landscape window against a portrait base viewport, so it resolves to a
1492 × 932 logical viewport — everything renders at 86% of authored size. That
is legible but small, and it is a deliberate consequence of the window override,
not a bug.

## Latest revision: studio as the play surface

Following the user's [Steam reference](https://store.steampowered.com/app/239820/Game_Dev_Tycoon/),
the Studio is now a full-screen room with floating controls, not a scrolling
dashboard. Desktop opens at 1280 × 800; portrait remains supported through an
expanding 430 × 932 base viewport.

Company status sits upper left, clock and project cards upper right, with Studio
Menu and Develop/Projects along the bottom. A visible attention action surfaces
pending events, postmortems, staff matters and financial trouble. The Studio
Menu opens over a dimmed live room and exposes Office, Teams, Staff, Hiring,
Contracts, Finances, Games, Market, Engine Lab and Company. It pauses time and
restores the previous clock state when closed. Close, outside click and Escape
dismiss it; keyboard Tab stays inside the open menu.

Management pages are centered at a maximum 520 logical pixels on wide screens,
with the studio artwork dimmed behind them. They retain their existing navigation
back to Studio. The main play surface has no permanent five-tab bar.

Validation: SurfaceCheck passed 57 checks each in desktop and portrait renders,
covering room/control bounds, menu destinations, opening/closing and clock-state
restoration. CashRunwayTest passed 23 checks and PhaseD passed 66. Final render
logs contain no script errors or resource-leak warnings; sandbox certificate-store
messages remain environmental. Artifacts are in
[studio-surface-2026-09-08](../artifacts/studio-surface-2026-09-08/).

The following notes describe the earlier same-day iteration that preceded this
full-screen studio revision.

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
