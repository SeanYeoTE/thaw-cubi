# Sprint 3 contract (frozen once agents start)

Branch `feature/s3-polish` from `main` (sprints 1 and 2 merged). Goal: close the sprint 2 P3 list.
Same ground rules as sprint 2 (`docs/contracts/sprint-2.md`): Swift 6 / MainActor default (pure logic `nonisolated`), Decimal money, `os.Logger`, no `print`/`NSLog`/debug hooks, clean build with exit code checked, explicit-pathspec commits `[task-id] summary` + Co-authored-by trailer, `git pull --rebase` on rejected push. XcodeGen: new files need `xcodegen generate`; the owner of a new file regenerates and commits `Thaw.xcodeproj/project.pbxproj` ONLY if the file list changed (do not commit pure churn such as `explicitFileType` diffs).

## Decisions
| # | Decision |
|---|---|
| D1 | Tapping the payday notification (default action) or its "Review now" action opens the Payday review. Works from cold launch and while running. |
| D2 | "Remind me tonight" schedules the same payday notification again at 20:00 today, or +1 hour if it is already past 20:00; it does not open the app. |
| D3 | Cubi gets a Frost variant (white body, `Theme` Snow/Frost-friendly stroke) for use on Frost (`#D9EEF5`) backgrounds. Default unchanged. |
| D4 | Every screen is usable at AX5: no clipped or truncated primary text, controls keep a 44pt minimum hit area, content scrolls. |
| D5 | Out of scope: share sheet extension, Identity wordmark screen. |

## Backend (owns `Thaw/Models/**`, `Thaw/Services/**`, `ThawTests/Backend*Tests.swift`) — task `s3-be-actions`
```swift
nonisolated enum NotificationRoute: Equatable, Sendable { case review }
extension PaydaySettings { /* none */ }
enum NotificationReminder { nonisolated static func tonightDate(now: Date, calendar: Calendar) -> Date }  // D2
protocol NotificationScheduling { /* existing + */ func scheduleReminder(at: Date, thawingCount: Int, total: Decimal) async }
final class NotificationActionHandler: NSObject, UNUserNotificationCenterDelegate {
    init(scheduler: NotificationScheduling, store: WantStore, onRoute: @escaping @MainActor @Sendable (NotificationRoute) -> Void)
    // didReceive: default action and "Review now" -> onRoute(.review); "Remind me tonight" -> scheduleReminder(at: tonightDate, ...)
    // willPresent: show banner + sound while the app is in the foreground
}
```
Use the existing category/action identifiers in `NotificationScheduler.swift`. Tests: `tonightDate` before 20:00, after 20:00, at midnight, DST-agnostic via fixed calendar/time zone.

## Designer (owns `Thaw/DesignSystem/**`, `Thaw/Assets.xcassets/**`, `docs/design/**`) — tasks `s3-ds-frost`, `s3-ds-a11y`
- `CubiView.init(mood:size:onFrost:)` with `onFrost: Bool = false` (existing inits unchanged); also `setOnFrost(_:)`.
- Audit `Components.swift` and friends for AX5: fixed heights become `minHeight`, `KeepToggleButton`/`ChoiceRowView`/`SettingsRowView`/`PillButton` grow with text, 44pt minimum hit area, labels `numberOfLines = 0`.
- Verify the Reduce Motion path in `CubiView` really cross-fades (read the code; add a unit-free fix if it does not) and that `spokenLine` is exposed as "Cubi: <line>" with decorative layers hidden from accessibility.

## Frontend (owns `Thaw/App/**`, `Thaw/Features/**`, `ThawTests/ThawTests.swift`) — tasks `s3-fe-route`, `s3-fe-ax5`
- Task `s3-fe-route` (after `[s3-be-actions]` lands; poll `git log --oneline -F --grep "[s3-be-actions]"` every 60 s): create the `NotificationActionHandler` in `AppDelegate`/`SceneDelegate` and set it as `UNUserNotificationCenter.current().delegate` before launch finishes (strong reference held). `onRoute(.review)` presents `PaydayReviewViewController` modally from the root, dismissing any presented sheet first; it must also work on cold launch (queue the route until the root view controller exists). Hide nothing behind launch args.
- Task `s3-fe-ax5`: AX5 sweep of Item detail, Add, Saved, Settings (and Home, review, onboarding regression). Fix clipping/truncation in `Thaw/Features/**`; anything in DesignSystem goes in your report to the PM, not an edit. Verify on iPhone 17 `90A40A3B-774D-4B44-97E2-C2AE34286430` only, then reset content size to `large`.
- Use `CubiView(... onFrost: true)` wherever Cubi sits on a Frost background after `[s3-ds-frost]` lands.

## Test cases (PM)
| ID | Case |
|---|---|
| TC-S3-1 | `simctl push` with the payday category; tapping the banner opens Payday review (running and cold launch). |
| TC-S3-2 | "Remind me tonight" schedules a request for tonight (verified via unit tests + pending request log). |
| TC-S3-3 | AX5 on Item detail, Add, Saved, Settings, Home, review, onboarding: no clipped text, scrolls. |
| TC-S3-4 | Reduce Motion on: Cubi cross-fades, no movement. |
| TC-S3-5 | Clean build exit 0, all unit tests pass, greps clean. |
