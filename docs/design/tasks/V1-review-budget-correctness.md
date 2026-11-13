# V1: Review and budget correctness

Read [../README.md](../README.md) first for the working rules and build command.

**Owns:**
- `Thaw/Features/Payday`, `Thaw/Features/PaydayReview`, `Thaw/Features/StillWantIt`;
- `Thaw/Models` (budget maths only: `FunMoneySummary` in `Want.swift`, or a new file next to it);
- `ThawTests/PresenterPaydayTests.swift`, `PresenterPaydayReviewTests.swift`, `PresenterStillWantItTests.swift`;
- a new `ThawTests/IntegrationReviewTests.swift`.

**Wave:** 1. **Product decisions:** D4 and D5. Confirm with the user before step 3.

Review findings 1, 2, 3, 10 and the clipped-text part of 4.

## 1. Crash in "Still want it?" (must fix)
`Thaw/Features/StillWantIt/StillWantItPresenter.swift`:
- `current` (line 22) is `interactor.wants[index]`, with no bounds check.
- `advance()` (line 52) increments `index` and starts the dismiss.
- A second tap on **Buy it** (`tapBuy`, line 36) or **Wait a payday** (`tapWait`, line 43) during the dismiss animation reads past the end and traps.

**Fix:**
- Add an `isFinished` (or `isBusy`) flag. Every action returns early once the last want is decided, or while a decision is being applied.
- Make `current` optional or guarded, so it can never trap.
- Disable the three buttons while the moment or dismiss runs. That needs a view method, for example `setActionsEnabled(false)`.

**Test:** decide the last want, call `tapBuy()` and `tapWait()` again, and check there's no crash and no second store call.

## 2. Done applies twice in the Payday review (must fix)
`Thaw/Features/PaydayReview/PaydayReviewPresenter.swift`, `tapCTA()` (line 58):
- It calls `interactor.apply(choices:)` with no guard.
- A double-tap or a VoiceOver double-activate applies everything twice.
- Wait calls `WantStore.decide(keep: false)`, which moves `thawsAt` to `paydayAfter(max(thawsAt, now))`. So a second call pushes the want **another** payday out.

**Fix:**
- Add an `applied` flag set on the first `tapCTA`. Later calls do nothing.
- The view disables the Done button after the first tap.

**Test:** call `tapCTA()` twice and check `apply` was called once.

## 3. One budget rule for the Payday tab and the review (must fix, after D4 and D5)
Today the two screens compute "what fits" differently.

| | Payday tab (`PaydayPresenter`) | Review (`PaydayReviewPresenter` lines 20–25, `StillWantItPresenter` line 66) |
|---|---|---|
| Quick thaws | Left out of the total (D2) | Counted in the meter and the defaults |
| After the first overflow | Everything after it is "Over budget" (`budgetSections`, comment at line 146) | A later cheaper want can still default to Keep |
| Order | Sorted by `thawsAt` (line 74) | `reviewQueue` order, unsorted |

Example: S$300 fun money, ready wants are a S$24 quick thaw and a S$280 payday want. The Payday tab says "S$20 left", but the review meter says "S$4 over".

**Fix:**
1. Add one pure function in `Thaw/Models`, for example `FunMoneyPlan.make(wants:funMoney:timerThreshold:)`. It returns:
   - the payday wants in `thawsAt` order, each marked fits or over;
   - the quick thaws, separately;
   - the totals and the left/over figure.

   Use the rules the user confirms:
   - **D4 (recommended):** quick thaws are excluded from the meter and the defaults.
   - **D5 (recommended):** best fit in thaw order. Keep any want that still fits, even after an earlier one overflowed.
2. **Payday tab:** the Fits / Over budget sections and the budget block use it.
3. **Payday review:**
   - the default choices and the meter use it;
   - rows are shown in its order;
   - quick thaws are shown as their own group (`SectionHeaderView` "Quick thaws"), with Keep · Wait · Let go that apply normally but don't count in the meter.
4. **"Still want it?":**
   - the meter uses it;
   - `boughtTotal` keeps counting only this session's buys (today's behaviour);
   - check whether `funMoney` should also be net of wants already bought this payday, and say what you found in the report.

**Tests:**
- Unit tests for `FunMoneyPlan`:
  - exactly on budget;
  - fun money 0;
  - only quick thaws;
  - overflow followed by a cheaper want (D5);
  - mixed order (sorted by `thawsAt`).
- Payday and review presenter tests with the **same** inputs give the **same** left/over figure. Write one test that runs both presenters on the example above.

## 4. Changes reach other tabs late after Let go (should fix)
- In `StillWantItPresenter.tapLetGo` (line 29), the skip is written straight away, but `interactor.publishChange()` only runs inside `advance()`, after the 1.2 s Cubi moment.
- **Fix:** publish straight after the store write. Keep `advance()` for navigation only.
- **Test:** Let go publishes before the moment completes.

## 5. Clipped text on Payday review (accessibility audit)
- `NewScreensAuditTests.testPaydayReviewAudit` reports **Text clipped** on the Payday review at the default text size. The audit didn't name the element.
- Find it:
  1. run `xcodebuild … -only-testing:ThawUITests/NewScreensAuditTests/testPaydayReviewAudit test`;
  2. read the `AUDITISSUE` lines;
  3. inspect the screen. Likely suspects are the three-way `ReviewChoiceControl` segments and the long quote line.
- **Fix:** let the text wrap, or stack the control at large sizes.
- The Dynamic Type issues on the same screen are V2's job (font cap). Rerun the audit after V2 merges.

## Integration test (new `ThawTests/IntegrationReviewTests.swift`)
Use a real temp-file `WantStore` with the real interactor and presenter. Run it through the review:
- a Wait moves `thawsAt` to the next payday **once**, even when Done is tapped twice;
- a Let go ends up `.skipped`, with `decidedOn` set;
- the review queue no longer contains decided wants.

## Done when
- Findings 1, 2, 3, 10 and the clipped text are fixed.
- D4 and D5 are confirmed and implemented the same way on both screens.
- The new tests and the existing tests pass.
- Before and after screenshots of the Payday tab and the review are taken with `-thawFixture thawed` and with the default seed, including AX3.
