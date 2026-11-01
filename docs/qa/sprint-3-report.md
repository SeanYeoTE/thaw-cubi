# Sprint 3 QA report

Contract: `docs/contracts/sprint-3.md`. Clean build exit 0; 24 unit tests, 0 failures; no `print`/`NSLog`/debug-hook hits.

| Case | Result |
|---|---|
| TC-S3-1 notification tap opens Payday review (running and cold launch) | Verified by the frontend agent on iPhone 17 using `simctl push` (category `thaw.payday`). The cold-launch screenshot matched the running case, so a stale capture can't be fully ruled out. The PM re-run on the QA simulator could not catch the banner in time (screenshots are slow here), so this is **not independently confirmed**. |
| TC-S3-2 "Remind me tonight" | Unit-tested date logic only (`tonightDate`: before 20:00, at 20:00, after 20:00, 23:30, midnight). The action itself was not exercised on a simulator. |
| TC-S3-3 AX5 sweep | Frontend checked Home, Item detail, Settings, Saved, review, onboarding and the payday sheet: no clipping, all scroll. Add screen's lower fields not checked. |
| TC-S3-4 Reduce Motion | Code read only: `CubiView` cross-fades and skips motion animations. Not run with the setting on. |
| TC-S3-5 build, tests, greps | Pass |

## Changes
- `NotificationActionHandler` (default tap and "Review now" route to review; "Remind me tonight" reschedules at 20:00, or +1 h after 20:00; foreground banners shown).
- `ReviewRouter` presents the review from the tab root and queues it until the root exists.
- `CubiView(onFrost:)` variant (no screen uses it yet).
- `PillButton` and `KeepToggleButton` wrap and keep a 44pt hit area; settings steppers get a 44pt row.

## Known issues
- P3: "Remind me tonight" `PillButton` wraps at about half width at AX5 (readable).
- P3: Add screen name/price fields are single line and truncate long input at AX5.
- P3: tapping the notification when nothing has thawed opens nothing.
- Not built: share sheet capture, Identity wordmark screen (out of scope, D5).
