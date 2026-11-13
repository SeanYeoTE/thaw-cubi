# Thaw design handover (s13: review fixes)

s12 shipped in SeanYeoTE/thaw-cubi#19, with Cubi changes in #20 and #21. A review on 12 Nov 2026 found a crash, a decision that can be applied twice, budget figures that disagree between screens, and 11 failing accessibility audits. A follow-up read of the notification code found that "Remind me tonight" is wiped by the next refresh, and that the different notification paths count different wants. s13 fixes those. It adds no new features.

## Review results that set the scope

Full suite run on `main` at `8c5c8cf`, iPhone 17 Pro simulator:
- **Unit tests:** 233, all pass.
- **UI tests:** 23 run, 12 fail:
  - all 11 accessibility audits;
  - `ReviewFlowUITests.testReviewCloseWithChangesAsksBeforeDiscarding`.

| # | Finding | Severity | Task | Status (V4) |
|---|---|---|---|---|
| 1 | Crash: double-tap Buy or Wait on the last want in "Still want it?" | Must fix | V1 | Fixed in code: actions disabled while a decision runs (`StillWantItPresenter.beginDecision`); `PresenterStillWantItTests.testTappingAgainAfterLastWantIsDecidedDoesNothing`, `testWaitTwiceOnLastWantWaitsOnce`. Not checked on the simulator (V4 blocked) |
| 2 | Double-tapping Done in the Payday review applies decisions twice; a Wait want moves two paydays | Must fix | V1 | Fixed in code: `applied` guard in `PaydayReviewPresenter`; `IntegrationReviewTests.testReviewAppliesEachChoiceOnceEvenWhenDoneIsTappedTwice`, `testDoneTwiceAppliesOnce`. Not checked on the simulator |
| 3 | The Payday tab and the review disagree on the budget (quick thaws, cut-off rule, ordering) | Must fix | V1 | Fixed in code: one rule, `FunMoneyPlan`, used by the Payday tab, the review, "Still want it?" and `Reminders`; `PresenterPaydayTests.testPaydayTabAndReviewAgreeOnLeftWithAQuickThaw`. Figures not compared on the simulator |
| 4 | Accessibility audit: 123× "Dynamic Type font sizes are partially unsupported", 1× text clipped (Payday review), 2× potentially inaccessible text (Stats) | Must fix | V2 (fonts, Stats, tests), V1 (clipped review text) | Fixed: all 11 audits pass on `36136f7` (23 UI tests, 0 failures) |
| 5 | UI test queries the review discard dialog as an alert; it is an action sheet | Must fix | V2 | Fixed: `testReviewCloseWithChangesAsksBeforeDiscarding` passes on `36136f7` |
| 6 | Cubi idle loops make opacity fades additive, so the star twinkle and drip fade never show | Must fix | V3 | Fixed in code: idle fades use absolute opacity; `CubiMotionTests.testIdleFadesUseAbsoluteOpacity`. Not seen by eye |
| 7 | Drawn large title sits 20 pt inside the cards on iPad and wide screens (Cooling, Stats) | Should fix | V3 | Fixed in code: `ThawColumnTests.testTitleLinesUpWithPlainSections`, `testTitleLinesUpWithInsetGroupedCards`. Not seen on iPad |
| 8 | Reopening a decided want in Edit shows no thaw line, so it can return as already thawed without warning | Should fix | V3 | Fixed in code: "Back to cooling · …" line; `PresenterAddWantTests.testReopening*`. Not seen by eye |
| 9 | The gap above Delete in the Edit sheet is likely lost (spacing attached to a hidden label) | Should fix | V3 | Fixed in code: `deleteGap` spacer in `AddWantViewController`. Not seen by eye |
| 10 | After Let go in "Still want it?", other tabs refresh only after the Cubi moment ends | Should fix | V1 | Fixed in code: `publishChange()` before the Cubi moment; `testLetGoShowsMomentThenAdvancesAndSpendsNothing`. Not seen on the simulator |
| 11 | No s12 QA report, and D1–D3 weren't recorded | Process | This README, V4 | Partly fixed: D1–D3 recorded above. The s13 report, [sprint-13-report.md](../qa/sprint-13-report.md), exists, but the simulator pass was blocked, so this stays open |
| 12 | "Remind me tonight" is wiped by the next `Reminders.refresh`, because `cancelAll()` removes every pending notification and the reminder is never rescheduled | Must fix | V5 | Fixed in code: refresh removes only the requests it owns; `NotificationSchedulingTests`. The survival check on the simulator was blocked (V4 step 13.4–13.5) |
| 13 | The payday notification, the Payday tab's "Remind me tonight" and the notification's own "Remind me tonight" action count different wants | Must fix | V5 | Fixed in code: one `Reminders.paydaySummary()` built on `FunMoneyPlan`; `NotificationSchedulingTests`. Warm start showed badge 3 and review 3 rows; no real payday request was compared (V4 step 13.6) |
| 14 | Notifications have been barely tested since sprint 3: no test of what gets scheduled or where a tap goes. The s11 change (a tap opens the Payday tab) has never been checked on a device. The notification handler also captures fun money once at launch. | Must fix | V5 | Partly fixed: scheduling and routing are unit-tested (`NotificationSchedulingTests`, `ReviewRouterTests`), and the warm-start tap opens the Payday review on the simulator. Fun money is read at run time. Cold start, actions and the timer-thaw route weren't checked (V4 blocked). New: N1, nothing reschedules at launch or on foreground |

## Tasks

| ID | Doc | Owns (only edit these) | Wave |
|---|---|---|---|
| V1 | [Review and budget correctness](tasks/V1-review-budget-correctness.md) | `Thaw/Features/Payday`, `Thaw/Features/PaydayReview`, `Thaw/Features/StillWantIt`, `Thaw/Models` (budget maths only), their presenter tests, a new `ThawTests/Integration*Review*Tests.swift` | 1 |
| V2 | [Dynamic Type and UI tests](tasks/V2-dynamic-type-ui-tests.md) | `Thaw/DesignSystem/Theme.swift`, `Thaw/Features/Saved`, `ThawUITests`, `docs/screenshots` | 1, then a rerun in 2 |
| V3 | [Cubi, title and Edit sheet polish](tasks/V3-polish.md) | `Thaw/DesignSystem/CubiMotion.swift`, `Thaw/DesignSystem/CubiView.swift`, `ThawTests/CubiMotionTests.swift`, `Thaw/DesignSystem/ThawListScreen.swift`, `ThawTests/ThawColumnTests.swift`, `Thaw/Features/AddWant`, `ThawTests/PresenterAddWantTests.swift` | 1 |
| V5 | [Notifications](tasks/V5-notifications.md) | `Thaw/App`, `Thaw/Services/NotificationScheduler.swift`, `ThawTests/BackendNotificationTests.swift`, new `ThawTests/NotificationSchedulingTests.swift` and `ThawTests/ReviewRouterTests.swift` | 1 (step 4 count rule in 2, after V1) |
| V4 | [s13 QA pass and report](tasks/V4-qa-report.md) | `docs/qa`, `docs/design/s11-screens.jpg` (replaced by `s13-screens.jpg`), the findings table in this README | 2 |

**Waves:**
- **Wave 1, in parallel:** V1, V2, V3 and V5. No file is owned by more than one task.
- **Wave 2, after wave 1 is merged:**
  - V5 switches its notification counts to V1's single budget rule.
  - V2 reruns the full UI and audit suite against the merged result. V2's font change can move layouts on V1's and V3's screens.
  - V4 does the QA pass, including notifications.

**Setup:**
- Base branch: `docs/s13-fixes` (`main` plus these docs).
- Each agent works in its own git worktree on `feature/s13-<task>`, for example `feature/s13-v1-review`. Commit prefix: `[s13]`.
- Open PRs against `main`.

**Out of scope:** if you need a file outside your list, don't edit it. Write it in your report. `project.yml` belongs to the user.

## Product decisions

**Already made in s12** (built as recommended in #19, and now recorded here):
- **D1:** the batch Payday review offers Keep · Wait · Let go.
- **D2:** the Payday tab is about the budget decision. Quick thaws sit in their own section and are left out of the payday total.
- **D3:** Item detail has two actions, **Let go · save S$X** (with confirmation) and **Decide now**. The standalone Wait button was removed.

**Decided for s13** (13 Nov 2026, the recommendations, all reversible):

| # | Question | Decision | Task |
|---|---|---|---|
| D4 | Do ready quick thaws count against fun money in the Payday review and in "Still want it?"? | **No, to match D2.** Show them in the review as their own group. Their choices still apply, but they don't move the meter or the Keep defaults. | V1 |
| D5 | When a want overflows the budget, do later, cheaper wants still "fit"? | **Yes, best fit in thaw order:** walk wants by `thawsAt`, keep any that still fit, wait the rest. Use the same rule for the Payday tab's Fits / Over split and the review's defaults. | V1 |
| D6 | The Stats header became a dark hero card with a larger Cubi (from #20, not briefed). Keep it? | **Keep**, provided every text colour on the card meets 4.5:1 and the audit passes. Otherwise go back to the light header. | V2 |
| D7 | Where should tapping a quick-thaw ("timer") notification go? Today it opens the whole review. | **That want's "Still want it?" screen**, or Item detail if it's already decided. | V5 |
| D8 | Should the payday notification set an app icon badge? | **No.** The in-app Payday tab badge is enough. | V5 |

**Process for s13:** wave-1 agents build and run unit tests only. UI tests, audits, screenshots and simulator checks run once, on the merged result (wave 2). Agents don't commit `Thaw.xcodeproj`; it's regenerated with `xcodegen` after the merge.

## Working rules (unchanged)

- **VIPER**, as in `docs/contracts/sprint-4-viper.md`:
  - the view controller only does UIKit;
  - the presenter imports Foundation only and holds all copy and logic;
  - the interactor wraps `WantStore` and `Reminders`;
  - the router wires the module and navigates.
- Add an explicit `deinit {}` on MainActor classes that hold weak references.
- **Live updates:** every mutation is followed by `DataChange.post()` and `reminders.refresh(requestingPermission: false)`.
- **Modals:**
  - Use page sheets.
  - Every sheet has a close button and supports `accessibilityPerformEscape`.
  - Sheets holding unsaved input set `isModalInPresentation` and confirm before discarding.
  - Dismiss only what you presented.
- **Layout:** a 700 pt column, `Theme.Spacing.screen` margins plus safe area. List screens use `ThawListViewController` for their drawn title and column. Light mode only.
- **Colour:**
  - `Theme.controlBorder` for interactive edges (3:1).
  - `Theme.timer` for quick-thaw tone on light backgrounds.
  - `Theme.border` only for decorative edges.
  - Never use colour as the only cue.
- **Accessibility:**
  - Dynamic Type everywhere.
  - Stacked layouts at accessibility sizes.
  - Touch targets of at least 44 pt.
  - Full sentences for VoiceOver.
  - Anything reachable by swipe is also reachable by tap.
- **Copy:**
  - one line per row;
  - numbers over sentences;
  - at most one Cubi line per screen;
  - no explainer paragraphs.
- **Every action that changes data must be safe to tap twice.** Guard with a flag or by disabling the control until the screen leaves. This is new in s13, from findings 1 and 2.

## Build and check

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Thaw.xcodeproj -scheme Thaw -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath .build/dd-<task> test
```

- **Unit tests only:** add `-only-testing:ThawTests`.
- **UI tests only:** add `-only-testing:ThawUITests`. The full UI suite takes about 16 minutes.
- **Fixtures:**
  - `-thawReset`: empty app, starts in onboarding.
  - `-thawFixture sprint1`: four cooling wants.
  - `-thawFixture history`: decided wants.
  - `-thawFixture thawed`: three ready wants (S$189, S$69, S$420 against S$300 fun money).
- **Simulator taps can lag by one action.** Confirm each tap with a screenshot.

**Report, at the end of each task:**
- build and test results, with failure output;
- before and after screenshots at the default size and at AX3;
- what you didn't check;
- identifiers you changed;
- files outside your list that need changes.

## History

- [archive/s12-README.md](archive/s12-README.md) and [archive/s12-tasks/](archive/s12-tasks/): s12, done.
- [archive/s11-README.md](archive/s11-README.md) and [archive/s11-tasks/](archive/s11-tasks/): s11, done.
- [archive/ux-audit.md](archive/ux-audit.md): the earlier modality audit.
- [s11-screens.jpg](s11-screens.jpg): screenshots from the end of s11. V4 replaces it with `s13-screens.jpg`.
