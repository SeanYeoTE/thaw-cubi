# V5: Notifications

Read [../README.md](../README.md) first for the working rules and build command.

**Owns:**
- `Thaw/App` (`AppDelegate`, `SceneDelegate`, `ReviewRouter`, `Reminders`, `RootTabBarController`);
- `Thaw/Services/NotificationScheduler.swift`;
- `ThawTests/BackendNotificationTests.swift`;
- new `ThawTests/NotificationSchedulingTests.swift` and `ThawTests/ReviewRouterTests.swift`.

**Wave:** 1, with step 4 in wave 2, after V1 merges.

Review findings 12, 13 and 14.

## Why
Notifications are how the app brings you back at payday, and they've barely been tested since sprint 3:
- The only unit tests are three checks of the "Remind me tonight" time maths.
- No test checks what `Reminders.refresh` schedules, or where a tapped notification goes.
- Since s11, a tap should open the **Payday tab** with the review, not Cooling. Nobody has checked that on a device.

Reading the code while planning also turned up three definite bugs (steps 1 to 3).

## 1. "Remind me tonight" is wiped by the next refresh (must fix)
- `Reminders.refresh` (`Thaw/App/Reminders.swift`) calls `scheduler.cancelAll()`.
- That runs `removeAllPendingNotificationRequests()` (`NotificationScheduler.swift`, `cancelAll`), and refresh then reschedules only the payday review and timer thaws.
- The tonight reminder (`ThawNotification.reminderIdentifier`) is removed and never put back.
- `refresh` runs after almost every change (Add, Edit, review, Settings autosave, delete, launch). Scenario: tap "Remind me tonight", then add a want, and no reminder comes.

**Fix:**
- `cancelAll` is replaced by removing only the identifiers that refresh owns: the payday identifier and the timer prefix.
- Or the reminder is stored, with its date, and rescheduled by refresh while it's still in the future and the queue isn't empty.
- If the queue becomes empty, the reminder should be removed.

**Test:** with a fake scheduler, call `remindTonight`, then `refresh`. The reminder is still scheduled. Empty the queue and refresh, and it's gone.

## 2. Three different counts for the same payday (must fix)

| Path | What it counts |
|---|---|
| `Reminders.refresh`, the payday notification | cooling wants with `price >= timerThreshold && thawsAt <= nextPayday` (payday wants only) |
| `Reminders.remindTonight`, the Payday tab button | `store.reviewQueue` |
| `NotificationActionHandler`, the notification's own "Remind me tonight" action | `store.thawedWants`, which includes quick thaws |

The same reminder can therefore say "3 wants have thawed" from one path and "4" from another.

**Fix:**
- All three use one function in `Reminders` that returns the count and total.
- In wave 2 that function switches to V1's single budget rule (`FunMoneyPlan`, see V1 step 3). That way the notification, the Payday tab badge and the review agree.
- Until V1 merges, use `reviewQueue` filtered to payday wants, which matches D2.

**Test:** the same store gives the same count and total from all three paths.

## 3. Stale fun money in notification text (must fix)
- `AppDelegate` builds `NotificationActionHandler` with `UserNotificationScheduler(funMoney: store.effectiveSettings.funMoney)` **once at launch**.
- After fun money changes in Settings, the action's "Remind me tonight" text quotes the old amount (`ThawNotification.paydayBody`).

**Fix:** the handler reads fun money when it runs, from `store.effectiveSettings` or through `Reminders`. Don't capture it at launch.

**Test:** change the settings after the handler is created; the scheduled text uses the new amount.

## 4. Routing and timer thaws
**Tap routing** (`ReviewRouter.requestReview`):
- default tap and the "Review now" action select the **Payday** tab (`RootTabBarController.Tab`), pop to root, and present the review;
- cold launch holds the request until the tabs exist (after onboarding as well);
- an empty queue shows "Nothing to review right now".

Write unit tests where the logic can be pulled out without UIKit: route decisions and the pending-until-ready flag. Cover the rest on the simulator.

**Timer-thaw notifications** have no category, so a tap opens the whole review. **Confirm with the user (D7):**
- **Recommendation:** a tap opens that want's **"Still want it?"**, using its id from the notification identifier `timerPrefix + uuid`, or Item detail if it's already decided.
- **Alternative:** a tap opens the Payday tab.

If the user picks the recommendation, add `userInfo` with the want id and a route case. The presentation code lives in `Thaw/Features/StillWantIt` (owned by V1), so call its existing `createModule`; don't edit it.

**Permission:** asked at the first Add or the end of onboarding only, never by Settings or a refresh. The rule is already there (`requestingPermission`); add a test that refresh never asks.

**App icon badge:** check whether the payday notification should set `content.badge` to the ready count. Nothing sets it today. Recommendation: don't add an icon badge, because the in-app Payday tab badge is enough. Note the decision in the report.

## 5. Simulator checks
Use `xcrun simctl push` with an `.apns` payload that has `"aps": {"category": "thaw.payday", …}`. The sprint-3 approach is in `docs/qa/sprint-3-report.md` (TC-S3-1).
1. **Warm start:** the app is open on Cooling; push and tap the banner. The Payday tab opens with the review.
2. **Cold start:** quit the app, push, and tap. The app opens on Payday with the review.
3. **Empty queue:** push with nothing ready. You get the alert.
4. **Banner actions:**
   - long-press, then "Review now";
   - long-press, then "Remind me tonight": the reminder is scheduled (check with `simctl` or a debug log) and survives a following Add (step 1).
5. **Payday tab "Remind me tonight":** the same survival check.
6. **Timer thaw:** freeze a cheap want, wait for or fake the trigger, then tap. The result depends on D7.
7. **Settings:** change the payday. The pending payday notification moves; check that there is exactly one.

## Done when
- Steps 1 to 3 are fixed, with tests.
- Routing is tested and checked on the simulator: warm, cold, empty and actions.
- D7 is decided and implemented.
- The report lists pending notifications before and after each check (from a debug log or `getPendingNotificationRequests`).
- Tests and build pass.
