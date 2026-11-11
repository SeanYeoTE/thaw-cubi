# Thaw UX audit: modality, dismissal and escape routes

> Archived. Kept for its modal rules (summarised in `docs/design/README.md`) and the fix history. UX-15 is fixed by the redesign (T5); UX-16 stays in the backlog. Line numbers below refer to older code.

## 1. Scope and method

Read-only heuristic audit of `Thaw/App/**`, `Thaw/Features/**`, `Thaw/DesignSystem/**` and `docs/contracts/*.md` (intended behaviour), judged against Apple HIG (Modality, Sheets, Navigation bars) and the app's own decisions (sprint-2 D5, sprint-3 D1/D2/D4). Static code reading only: nothing was built or run, so on-screen behaviour (animation timing, VoiceOver output) is inferred from code.

Modal inventory:

| Presenter | Presented screen | Style | Exit |
|---|---|---|---|
| `HomeViewController.swift:72-75` | `AddWantViewController` in nav | default (page sheet) | Cancel (`:24`), swipe-down |
| `HomeViewController.swift:77-81` | `PaydayNotificationViewController` | `.fullScreen` | "Remind me tonight" only |
| `PaydayNotificationViewController.swift:64-71` | `PaydayReviewViewController` in nav | `.fullScreen` | Close (`PaydayReviewViewController.swift:35`), CTA |
| `ReviewRouter.swift:25-30` | `PaydayReviewViewController` in nav | `.fullScreen` | Close, CTA |
| `ItemDetailViewController.swift:77-82` | `StillWantItViewController` in nav | `.fullScreen` | Close (`StillWantItViewController.swift:30`), finishing queue |
| `HomeViewController.swift:67-70` | `ItemDetailViewController` | push | Back |
| `MomentView.swift:37-54` | Moment overlay (Add, Skip x2) | in-view overlay, 1.2 s | none (auto) |
| `SceneDelegate.swift:27-36` | `PaydaySetupViewController` onboarding | window root, bar hidden | Save |

Severity is strict. **P1** means the user has no way out. None was found: every presented screen has at least one working exit (see UX-01 for the closest case). The trigger screen is P2, not P1.

## 2. Findings

| ID | Screen / file:line | Pattern | What happens today | User impact | Sev | Recommended fix |
|---|---|---|---|---|---|---|
| UX-01 | Payday notification preview, `PaydayNotificationViewController.swift:56-61`; presented `HomeViewController.swift:78-80` | Modal with no close affordance; fullScreen that should be a sheet | `.fullScreen`, no nav bar, no X, no swipe-down. The only exits are "Review now" and "Remind me tonight". Sprint-1 QA and the contract call it a "sheet". | User who tapped the payday card to peek must pick a labelled action to leave. Not a trap (the quiet button leaves) but it is a forced choice. VoiceOver escape scrub does nothing. | P2 | Drop `.fullScreen` at `HomeViewController.swift:79` (use default page sheet), wrap in `UINavigationController` with `navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })`, and add `accessibilityPerformEscape` returning dismiss + true. |
| UX-02 | `PaydayNotificationViewController.swift:58-59` | Button label does not match behaviour | "Remind me tonight" only calls `dismiss`. Sprint-3 D2 says it must schedule the reminder for 20:00 (or +1 h). The in-app button schedules nothing. | User believes a reminder is set; none comes. Can miss the payday review window. | P2 | Either call `reminders`/scheduler with `NotificationReminder.tonightDate(now:calendar:)` before dismissing, or relabel to "Not now" and add the real close from UX-01. |
| UX-03 | `PaydayNotificationViewController.swift:18-19,64-66`; `HomeViewController.swift:52,77` | Flow dead-end (empty review queue) | Payday card is always tappable. With an empty `reviewQueue` the preview reads "Payday. 0 wants have thawed." and "Review now" silently dismisses. | Misleading screen, button that does nothing visible. | P2 | In `paydayTapped` return early (or present an empty state with a single Close) when `store.reviewQueue.isEmpty`; disable `payday` control (`isEnabled = false`) when empty. |
| UX-04 | `ReviewRouter.swift:23-24` | Dead-end from notification tap | Tapping the notification (or "Review now" action) with an empty queue does `guard !wants.isEmpty else { return }`: app opens to Home, nothing explains why. | Feels like the tap failed (queue already decided from Item detail or another device clock). | P2 | When empty, show a one-line non-modal banner or a `UIAlertController` ("Nothing to review right now") with OK. |
| UX-05 | `PaydayReviewViewController.swift:143,147`; `StillWantItViewController.swift:113,120` | Dismissal tears down the wrong stack | All four call `view.window?.rootViewController?.dismiss`. That dismisses whatever the tab controller presented first and everything above it. Via preview -> review, Close/CTA skips the preview and lands on Home (arguably wanted, but accidental). It also silently depends on the screen being in a window and on root being the presenter. | Back from the review never returns to the screen that opened it; any future sheet presented from the root will be torn down with it. Fragile. | P2 | Use `dismiss(animated:)` on the nav (`navigationController?.dismiss`) for Close; for "finish whole flow" have the router/presenter hold a `onFinish` closure and call `presentingViewController?.dismiss`. Make the intended result (Home vs preview) explicit. |
| UX-06 | `AddWantViewController.swift:24,76-78,81-96`; sheet presented `HomeViewController.swift:74` | Sheet loses input silently | Page sheet with typed name/price/reason: swipe-down and Cancel both discard instantly. `isModalInPresentation` is never set. `ReviewRouter.swift:31-32` also dismisses an open Add sheet (animated: false) when a notification arrives. | Lost typing, notably the free-text "why" the app later reads back. | P2 | In Add: `isModalInPresentation = hasInput` (update from `textDidChange`) and implement `presentationControllerDidAttemptToDismiss` + Cancel to show an action sheet "Discard" / "Keep editing" when any field is non-empty. |
| UX-07 | `MomentView.swift:37-54`; callers `AddWantViewController.swift:93`, `ItemDetailViewController.swift:96`, `StillWantItViewController.swift:90` | Transient overlay blocks input, cannot be skipped | Fixed 1.2 s overlay, covers the view and swallows touches, no tap-to-skip, no Reduce Motion/VoiceOver adjustment. `screenChanged` focuses the Cubi line (`:48`) but the overlay is gone after 1.2 s, usually before VoiceOver finishes speaking "Cubi: ...". Content is also unstoppable for users who need more time. | Spoken line truncated for VoiceOver users; impatient users wait; AX timing guideline (WCAG 2.2.1) not met. | P2 | Add a tap `UITapGestureRecognizer` that completes immediately (guard double completion), and extend duration when `UIAccessibility.isVoiceOverRunning` (e.g. 3 s) or wait for `UIAccessibility.announcementDidFinishNotification`. |
| UX-08 | `ItemDetailViewController.swift:77-82`; `StillWantItViewController.swift:110-114` | Flow returns to a stale screen | "Decide now" presents StillWantIt for a single want. After Buy/Wait/Skip the modal dismisses and the user is back on Item detail for a want that no longer cools (`let want` snapshot, `:6`), still offering "Wait one more payday", "Skip it now". Only the Skip action pops the detail (`:98`). | Duplicate or conflicting decisions on an already decided want. | P2 | Pass a completion closure to StillWantIt that pops detail (`navigationController?.popViewController`) after dismiss, or re-fetch `store.want(id:)` in `viewWillAppear` and pop when it is no longer cooling. |
| UX-09 | `AddWantViewController.swift:27-60`; `ScrollStackViewController.swift:22` | No keyboard avoidance / dismiss | `scrollView` bottom is pinned to `view.bottom`, no `keyboardLayoutGuide`, no `keyboardDismissMode`. Decimal pad has no Done key. `errorLabel` (`:55-60`) is the last row. | Reason field and the validation error sit under the keyboard, especially in landscape and at large text: "Add to Thaw" appears to do nothing. | P2 | `scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)` in the base class, `scrollView.keyboardDismissMode = .interactive`, and `scrollRectToVisible(errorLabel.frame)` in `showError`. |
| UX-10 | `ScrollStackViewController.swift:19-27` | Landscape / notch safe area | `scrollView` and `stack` are pinned to `view.leadingAnchor/trailingAnchor` (not the safe area) with a 20 pt inset. `contentInsetAdjustmentBehavior` does not add horizontal insets. All screens, including the fullScreen modals, inherit this. | On notched iPhones in landscape, content and the Close button's neighbours run under the sensor housing / home indicator side; on iPad full-screen modals text and pill buttons stretch edge to edge. | P2 | Pin `stack` to `view.safeAreaLayoutGuide` horizontally and use `view.readableContentGuide` (or a max width of ~560 pt centred) for iPad. |
| UX-11 | `ReviewRouter.swift:28`; `PaydayNotificationViewController.swift:69`; `ItemDetailViewController.swift:80` | fullScreen modals that should be sheets | Review (multi-item task) and StillWantIt (single-want decision) are `.fullScreen`, Add is a sheet. HIG: fullScreen is for immersive content. Close is the only way out and swipe-down does nothing. | Inconsistent with Add; on iPad a full-bleed form. | P3 | Use `.pageSheet` for review and decide-now with `isModalInPresentation = true` (the CTA/Close are explicit exits) so a stray swipe cannot discard; keep fullScreen only for onboarding. |
| UX-12 | `PaydayReviewViewController.swift:35,146-148` | Close discards choices silently | Close dismisses with no confirmation; keep/wait toggles reset and the want stays in the queue. Nothing is saved, nothing lost permanently. | Minor: user re-does toggles. | P3 | If `keeping` differs from the default set, show a "Discard choices?" confirmation; otherwise leave as is. |
| UX-13 | All custom modals: `PaydayNotificationViewController`, `PaydayReviewViewController`, `StillWantItViewController`, `AddWantViewController`, `MomentView` | Missing VoiceOver escape | No `accessibilityPerformEscape` anywhere (grep). Review/StillWantIt/Add have a nav-bar Close/Cancel so VoiceOver users can still leave; preview and Moment have nothing. | VoiceOver two-finger scrub has no effect; relevant mainly to UX-01. | P3 | Override `accessibilityPerformEscape()` on the nav root VCs (call the same close action, return true); for `MomentView`, end early. |
| UX-14 | `ItemDetailViewController.swift:95-99`; `StillWantItViewController.swift:89-93` | Overlay hides nav bar, tab bar still visible | Moment hides the nav bar (back/close vanish) but the overlay is added to the controller's view, so on Item detail the tab bar remains tappable during the 1.2 s. The completion then pops the Cooling stack whichever tab is selected. In landscape and at AX5 the centred stack has no scroll and can clip. | Odd transitions; possible clipped line. | P3 | Present the moment from `tabBarController?.view` or set `hidesBottomBarWhenPushed = true` on Item detail; wrap `MomentView` stack in a scroll view or use `lessThanOrEqual` heights. |
| UX-15 | `PaydaySetupViewController.swift:99-102,235-248` | Unsaved edits in a tab | Settings tab: edits to payday/fun money are lost silently when switching tabs; only the Save button commits, no indication of pending changes. | Small risk of believing a change applied. | P3 | Add `hasChanges` state: enable Save only when dirty, or auto-save on tab change. |
| UX-16 | `ItemDetailViewController.swift:84-100` | Irreversible action without confirmation/feedback | "Wait one more payday" pops instantly with no confirmation or toast; "Skip it now" is a final decision (celebrated but not confirmable). | Accidental tap on a quiet, full-width button is not recoverable from the UI. | P3 | Add `UIAlertController` (destructive "Skip it now") for skip, and a short toast for wait. |
| UX-17 | `PaydayNotificationViewController.swift:21-45` | Fake system chrome | Screen mimics a notification banner ("Thaw · now") but is a full page; the "app icon" is a drawn stand-in. | Users may expect to be able to swipe it away like a banner (cf. UX-01). | P3 | Label it clearly ("Payday preview") in the title and rely on the standard sheet/close. |
| UX-18 | `SceneDelegate.swift:27-36`; `PaydaySetupViewController.swift:99-102` | Onboarding gate | Nav bar is hidden and Save is the only way forward. It is prefilled with defaults, so not a trap; there is no "skip, use defaults" or explanation of the permission prompt that follows Save. | Mild surprise at the notification prompt. | P3 | Add a footnote above Save: "We'll ask to send payday reminders next." |

Totals: **P1: 0, P2: 10, P3: 8.**

## 3. Recommended modal rules

1. **Every modal has a visible exit.** Task sheets: leading `Cancel` (text) when input would be lost, `Close` (X, `.close` system item) when only viewing or when decisions are already saved. Never both styles for the same kind of screen.
2. **Sheet by default, fullScreen only for onboarding or immersive content.** Add, Review, Decide-now and the payday preview are page sheets inside a `UINavigationController`.
3. **Guard unsaved input.** If a sheet holds user input, set `isModalInPresentation = true` while dirty and show a Discard/Keep editing action sheet from Cancel and `presentationControllerDidAttemptToDismiss`. Otherwise allow swipe-down freely.
4. **Dismiss exactly what you presented.** Use `dismiss`/`pop` on the nearest controller (or a closure from the presenter). Do not use `view.window?.rootViewController?.dismiss`. If a flow must tear down a stack, the presenter owns that decision.
5. **Labels say what happens.** Buttons describe their effect ("Remind me tonight" must schedule it; otherwise "Not now").
6. **No dead ends.** Entry points check preconditions (empty review queue) before presenting; completed flows return to a screen that reflects the new state.
7. **Transient overlays are skippable and timed for accessibility.** Tap to skip, longer for VoiceOver/AX text sizes, never block the only exit; honour Reduce Motion.
8. **Accessibility.** Custom modals implement `accessibilityPerformEscape`; close controls are system bar items (44 pt, scale with Dynamic Type) or have a 44 x 44 minimum area; content scrolls at AX5.
9. **Layout.** Pin to safe area horizontally, cap content to the readable width on iPad, handle the keyboard with `keyboardLayoutGuide`, and verify portrait and landscape.

## 4. Not a problem (checked)

- Review (`PaydayReviewViewController.swift:35`) and StillWantIt (`:30`) use the system `.close` item: 44 pt, Dynamic Type safe, VoiceOver-labelled. Add uses `.cancel` (`AddWantViewController.swift:24`); X for view-only and Cancel for input matches HIG.
- Add sheet: Cancel and Add are disabled after save (`:91-92`), a repeat dismiss from the Moment completion is a harmless no-op, validation messages are present.
- Moment auto-completes in all three call sites and cannot hang; completions are not retained strongly (`[weak self]`).
- `PillButton` (`Components.swift:72`), `KeepToggleButton` (`:282`), `ChoiceRowView` (`:236`), `StepperSettingRow` (`:39`) and the Home "+" (`HomeViewController.swift:25-26`) meet 44 pt; titles wrap at AX sizes.
- Payday card and rows switch to vertical stacks at accessibility sizes (`PaydayCardView.updateAxis`, `AdaptiveStackView`).
- Item detail is a push with a standard back button and swipe-back; Saved and Settings are tabs.
- `ReviewRouter` holds a pending route until tabs exist (cold launch, onboarding) and dismisses a presented controller before presenting, as sprint-3 D1 specifies.
- Onboarding Save is always enabled with defaults and requires no hidden choice, so it is not a trap.
- iPad/landscape orientation keys: none are declared in `project.yml` (device family is 1,2 in the project). The claim that all orientations are supported could not be verified from source.

## 5. Triage (decided by PM)

Rule: fix every P2, plus P3s that touch the same files or are one-line changes. Defer the rest with a reason.

| ID | Decision | Owner | Notes |
|---|---|---|---|
| UX-01 | Fix now | Frontend | Page sheet in a nav controller with a `.close` item; `accessibilityPerformEscape`. This is the screen that triggered the audit. |
| UX-02 | Fix now | Frontend | "Remind me tonight" schedules via `NotificationReminder.tonightDate` before dismissing (matches sprint-3 D2). |
| UX-03 | Fix now | Frontend | Payday card disabled (and dimmed) when the review queue is empty; preview never opens empty. |
| UX-04 | Fix now | Frontend | Empty-queue notification tap shows a short "Nothing to review right now" alert with OK. |
| UX-05 | Fix now | Frontend | Dismiss exactly what you present; no `view.window?.rootViewController?.dismiss`. Closing review from the preview returns to the preview's presenter (Home). |
| UX-06 | Fix now | Frontend | `isModalInPresentation` while dirty, Discard / Keep editing sheet from Cancel and swipe-down attempt. |
| UX-07 | Fix now | Frontend | `MomentView`: tap to skip; longer duration when VoiceOver is running; guard double completion. |
| UX-08 | Fix now | Frontend | After Decide now, Item detail pops (or re-checks the want) instead of showing a stale screen. |
| UX-09 | Fix now | Designer | `ScrollStackViewController`: `keyboardLayoutGuide`, interactive keyboard dismiss. Frontend adds `scrollRectToVisible` for the error label. |
| UX-10 | Fix now | Designer | `ScrollStackViewController`: pin horizontally to the safe area and cap content to the readable width on iPad. |
| UX-11 | Fix now | Frontend | Review and Decide-now become page sheets with `isModalInPresentation = true`; onboarding stays full screen. |
| UX-12 | Fix now | Frontend | Discard confirmation when Close would drop changed Keep/Wait choices. |
| UX-13 | Fix now | Frontend | `accessibilityPerformEscape` on the custom modals. |
| UX-14 | Fix now | Frontend | `hidesBottomBarWhenPushed` on Item detail so the tab bar can't be tapped under the moment overlay. |
| UX-15 | Backlog | | Settings dirty-state. Low risk; needs a product decision (auto-save vs. enable Save when dirty). |
| UX-16 | Backlog | | Skip confirmation / Wait toast. Needs a product decision; the celebration already gives feedback. |
| UX-17 | Fix now | Frontend | Title the preview "Payday preview". |
| UX-18 | Fix now | Frontend | One-line footnote above Save about the reminder permission prompt. |

Orientation note: the audit could not see orientation keys because they are not on this branch; they are in PR #4.

## 6. Fix status

Implemented in `[ux-ds-scroll]` (4e268d6, 8480afb) and `[ux-fe-modals]` / `[ux-fe-scroll]` (1645fd3, ce3bf16). Clean build exit 0, 24 unit tests pass, greps for `print`/`NSLog`/`rootViewController?.dismiss` clean.

| ID | Status | Evidence |
|---|---|---|
| UX-01 | Fixed | Checked on simulator: page sheet "Payday preview" with a close (X); X returns to Home. |
| UX-02, 03, 04, 07, 08, 09 (keyboard / scroll-to-field), 13 | Fixed in code | Not exercised on a simulator: reminder scheduling, empty-queue alert, Moment tap-skip and VoiceOver timing, Decide-now pop, keyboard scrolling, VoiceOver escape. |
| UX-05, 06, 11, 12 | Fixed | Frontend checked on a simulator: preview to review as sheets, review Close shows "Discard choices?", Wait on all dismisses both sheets to Home, Add Cancel with input shows Discard. |
| UX-10 | Fixed | Onboarding and Home render full width on iPhone portrait (a first version collapsed the column; fixed in 8480afb). Landscape and iPad not checked. |
| UX-14 | Fixed | Checked: the tab bar is hidden on Item detail. Moment at AX5 not checked. |
| UX-17, 18 | Fixed | Title "Payday preview"; onboarding footnote "We'll ask to send payday reminders next." visible. |
| UX-15 | Fixed | T5 (770dd42): Settings saves each change as you go; no Save button. |
| UX-16 | Backlog | Needs a product decision. |

Also added: Home and Item detail refresh through a `.thawDataChanged` notification after a review or Decide now.
