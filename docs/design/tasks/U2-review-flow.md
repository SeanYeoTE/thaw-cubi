# U2: Review flow (Payday review and Still want it)

Read [../README.md](../README.md) first for the working rules, copy rules and build command.

**Owns:** `Thaw/Features/PaydayReview`, `Thaw/Features/StillWantIt`, `ThawTests/PresenterPaydayReviewTests.swift`, `ThawTests/PresenterStillWantItTests.swift`, `Thaw/Features/Shared/WantStore+Review.swift`.
**Wave:** 1. **Product decision:** D1. Confirm with the user before building.

## Why this matters
Deciding is what the app exists for, and it's the least checked part. Neither screen was looked at in the s11 redesign, and the ready-to-review state was never seen on a device.

## Step 1: walk the flow before changing anything
Launch with `-thawFixture thawed` (three ready wants: keyboard S$189, overshirt S$69, grinder S$420; default fun money S$300).

1. **Payday tab → Review:** choose Keep and Wait, go over budget, then "Wait on all". Close with choices made (expect "Discard choices?").
2. **Cooling → a want → Decide now:** Still want it, then "Yes, I'll buy it", "Skip and keep S$…" and "Not sure? Wait one more payday".
3. **Confirm:** Stats updates after a skip, the Payday badge count drops, and nothing reappears in the queue.

Write down every bug, dead end or confusing moment, with a screenshot, in your report under "Before". Fix bugs as part of this task. Anything outside your folders goes in the report.

## Problems already known
- **No Let go in the batch review (D1).** The batch review only offers **Keep** or **Wait**. Its footer says: "Anything you don't keep waits one more payday. Let go of it anytime from its page." Saving money, the point of the app, isn't possible from the main review.
- **Two review designs.** The batch review and the single-want "Still want it?" look and read differently.
- **Too much text:**
  - a Cubi quote plus "Pick what fits your fun money." shown twice;
  - "Fun money if you buy: S$… of S$… left";
  - "On 5 Nov, you said\n"…"";
  - long button labels.

## Recommended direction
**Batch review (`PaydayReview`):**
- **Top:** a fun money meter (keep `FunMoneyMeterView`) with "S$120 left" or "S$69 over" in words, updating live.
- **One row per want:** name, price, and the "why" in one quoted line (truncated, full text for VoiceOver). Under it a three-way segmented choice: **Keep · Wait · Let go** (D1). Default: Keep if the want fits the budget in thaw order, otherwise Wait. That's the current rule, extended.
- **Primary button:** "Done · keep 2, let go 1". Over budget is allowed but the meter says so.
- **No footer paragraph.**
- **Let go:** calls `store.update(id, status: .skipped)` through the interactor. The store already supports it, and `decidedOn` is set there.

**Single decision (`StillWantIt`):**
- Same visual language as a single review row, made bigger: name, price, the quoted "why" with its date ("5 Nov"), and the meter.
- Actions: **Keep** (buy), **Let go** (primary tone, since it saves money), **Wait one more payday** (quiet).
- Button labels: **"Let go · save S$189"**, **"Buy it"** and **"Wait a payday"**.

**Both:**
- Page sheets with close buttons, `accessibilityPerformEscape`, "Discard choices?" when there are unsaved picks (as now).
- The Cubi moment after deciding stays (`MomentView`).

## Notes for building
- `FunMoneySummary.make` lives in `Thaw/Models/Want.swift`, which you don't own. Let-go wants simply aren't passed in `keptPrices`, so it should need no change. If it does, put it in your report.
- `ReviewSheet.wrap` and `ReviewRouter` (in `Thaw/App`, owned by U1) present these screens. Don't change how they're presented. If you need to, write it in your report.
- New identifiers: `review.row`, `review.keep`, `review.wait`, `review.letGo`, `review.done`, `decide.buy`, `decide.letGo`, `decide.wait`.

## Tests
- **Batch:**
  - defaults (Keep while it fits, otherwise Wait);
  - choosing Let go updates the summary (spends nothing) and is applied as skipped on Done;
  - Wait moves `thawsAt` to the next payday;
  - Discard only when picks changed;
  - "Wait on all" still works.
- **Single:**
  - each action calls the right store method;
  - copy matches ("Let go · save S$189");
  - the meter text for left and over.
- Existing tests still pass, or are updated with a reason.

## Done when
- The flow was walked before and after, with screenshots, including AX3.
- Let go is possible from the batch review, or the user declined D1 and the report says so.
- Both screens share one visual language.
- Tests and build pass.
