# M3 completion gate: from founder to studio

Status: acceptance criteria established; completion has not been demonstrated.

The [September 7 test pass](M3_TEST_REPORT_2026-09-07.md) found a confirmed
Studio dashboard overflow, two career-balance assertion failures and a faulty
delay-test assumption. Workforce and two-team integration checks provide partial
evidence; the connected UI growth journey is still pending.

M3 is complete only when the player can perform every action below through the
game UI in a connected career. The existence of a manager, formula, screen or
passing isolated test is supporting evidence, not milestone acceptance.

The decisive requirement is: **a 10-person studio should feel fundamentally
different from the original one-person company.** Count the founder in headcount.

## Required player outcomes

All rows remain unverified until a recorded playthrough demonstrates them.

| Player can | Observable acceptance evidence |
| --- | --- |
| Start alone in a bedroom | A new company has one founder, bedroom capacity and no hired payroll. |
| Earn enough to rent an office | Ordinary play funds the first move and subsequent rent without injected cash. |
| Hire employees | Recruit through the UI; the employee joins the roster, occupies capacity and adds the agreed salary. |
| Pay recurring payroll | Multiple monthly settlements deduct salaries, including while employees are idle. Costs are readable in the books. |
| Assign employees to projects | Change assignments through the UI and see the correct people contribute to the intended project. |
| See skill differences matter | Compare staff on the same discipline and scope; the stronger relevant skill changes visible output or forecast. |
| Manage employee workload | See total workload and its sources; redistribute work and observe overload and its consequences decrease. |
| Handle stress and morale | Understand deteriorating condition and use available actions to improve it, with visible production consequences. |
| Use crunch if desperate | Enable and end crunch for a team; see a short-term production benefit and accumulating human costs. |
| Deal with burnout | Observe warnings, actual burnout, lost availability and recovery; adapt the affected project while salaries continue. |
| Train employees | Pay for training, accommodate its availability cost and see the completed course improve the employee. |
| Promote employees | Promote an eligible employee through the UI and see title, salary and career history change. |
| Watch juniors become veterans | Retain a junior through sustained work, skill growth and seniority progression; their accumulated skills and record make them more valuable. |
| Build teams | Form teams, select members and see their composition affect production and working relationships. |
| Manage project scope | Understand scope before committing and reduce an active project's scope with visible effort and quality tradeoffs. |
| Identify development bottlenecks | Read a specific diagnosis, act on it and observe the bottleneck or forecast respond. |
| Move into larger offices | Progress through office tiers; pay moving and recurring costs and gain usable capacity. |
| Install studio upgrades | Purchase and install an upgrade; verify its cost, constraints and actual gameplay effect. |
| Operate two teams | Run two concurrent projects with distinct assignments; managing one preserves the other's state and ownership. |
| Stay financially solvent while carrying payroll | Fund recurring payroll, rent and development from normal income across releases and revenue gaps. |

## Connected career demonstration

1. Start a fresh company on Normal difficulty. Earn the first office through
   ordinary releases; record elapsed weeks, cash and moving costs.
2. Recruit a complementary employee, assign work and carry at least three
   monthly payroll settlements. Show how this changes the founder's workload.
3. Grow through the office tiers. Retain an early junior, train them and follow
   their skill growth and promotions into a veteran role.
4. Make a scope or staffing mistake visible through a bottleneck. Correct it.
   Demonstrate crunch, burnout and recovery on a saved branch if needed so the
   main career can continue; record the costs and staffing response.
5. Reach ten people, install an upgrade and operate two teams on concurrent
   projects. Sustain at least six monthly settlements, including a period
   without a new release, without cash grants or waived expenses.
6. Save and reload during concurrent development. Confirm assignments, project
   progress, condition, training, promotions, offices, upgrades and financial
   obligations persist. Continue through the next payroll settlement.

These observation windows are minimum evidence, not new simulation rules.
Record game version, difficulty, dates, actions, balances, payroll, screenshots
and failures. Debug fixtures can support targeted checks but cannot prove that
the growth path is affordable or discoverable in normal play.

## One person versus ten people

| Decision | Bedroom founder | Ten-person studio must demonstrate |
| --- | --- | --- |
| Production | Choose work the founder can cover. | Balance specialists, discipline coverage and coordination across two teams. |
| Time | Allocate the founder's limited effort. | Reassign overload, cover absences and reserve time for training. |
| People | Manage personal condition. | Retain and develop people whose skills, morale and career histories differ. |
| Money | Finance a small project and basic overhead. | Carry committed payroll and office costs while releases and revenue arrive at different times. |
| Growth | Decide when the first hire is affordable. | Weigh another hire or upgrade against runway, team needs and larger scope. |

Fail this gate if ten people simply make the same solo project faster, if
assignments and skill coverage are inconsequential, or if payroll and employee
condition can routinely be ignored. The player must be able to explain the
consequences from information available on screen.

## Existing evidence and remaining verification

The repository includes workforce smoke coverage in `M3EmployeeSmokeTest`,
targeted suites including `TrainingTest`, `MoraleTest`, `BurnoutTest`,
`ScopeTest` and `BottleneckTest`, and career phases under
`scripts/tests/acceptance/`. These are starting points for verification;
this document does not claim they have passed.

Phase A drives managers directly and uses a forced successful hiring roll.
It is useful simulation coverage, but cannot establish normal UI recruiting,
discoverability or the qualitative difference between solo and studio play.
Complete the connected UI demonstration and record evidence for every row
before declaring M3 finished. Later-milestone features do not substitute for
an unmet M3 requirement.
