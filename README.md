# Indie Empire

A Godot 4 prototype for a mobile-first game-development tycoon.
Built and verified against Godot 4.7.2 stable.

First-hour contextual onboarding, progressive disclosure, skip behavior, and
save compatibility are documented in [docs/ONBOARDING.md](docs/ONBOARDING.md).

Audio states, original feedback assets, iOS behavior, and haptic architecture
are documented in [docs/AUDIO_AND_GAME_FEEL.md](docs/AUDIO_AND_GAME_FEEL.md).

Simulation-driven employee activity, office-tier presentation, deterministic
movement, and save reconstruction are documented in
[docs/STUDIO_VISUAL_FEEDBACK.md](docs/STUDIO_VISUAL_FEEDBACK.md).

## Open it

1. Install Godot 4.7 or newer.
2. Open `project.godot`.
3. Press F5 to run.

The base viewport is 430 x 932 for portrait play. Desktop opens at 1280 x 800
with an expanding viewport: the studio fills the play surface, while management
pages remain centered, readable panels. The Studio menu opens over the room.

## The loop

The game runs in real time. Weeks pass on their own; you never advance a turn.
Pause and speed (1x / 2x / 4x) sit in the clock bar on every screen, and the
clock stops on its own when something needs you: a project reaching 100%, or
the studio running out of money.

Choose a project -> watch it build -> polish or ship -> reviews ->
sales arrive week by week -> learn from the release -> gain experience ->
the market moves on -> choose the next project.

Each build now has hands-on direction in all three phases. Planning can favour
prototyping, world-building, or a tightly locked scope; production can favour
systems, technology, presentation, or narrative; and the finishing pass can
prioritise stability, optimization, tuning, or audiovisual impact. Every focus
has visible schedule, cost, quality, and bug tradeoffs, can be changed while its
phase is active, and is saved with the project.

## M2 systems

**Save/load.** Autosave after every project start, development week, release,
sales week and major event, plus three manual slots under `user://saves/`. The
game resumes straight into a running company.

**Studio creation.** Name, founder and difficulty (Relaxed / Normal / Hard),
starting in 1985. Difficulty changes starting cash, sales, expenses and how many
weeks of negative cash the studio survives.

**Ongoing sales.** A release stays on the market and sells every week from base
demand x review x trend x platform x reputation x word of mouth x age decay.
Word of mouth is computed from review score, gameplay, innovation, bugs and
reputation, so a strong game can climb for weeks before it fades and a weak one
collapses immediately.

**Game history.** Every release is a permanent object with a stable id, its full
sales curve, critic reviews, profit and development history, browsable from the
Games tab and its own detail page.

**Postmortems.** A finished sales run produces what went well, what went poorly,
and the exact knowledge that moved (`??? -> Good`, stars before and after).
Analysing a project is what awards its experience.

**Knowledge.** Genre, theme and platform experience is earned in XP and read as
levels (Unknown to Master) worth +1% to +8% quality. Theme/genre compatibility
is hidden until shipped, then described in words with a confidence rating. Raw
multipliers are never shown.

**Market.** Genre popularity drifts each season with news coverage, and your own
releases saturate a genre until the audience recovers.

**Platform lifecycle.** Platforms are announced, launch, grow, peak, decline and
are discontinued, each with an authored per-year install base curve. Bigger
platforms cost more to develop for.

**News.** Platform, market, company, game, industry and financial stories,
including sales milestones, breakout hits and commercial failures.

**Release presentation.** Shipping a game plays a staged reveal: a launch
beat, the critic outlets one at a time, the average score, the initial player
response, week-one sales on a self-drawn chart, and the change to revenue,
fans and reputation -- ending on a headline verdict (`RECORD LAUNCH`,
`CRITICAL ACCLAIM`, `100K COPIES`, `SALES COLLAPSE`, `TECHNICAL PROBLEMS`,
...) and a short plain-language account of what carried the game or held it
back. A tap fast-forwards each beat; a SKIP button appears once the player
has seen a full reveal; a Reduce Motion setting makes it all instant. The
whole thing is presentation over numbers the simulation already produced --
`ReleaseSummarySimulator` and the results screen never mutate anything. The
same verdict and sales chart are on each game's detail page in Game History.

**Money.** Every transaction is written to a ledger. Per-year income, costs and
net are kept permanently for the studio's whole life, while the transaction
detail is a rolling window. Each game reports development, platform fees,
wages, revenue and profit.

A game's cost is what it actually cost to make, wages included. Salaries leave
the bank monthly as a company-wide payroll expense and are never charged twice,
but every development week also accrues that team's wages onto the project it
was building, so a release has to out-earn the people who made it and not just
its equipment budget. The development budget the player sets, and the advance a
publisher offers against it, are both about the cash side only.

**Bankruptcy.** Cash may go negative, with a difficulty-dependent grace period
and warnings, before the studio closes for good.

**Unlocks.** Genres, themes and project sizes open with time and shipped games,
announced as they arrive.

## Architecture

**Managers** (`autoload/`) own state and orchestrate. **Simulators**
(`scripts/simulation/`) are pure static maths that hold nothing and call no
manager. If a file has a `var`, it is a manager.

```
autoload/
    EventBus.gd          every cross-system signal
    GameState.gd         pure company state, no rules
    TimeManager.gd       the clock
    DataManager.gd       authored data
    FinanceManager.gd    ledger, cash, solvency
    ExperienceManager.gd xp, levels, combination knowledge
    PlatformManager.gd   hardware lifecycle
    MarketManager.gd     trends and saturation
    UnlockManager.gd     content availability
    SalesManager.gd      games on the market
    NewsManager.gd       the feed
    Notifications.gd     toasts
    Settings.gd          player preferences
    World.gd             THE WORLD TICK
    SaveManager.gd       autosave and slots

scripts/simulation/
    DevelopmentSimulator.gd  ReviewSimulator.gd  SalesSimulator.gd
    MarketSimulator.gd       PlatformSimulator.gd  TrendSimulator.gd
    KnowledgeSimulator.gd    PostmortemSimulator.gd  CompanyStats.gd
```

### The weekly tick

One week is the fundamental unit of simulation. `GameClock` turns real seconds
into weeks, and `World.gd` is the only subscriber to `TimeManager.week_advanced`.
Everything that happens over time is ordered there, and new systems join that
list rather than hooking the clock:

```
GameClock (real time) -> TimeManager.advance_week()
        |
   PlatformManager   hardware ages, launches and dies
   ProjectManager    the project in development does a week of work
   SalesManager      games on the market sell another week
   MarketManager     trends drift, saturation decays
   UnlockManager     new content becomes available
   FinanceManager    books settle, then solvency is judged
   NewsManager       stories posted by the events above
   SaveManager       the week is committed to disk
```

### Event bus

Simulation emits, UI listens. No system touches a screen directly:
`game_released`, `game_hit_sales_milestone`, `game_sales_ended`,
`platform_announced`, `platform_released`, `platform_discontinued`,
`genre_trend_changed`, `company_cash_changed`, `company_bankruptcy_warning`,
`genre_unlocked`, `theme_unlocked`, `experience_level_up`, and more.

### Mobile rules

Portrait, one thumb. Every tappable control is at least 48px high and primary
actions are 62px. No hover states, no right-click, no tooltips. Toasts never
block input and never need a tap.

### Numbers

Dashboards show compact numbers (`12.4K`, `1.8M`, `2.4B`); financial pages
always show exact amounts. The player can switch to exact everywhere in
Settings.

## Screens

```
Main Menu -> New Company / Load / Settings
Studio | Games -> Game Details | Market | News | Company
Company -> Financials / Records / Saves / Settings
Postmortem, Game Over
```

## M3 studio progression — acceptance pending

M3 completion is governed by [the player acceptance gate](docs/M3_ACCEPTANCE.md):
a connected journey from bedroom founder to a solvent ten-person studio running
two teams. Every listed outcome must be demonstrated through play, and managing
ten people must feel fundamentally different from managing the founder alone.
The implementation notes below describe systems present, not milestone sign-off.

The founder is now a real, persistent employee using the same employee model as
future hires. Employees carry identity and employment data, eight skills, six
attributes, morale/energy/stress/burnout, progression and traits. Existing M2
version 5 saves migrate forward by creating their named founder as employee one.

Hiring, payroll settlement, teams, training and office capacity build on this
foundation. Their integrated progression and player-facing consequences still
need to satisfy the M3 acceptance gate.

The initial role catalog is deliberately small: programmer, designer, artist,
writer, audio designer, QA tester, producer and generalist. Candidate generation
creates broadly capable generalists and increasingly focused junior, mid-level
and senior specialists, with role-shaped attributes and salary expectations.

The labor market presents three candidates at a time and refreshes every four
weeks. The studio carries an employer reputation, shown as a five-star rating
on the hiring screen: employer reputation itself, headcount, best review,
existing salary levels, office quality, profitability, work-life balance and
how the current team feels all feed it, an active crunch drags it down on the
spot, and a recent round of layoffs drags it down hard. A better place to work
attracts a better mix of interns, juniors,
mid-level staff, seniors, generalists and producers -- and makes offers more
likely to land. Hiring charges a one-time fee; employee salaries are then
settled each month.

Offers can be adjusted from 60% to 150% of a candidate's request and show a
plain-language acceptance chance. A rejected candidate leaves the current
market, preventing consequence-free offer spam. Monthly books separately record
negotiated salaries, office rent, utilities and per-employee software costs.

Every candidate also rolls a rarity tier -- common, skilled, exceptional or
star (`data/candidate_rarities.json`), heavily weighted toward common. A rarer
find is a genuinely better candidate (a stat bonus on their primary and, at
half strength, secondary skill) who also knows their own worth and asks a real
premium on top of ordinary market pay. Exceptional and star candidates carry a
banner on their hiring-screen card so they stand out from the rest of the
rotation -- the whole point is the moment a studio that can barely make
payroll has to decide whether to gamble on someone it cannot really afford.
The tier is rolled once, at generation, and stays on their record for the rest
of their career.

Candidate names are generated from configurable pools
(`data/first_names.json`, `data/last_names.json`) rather than a hardcoded list
in code, so the roster is a data change away from growing -- or, later, from
speaking a different locale.

People climb a four-rung ladder -- junior, mid-level, senior, Lead -- as their
experience passes each rung's bar and they ask for the step up. The labor
market tops out at senior, so a Lead is always somebody the studio grew: the
promotion raises their pay to the new rung's market rate, lifts morale, and
adds to their leadership attribute -- most of all at Lead, where it can change
who the game picks to run a project. The rung only ever changes the job title
and the pay band; the underlying discipline is untouched.

The studio can also let people go. A layoff pays severance -- a month's salary
plus half a month for every year served -- whatever the bank balance, since a
studio usually cuts staff precisely because it cannot make payroll. The
person's own team takes it hard and the rest of the studio takes a lighter
knock; loyalty and work-life balance both suffer. One call is business; three
inside a year reads as a round of cuts, and from there each one costs the
studio's employer reputation and makes the industry news. Laid-off staff keep
their full career record and can resurface elsewhere later, the same as
anyone who quit.

The studio's standing is tracked as two independent numbers rather than one:
consumer reputation (`GameState.consumer_reputation`) is what players think of
its games, moved by reviews, sales, and contract and publishing work; employer
reputation (`GameState.employer_reputation`) is what the industry thinks of it
as somewhere to work, moved by things like layoffs and read by the hiring
screen's star rating. A studio can ship acclaimed games while treating its
people badly, or the reverse, and the two numbers no longer bleed into each
other -- previously the hiring formula's "reputation" term was fed directly by
consumer reputation, so a run of hits quietly bought easier recruiting too.
Employer reputation starts at a neutral 50 (the same convention culture values
use) rather than 0, since a new studio has not yet been judged as an employer
one way or the other. Neither number has a dedicated screen of its own yet.

Salaries and office rent both drift upward over a long playthrough on a
year-keyed multiplier curve (`data/inflation.json`, `InflationSimulator`):
1985 is the baseline (1.0x), climbing to roughly 2.8x by 2020 and continuing
to drift at that pace beyond it. It is approximate and fictionalized, not a
real price index, and exists so a studio that plays for decades keeps facing
period-appropriate costs instead of paying 1985 prices forever. A candidate's
salary reflects the year they were hired or last given a raise; existing
employees are not retroactively repriced.

Small studio events surface from time to time -- an artist asking to attend a
conference, two teammates who keep butting heads, a workstation failing
mid-project -- one at a time, each a choice the player answers on its own
screen while the clock holds. Approving the conference costs money and buys
skill experience and morale; ignoring it is taken as a no. Mediating the
conflict trades one person's mood for team chemistry, or you can stay out of
it and let the chemistry rot. Replacing the dead workstation costs money;
making do drags development efficiency down until the trouble passes. Events
are authored in
`data/studio_events.json` with a plain three-token condition grammar
(`employee_art > 45`, `has_active_project == 1`), a weight, a cooldown and a
list of choices with typed effects, so new ones are added as data. The
catalogue is around a hundred events; every one carries a marked default so
ignoring it is a real answer.

The authored content catalogues -- roughly 15 genres, 55 themes (each with a
full per-genre affinity map), a continuous fictional platform timeline from
1985 through the present, ~30 employee traits, ~20 studio customizations,
and ~95 technologies and game features combined -- are all data-driven
through `DataManager` and lint-checked by `ContentValidationTest`
(duplicate ids, broken prerequisites, missing names, dangling references,
impossible unlocks, malformed platform timelines, out-of-range affinities).

Office progression runs sequentially from a one-person bedroom through a shared
workspace, small office and professional studio to a twelve-person large studio
floor. Each space has rent, capacity, prestige, comfort, productivity and
expansion slots. Hiring respects the hard capacity limit and links directly to
the office screen when full, while moves charge a one-time cost and improve the
studio's ability to attract experienced candidates.

Separate from the building, every employee wants a workstation of their own --
Basic, Standard or Pro, bought once per person from their profile or in bulk
from the office screen. Basic is the unremarkable, unpenalised baseline; Pro
costs the most and pays off in whichever disciplines actually lean on
hardware (programming, art, audio, testing -- not design or writing). Nobody
gets one for free: skipping it is a real handicap to that person's output and
a small hit to their morale, not just a missed bonus, so headcount and
equipment spend grow together. Deliberately coarse -- three tiers, no CPUs and
GPUs to shop for.

The Staff tab and the team-assignments list both filter the roster once it is
worth filtering: All, one chip per role actually on staff, Available and
Overworked, reading off the same workload bands the rest of the game already
uses. A chip that would match nobody -- a discipline nobody has hired into
yet -- never appears.

Both also show each person's effective contribution: their strongest skill,
scaled by exactly the three levers the player watches and manages day to
day -- morale, stress and workload -- so the cost of running somebody into
the ground is a number on screen, not a hunch. A well-rested, settled
performer reads a little above their raw skill; the same person overworked
and stressed reads well below it. Deliberately simplified next to the real
project simulation, which also weighs attributes, experience, equipment and
traits -- this is the three things a player can actually see and act on,
made legible.

Every office is rendered as a layered physical scene: opaque room art, moving
employee contact shadows, animated employees, transparent furniture fronts for
occlusion, and a restrained atmospheric layer of window light, screen glow and
dust. The same normalized desk and path anchors drive walking and seating in
all five tiers.

Studios can organize employees into Team A and Team B and run one concurrent
project per team. New projects assign lead programming, design, art, writing,
audio, QA and production independently; one person may cover several roles, but
their contribution falls as their workload climbs. Team membership, project
ownership, role assignments and both active projects persist in saves.

Project roles carry explicit workload percentages. Assignments totaling 100% or
less remain fully effective; overload reduces that employee's development
contribution, raises project bug risk, drains energy and morale, and builds
stress each week. The team and employee views show every role and the exact
total rather than hiding the pressure behind a generic status.

Employee contribution is multiplicative rather than headcount-based: role skill,
relevant creative/quality/leadership attributes, experience, morale, condition
and workload efficiency combine into an output rating. Design drives gameplay
and innovation; programming drives technology, performance and safer code; art,
writing and audio own their disciplines; QA discovers and removes bugs while
adding polish; and production improves scheduling and softens overload penalties.

Positive modifiers are bounded. Genre, theme and platform knowledge, chemistry,
morale, traits, equipment, office comfort, producer and lead coordination,
engine features, culture and the pre-production plan used to multiply into the
same number, which took a maxed studio to +315% before headcount was counted at
all. `BonusStack` sorts them into five categories, caps each, adds rather than
multiplies them, and caps the total at +41%. Capacity, core competence,
penalties and trade-offs deliberately stay outside it -- see
`docs/BONUS_STACKING_2026-09-08.md`.

Quality accrues per unit of work completed, not per week elapsed. Otherwise a
slower team banks more quality for the same project, and the team's own craft
cancels out of the result. Speed buys throughput -- more games per year -- not
worse games.

Team throughput follows a diminishing-return curve from 1.0x for one assigned
contributor to 5.2x for twelve, with producers recovering a small amount of
coordination overhead. Chemistry blends time together, teamwork, morale,
leadership, personality conflicts and recent review results. Its bounded effect
ranges from -8% to +5% development speed, up to -5% bug risk, and +10% stress
gain for struggling teams.

A review score has no ceiling tied to project size. A solo developer who
actually clears a tiny project's own quality bar can ship a 9 or a 10, same as
a twelve-person studio can on an AAA one -- real indie darlings do exactly
that. What a small team cannot do is generate enough raw quality across enough
disciplines to clear a *large* project's much higher bar in the first place:
each size sets its own expected quality, and understaffing it costs both speed
and the output that quality is built from. Team size buys the capacity to
reach a bigger bar, not a better score for clearing the same one.

Quality does not convert to a review score linearly. The scoring components add
up to an open-ended *merit* figure, and `ReviewSimulator.curve()` bends that
into a score with diminishing returns at both ends: through the middle a point
of merit is worth most of a point of score, and past the competent bar the
return decays towards nothing. Clearing the bar comfortably is a 7; clearing it
by a mile is an 8; a 9 takes an exceptional release and 9.6+ takes a
near-perfect one. Credit for over-delivering against your own size's bar
saturates, so a veteran studio's tiny project is not a free 9. A competent
studio averages about 7.1 across a career rather than drifting up to 9 and
staying there. See `docs/REVIEW_SCALE_2026-09-08.md` and
`docs/BONUS_STACKING_2026-09-08.md` for the measured distributions.

Scope is named in the same currency development actually runs on: every size
sets a required effort total, employees generate effort every week through
exactly the same staffing maths, and development length is never separately
authored -- it is just how many weeks that took. The project-setup screen
shows required effort next to the scope so the comparison is not hidden in
the numbers behind it.

A project can also name specific features -- Save Games, Branching Dialogue,
Turn-Based Combat, Open World and more, authored in `data/game_features.json`
and picked once at project start. Each adds effort, discipline demand,
complexity and bug risk; its potential is realised gradually according to the
assigned team's ability to execute it. Every scope has a recommended complexity
range, but over-scoping remains an allowed, explicitly warned choice. Research
unlocks advanced features while the selected engine must actually contain any
capabilities they require. Soft genre relevance can help without creating a
single correct feature list. Outcomes survive saves and become durable studio
knowledge when the player completes a postmortem. Nothing here is required --
a project with no features chosen behaves exactly as it always has.

Named project assignments act as discipline leads. Other members of the active
team contribute as project support at 35% workload, allowing the full twelve-
person output curve without turning project setup into dozens of role toggles.

Employees carry one or two visible gameplay traits drawn from a catalogue of
around thirty (perfectionist, workhorse, lone wolf, code poet, night owl,
burnout-prone and so on). Each trait's mechanical effect is authored as a
structured `effects` block in `data/employee_traits.json` and read through
`EmployeeTraitSimulator` (pure); the contribution, overload, burnout,
chemistry, learning and market-value call sites consult it rather than
checking trait ids one by one, so a new trait is a data change. Their
tradeoffs feed contribution, overload, burnout, chemistry and learning
directly. Actual
weekly role use awards discipline-specific XP; support work awards slower XP in
the employee's specialty. Each skill has its own level and progress bar, and a
level-up adds five points to that underlying skill rather than a generic stat
pool. A junior who starts at 42 can reach 67 after roughly three years of steady
lead work, making developed employees meaningfully more valuable to retain.

Every employee keeps a career record that outlives their employment: the
games they were credited on and the role they held, their salary from the
hiring offer onward, every promotion, and every course finished here. Awards
have a place in the record too, ready for a later ceremony. Shipped games,
average review score and best-rated game are read straight off that history,
it survives into the list of people who have left, and older saves backfill
it from the games the studio has already shipped -- so when M4 rivals let a
former employee turn up working for a competitor, there is a real history
behind the name.

A project can also carry an optional target release date, set from the
development screen the same way a budget target is: purely a self-imposed
number, with nothing in the simulation enforcing it on its own. Once set, the
DEADLINE section reads the same live schedule forecast the budget warning
already uses (`DevelopmentSimulator.estimate_remaining`'s worst case) against
the target and, the moment that forecast would actually miss it, surfaces the
gap in weeks alongside four real levers: cut a chosen feature out of the
build (its effort comes off what's left immediately, and it earns no more
quality from there on -- whatever it already banked stays), jump to hiring,
switch on the team's existing crunch toggle, or admit the date and push the
target out to match the forecast. See `DeadlineSimulator` and the DEADLINE
section of `DevelopmentScreen`.

Separately, every active project's own live schedule forecast is watched week
to week for real drift -- not a random event. A week or two of ordinary noise
is never worth interrupting the player for, but a genuine slip pauses the
clock and names the actual cause: whichever assigned role is contributing
worst, a real bug pile-up, or a specific overloaded person by name. It fires
from the world tick itself, so it reaches the player the same way bankruptcy
already does, regardless of which screen they are on. See `DelaySimulator`
and `EventBus.project_schedule_slipped`.

The development screen also runs a standing diagnosis rather than waiting for
a slip: its own BOTTLENECK panel reads the same per-role numbers and calls
out whichever single discipline is actually holding the project back -- an
unstaffed role reads as the worst case of all -- alongside a concrete next
step ("Assign another programmer."). See `BottleneckSimulator`.

Employees also carry a `specialization_id`, empty until something sets it.
Skills split into named tracks -- programming into Engine, Gameplay, Tools
and AI, and so on for all eight -- authored in `data/specializations.json` so
a save already has somewhere to keep a choice. Nothing yet offers that choice
or gives it any effect: the actual moment an experienced employee specializes
is deliberately left for M4/M5, and this is only the record it will need.
Deliberately a second, independent axis from the seniority ladder above, not
a merged one: "Junior -> Senior" is career level, changing only title and pay
band, while "Programmer -> AI Programmer" is expertise within the discipline,
and a Junior can hold a specialization exactly the same as a Lead can.

That choice is actually reachable in M3 -- through training, not a separate
screen. Every one of the 32 specialization categories now has its own course
in `data/training.json`, alongside the broader per-skill ones. Finishing one
sets `specialization_id` to that category (a later specialization course
redirects it, the same person can change focus more than once) and, the
first time it ever happens for someone, is announced on its own rather than
folded into the ordinary "training complete" toast. Nothing about seniority,
title or pay is touched by any of it. See `TrainingManager._apply_specialization`
and `EventBus.employee_specialized`.

Studio creation also offers a founder background -- Programmer, Designer,
Artist or Generalist, authored in `data/founder_backgrounds.json` -- purely
for replayability: a one-time tilt to the founder's own starting skills
(e.g. a Programmer opens Programming +20, Testing +10, Design -5; Generalist
spreads a smaller +5 across all eight instead of leaning into one), applied
once at creation and clamped to the normal 0-100 range. It never touches
seniority, title or pay, and has nothing to do with the specialization system
above -- a different, one-time choice about who the founder already was
before the studio existed. See `EmployeeManager._apply_background` and the
new-company screen's background picker.

The same screen also offers a founder trait -- one, chosen deliberately from
the same catalog every hired candidate randomly draws one or two from,
replacing that random roll rather than adding to it. Two new entries joined
`data/employee_traits.json` to round the choice out: People Person softens
the morale hit of being overworked the same way Workhorse already softens
its stress, and Technical Genius lifts both programming and testing
contribution with no chemistry cost, unlike the narrower Lone Wolf. Both are
real additions to the shared pool, not founder-only flavor -- an ordinary
hire can roll either one too, and both move market value like every other
trait already does.

The Company screen also reads a curated STUDIO STRENGTHS panel, distinct
from the exhaustive genre/theme breakdown STUDIO EXPERIENCE already gives
further down the same page. It blends two different things: shipped-game
track record (the same genre/theme levels ExperienceManager already tracks)
and who is actually on the roster right now. A discipline's strength reads
off the studio's own bench -- the average of its top three people in that
skill, not a flat roster average an unrelated hire would only dilute -- plus
a real bump for anyone actually specialized in it. The four strongest
strengths across genre, theme and all eight disciplines are shown together,
ranked, exactly as the mock-up shows RPG and Space alongside Storytelling
and Technology; a studio with nothing shipped and nobody hired yet shows no
panel at all rather than a wall of empty stars. See `StudioIdentitySimulator`.

Employees also carry `employer` -- unemployed, player or competitor -- a
second, independent record from `status` above: `status` is their lifecycle
stage with whoever currently employs them (candidate/active/departed/
laid_off), `employer` is *who* that is. Every existing employment transition
already keeps it current (generated candidates are unemployed, hiring makes
them the player's, a layoff or a resignation returns them to unemployed), but
nothing today ever sets "competitor" -- there are no rival studios yet to be
employed by. Poaching, where an employee moves to or from a competitor, is
deliberately left for M4 rival studios; this is only the record it will need,
the same way `specialization_id` above was recorded years before training
could ever set it.

Employment itself stays deliberately simple for M3: hiring is indefinite,
with no contract length or expiration to track and nothing to renegotiate.
Contract terms -- a fixed-length deal, negotiation, a term coming up for
renewal -- are a real system with real payoff once rival studios exist to
create competition for a person's signature; before that, they would only be
complexity with nothing backing it.

M4 rival studios, M5 publishers and contracts, M6 engines and technology,
M7 advanced studio operations, M8+ acquisitions, franchises, publishing and
eventually your own console.

## Sequels and franchises

Every original game the studio ships becomes an intellectual property. From any
released game's detail page -- or the new Franchises list off the Games tab --
the player can start a **sequel**: game creation opens with a NEW IP / SEQUEL
choice, and picking a franchise pre-fills and locks its genre and theme. A
sequel is linked by `GameProject.series_id` and numbered by `sequel_number`;
`Franchise` (`GameState.franchises`) tracks each series' entries, lifetime units
and revenue, average review, and three stateful figures that move every week and
every release -- fan interest, reputation and fatigue. All of it persists in
saves (v23); a career loaded from an older save has each shipped game backfilled
as its own single-entry IP.

`FranchiseSimulator` is the pure maths, and it is tuned so a sequel is worth
making without being a free win. A sequel to an anticipated series opens to a
real launch-demand bonus from its fan interest, plus small reused-design-
knowledge quality and team-familiarity speed bonuses -- but it is also judged
against the series' own standard (a raised review bar that scales with the
franchise's reputation and how long it has run), and against
`SalesSimulator.QUALITY_EXPONENT` a higher bar is a genuine cost. Shipping
entries close together accumulates **franchise fatigue** faster than the gap
between them clears it; strong innovation partly counters the addition, and time
away decays it. By the fourth or fifth annual entry of a milked series the
fatigue penalty outweighs the fan-interest bonus and the sequel opens *worse*
than a brand-new IP would have. `FranchiseEconomyTest` measures a scripted
five-entry series to pin that no-runaway property, the same way
`EconomyPlateauTest` does for the whole career; `FranchiseTest` covers IP
creation, sequel linkage, fan carryover, expectations, fatigue and its decay,
serialization and history. The release presentation and postmortem both explain
a sequel's performance in franchise terms.

Architecture is prepared for remakes, remasters, spin-offs and expansions as
future entry kinds without further model changes, but only the sequel is
implemented here.

## The Annual Game Awards

Once a year a fictional industry ceremony judges the previous calendar year's
releases. Categories are authored in `data/awards.json` -- Game of the Year,
Best RPG / Action / Strategy / Simulation, Best Technology, Best Visuals, Best
Narrative, Most Innovative and Best Indie Game -- each with a review-score
floor, a minimum number of eligible releases before it forms at all, and a set
of weights over the underlying craft it is about. A narrative award scores
story and writing execution, not the review number; Best Technology scores the
engine, stability and innovation; Game of the Year scores overall quality,
reception and commercial reach. `AwardsSimulator` is the pure maths and
`AwardsManager` owns the yearly cadence off `World`'s tick, the same way the
platform and unlock systems do. With no rival studios yet (M4) every eligible
release is one of the player's own, so a ceremony that forms is the studio's to
sweep -- the eligibility pool simply widens when competitors arrive.

Winning is a prestige goal, not an economic lever. The rewards are one-off and
touch only soft systems: a capped bump to consumer reputation, fans, employer
(recruiting) reputation and studio-wide morale, plus a little renewed fan
interest for a winning entry's franchise. Nothing here ever grants cash or
changes a game's quality, and every per-ceremony figure is capped so a clean
sweep is a good year rather than a windfall -- `AwardsEconomyTest` sweeps
fifteen dominant years and pins that the awards contribution stays a rounding
error next to what the catalogue earns on its own.

Every nomination and win is kept permanently on `GameState.award_ceremonies`
and, for the credited team of a winning game, on each person's career record
(`Employee.awards`). The short annual ceremony screen lists each category's
nominees and winner and the prestige the night brought; a game's detail page
shows the awards it took; the Records screen carries the full history and the
Company screen's statistics show total nominations, total awards and Game of
the Year wins. Save format is v24; older careers load with an empty history and
begin judging from the year they are opened in.

## Financial crisis and recovery

Money trouble is a management problem before it is a game over. `CrisisSimulator`
grades the studio's cash position into four staged levels -- **Runway Low**
(cash still positive but under two months of burn), **Financial Trouble**
(overdrawn, most of the grace window intact), **Critical** (half the grace
window gone) and **Insolvent** -- and `FinanceManager` only interrupts the
player when the level *steps up*, not every overdrawn week. Runway Low is a
quiet heads-up; Trouble and Critical pause the clock once and post a story.

The crisis plan screen mirrors the schedule-slip panel: it shows cash, monthly
burn, runway, the upcoming payroll, the active project's estimated completion,
a conservative read of near-term income, and any debt -- then names the single
biggest recurring cost (`CrisisSimulator.biggest_driver`, the financial analogue
of `BottleneckSimulator`) and lists concrete levers with their consequences.
Every lever reuses an existing system: cancel the active project, cut a feature
to shrink its remaining scope, lay staff off, move to a cheaper office
(`OfficeManager.downgrade` -- the office ladder now runs downward as well as up,
blocked if the smaller space cannot hold the team), or take contract work.

The one new mechanic is a capped **emergency loan** (`LoanSimulator` /
`LoanManager`). One at a time, principal capped at 60% of the studio's best
proven trading year (floor for a studio with no track record, hard ceiling of
$250K), ~1%/week interest over a 52-week amortised schedule, and no lender will
extend more than four across a whole career. The weekly repayment is drawn in
the world tick right before the books settle, exactly like payroll, so a loan
the studio cannot service just deepens the hole. Taking a loan adds cash and
nothing else -- it never resets the overdrawn grace clock. `CrisisEconomyTest`
plays a structurally insolvent studio that borrows the maximum every time it
can and confirms it still goes bankrupt within months, not years; the regular
balance probes are unchanged because they model no loan-taking manager.
Bankruptcy itself is untouched: a badly run studio still runs out of grace and
closes. Save format is v25 (loan, crisis level and lifetime loan count).

## Difficulty, settings and lifecycle

Difficulty (Relaxed / Normal / Hard, `data/difficulties.json`) is a small set
of economic and risk scalars over one shared simulation, not three separate
ones, and never changes what content is compatible or available. A tier sets
starting cash, sales strength, operating expenses, bankruptcy grace, candidate
salary pressure and project bug risk. Normal is the canonical balance target
and every Normal multiplier is exactly 1.0, so the balance probes are
unaffected; the last two scalars are the only additions and an unknown
difficulty id falls back to Normal-equivalent numbers.

Player settings persist to `user://settings.json`, separate from the company
saves, so preferences outlive a new company or a bankruptcy: master / music /
SFX / ambience volume, subtle haptics, reduced motion, compact numbers,
notifications, tutorials, a starting game speed, an autosave toggle and a text
size (`Settings.TEXT_SCALES`). Text scaling runs every code-built font size and
tap-target height through `UiBuilder`, and the theme base size through
`VisualTheme`, growing touch targets with the text and never below the 44 px
minimum. Turning autosave off still leaves the manual slots and the lifecycle
safety save; the player is never left with nothing.

`AppLifecycle` hardens the game against iOS suspending or terminating it.
Backgrounding, an interruption, the screen locking, a memory warning or the
player swiping the app away all pause the clock and write the autosave slot
immediately — ignoring the autosave preference — so a returning player resumes
an in-development project and a shipped game's sales without losing meaningful
progress. On resume the clock stays paused until the player taps play, so no
real time is silently converted into simulated weeks.

## M6 foundation

The Engine Lab lets studios research era-appropriate technology and combine
the features they know into named, reusable custom engines. New games can use
any engine the studio has built. Its feature set affects production speed,
technology, graphics, sound, performance and bug risk, so an engine is a real
production choice rather than a cosmetic label. Research, engine history and
the engine attached to every game persist in saves; older saves begin with the
two dependable 1985 starter technologies.
