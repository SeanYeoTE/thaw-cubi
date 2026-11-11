# T5: Settings

> **Done.** Shipped on `feature/s11-ui-standardise` (SeanYeoTE/thaw-cubi#18). Kept for history; the code is the source of truth now.

Read [../../README.md](../../README.md) first for the working rules.

**Owns:** `Thaw/Features/PaydaySetup` (including `StepperSettingRow.swift`), `ThawTests/PresenterPaydaySetupTests.swift`.
**Depends on:** nothing. It can run in wave 1.

## Problem
- **Two titles.** The nav bar says "Settings" and the page heading says "When's payday?", which is onboarding copy left on the tab.
- **The four payday-rule options are big rows** and take most of the screen.
- **Every setting uses a stepper.** Review time goes up 30 minutes per tap through 24 hours, and fun money goes up S$50 per tap to S$5,000.
- **Everything is in one flat card**: payday rule, review time, budget and timer rules.
- **Changes only stick after tapping Save.** Switching tabs loses them silently (UX-15). The button reads "Save · next payday 25 Nov" even with nothing changed.

## Goal
**Onboarding and the Settings tab become two different screens:**
- Onboarding stays a focused one-question flow.
- The tab becomes a native-feeling grouped settings list that **saves as you change it**.

## Settings tab (not onboarding)
Use `UICollectionView` with `UICollectionLayoutListConfiguration(appearance: .insetGrouped)`, `UIListContentConfiguration` cells and `Theme.background` behind it.
- Large title "Settings" through the normal nav bar. No "When's payday?" heading.
- 700 pt column cap as on other screens (the inset-grouped layout already insets; just cap the width on iPad).

| Section | Row | Control |
|---|---|---|
| **Payday** | Payday · "Same date · 25th" | Pushes the Payday rule screen (below) |
| | Next payday · "25 Nov" | Read-only secondary text |
| **Budget** | Fun money · "S$300" | Inline right-aligned text field, decimal pad, "S$" prefix, Done toolbar. Range 0–100,000; clamp and round to whole dollars |
| **Quick thaws** *(footer: "Cheaper wants use a timer instead of waiting for payday.")* | Under · "S$50" | Inline amount field as above, 0–10,000 |
| | Timer · "3 days" | `UIStepper`, 1–14 (keep `StepperSettingRow`) |
| **Reminders** | Payday review at | `UIDatePicker` `.time`, `.compact`, `minuteInterval = 15` |
| **footer** | "Entered by you, kept on this phone. Thaw never reads your bank." | Section footer text |

**Payday rule screen** (pushed, same module):
- Section 1: four rows with a checkmark on the selected one: Same date every month · Last working day · Twice a month · No fixed payday. One-line secondary text where it helps ("Moves around weekends").
- Section 2 shows only for rules that need a number: day of month (1–31), first payday (1–28) or wait length (1–60 days). Use a wheel `UIPickerView` in a cell, or a compact menu.
- Section 3: "Next payday · 25 Nov", updating live.
- Changes save immediately; Back simply returns.

**Saving:**
- Every change saves straight away. No Save button on the tab.
- Debounce field edits: save on end-editing, not per keystroke.
- On the tab, call `reminders.refresh(requestingPermission: false)`. The permission prompt stays an onboarding and first-Add thing; see the interactor below.
- Light haptic on save. No toast.
- `DataChange.post()` after saving, so Cooling, Payday and Stats update (for example a changed payday moves the countdown).

## Onboarding (`router.isOnboarding == true`)
Keep it as a full-page flow with the nav bar hidden. Trim it:
- Heading "When's payday?" and one subtitle line (keep).
- The four choice rows (keep `ChoiceRowView`) plus the day stepper for the chosen rule.
- **Remove** fun money, timer threshold, timer length and review time from onboarding. They take their defaults (`PaydaySettings.default`) and can be changed later in Settings.
- Footnote "We'll ask to send payday reminders next." (keep, from UX-18) and a primary button **"Continue · next payday 25 Nov"**.
- Continue saves with `requestingPermission: true`, then `finishOnboarding()`, as today.

## Suggested structure
- Pull the payday-rule state and copy (`Kind`, `choiceCopy`, `detail()`, `ordinal`, the next-payday text) out of `PaydaySetupPresenter` into a Foundation helper in the same folder (for example `PaydayRuleModel`), so both screens share it.
- `PaydaySetupRouter.createModule` returns the onboarding VC when `onSaved != nil`, otherwise the new `SettingsViewController` with its own presenter (`SettingsPresenter`), and the rule screen as a pushed VC from the same router.
- Interactor: `save(_ settings: PaydaySettings, requestingPermission: Bool)` (the onboarding presenter passes `true`, Settings passes `false`), plus `DataChange.post()`.
- Presenters stay Foundation-only. Time is passed as minutes since midnight; the view converts to and from `Date` for the picker.

## Tests (`PresenterPaydaySetupTests.swift`)
- **Settings:**
  - each change saves once with the right value;
  - the fun money text "abc" or a negative value doesn't save and keeps the old value;
  - values above the cap are clamped;
  - time minutes map to hour and minute.
- **Rule screen:**
  - selecting a rule saves it;
  - the day section shows only for rules that need it;
  - the next-payday text updates.
- **Onboarding:**
  - only the rule and day are shown;
  - Continue saves with permission requested and finishes;
  - the other settings stay at their defaults.
- **Unchanged:** `ordinal` and `timeText` behaviour.

## Simulator check
- `-thawReset`: onboarding → Continue → the app opens.
- Settings tab: change each row, switch tabs and come back, and the values are kept. Relaunch, and they're still kept. The Cooling and Payday countdowns reflect a changed payday.
- Screenshots of onboarding, Settings and the rule screen at the default size and at AX3.

## Done when
- The tab has no Save button and changes persist immediately. This closes UX-15 in `../ux-audit.md`.
- Onboarding is the trimmed one-question flow.
- Tests and build pass.
