# PA.6 — First-Hour Onboarding

Indie Empire teaches its opening loop with compact contextual callouts and a
gold focus outline around the relevant control. Callouts do not pause or cover
the whole interface. Players can keep interacting, acknowledge with **Got it**,
or choose **Skip onboarding** at any point. The same choice is available under
Settings → Contextual onboarding.

## First-hour sequence

1. Bedroom studio and the Develop Game action
2. First Tiny game: title, theme, genre and platform only
3. Development phases and release
4. Review reveal, then the first weekly sales result
5. Postmortem and research points
6. First researched technology
7. Second game with one supported feature
8. Market information
9. Affordable office growth
10. First hire, payroll, and employee assignment

The first project hides scope, engine, team, role, feature, priority, budget,
knowledge and detailed cost controls. Their safe defaults still build a valid
Tiny founder project. Market and staff navigation, engines, contracts, culture,
and detailed finance are revealed only when their concepts become relevant.

## Contextual conditions

One-time contextual lessons are independent of the main sequence:

- a live project bottleneck explains limiting disciplines;
- stress at 55 or an at-risk employee explains recovery and burnout;
- a commercial failure explains burn and cash runway;
- a retiring platform explains platform lifecycle;
- an over-scoped feature selection explains complexity consequences.

## Persistence

Save version 22 stores completed steps, queued steps, contextual lessons already
seen, and the per-company skip flag under `onboarding`. Pre-v22 careers load
with onboarding skipped so established players are never dropped into lesson
one. A new company follows the global Settings preference.

## Extension contract

Simulation code should emit a factual EventBus signal. `TutorialManager` owns
ordering and persistence. A screen calls `TutorialManager.offer(id, control)`
after layout to attach the lesson to a useful interface element. Contextual
conditions call `TutorialManager.context(id, control)` and are de-duplicated by
the manager.
