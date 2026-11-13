# Thaw design handover (s12)

> **Done.** The s12 handover index, shipped in #19. Current handover: `docs/design/README.md`.

The s11 redesign is finished: four tabs (Cooling · Payday · Stats · Settings), shared components and accessibility fixes, all in SeanYeoTE/thaw-cubi#18. [s11-screens.jpg](../s11-screens.jpg) shows where the app is now.

s12 finishes the job. It brings the remaining screens into the same style, makes the Payday tab about the budget decision, gets the review flow working end to end, and adds the testing s11 skipped. Six task docs follow; each can be handed to one agent cold.

## Before anyone starts

1. **Already done:** #18 is merged into `main` (11 Nov 2026). `main` also has the UI test target and `-thawFixture thawed` from #17.
2. **Base branch: `docs/s12-handover`.** It is `main` plus these handover docs. Every agent branches from it, in its own git worktree, named `feature/s12-<task>` (for example `feature/s12-u3-item-detail`). Commit prefix: `[s12]`.
3. **Merging:** each task opens its PR against `main`. Whoever merges first brings the docs along; the rest are unaffected, because the docs are their only shared change.

## Tasks

| ID | Doc | Owns (only edit these) | Wave |
|---|---|---|---|
| U1 | [Payday tab: the budget decision](s12-tasks/U1-payday-budget.md) | `Thaw/Features/Payday`, `Thaw/App`, `ThawTests/PresenterPaydayTests.swift` | 1 |
| U2 | [Review flow](s12-tasks/U2-review-flow.md) | `Thaw/Features/PaydayReview`, `Thaw/Features/StillWantIt`, their presenter tests, `Thaw/Features/Shared/WantStore+Review.swift` | 1 |
| U3 | [Item detail](s12-tasks/U3-item-detail.md) | `Thaw/Features/ItemDetail`, `ThawTests/PresenterItemDetailTests.swift` | 1 |
| U4 | [Add and Edit sheet](s12-tasks/U4-add-edit-sheet.md) | `Thaw/Features/AddWant`, `ThawTests/PresenterAddWantTests.swift`, `ThawTests/IntegrationEditTests.swift` | 1 |
| U5 | [UI tests and accessibility audit](s12-tasks/U5-ui-tests-a11y.md) | `ThawUITests`, `docs/screenshots` | 1, then again in 2 |
| U6 | [Shared list foundation and polish](s12-tasks/U6-list-foundation.md) | `Thaw/DesignSystem`, `Thaw/Features/Shared` (except U2's file), `Thaw/Features/Home`, `Thaw/Features/Saved`, `Thaw/Features/PaydaySetup` | 2 |

**Waves:**
- **Wave 1, all in parallel:** U1, U2, U3, U4, and U5 phase 1. None of them share files.
- **Wave 2, after wave 1 is merged:** U6, and U5 phase 2 (rerun everything and extend the audit to the new screens).

**If you need a file outside your list,** don't edit it. Write it in your report so the owner, or whoever merges, can make the change.

**`project.yml` belongs to the user.** Folders are synchronised, so new files under `Thaw/` are picked up after `xcodegen generate`.

**New shared components:** in wave 1, build any new reusable view inside your own feature folder. U6 moves the ones worth sharing into `Thaw/DesignSystem`, which stops four agents editing `Components.swift` at once.

**Accessibility identifiers:** keep the existing `accessibilityIdentifier`s working, because U5's UI tests rely on them. If you rename or remove one, list it in your report. Give new controls identifiers in the form `<screen>.<thing>`, for example `detail.wait` or `review.keep`.

## Product decisions to confirm with the user

These change behaviour, so each owner confirms with the user before building. The task docs give my recommendation.

| # | Question | Recommendation | Task |
|---|---|---|---|
| D1 | The batch Payday review only offers **Keep** or **Wait**. Skipping (which is how you save money) happens only from a want's own page. Should the review offer **Let go** too? | Yes. Each review row gets Keep · Wait · Let go. | U2 |
| D2 | What is the Payday tab for, most of the month? | The budget decision: how much is spoken for, how far over, and which wants push you over. It stops repeating Cooling's list. | U1 |
| D3 | Item detail has three actions (Wait one more payday, Decide now, Skip it now). | Two clear actions: **Let go** (saves the money) and **Decide now**. "Wait one more payday" moves into the decision screen. | U3 |

## Working rules (unchanged from s11)

- **VIPER**, as in `docs/contracts/sprint-4-viper.md`:
  - the view controller only does UIKit;
  - the presenter imports Foundation only and holds all copy and logic;
  - the interactor wraps `WantStore` and `Reminders`;
  - the router wires the module and navigates.
- Add an explicit `deinit {}` on MainActor classes that hold weak references.
- **Live updates:** interactors observe `DataChange`. Every mutation is followed by `DataChange.post()` and `reminders.refresh(requestingPermission: false)`.
- **Modals:**
  - Use page sheets, except for onboarding.
  - Every sheet has a close button and supports `accessibilityPerformEscape`.
  - Sheets holding unsaved input set `isModalInPresentation` and ask before discarding.
  - Dismiss only what you presented.
- **Layout:** a 700 pt content column, `Theme.Spacing.screen` margins plus safe area. Light mode only.
  - List screens draw their own large title, because the system one stays blank over a collection view until the first scroll. See `HomeViewController` and `SettingsViewController`.
- **Colour:**
  - `Theme.controlBorder` for the edges of interactive controls (3:1).
  - `Theme.timer` for quick-thaw tone on light backgrounds.
  - `Theme.border` only for decorative edges.
  - Never use colour as the only cue.
- **Accessibility:**
  - Dynamic Type everywhere.
  - Horizontal rows switch to stacked layouts at accessibility sizes.
  - Touch targets are at least 44 pt.
  - Visible text can be terse, but VoiceOver gets the full sentence.
  - Anything reachable by swipe is also reachable by tap.

## Copy rules

1. One idea per line, one line per row. No status sentences on rows.
2. Section headers carry shared context; don't repeat it on every row.
3. Numbers over sentences: "14 days", "S$1,240", "3 ready". Captions are 1 to 3 words.
4. Cubi says at most one short line per screen, and only when it adds something.
5. No repeated advice. Hints appear once, in empty states.
6. Explainer paragraphs under forms are a smell. If a rule needs explaining, show it in place, for example "Thaws on payday · 25 Nov" next to the price.

## Build and check

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Thaw.xcodeproj -scheme Thaw -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath .build/dd-<task> test
```

**Launch arguments:**
- `-thawReset`: empty app, starts in onboarding.
- `-thawFixture sprint1`: four cooling wants.
- `-thawFixture history`: five decided wants.
- `-thawFixture thawed`: three wants ready to review. Use this for U1 and U2.
- A DEBUG first launch seeds both cooling and history.

**Simulator taps can lag by one action.** Take a screenshot after each tap to confirm it landed before tapping again. If the same lag happens on a real device, report it as a bug.

**Your report must include:**
- build and test results, with any failure output;
- before and after screenshots at the default text size and at AX3;
- what you did not check;
- identifiers you changed;
- files outside your list that need changes.

## Known gaps not in s12

- **Dark mode and Increase Contrast:** the app forces light mode ([SceneDelegate.swift](../../../Thaw/App/SceneDelegate.swift)), and the theme colours are fixed values. Worth its own sprint.
- **UX-16** (no confirmation before Skip, no toast after Wait): partly covered by D3 in U3. Recheck after.

## History

- [archive/s11-README.md](s11-README.md) and [archive/s11-tasks/](s11-tasks/): the s11 handover, done.
- [archive/ux-audit.md](ux-audit.md): the earlier modality audit.
- Contracts: `docs/contracts/`. QA reports: `docs/qa/`.
