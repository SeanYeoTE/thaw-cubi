# Sprint 5: Goals (FROZEN)

Design source: `docs/design/goals/thaw-goals-mockups.html` (all screens + engineering notes) and `docs/design/goals/HANDOFF-design-status.md` (sample scenario, rules). Match the mockups using existing components. Architecture: VIPER modules per `docs/contracts/sprint-4-viper.md`.

## Product rules
- Fun money (monthly, S$300 default) is unchanged. Goals are optional and never block thawing or review.
- A goal: name, target, optional deadline. Target must be **greater than one month of fun money**.
- **Monthly pool = prices of wants skipped that month + fun money left unspent** (unspent = fun money minus bought that month, floored at 0). It lands at **calendar month end**.
- Fill order: deadline ascending, no-deadline last (oldest first). Overflow flows to the next goal. If all goals are full, the remainder stays in Kept (no goal).
- Live "S$X pending" pool line on Saved: skipped so far this month + current unspent. Hidden when there are no active goals.
- Deadline passed and goal unmet: silently extend by one payday cycle (`PaydaySettings.nextPayday` after the old deadline), "Extended" tag, History row, no notification.
- Completed goal: celebration screen, then archived (not reset). "Later" leaves it at 100% on Saved until archived.
- Empty state "Not now" hides the goal invite for 30 days.

## Backend (owns Models, Services, ThawTests/Backend*): FROZEN API
All types `nonisolated`, Codable, Sendable. New JSON keys must decode when absent (old saves keep loading).

```swift
struct Goal: Identifiable, Codable, Equatable, Sendable {
    enum Status: String, Codable, Sendable { case active, completed, archived }
    let id: UUID
    var name: String
    var target: Decimal
    var saved: Decimal
    var deadline: Date?
    let createdOn: Date
    var status: Status
    var completedOn: Date?
    var history: [GoalEvent]
    var isFunded: Bool { saved >= target }
    var progress: Double          // 0...1
    var isExtended: Bool          // any .extended event
}
struct GoalEvent: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case contribution, extended, completed }
    var date: Date; var kind: Kind
    var amount: Decimal?          // contribution
    var newDeadline: Date?        // extended
}
```
`Want` gains `var decidedOn: Date?` (set when a want becomes skipped or bought; optional, decodes when absent).

```swift
enum GoalLedger {
    static func fillOrder(_ goals: [Goal]) -> [Goal]            // active only, deadline asc, nil last, createdOn asc
    static func pool(skipped: Decimal, unspent: Decimal) -> Decimal
    struct Result { var goals: [Goal]; var applied: [UUID: Decimal]; var keptRemainder: Decimal; var completed: [UUID] }
    static func consolidate(pool: Decimal, goals: [Goal], month: Date) -> Result   // marks funded goals .completed + history
    static func extendOverdue(_ goals: [Goal], now: Date, settings: PaydaySettings) -> [Goal]
    static func validate(target: Decimal, funMoney: Decimal) -> Bool                // target > funMoney
}
struct MonthEndSummary: Codable, Equatable, Sendable {
    var month: Date; var pool: Decimal; var skipped: Decimal; var unspent: Decimal
    var applied: [GoalContribution]; var keptRemainder: Decimal
    struct GoalContribution: Codable, Equatable, Sendable { var goalId: UUID; var goalName: String; var amount: Decimal; var completed: Bool }
}
```
`WantStore` (file `WantStore+Goals.swift`), every mutation saves and posts `DataChange`:
```swift
var goals: [Goal] { get }                  // all
var activeGoals: [Goal] { get }            // fillOrder
var finishedGoals: [Goal] { get }          // completed + archived
func goal(id: UUID) -> Goal?
func addGoal(name: String, target: Decimal, deadline: Date?, now: Date) throws -> Goal   // throws GoalError.targetTooLow / .emptyName
func updateGoal(id: UUID, name: String, target: Decimal, deadline: Date?) throws
func deleteGoal(id: UUID)
func archiveGoal(id: UUID)
func pendingPool(now: Date) -> PendingPool            // struct { skipped, unspent, total: Decimal }
func runMonthEndIfNeeded(now: Date) -> MonthEndSummary?   // idempotent per month; also runs extendOverdue; nil when no goals/months to process
var monthEndSummary: MonthEndSummary? { get }          // last undismissed, for the Home notice
func dismissMonthEndSummary()
var goalInviteHiddenUntil: Date? { get }; func hideGoalInvite(until: Date)
```
Call `runMonthEndIfNeeded` at launch and on foreground (AppDelegate/SceneDelegate: frontend wires it).
Tests: ledger (fill order, overflow, all-full remainder, completion, extension, validation, the sample scenario in HANDOFF: S$600 -> Espresso +490 complete, Japan +110), pool math, idempotence, old-save decode.

## Designer (owns DesignSystem, Assets, docs/design/goals): new components, plain values, no store access
`GoalCardView` (name, saved/target money, progress bar, deadline text, tags: "Fills first" frost #D9EEF5/#08506A, "Extended" glow #FBE3D3/#7A3407; axis switches to vertical at AX3+), `PendingPoolView` (frost card, "S$X pending, lands at month end"), `TagLabel`, `GoalProgressBar`, new Theme tokens (`frost`, `frostText`, `extendedText`, `destructive` #B3261E). Reuse existing Cubi moods. Provide a Swift-only preview/fixture-free API:
```swift
struct GoalCardModel { var name, savedText, targetText: String; var progress: Double; var deadlineText: String?; var fillsFirst: Bool; var extended: Bool; var accessibilityLabel: String }
final class GoalCardView: UIView { func configure(_ model: GoalCardModel) }
final class PendingPoolView: UIView { func configure(amountText: String, detail: String?) }
```
Also: ensure 700pt content cap and VoiceOver label format from the mockup notes.

## Frontend A (Saved + Home + Review): `Thaw/Features/Saved`, `Home`, `StillWantIt`, `PaydayReview`, `Thaw/App`
- Saved: goal cards (tap -> detail), pending pool line, finished section (collapsed), empty state with "Add a goal" / "Not now". Keep existing Saved content that the mockup keeps ("Kept since you started").
- Home: month-end notice card from `store.monthEndSummary`, dismissable; tapping opens goal complete when a goal completed.
- Decide now / review: skip hint line ("Skipping adds S$X to this month's pool") only when active goals exist.
- App wiring: call `runMonthEndIfNeeded(now:)` at launch/foreground; set `Want.decidedOn` is backend's job.
- Navigation to goal module entry points via `GoalDetailRouter.createModule(store:goalId:)`, `GoalEditorRouter.createModule(store:goalId:onFinish:)`, `GoalCompleteRouter.createModule(store:goalId:onFinish:)` (defined by Frontend B; use stubs only until they land, never duplicate).

## Frontend B (Goal module): new `Thaw/Features/Goals/{Editor,Detail,Complete}`
- Editor (add/edit sheet): name, target, deadline toggle + date; Save disabled until target > fun money (show hint); X close; Discard confirmation (system action sheet) when edited, per `docs/design/ux-audit.md` modal rules; dismiss only what you present.
- Detail: progress header (fun-money-meter style), contributions by month, History (extensions), archive and delete (destructive confirm).
- Complete: celebration with Cubi happy, "Archive" and "Later".
- Each is a VIPER module with presenter tests.

## Shared rules
- Commit prefix `[s5-backend]`, `[s5-designer]`, `[s5-fe-a]`, `[s5-fe-b]`; explicit pathspecs only; `git pull --rebase` before push; push to `feature/s5-goals`. Agents share one working tree: never `git add -A`, never checkout other branches, never discard others' files.
- Build with your own derivedDataPath (`.build/dd-<role>`), check exit codes. PM owns `project.yml` and `xcodegen generate`; if files are added, run `xcodegen generate`, commit `Thaw.xcodeproj` only if the file list changed, and discard `explicitFileType` churn.
- Frontend may build before backend/designer land: poll `git log --grep "\[s5-backend\]"`. Do not invent alternate APIs; if the contract is wrong, report to PM.
- Done: clean build exit 0, all tests pass, no `print`/`NSLog`, presenters free of UIKit, view controllers free of `WantStore`.
