# T6: Stats

Read [../README.md](../README.md) first for the working rules.

**Owns:** `Thaw/Features/Saved`, `ThawTests/PresenterSavedTests.swift`, `ThawTests/IntegrationSavedTests.swift`.
**Depends on:** T1 merged (`Want.decisionDate`) and T2 merged (`StatChipView`, `FilterChipBar`, `SectionHeaderView`, `EmptyStateView`, leaner `WantRowModel`).

## Problem
- **The headline number is missing.** `SavedPresenter` computes `savedText` (total saved) and the view never shows it.
- **Too much small text.** Cubi sits beside three stats, each with a caption ("paydays in a row", "months of fun money", "let go · 3 of 5"): nine bits of text competing.
- **Repeated advice.** Cubi's line, the empty text and the spoken streak all say "decide at payday…" in slightly different words.
- **The chart skips empty months**, so the bars look evenly spaced when they aren't. It's grouped by freeze month (fixed by T1 plus this task).
- **History** shows a full date and "Skipped"/"Bought" on every row, sorted by freeze date.

## Layout, top to bottom
1. **Title** "Stats" (drawn in the list as today).
2. **Hero:** Cubi (mood as today: frozen / proud / snoozing, about 72 pt) beside **"S$1,240"** (`ThawFont.display`, large) with "saved" under it in `inkSecondary`.
   - **No Cubi line on screen.** Keep it as Cubi's `spokenLine` for VoiceOver.
3. **Stat chips** (`StatChipView`, one row, wrapping at accessibility sizes):
   - `flame.fill` **3**: streak.
   - **60%**: let go.
   - **1.4 mo**: fun money saved. Below one month, show a percentage: "40%" with symbol `banknote`.

   Tapping a chip shows its full sentence (the existing `spoken` text) in a small popover or an alert with OK. VoiceOver reads the sentence directly.
4. **Chart** (Swift Charts, as today), no "Saved per month" label above it:
   - **Fill empty months with 0** between the first decision and now.
   - Current month in `Theme.accent`, other months in `Theme.accent` at about 35% opacity.
   - Range picker above the chart: **6M · 1Y · All** (segmented `FilterChipBar` or `UISegmentedControl`). Default 6M. Hide the picker when there's under 6 months of data.
   - Tap or drag on a bar to show "Oct · S$320" (`chartXSelection`).
   - Show the chart once there are 2 or more months in the range, as today.
5. **History**:
   - `FilterChipBar`: **All · Let go · Bought**.
   - Sections by **decision month** (`SectionHeaderView`), newest first: title "November 2026" (drop the year for the current year), trailing "S$320 saved", counting skipped wants only. Omit the trailing text if nothing was saved that month.
   - Lean rows: `leadingSymbol` `xmark.circle` with the accent tone for let go, `checkmark.circle` with the neutral tone for bought. Then title and price. **No status text, no date.**
   - VoiceOver value keeps the outcome and full date: "Let go, decided 3 November 2026".
   - Swipe Edit/Delete and the delete confirmation stay as they are.

## Data (uses T1)
- Replace every `frozenOn` in `SavedPresenter` with `want.decisionDate`: history sort, history grouping, `monthlySaved`.
- `ProgressStats` is already switched to `decisionDate` by T1.

## Copy
- Empty, nothing decided yet: `EmptyStateView`, Cubi `.frozen`, "Your savings show up here after payday." No button. This is the **only** place the "after payday" advice appears.
- **Delete** these strings: the "Brr. Decide on a few wants…" line, "A fresh start. Let one go…", the separate `emptyText`, and the "Saved per month" and "History" labels.
- Chip spoken text: keep the existing full sentences.

## Remember choices
- History filter and chart range survive relaunch: interactor-backed `UserDefaults` keys `stats.historyFilter` and `stats.chartRange`, with the same pattern as T4.

## Tests
`PresenterSavedTests.swift`:
- The hero shows the total saved (the `savedText` bug is fixed).
- Chips: streak, percentage, and the months-or-percentage switch at 1.0.
- `monthlySaved` fills gaps with zero; the range limits the months shown; the current month is flagged.
- History is grouped by decision month, newest first, and section totals count only skipped wants.
- A want frozen in March and decided in May is in May's section and May's bar.
- Filters All / Let go / Bought.
- Empty state when nothing is decided.

`IntegrationSavedTests.swift`: update the expected strings; the skip, reopen and buy flows still re-render correctly.

## Simulator check
- `-thawFixture history` and the DEBUG first-launch seed: hero, chips (tap one), chart (tap a bar, switch range), filters, sections, swipe Edit/Delete.
- `-thawReset`: empty state.
- Screenshots at the default size and at AX3.

## Done when
- Stats leads with the total, has one chip row, a gap-free chart with a range picker, and filterable month-grouped history.
- Every visible date is the decision date.
- Tests and build pass.
