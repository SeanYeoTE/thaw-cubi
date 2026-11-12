# T1: Decision date (`decidedOn`)

> **Done.** Shipped on `feature/s11-ui-standardise` (SeanYeoTE/thaw-cubi#18). Kept for history; the code is the source of truth now.

Read [../../README.md](../../README.md) first for the working rules.

**Owns:** `Thaw/Models`, `Thaw/Services`, `ThawTests/Backend*`, plus the new `ThawTests/BackendDecisionDateTests.swift` if you prefer a separate file.
**Depends on:** nothing. **Unblocks:** T6 (Stats).

## Problem

`Want` stores when it was frozen (`frozenOn`) and when it thaws (`thawsAt`), but not when it was decided. Stats uses a different stand-in in each place:

| Where | Uses today | Wrong when |
|---|---|---|
| Stats history date and sort (`SavedPresenter.refresh`) | `frozenOn` | Always: it shows when the want was added, not when it was decided |
| Monthly chart (`SavedPresenter.monthlySaved`) | `frozenOn` | Frozen in March, skipped in May: counted as March |
| Streak (`ProgressStats.make`) | `thawsAt` | "Skip it now" from Item detail before `thawsAt`: counted in a future month |

## Change

### Model (`Thaw/Models/Want.swift`)
- Add `var decidedOn: Date?` as the last stored property, plus `decidedOn: Date? = nil` as the last initializer parameter. Existing call sites must compile unchanged.
- Add:
  ```swift
  /// When the want was skipped or bought. Data saved before `decidedOn` existed falls back to the payday it thawed on.
  var decisionDate: Date { decidedOn ?? thawsAt }
  ```
- No migration code is needed. Swift's built-in `Decodable` reads a missing optional key as `nil`, so old saves keep loading. A test must prove this (below).

### Store (`Thaw/Services/WantStore.swift`)
All status changes go through one private helper:
```swift
private func setStatus(at index: Int, to status: Want.Status, now: Date) {
    let wasDecided = wants[index].status != .cooling
    wants[index].status = status
    switch status {
    case .cooling: wants[index].decidedOn = nil
    case .skipped, .bought: if !wasDecided { wants[index].decidedOn = now }
    }
}
```
| Function | Status change | `decidedOn` |
|---|---|---|
| `decide(id:keep: true, now:)` | → bought | set to `now` |
| `decide(id:keep: false, now:)` | stays cooling (Wait) | unchanged (`nil`) |
| `update(_:status:now:)` | add a `now: Date = .now` parameter | set on skip/bought, cleared on cooling |
| `reopen(_:)` | → cooling | cleared |
| `setDecision(_:to:)` | skipped ↔ bought | **kept** (a correction, not a new decision) |

- `fixtureHistory`: set `decidedOn` to the same value as `thawsAt` so demo data stays realistic.
- `edit` never touches `decidedOn`.

### Stats model (`Thaw/Models/ProgressStats.swift`)
- The streak groups skipped wants by the month of `decisionDate`, not `thawsAt`. Update the doc comment.

### Not in scope
- `SavedPresenter` (history sort and date, chart grouping) belongs to T6. Leave it; T6 switches it to `decisionDate`.

## Decision taken
A skip made on the 1st for a payday on the 30th counts in the new month. Accepted: "when you decided" is simple to explain and only matters at month edges. Don't add a separate "payday decided on" field.

## Tests
In `ThawTests/BackendPersistenceTests.swift` / `BackendProgressStatsTests.swift` or a new file:
- **Old data:** decoding a JSON want with no `decidedOn` key works; `decidedOn == nil` and `decisionDate == thawsAt`.
- **Survives reload:** skip with a fixed `now`, reload with a new `WantStore(fileURL:)`, and `decidedOn` equals that `now`.
- **Paths:**
  - `decide(keep: true)` sets the date.
  - `decide(keep: false)` leaves it `nil`.
  - `update(status: .skipped, now:)` sets it.
  - `reopen` clears it.
  - `setDecision` keeps the original date.
- **Streak:** a want frozen 3 months ago and skipped this month (`decidedOn = now`, `thawsAt` in the future) gives `streak == 1`.
- All existing backend tests still pass.

## Done when
- Build and all tests pass.
- Nothing outside the owned folders changed.
- Report lists the new public API (`decidedOn`, `decisionDate`, `update(_:status:now:)`) for T6.
