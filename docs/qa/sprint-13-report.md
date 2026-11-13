# Sprint 13 QA report: review fixes (V4)

**Environment:**
- Commit: `36136f7` (merge of #25, `integration/s13`) on `main`.
- Simulators: iPhone 17 Pro (iOS 26.0), iPad Pro 13-inch (iOS 26.0).
- Build: `xcodebuild … build-for-testing`, exit 0.

**Status: the simulator pass is blocked.** Only the notification warm-start check (step 13.1) was run, on a separate simulator, before permission for more simulator runs was refused there too. The app built, and one driver run started. After that, the session's permission policy refused every further action on the QA simulator: running the UI-test driver, uninstalling, and reinstalling the app. So no step below was driven by eye, no screenshots were taken, and `docs/design/s13-screens.jpg` wasn't made. `s11-screens.jpg` stays until the new sheet exists. What's left is code reading and the automated suite, both listed below. Rerun the pass once simulator access is granted.

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
| 13. Notifications | 1 of 8 checks run: warm start passes. The rest are blocked; see below | [s13-notif-1c-warm-payday-review.png](s13/s13-notif-1c-warm-payday-review.png) |
| 14. VoiceOver spot check | Not run (blocked) | — |

AX3 repeats of the starred steps: not run (blocked).

### Step 13: Notifications

**Environment**
- Simulator: iPhone 17 Pro "Thaw-s13-qa-notif" (C8981E83-21F3-4212-9407-4A6222D5905B), iOS 26.0 (23A8464)
- Commit: `36136f7` (main, after the PR #25 merge), Debug build, bundle `com.tinkercademy.thaw`
- Notification permission: `xcrun simctl privacy … grant notifications` isn't supported ("Operation not permitted"), so it was granted by tapping **Allow** after onboarding (`-thawReset`) ([s13-notif-0-permission-prompt.png](s13/s13-notif-0-permission-prompt.png)).
- Method: `xcrun simctl push` with an `.apns` payload (`"category": "thaw.payday"`). A throwaway XCUITest, kept in a session copy outside the repo, waited for the banner in SpringBoard and tapped it. This is a real banner tap, not a simulated route call.
- Pending notifications: from the DEBUG log, `log stream --predicate 'subsystem == "app.thaw" AND category == "Notifications"'`.
- **Blocked:** after check 1 passed, permission to run more simulator QA (UI test runs, and `simctl launch`/push on this device) was denied. Checks 2 to 8 were therefore **not run**.

| Step | Result | Evidence | Pending before / after (debug log) |
|---|---|---|---|
| 1. Warm start: app open on Cooling (`-thawFixture thawed`, 3 ready payday wants). Push `thaw.payday`, tap the banner. | **Pass**: the Payday tab is selected (`Payday tab selected=true`) and "Payday review" is on top with 3 rows (Mechanical keyboard, Linen overshirt, Espresso grinder; "Done · keep 2"). | [s13-notif-1a-warm-cooling-before.png](s13/s13-notif-1a-warm-cooling-before.png), [s13-notif-1b-warm-banner.png](s13/s13-notif-1b-warm-banner.png), [s13-notif-1c-warm-payday-review.png](s13/s13-notif-1c-warm-payday-review.png) | 0 / 0 (`Pending after launch: 0 request(s)`. A fixture launch runs no refresh and a pushed notification isn't a pending request, so nothing was scheduled.) |
| 2. Cold start: app terminated, push, tap. | Not run (blocked) | – | – |
| 3. Empty queue (`-thawFixture history`): push, tap, expect "Nothing to review right now". | Not run (blocked) | – | – |
| 4a. Long-press the banner, then "Review now". | Not run (blocked) | – | – |
| 4b. Long-press the banner, then "Remind me tonight"; the reminder is still pending after a following Add. | Not run (blocked) | – | – |
| 5. Payday tab "Remind me tonight"; the reminder survives a following Add. | Not run (blocked) | – | – |
| 6. The payday notification's count matches the Payday tab badge and the review. | Not run (blocked). Partial: in check 1, the badge showed **3** (`1b`) and the review showed **3** rows (`1c`). No real payday request was pending to compare against (0 pending, see bug N1). | [s13-notif-1b-warm-banner.png](s13/s13-notif-1b-warm-banner.png), [s13-notif-1c-warm-payday-review.png](s13/s13-notif-1c-warm-payday-review.png) | 0 / 0 |
| 7. Change the payday in Settings: exactly one payday request pending, at the new date. | Not run (blocked) | – | – |
| 8. Timer-thaw tap with `wantID`: that want's "Still want it?"; a decided want opens Item detail (D7). | Not run (blocked) | – | – |

**Bugs / observations**
- **N1 (P2, owner `Thaw/App`): nothing reschedules notifications at launch or when the app comes to the foreground.**
  - `Reminders.refresh` only runs after a data change: Add, Edit, delete, review, Settings, or share-sheet ingest.
  - `AppDelegate` only logs the pending requests at launch, and `SceneDelegate.sceneWillEnterForeground` only ingests share drafts and refreshes the badge.
  - **Repro:** launch with `-thawFixture thawed` (3 payday wants ready). The debug log shows `Pending after launch: 0 request(s)` and nothing is scheduled until the user changes something.
  - **Real-world effect:** after a payday notification fires, the next payday's notification is only scheduled when the user next edits or decides something. Pending requests are also lost after a reinstall or restore, and nothing puts them back.
  - **Suggested fix:** call `refresh(requestingPermission: false)` at launch and on foreground.
  - Seen on the fixture launch and confirmed by reading the code; not checked over a real payday rollover.
- **Note (tooling):** `simctl privacy grant notifications` doesn't work on iOS 26.0 simulators, so permission has to be granted through the onboarding prompt.

**Not checked**
- Checks 2 to 8, blocked as above: cold start, empty queue, both banner actions, the Payday-tab reminder surviving an Add, the count against a real scheduled payday request, the Settings payday move, and D7 timer-thaw routing.
- The pending before/after for checks 4b, 5 and 7 (the reminder survives refresh; one payday request) still needs the debug log on a simulator. These are covered only by the V5 unit tests (`NotificationSchedulingTests`, `ReviewRouterTests`).
- A real scheduled payday or timer notification firing. Only `simctl push` payloads were used, so the request identifiers (`thaw.payday.review`, `thaw.timer.<uuid>`) were not exercised.

## Bugs

| # | Bug | Severity | Owner |
|---|---|---|---|
| N1 | Nothing reschedules notifications at launch or on foreground, so after a payday notification fires the next one isn't scheduled until the user changes something. Details under step 13. | P2 | `Thaw/App` |

Apart from N1, code reading turned up nothing. Most steps weren't checked by eye, so this isn't a clean result.

## What wasn't checked

- Every simulator step (1–12, 14) and notification checks 2–8, at the default size and at AX3, on iPhone and iPad.
- The screenshot sheet `docs/design/s13-screens.jpg`. `s11-screens.jpg` is kept until it exists.
- By eye only, with no test cover: the Cubi twinkle and drip fades (finding 6), the gap above Delete (finding 9), the share-sheet round trip, and the VoiceOver reading order.
- Side effect: the blocked run left Thaw uninstalled on the QA iPhone simulator (`1C8E32D3…`).
