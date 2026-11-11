# T4: Cooling

Read [../README.md](../README.md) first for the working rules.

**Owns:** `Thaw/Features/Home`, `Thaw/Features/PaydayPreview` (you delete it), `ThawTests/PresenterHomeTests.swift`.
**Depends on:** T2 merged (`FilterChipBar`, `SectionHeaderView`, `EmptyStateView`, leaner `WantRowModel`). Step 5 waits for T3 to be merged.

## Problem
- The payday card dominates the screen and sits at 50% opacity most of the month.
- Each row carries a status sentence ("7-day timer · 18 Nov") as well as the days left.
- No way to narrow or reorder the list.
- The empty state is a single grey sentence.

## Goal
Cooling is **just the list**: fast to scan, filterable and sortable. Deciding happens on the Payday tab (T3).

## Layout, top to bottom
1. Title "Cooling" (drawn in the list as today) with the accent **+** in the nav bar (keep `home.add`).
2. **Sort** button in the nav bar, to the left of +: `arrow.up.arrow.down` opening a `UIMenu` with:
   - **Thaws soonest** (default)
   - **Price: high to low**
   - **Recently added**
   - **Name**

   The current choice shows a checkmark.
3. **`FilterChipBar`**: **All · Payday · Quick thaw**.
   - Payday: `price >= timerThreshold`.
   - Quick thaw: `price < timerThreshold`, the same rule `HomePresenter.card` uses for `isTimer` today.
4. The list.
   - With **Thaws soonest**, split it into `SectionHeaderView` sections:
     - **"This payday"**: `thawsAt <= nextPayday`. Trailing detail: section total, for example "S$258".
     - **"Later"**: everything else.
   - Other sorts: one flat list, no headers.

## Rows (lean `WantRowModel`)
- Leading symbol: `timer` for quick thaws, `calendar` for payday wants.
- Title, price, and trailing days left ("Today", "1 day", "5 days"). **No status line.**
- Keep the progress strip (`timer` tone for quick thaws, `accent` for payday).
- VoiceOver keeps the full detail. Label "Mechanical keyboard, S$189". Value "Thaws on payday, 25 November, 14 days".
- Swipe Edit/Delete, tap to Item detail, and the delete confirmation all stay as they are.

## Empty states (`EmptyStateView`)
- **No wants:** Cubi `.frozen`, "Nothing cooling.", button **"Add a want"** → the same route as +.
- **Filter matches nothing:** no Cubi, one line ("No quick thaws cooling.") and a quiet "Show all" button that resets the filter.

## Remember choices
- Filter and sort survive relaunch. The interactor stores them in `UserDefaults` (keys `cooling.filter`, `cooling.sort`). The presenter reads them through the interactor protocol; it stays Foundation-only with no defaults access of its own.
- Use `String` raw-value enums for both, and fall back to the defaults when a stored value is unknown.

## Step 5: remove the payday card (after T3 is merged)
- Remove the `.payday` item, `tapPayday`, `HomeViewModel.daysLeft/nextPaydayText/paydaySubtitle/hasReview`, `HomeRouter.showPaydayPreview`, and the card tests.
- Delete the `Thaw/Features/PaydayPreview` module. Confirm with `grep -rn PaydayPreview Thaw ThawTests` that nothing else refers to it (T3 moved "Remind me tonight" to the Payday tab).
- Don't delete `PaydayCardView` from `Components.swift` (T2 owns it). Report whether anything still uses it, so it can be removed later.

## Presenter shape (suggested)
```swift
enum CoolingFilter: String, CaseIterable { case all, payday, quickThaw }
enum CoolingSort: String, CaseIterable { case soonest, priceHigh, recent, name }

struct HomeSectionViewModel: Equatable {
    let title: String?        // nil = no header
    let trailing: String?
    let cards: [HomeCardViewModel]
}
// HomeViewModel gains: filterTitles, filterIndex, sortOptions (title, isSelected), sections, empty (EmptyKind?)

protocol HomePresenterProtocol { …; func selectFilter(at: Int); func selectSort(_: CoolingSort); func tapShowAll() }
```
Keep sorting, filtering and sectioning in the presenter so they're unit-tested.

## Tests (`PresenterHomeTests.swift`)
- Each filter keeps the right wants (threshold edge: price exactly equal to `timerThreshold` counts as Payday).
- Each sort orders correctly. Ties are broken by name, then id, so the order is stable.
- Soonest gives "This payday" / "Later" sections with correct totals; other sorts give one untitled section.
- No wants → empty kind `.noWants`; filter with no matches → `.noMatches`; `tapShowAll` resets to All.
- Filter and sort are read from and written to the interactor.
- Existing edit, delete and route tests still pass. After step 5, drop the payday-card tests.

## Simulator check
- `-thawFixture sprint1`: each filter, each sort, swipe, tap, empty state (`-thawReset`, then finish onboarding), and relaunch keeps the choices.
- Screenshots at the default size and at AX3.

## Done when
- Cooling shows title, filter chips, sort menu and lean rows.
- The payday card and `PaydayPreview` are gone, after T3.
- Tests and build pass.
