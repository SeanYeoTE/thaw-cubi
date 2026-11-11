# T3: Payday tab

> **Done.** Shipped on `feature/s11-ui-standardise` (SeanYeoTE/thaw-cubi#18). Kept for history; the code is the source of truth now.

Read [../../README.md](../../README.md) first for the working rules.

**Owns:** `Thaw/Features/Payday` (new VIPER module), `Thaw/App` (`RootTabBarController`, `ReviewRouter`, `SceneDelegate`, `Reminders`), new `ThawTests/PresenterPaydayTests.swift`.
**Depends on:** T2 merged (`EmptyStateView`, `SectionHeaderView`, leaner `WantRowModel`). **Unblocks:** T4's last step (removing the card from Cooling).

## Problem
The only way into the payday review is tapping the payday card on Cooling. It looks like information, not a button, and it's greyed out at 50% most of the month. People don't find the review.

## Goal
A **Payday** tab, second in the bar, that always has something useful on it and badges when there's a decision to make.

Tab order: **Cooling** (`snowflake`) · **Payday** (`calendar` or a Cubi-like symbol, your choice) · **Stats** (`chart.bar`) · **Settings** (`gearshape`).

## Screen states

The data is already in the store:
- `reviewQueue`: wants ready to decide (thawed timers, plus payday wants once payday arrives).
- `payday.nextPayday` and `payday.daysUntilNext`.
- `effectiveSettings.funMoney`.

**1. Nothing ready (most days)**
- Title "Payday".
- Hero: Cubi (`.frozen`, about 96 pt) and a big **"14 days"** (`ThawFont.display`) with a small "to 25 Nov" under it.
- Budget bar: what will thaw this payday against fun money, for example "S$120 of S$300". Reuse `FunMoneyMeterView` or a `ProgressBarView`. Over budget uses the existing over-budget style.
- Section "Thawing this payday" (`SectionHeaderView`, total on the right): lean read-only rows of the cooling wants with `thawsAt <= nextPayday`, soonest first. Tapping a row pushes Item detail (`ItemDetailRouter.createModule`). No swipe actions here; editing stays on Cooling.
- Nothing cooling at all: `EmptyStateView` (frozen, "Nothing on ice.", no button). Adding stays on Cooling.

**2. Ready to review (`reviewQueue` not empty)**
- Cubi `.thawed`, big **"3 ready"**, total price · fun money on one line.
- Primary `PillButton` **"Review"**, which presents `PaydayReviewRouter.createModule(store:reminders:wants:onFinish:)` in `ReviewSheet.wrap(...)`, dismissed by this module's router.
- Quiet button **"Remind me tonight"**, which calls `Reminders.remindTonight` (moved here from the `PaydayPreview` sheet), then success haptic and the button shows "Reminder set".
- Section "Ready": rows of the queue. Below it, "Thawing this payday" for the rest, as in state 1.

## Badge
- `RootTabBarController` sets the Payday tab's `badgeValue` to `store.reviewQueue.count` (`nil` when 0).
- Update on `DataChange`, on `sceneWillEnterForeground`, and on a timer firing at the next timer thaw while the app is open. A simple option: refresh on `UIApplication.significantTimeChangeNotification` plus foreground. Timers thaw by date, so the count changes with no data change.
- The badge must be correct at cold launch, before the tab has ever been opened. Don't rely on the Payday view having loaded.

## Notification entry (`ReviewRouter`)
- On a review request: select the **Payday** tab (index 1), pop it to root, then present the review as it does today. When the review finishes, the user is left on Payday instead of Cooling.
- Keep the existing "Nothing to review right now" alert for an empty queue.
- `RootTabBarController` should expose the tab index as a constant (for example `enum Tab: Int`) so `ReviewRouter` doesn't hardcode `1`.

## Copy (presenter)
- "14 days" / "1 day" / "Today". "to 25 Nov" uses `Formatting.paydayDate`.
- "3 ready" / "1 ready".
- Spoken hero: "14 days to payday, 25 November. 2 wants thaw then, S$120 of your S$300 fun money."
- No other sentences on screen.

## Not in scope
- Don't edit `Thaw/Features/Home` or `Thaw/Features/PaydayPreview`. T4 removes the card from Cooling and deletes `PaydayPreview` after you merge. Until then both entry points exist; that's fine.
- `PaydayReview` and `StillWantIt` are unchanged.

## Tests (`ThawTests/PresenterPaydayTests.swift`, fake view, interactor and router; see `PresenterTestSupport.swift`)
- Empty queue → "N days" hero, no Review button, "Thawing this payday" rows sorted soonest first, budget total correct.
- Queue of 3 → "3 ready", Review routes with exactly those wants.
- Review tapped with an empty queue does nothing.
- Remind tonight → interactor called; on completion the view shows the success state.
- `DataChange` → re-renders.
- Row tap routes to Item detail with the right id.
- Badge: a small unit test of the count helper, if you pull it out of `RootTabBarController` into something testable.

## Simulator check
- `-thawFixture sprint1` (nothing ready) and a state with a thawed timer want (frozen more than `timerDays` ago; the DEBUG first-launch seed has one).
- Badge shows the right count at cold launch.
- A notification tap (`xcrun simctl push` with the payday category; see `docs/qa/sprint-3-report.md` TC-S3-1) lands on Payday with the review open.
- Screenshots at the default size and at AX3.

## Done when
- Four tabs, the badge works, the notification goes to Payday, and the Remind tonight flow works.
- Tests and build pass.
- The report tells T4 that the merge is done.
