# Sprint 5: Goals (DRAFT, awaiting approval, no code written)

## Product rules (from user)
- Fun money = monthly amount set aside from salary for wants. Unchanged, separate from goals.
- A goal is for a want that exceeds one month's fun money. Optional: thaw/review work with zero goals.
- Goals have a target and an optional deadline.
- Skipping a want adds its price to a pending pool for the month. Wants can be added any time, so the pool is only **consolidated at month end**.
- Goal contributions only ever come from fun money (wants tracking only, not general savings).
- Completed goal -> **archived** (not reset/restarted).
- Deadline passed and unmet -> **extended** automatically (no nag).

## Assumptions to confirm
1. Month-end contribution = skipped total for the month, capped at unspent fun money (monthly fun money minus bought/kept wants). Never exceeds what was actually left.
2. Month boundary = payday cycle (same as the review cycle) rather than calendar month.
3. With several active goals the pool fills the earliest-deadline goal first, then the next. With none, the pool carries over.
4. Extension adds one payday cycle per missed deadline.

## Model (Models/, backend-owned, nonisolated, Codable)
- `Goal`: id, name, target, saved, deadline?, createdOn, status (.active/.archived), archivedOn?.
- `PendingContribution`: amount, date, wantId.
- `GoalLedger` (pure logic): `consolidate(pending, funMoney, bought, goals, now) -> (goals, carryOver)`, `extendOverdue(goals, now, cycle)`, `archiveCompleted`.
- Persisted via the existing store JSON (backward compatible: missing keys decode to empty).

## Services
- `WantStore`: records a pending contribution on skip; runs consolidation on launch and when a cycle ends; exposes active/archived goals.
- Goals CRUD on the store; notifications unchanged.

## UI (VIPER modules per docs/contracts/sprint-4-viper.md)
- `Goals` module on the Saved tab: active goal cards (progress, deadline), archived section, add/edit/delete via modal sheet (X to close, Discard guard per ux-audit).
- Review summary may show "S$X goes toward <goal> at month end". No change to Keep/Wait.
- Empty state: invites adding a goal, never blocks anything.

## Ownership
Backend: Models, Services, tests. Designer: goal card + progress component in DesignSystem. Frontend: Goals module and Saved wiring.

## Tests
`GoalLedger` unit tests (cap at unspent, ordering, extension, archive, no-goals carry over), persistence migration test, presenter tests with fakes.

## Done when
Clean build exit 0, all tests pass, simulator QA report `docs/qa/sprint-5-report.md`, PR opened (not merged without approval).
