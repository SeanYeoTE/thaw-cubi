# Sprint 13 QA report: review fixes (V4)

**Environment:**
- Commit: `36136f7` (merge of #25, `integration/s13`) on `main`.
- Simulators: iPhone 17 Pro (iOS 26.0), iPad Pro 13-inch (iOS 26.0).
- Build: `xcodebuild … build-for-testing`, exit 0.

**Status: the simulator pass is blocked.** The app built, and one driver run started. After that, the session's permission policy refused every further action on the QA simulator: running the UI-test driver, uninstalling, and reinstalling the app. So no step below was driven by eye, no screenshots were taken, and `docs/design/s13-screens.jpg` wasn't made. `s11-screens.jpg` stays until the new sheet exists. What's left is code reading and the automated suite, both listed below. Rerun the pass once simulator access is granted.

## Full test suite

Run on the merge commit's code, iPhone 17 Pro, iOS 26.0 (from the #25 merge run, not rerun here):

| Suite | Result |
|---|---|
| Unit tests (`ThawTests`) | 275 run, 0 failures |
| UI tests (`ThawUITests`) | 23 run, 0 failures |
| Accessibility audits (inside the UI tests) | 11 of 11 pass |

## Pass

| Step | Result | Evidence |
|---|---|---|
| 1. Onboarding | Not run (blocked) | Covered in part by `PersonaTests.testLazyUser` (green in the suite) |
| 2. Cooling: filters, sort, swipe, row, relaunch | Not run (blocked) | — |
| 3. Item detail: Let go confirm, Decide now | Not run (blocked) | `ReviewFlowUITests.testDetailLetGoConfirmRemovesWant`, `testDetailDecideNowOffersThreeChoices` (green) |
| 4. Payday tab: over budget, figures match the review | Not run (blocked) | Code: the Payday tab, the review, "Still want it?" and `Reminders` all use `FunMoneyPlan`. `PresenterPaydayTests.testPaydayTabAndReviewAgreeOnLeftWithAQuickThaw` (green) |
| 5. Review: Keep · Wait · Let go, meter, double Done, discard | Not run (blocked) | `IntegrationReviewTests.testReviewAppliesEachChoiceOnceEvenWhenDoneIsTappedTwice`, `ReviewFlowUITests.testReviewKeepWaitLetGoAppliesChoices`, `testReviewCloseWithChangesAsksBeforeDiscarding` (green) |
| 6. "Still want it?": double Buy on last want, Let go refresh | Not run (blocked) | `PresenterStillWantItTests.testTappingAgainAfterLastWantIsDecidedDoesNothing`, `testWaitTwiceOnLastWantWaitsOnce`, `testLetGoShowsMomentThenAdvancesAndSpendsNothing` (green) |
| 7. Stats: hero, tiles, chart, filters, row to Edit | Not run (blocked) | Stats audit passes in the suite |
| 8. Settings: values kept, rule screen, countdown | Not run (blocked) | — |
| 9. Edit sheet: "Back to cooling · …", gap above Delete | Not run (blocked) | `PresenterAddWantTests.testReopeningAWantStillCoolingShowsItsOriginalDate`, `testReopeningAPastDueWantSaysItIsReadyNow` (green). Gap: `deleteGap` spacer in `AddWantViewController` |
| 10. Share sheet from Safari | Not run (blocked) | — |
| 11. iPad: titles line up with the cards | Not run (blocked) | `ThawColumnTests.testTitleLinesUpWithPlainSections`, `testTitleLinesUpWithInsetGroupedCards` (green) |
| 12. Reduce Motion on and off | Not run (blocked) | `CubiMotionTests.testIdleLoopsForeverAndStopsUnderReduceMotion`, `testIdleFadesUseAbsoluteOpacity` (green) |
| 13. Notifications | See below | |
| 14. VoiceOver spot check | Not run (blocked) | — |

AX3 repeats of the starred steps: not run (blocked).

### Step 13: Notifications

<!-- NOTIFICATIONS -->

## Bugs

None found. The code reading turned up nothing, but nothing was checked by eye, so this isn't a clean bill.

## What wasn't checked

- Every simulator step (1–12, 14), at the default size and at AX3, on iPhone and iPad.
- The screenshot sheet `docs/design/s13-screens.jpg`. `s11-screens.jpg` is kept until it exists.
- By eye only, with no test cover: the Cubi twinkle and drip fades (finding 6), the gap above Delete (finding 9), the share-sheet round trip, and the VoiceOver reading order.
- Side effect: the blocked run left Thaw uninstalled on the QA iPhone simulator (`1C8E32D3…`).
