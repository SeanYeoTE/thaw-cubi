# U1: Payday tab, the budget decision

Read [../README.md](../README.md) first for the working rules, copy rules and build command.

**Owns:** `Thaw/Features/Payday`, `Thaw/App` (badge and notification routing), `ThawTests/PresenterPaydayTests.swift`.
**Wave:** 1. **Product decision:** D2. Confirm the direction below with the user before building.

## Problem
Look at the Payday panel in [../s11-screens.jpg](../s11-screens.jpg).
- **Most of the month the tab repeats Cooling.** It shows the same four wants under "Thawing this payday" that Cooling shows under "This payday".
- **The budget line doesn't say what it means.** "S$702 of S$300" sits under a full orange bar, with no "S$402 over" and no hint about what to do.
- **The rows don't show timing.** Payday rows show no days left, while quick-thaw rows do, so the two kinds read differently for the same want.
- **The ready-to-review state has never been checked on a device.**

## Recommended direction (D2)
The Payday tab answers one question: **"Will this payday's wants fit my fun money, and if not, what has to give?"**

1. **Hero** (keep the dark card, the countdown and Cubi): "14 days · to Wed 25 Nov".
2. **Budget block**, the new focus:
   - A big figure and a short caption. Under budget: **"S$120 left"**. Over budget: **"S$402 over"**, using `Theme.timer` or a stronger warm on the dark card, with a contrast check.
   - The bar shows spoken-for against fun money, with a marker at 100% so "over" is visible without relying on colour.
   - One line under it: "S$702 thawing · S$300 fun money".
3. **"What fits"** (only when over budget): the wants that fit, in thaw order, under `SectionHeaderView` "Fits · S$282". Then "Over budget · S$420" for the ones that push past it. The cut-off is a running total in thaw order: list order, not a recommendation.
4. **Under budget:** a single "Thawing this payday" section, as now, but each row shows its days left too.
5. **Ready state** (`reviewQueue` not empty): the hero switches to Cubi `.thawed` and **"3 ready"**, with the primary **Review** button and the quiet **Remind me tonight** button, as today. The budget block shows what is *ready*, not what is still cooling.
6. Rows stay read-only. Tap opens Item detail. Editing stays on Cooling.

**Also confirm with the user:** do quick-thaw wants count against fun money? Today the total includes them (the S$24 phone case is in S$702), but they're decided whenever they thaw, not at the payday review. My recommendation: show quick thaws in their own small "Quick thaws" section and leave them out of the payday total. Either way, the presenter should make the rule explicit and test it.

## Notes for building
- Budget figures come from `snapshot.payday.funMoney` and the same queue rules as today (`PaydayPresenter.refresh`, `PaydayReadiness.swift`). Keep the money maths in the presenter so it's unit-tested.
- Use `Formatting.sgd` for every amount. Currency is S$.
- The spoken summary already exists (`countdownSpoken`). Extend it with "S$402 over" or "S$120 left".
- The badge and notification routing in `Thaw/App` must keep working. Change them only if the readiness rule changes.
- Keep these identifiers: `payday.hero`, `payday.review`, `payday.remind`, `payday.row`. Add `payday.budget`.

## Tests (`ThawTests/PresenterPaydayTests.swift`)
- Under budget: "S$120 left"; one section; rows carry days left.
- Over budget: "S$402 over"; "Fits" / "Over budget" sections split by the running total in thaw order; the section totals are correct.
- Exactly on budget counts as fitting ("S$0 left").
- Fun money of 0 doesn't crash; everything is "over".
- The quick-thaw rule from the user's decision is applied and tested.
- Ready state: "3 ready"; Review routes with exactly the ready wants; Remind tonight is unchanged.
- Existing tests still pass, or are updated with a reason.

## Simulator check
- Default seed (over budget), `-thawFixture thawed` (ready state), and `-thawReset` then onboarding (empty).
- Screenshots of each state at the default size and at AX3.

## Done when
- The Payday tab no longer duplicates Cooling.
- The budget says "left" or "over" in words.
- The ready state is checked on the simulator.
- Tests and build pass.
