# Mobile Playable Alpha acceptance

Status: **Alpha RC1 candidate prepared — physical mobile acceptance pending.**

`PASS` means repository evidence exists and passed on Godot 4.7.2. `BLOCKED`
means the check requires an actual iPhone and a human playthrough; it is not a
software failure. No physical-device result is claimed in this document.

## Automated verification

| Gate | Status | Evidence |
| --- | --- | --- |
| Project imports and scripts compile | PASS | Headless editor import, 2026-09-09 |
| Complete regression suite | PASS | 75 test scenes; see dated mobile report |
| Canonical portrait and representative viewport layout | PASS | `MobileLayoutTest` (184 checks) plus `StatisticsTest` |
| Touch target sizing | PASS | Shared 54 px controls; layout and Statistics assertions |
| Project creation and greenlight | PASS | `GreenlightScreenTest` (50 checks) |
| Onboarding state, progressive disclosure and skip | PASS | `TutorialTest` (30 checks) |
| Release reveal, skip and Reduced Motion | PASS | `ReleasePresentationTest` and `ReviewRevealTest` |
| Audio settings, feedback routing and optional haptics | PASS | `AudioTest` (78 checks) |
| Mobile Statistics calculations and layout | PASS | `StatisticsTest` (15 checks) |
| Safe background pause and lifecycle save | PASS | `LifecycleTest` (10 checks) |
| Save/load across connected career phases | PASS | Phase A–D and system persistence suites |
| Content IDs, descriptions and prerequisites | PASS | `ContentValidationTest` (7,770 checks) |
| PA.16B final visual families | PASS | 155 SVG audits, nine final contact sheets, 100-cover before/after audit |
| Complete 430 × 932 visual fixture | PASS | 22/22 top views plus 13 bottom-scroll views, runtime theme, zero capture errors, 2026-09-10 |
| Long-career economy does not compound or collapse | PASS | `EconomyPlateauTest` (12 checks) |
| Financial recovery cannot defer insolvency forever | PASS | `CrisisEconomyTest` (7 checks) |

## Human mobile verification

| Gate | Status | Required evidence |
| --- | --- | --- |
| First 15 minutes, fresh 1985 Normal company | BLOCKED | Recorded touch-only playthrough; log every confusion point |
| First meaningful hour | BLOCKED | Multiple releases through employee/payroll progression |
| Ten-person studio and two teams | BLOCKED | Connected UI growth journey required by `M3_ACCEPTANCE.md` |
| 30–60 minute continuous comfort | BLOCKED | Thumb fatigue, scrolling, interruptions, audio/haptic fatigue |
| iPhone safe areas and software keyboard | BLOCKED | Real notch/home-indicator and text-entry checks |
| Background, lock, termination and reload | BLOCKED | Actual iOS lifecycle test, including force-close after autosave |
| Audio, silent switch and haptic feel | BLOCKED | Physical iPhone output; verify feedback is restrained |
| Performance, heat and battery | BLOCKED | Founder, 5-person, 10-person and long-career device sessions |
| Accessibility in real use | BLOCKED | Contrast, text sizes, Reduced Motion and non-audio comprehension |

## Connected playthrough protocol

Use the shipped touch UI only: no mouse, keyboard shortcuts, debug cash,
forced manager calls, cheats, or direct simulation manipulation. Start in 1985
on Normal. Record device model, OS, build commit, viewport, actions, in-game
date, cash, payroll, screenshots and every point of hesitation or confusion.

The first 15 minutes must establish company creation, first-project setup,
development, release, reviews and sales, and leave the tester wanting to make a
second game. The first hour must progressively introduce postmortem, research,
technology, a feature, Market, office growth, the first hire or a clear route to
one, payroll and project risk. Continue to ten people and two teams; verify the
information remains summary-first and manageable.

## Physical iPhone checklist

The authoritative run sheet and evidence template is now
`docs/ALPHA_RC1_DEVICE_TEST.md`. The concise checklist below remains a quick gate.

- [ ] Launch the game from a clean install.
- [ ] Create a company and type company/founder names.
- [ ] Create and name the first game using touch only.
- [ ] Complete onboarding without a covered or unreachable control.
- [ ] Finish development and release the game.
- [ ] Tap through every critic reveal and the week-one result.
- [ ] Research a technology.
- [ ] Create a second game and select a feature.
- [ ] Navigate Market and understand the useful recommendation.
- [ ] Move office and hire the first employee.
- [ ] Open Financials and understand runway/payroll.
- [ ] Open Statistics; switch Revenue/Profit and 1Y/5Y/10Y/ALL.
- [ ] Background and return; confirm the clock remains safely paused.
- [ ] Lock and unlock the phone.
- [ ] Force-close after autosave, relaunch and continue the career.
- [ ] Test music, effects, iOS silent-switch behavior and haptics.
- [ ] Test Reduced Motion through a full release reveal.
- [ ] Play at least 30 continuous minutes.
- [ ] Record crashes, frame drops, heat, battery drain, clipping, keyboard,
      touch, audio, haptic and save problems.

## Sign-off rule

Playable Alpha is `PASS` only after every physical row above has recorded
evidence and no release-blocking `FAIL`. Until then the recommendation is:

**PHYSICAL DEVICE ACCEPTANCE REQUIRED**
