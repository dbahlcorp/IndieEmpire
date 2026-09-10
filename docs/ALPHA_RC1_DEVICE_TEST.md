# Alpha RC1 physical-device test

Status: **Ready to run — no physical-device evidence recorded**  
Candidate revision: `a389389` plus the PA.16B final visual pass  
Required device: physical iPhone, current supported iOS, release-like build

This is the human acceptance script for Alpha RC1. A desktop window, simulator,
headless fixture, or automated suite cannot pass any physical-device row.

## Evidence header

Record this before play:

| Field | Value |
| --- | --- |
| Tester |  |
| Device model |  |
| iOS version |  |
| Build type |  |
| Commit SHA |  |
| Date and local time |  |
| Session start / end |  |
| Screen recording or screenshot folder |  |
| Peak memory, if available |  |

For each issue record the screen, in-game date, action, expected result, actual
result, reproducibility, screenshot/video reference, and severity. Do not use
debug actions, the console, forced candidates or publisher deals, direct manager
manipulation, simulation probes, or developer shortcuts.

## Run 1 — fresh install and first 15 minutes

1. Delete the app and its local data, install the candidate, and launch it.
2. Start a fresh **Normal** company in 1985 using touch only.
3. Create the founder and verify text entry, keyboard avoidance, dismissal,
   apostrophes, long names, and the return/done action.
4. Follow onboarding without prior knowledge: create the first project, choose
   genre, theme and platform, set priorities and features, greenlight, develop,
   release, reveal critics, inspect week-one sales, and read post-release feedback.
5. Record every hesitation, unnecessary tap, missed control, scroll reversal,
   unclear label/icon, keyboard obstruction, safe-area collision, and moment of
   visual clutter.
6. Answer in plain language: **After releasing the first game, do I understand
   what happened and want to make another one?**

Capture at minimum: Main Menu, New Company with keyboard, New Project selections,
Greenlight, active development, critic reveal, week-one result, and postmortem.

## Run 2 — first meaningful hour

Continue naturally; do not force unlocks. Make a second and third game, research
technology, select features, inspect Market, sales history and Financials, move
office when affordable, hire and assign the first employee, train where useful,
and inspect Game History and Statistics. Note pacing that feels too fast or slow.

At the first hire, ask and answer from the shipped UI:

- Why do I need another person?
- Who should I hire and what skill is missing?
- What can I afford?
- What will this employee improve?
- What happens to payroll and runway?

If any answer is unclear, log an explainability/UX defect rather than proposing a
new simulation system.

## Run 3 — legitimate ten-person career

Continue the same career or load a legitimate career that reached about ten
employees through ordinary play. Do not construct the state with debug tools.
Exercise two teams, multiple roles, projects, research, workload, morale, stress,
payroll, office, Financials, Statistics, and employee management. Confirm the
studio feels fundamentally different from the bedroom start without becoming
administrative chaos.

Record company year, cash, runway, employees, office, games released, active
projects, and any point where the player loses track of cause and effect.

## Run 4 — continuous 30–60 minute session

Observe thumb and scrolling fatigue, reachability, transition and frame pacing,
animation/audio/haptic repetition, heat, battery, memory warnings, and screen
loading. During the session:

- background and resume the app;
- lock and unlock the phone;
- force-close immediately after a visible autosave point, relaunch, and continue;
- test music/effects volume, iOS silent switch, and haptics;
- complete a release with Reduced Motion enabled;
- test larger text and verify critical actions remain visible;
- verify the app stays portrait and respects orientation lock.

## iPhone-specific pass/fail checklist

- [ ] No content enters the notch, Dynamic Island, status, or home-indicator areas.
- [ ] Company, founder, game, and engine text fields remain visible above the keyboard.
- [ ] Keyboard dismissal never traps progression.
- [ ] All primary touch targets are comfortable and reliable.
- [ ] 20–24 px icons remain recognizable at normal viewing distance.
- [ ] Theme, feature, and technology rows remain distinct at native scale.
- [ ] Covers remain readable in lists and preserve franchise continuity.
- [ ] Era props look embedded in office paintings, with plausible scale and occlusion.
- [ ] Background/resume returns safely paused.
- [ ] Lock/unlock and force-close/relaunch preserve the career without duplication.
- [ ] Audio obeys settings and iOS silent-switch expectations.
- [ ] Haptics and repeated feedback are restrained.
- [ ] Reduced Motion removes staged motion without hiding outcomes.
- [ ] Larger text does not clip labels, values, or primary actions.
- [ ] No repeatable crash, severe frame-pacing issue, runaway heat, or memory failure occurs.

## Session result

| Field | Value |
| --- | --- |
| Final company year |  |
| Cash / runway |  |
| Employees / teams |  |
| Office |  |
| Games released |  |
| Session duration |  |
| Crash count |  |
| Blocking layout failures |  |
| Major confusion points |  |
| Heat / battery / frame pacing |  |
| Result: PASS / FAIL / RETEST |  |

## RC rule

The first physical run starts Alpha RC mode. From then on, allow only demonstrated
bugs, crashes, save issues, UX friction, mobile layout, accessibility, performance,
balance, bad art, confusing feedback, fatigue, and content corrections. Do not add
M4, major features, speculative systems, competitors, or new management layers.
Balance observations must be reproduced across multiple deterministic careers
before tuning.

Alpha RC1 passes only when the fresh first game is understandable and touch-only,
research/features/hiring/payroll are explainable, a ten-person studio remains
manageable, save/lifecycle behavior survives real iOS conditions, and no blocking
layout defect or repeatable crash remains.
