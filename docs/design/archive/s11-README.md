# Thaw redesign: handover

> **Done.** The s11 handover index, kept for history. Current handover: `docs/design/README.md`.

Make the main screens simpler and less wordy, move the payday review into its own tab, add filters and sort, and fix how Stats dates decisions. The work is split into six task docs. Each one is written so a single agent can pick it up cold.

Base branch: `feature/s11-ui-standardise`. Commit prefix: `[s11]`.

## Target structure

| Tab | Job | Module |
|---|---|---|
| **Cooling** | The list: add, edit, delete, filter, sort | `Thaw/Features/Home` |
| **Payday** *(new)* | Decide: countdown, budget, what's ready, review | `Thaw/Features/Payday` |
| **Stats** | Results: total saved, streak, chart, history | `Thaw/Features/Saved` |
| **Settings** | Rules: payday, budget, quick thaws, reminders | `Thaw/Features/PaydaySetup` |

The payday card and Cubi move from Cooling to the Payday tab. The Payday tab icon shows a badge with the number of wants ready to review, so you no longer have to tap the payday card to find the review. The `PaydayPreview` sheet goes away.

## Tasks

| ID | Doc | Owns (only edit these) | Depends on |
|---|---|---|---|
| T1 | [Decision date](s11-tasks/T1-data-decided-on.md) | `Thaw/Models`, `Thaw/Services`, `ThawTests/Backend*` | none |
| T2 | [Shared components](s11-tasks/T2-shared-components.md) | `Thaw/DesignSystem`, `Thaw/Features/Shared` | none |
| T3 | [Payday tab](s11-tasks/T3-payday-tab.md) | `Thaw/Features/Payday` (new), `Thaw/App`, `ThawTests/PresenterPayday*` (new, not `PaydayReview`/`PaydaySetup`) | T2 merged (uses `SectionHeaderView`) |
| T4 | [Cooling](s11-tasks/T4-cooling.md) | `Thaw/Features/Home`, `Thaw/Features/PaydayPreview` (deletes it), `ThawTests/PresenterHomeTests.swift` | T2 merged; T3 merged before its last step |
| T5 | [Settings](s11-tasks/T5-settings.md) | `Thaw/Features/PaydaySetup`, `ThawTests/PresenterPaydaySetupTests.swift` | none |
| T6 | [Stats](s11-tasks/T6-stats.md) | `Thaw/Features/Saved`, `ThawTests/PresenterSavedTests.swift`, `ThawTests/IntegrationSavedTests.swift` | T1 and T2 merged |

**Order:**
- **Wave 1, in parallel:** T1, T2 and T5.
- **Wave 2, after T2:** T3 and T4. T4 does everything except removing the payday card, then removes the card once T3 is merged.
- **Wave 3, after T1:** T6.

Need a file outside your list? Don't edit it. Note it in your report so the owner, or the person merging, can make the change. `project.yml` belongs to the user; folders are synchronised, so new files under `Thaw/` are picked up after `xcodegen generate`.

## Working rules

- **Branches:** each agent works in its own git worktree on a branch cut from `feature/s11-ui-standardise`, named `feature/s11-<task>`, for example `feature/s11-t4-cooling`. Use explicit pathspecs with `git add`, never `git add -A`.
- **VIPER**, as in `docs/contracts/sprint-4-viper.md`:
  - the view controller only does UIKit;
  - the presenter imports Foundation only and holds all copy and logic;
  - the interactor wraps `WantStore` and `Reminders`;
  - the router wires the module and navigates.
- Add an explicit `deinit {}` on MainActor classes that hold weak references (the synthesized one corrupts the heap in the test host).
- **Live updates:** interactors observe `DataChange` (`Thaw/Features/Shared/DataChange.swift`) and forward it to the presenter. Every mutation is followed by `DataChange.post()` and `reminders.refresh(requestingPermission: false)`.
- **Modals** (rules carried over from [the archived UX audit](ux-audit.md)):
  - Use page sheets, not `.fullScreen`, except for onboarding.
  - Every sheet has a close button and supports `accessibilityPerformEscape`.
  - A sheet holding unsaved input sets `isModalInPresentation` and asks before discarding.
  - Dismiss only what you presented; never call `rootViewController?.dismiss`.
- **Layout:** content column capped at 700 pt and centred, with a side margin of `Theme.Spacing.screen` and safe-area insets. This matches `ScrollStackViewController` and the existing list screens. Light mode only.
- **Accessibility:**
  - Dynamic Type everywhere (`ThawFont`, `adjustsFontForContentSizeCategory`).
  - Rows that lay out horizontally switch to vertical at accessibility sizes.
  - Touch targets are at least 44 pt.
  - When text is removed from the screen, the full sentence still goes into `accessibilityLabel`/`accessibilityValue`.
  - Swipe actions are also exposed as custom accessibility actions.

## Copy rules: less text

The main complaint is too much text. Apply these on every screen:

1. **One idea per line, one line per row.** A want row shows name, price and one visual (progress strip, ring or icon). No status sentences.
2. **Section headers carry shared context.** If every row in a section thaws "this payday", say it once in the header, not on each row.
3. **Numbers over sentences.** "14 days", "S$1,240", "3 ready". Captions are 1 to 3 words.
4. **Cubi says at most one short line per screen**, and only when it adds something. The mood can carry the message without words.
5. **No repeated advice.** "Decide at payday…" style hints appear once, in empty states.
6. **Visible text can be terse; VoiceOver text is complete.** Keep the full spoken sentences that presenters already produce.

## Build and check

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Thaw.xcodeproj -scheme Thaw -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath .build/dd-<task> test
```

- **Launch arguments** for checking on the simulator:
  - `-thawReset`: empty app, starts in onboarding.
  - `-thawFixture sprint1`: four cooling wants.
  - `-thawFixture history`: five decided wants.
  - A DEBUG first launch seeds both sets.
- **Report**, at the end of each task:
  - build and test result, including the failure output if anything failed;
  - simulator screenshots of the changed screens at the default text size and at AX3;
  - what you did not check;
  - any file outside your list that needs a change.

## Background

- [archive/ux-audit.md](ux-audit.md): the earlier modality and dismissal audit. Mostly fixed; UX-15 (Settings changes lost silently) is fixed by T5 and UX-16 stays in the backlog.
- Contracts for earlier sprints: `docs/contracts/`. QA reports: `docs/qa/`.
