# Studio Visual Feedback

PA.9 extends `OfficeFloorView`, `OfficeLayout`, and `StudioRoomRenderer`; it
does not introduce a second simulation. Every employee pose, status marker,
desk, facility, and arrival is rebuilt from `GameState` and the existing
managers.

## Employee states

- Idle employees remain seated or take occasional deterministic breaks.
- Employees assigned to a project, contract, engine, or research work animate
  actively. Project bubbles retain their discipline and production-phase
  colours.
- Training and research use distinct status colours and output treatment.
- Crunch uses a restrained pulsing status marker.
- Employees on ordinary or burnout leave are absent. A hire or returning
  employee enters through the door and walks to their deterministic desk.
- Workstation ownership follows employee order and `workstation_tier`, so
  Basic, Standard, and Pro equipment is reconstructed after loading.

The coloured activity dot is intentionally compact for the mobile viewport:
grey is idle, blue is working, green is training, violet is researching, and
red is crunching.

## Office progression

The existing room dimensions, artwork, desk capacity, props, and ambience make
each move larger. Tier-specific presentation zones strengthen the progression:
the Small Office introduces a break-room area, the Professional Studio adds a
meeting area, and the Large Studio adds a QA lab. These are visual expressions
of existing office tiers only; they add no productivity or economic modifiers.

## Performance and persistence

Actors use simple seeded timers and request grid routes only when their state or
destination changes. There is no per-frame pathfinding or needs AI. A compact
state signature is checked twice per second so direct assignment, crunch, and
leave changes appear promptly. Drawing uses the existing canvas control rather
than adding a node per prop or effect.

`SaveManager.game_loaded` clears transient routes, bubbles, and reactions and
reconstructs the floor from loaded simulation state. No position, animation,
or visual status is saved or used by gameplay.

Regression coverage lives in `scripts/tests/OfficeFloorTest.gd` and includes
new-hire arrival, leave return, training, research, project assignment, crunch,
office movement, workstation assignment, and save/load reconstruction.
