# Acceptance suite

M3 milestone sign-off additionally requires the connected player journey and
solo-versus-ten-person comparison in [M3 acceptance](../../../docs/M3_ACCEPTANCE.md).
These automated suites provide supporting evidence; they do not replace the UI
playthrough or establish that a ten-person studio feels different to manage.

A full playthrough, split into four phases. Run them in order from a clean
`user://saves` directory; phase B deliberately depends on the save phase A
leaves behind.

    godot --headless --path . res://scripts/tests/acceptance/PhaseA.tscn
    godot --headless --path . res://scripts/tests/acceptance/PhaseB.tscn
    godot --headless --path . res://scripts/tests/acceptance/PhaseC.tscn
    godot --headless --path . res://scripts/tests/acceptance/PhaseD.tscn

- **PhaseA** founds a studio in 1985, grows it into a company with staff and
  offices, plays past 1995, then saves and quits.
- **PhaseB** is a separate process: it reloads that save and checks the
  simulation came back intact, then keeps playing.
- **PhaseC** manages badly and checks the studio actually dies, with warning.
- **PhaseD** checks the real-time clock drives the world unaided, and that
  every screen runs.

The unit suites alongside them:

    godot --headless --path . res://scripts/tests/M3EmployeeSmokeTest.tscn
    godot --headless --path . res://scripts/tests/ContractTest.tscn
    godot --headless --path . res://scripts/tests/TrainingTest.tscn
    godot --headless --path . res://scripts/tests/MoraleTest.tscn
    godot --headless --path . res://scripts/tests/RetentionTest.tscn
    godot --headless --path . res://scripts/tests/BurnoutTest.tscn
    godot --headless --path . res://scripts/tests/PublishingTest.tscn

Each phase exits non-zero on failure, so they can be chained in CI. Note that a
clean checkout needs one editor import first, so the `TestCase` global class is
registered:

    godot --headless --path . --editor --quit

Phase A plays a randomised career, so it is a smoke test of the *design* as
well as the code: it will fail when the economy stops behaving, which is the
point of it.
