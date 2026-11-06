# Sprint 10: share sheet capture, reversible decisions, persistence tests (FROZEN)

Branch `feature/s10-share-undo` (shared working tree; never switch branches, never `git add -A`, explicit pathspecs, `git pull --rebase` before push). VIPER rules from `docs/contracts/sprint-4-viper.md`; modal rules from `docs/design/ux-audit.md`. Explicit `deinit {}` on MainActor classes holding weak refs.

## Product decisions (from user)
1. **Share sheet**: a Share Extension shows the existing "Add to Thaw" form. Name is prefilled from the shared page title, the link is kept, price and reason are typed. Saving shows the Cubi "added" moment (design: Cubi appears when added from the share sheet) and closes. It lands in Thaw the next time the app opens or comes to the foreground.
2. **Reversible decisions**: on Saved, each History row has swipe actions **Edit** and **Delete**.
   - Edit opens an action sheet: "Move back to cooling", "Mark as bought" or "Mark as skipped" (whichever it isn't), Cancel.
   - Move back to cooling restores `status = .cooling` and keeps the original `thawsAt` (if that has passed it is thawed and appears in the next review).
   - Delete asks for confirmation (destructive) and removes the want entirely.
3. **Link on Item detail**: if a want has a link, Item detail shows its host as a tappable row that opens it in Safari.

## Backend (owns Thaw/Models, Thaw/Services, ThawTests/Backend*) FROZEN API
- `Want` gains `var link: URL?` (Codable, decodes when absent; old saves keep loading). Initializer gets `link: URL? = nil` as the last parameter.
- `WantStore`:
  - `func add(name: String, price: Decimal, reason: String, link: URL? = nil, frozenOn: Date = .now)`; existing callers unchanged.
  - `func reopen(_ id: UUID)`: decided (skipped/bought) -> cooling, `thawsAt` unchanged. No-op for cooling or unknown ids.
  - `func setDecision(_ id: UUID, to status: Want.Status)`: only between `.skipped` and `.bought`; no-op otherwise.
  - `func delete(_ id: UUID)`.
  - `@discardableResult func ingest(_ drafts: [SharedDraft]) -> Int`: adds each draft as a new cooling want using the *draft's* `createdAt` as `frozenOn` (thaw rules from current settings), skips drafts whose `id` was already ingested (keep a persisted `ingestedDraftIDs: [UUID]`, capped at the last 200), returns the number added.
  - Every mutation persists. (Posting `DataChange` stays the interactors' job.)
- `SharedDraft: Codable, Equatable, Sendable { let id: UUID; var name: String; var price: Decimal; var reason: String; var link: URL?; var createdAt: Date }`.
- `ShareInbox` (`nonisolated`, file `Thaw/Services/ShareInbox.swift`, compiled into both app and extension):
  - `static let appGroupID = "group.com.tinkercademy.thaw"`
  - `init(directory: URL?)`; `static var shared: ShareInbox` uses the app-group container (`FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`), nil-safe (no container -> no-op).
  - `func append(_ draft: SharedDraft) throws`, `func pending() -> [SharedDraft]`, `func remove(ids: Set<UUID>)`. One JSON file `inbox.json`, written atomically through `NSFileCoordinator`.
- Tests (new `ThawTests/BackendPersistenceTests.swift`, temp-directory store, reload from disk with a *new* `WantStore(fileURL:)` each time):
  skip / buy (via `decide(keep: true)`) / wait / reopen / setDecision / delete / edit / add-with-link all survive a reload; old JSON without `link` decodes; settings survive; corrupt file loads empty without crashing; inbox append -> pending -> ingest -> remove, ingest is idempotent across reloads, drafts keep their `createdAt` as `frozenOn`; reopen keeps `thawsAt`; reopen of a cooling want is a no-op.

## Frontend (owns Thaw/Features/Saved, Thaw/Features/ItemDetail, Thaw/App, ThawTests/Presenter{Saved,ItemDetail}*, ThawTests/Integration*)
- **Saved live updates**: `SavedInteractor` observes `DataChange` (like `HomeInteractor`) and forwards to the presenter, which re-renders. Saved must reflect skip/buy/undo made anywhere while it exists.
- **Saved as a list**: convert `SavedViewController` to a `UICollectionView` list (compositional layout, `.insetGrouped`-free plain cards matching the current look), keeping header content (Cubi, total, Your progress card) above the History rows. Content column capped at 700pt and centred (same as `ScrollStackViewController`). History rows get `trailingSwipeActionsConfigurationProvider` with **Delete** (destructive, red) and **Edit** (accent). Dynamic Type and VoiceOver: rows expose the swipe actions as accessibility custom actions ("Edit decision", "Delete").
- Presenter API additions: `tapEditDecision(id:)` -> view shows action sheet built from presenter-supplied options; `chooseDecisionOption(id:option:)`; `tapDelete(id:)` -> view confirms; `confirmDelete(id:)`. Interactor: `reopen`, `setDecision`, `delete` (each then `DataChange.post()` and `reminders.refresh(requestingPermission: false)`).
- **Ingest wiring**: drain `ShareInbox.shared` into the store at launch (before the first screen) and on `sceneWillEnterForeground`; if anything was added, post `DataChange` and refresh reminders.
- **Item detail link**: show the link's host as a tappable row ("Open link · example.com") when `want.link` exists; opening goes through the router (`UIApplication.shared.open`).
- Tests: presenter tests for the new Saved actions and ItemDetail link; an **integration test** (`ThawTests/IntegrationSavedTests.swift`) with a real temp-file `WantStore`, real `SavedInteractor` and `SavedPresenter`, fake view: skip a want (through the store + `DataChange.post()`), assert the view re-rendered with the new saved total and history; reopen it, assert it leaves history; buy one, assert history shows "Bought" and the total is unchanged.

## Share extension (owns Thaw/Features/AddWant, new `ThawShare/` folder, `ThawTests/PresenterAddWant*`, `ThawTests/PresenterShare*`)
- PM adds the `ThawShare` target, entitlements and app group in `project.yml` before you start (see below). You implement the code.
- Reuse the AddWant VIPER module: add `var draft: AddWantDraft? { get }` to `AddWantInteractorProtocol` where `struct AddWantDraft: Equatable { var name: String; var link: URL? }`. When present, the presenter configures add mode with the name prefilled and shows a caption "From <host>" (link read-only); the discard guard compares against the prefilled values. `add(name:price:reason:)` signature unchanged; the interactor attaches the link.
- `ThawShare/ShareViewController.swift` (principal class): extracts title + URL from the `NSExtensionItem`s (`attributedContentText`/`attributedTitle`, `public.url`, `public.plain-text` containing a URL), falls back to a humanised URL host/path for the name. Hosts the AddWant module in a navigation controller via `ShareAddRouter`/`ShareAddInteractor` (writes a `SharedDraft` to `ShareInbox.shared`); on save shows the existing Cubi moment then `extensionContext?.completeRequest`; cancel/discard -> `cancelRequest`.
- The extension must not touch `WantStore` or `Reminders`.
- Tests: presenter tests for prefilled draft mode (name prefilled, caption, discard only after a change, save passes typed fields), and a test for the title/URL extraction helper (make it a pure function, e.g. `ShareItemParser`, in a file compiled into the app too so tests can reach it).

## PM (project.yml, entitlements, pbxproj, docs, QA)
- `ThawShare` app-extension target (`com.tinkercademy.thaw.share`), `NSExtensionPointIdentifier = com.apple.share-services`, activation rule: web URL max 1, text max 1. Both targets get `com.apple.security.application-groups = [group.com.tinkercademy.thaw]`. Extension compiles `ThawShare/`, `Thaw/DesignSystem`, `Thaw/Models`, `Thaw/Services/{ShareInbox,Formatting}.swift`, `Thaw/Features/AddWant/{AddWantContracts,AddWantPresenter,AddWantViewController}.swift`, `Thaw/Features/Shared/{MomentView,ShareItemParser}.swift`, the font. Device builds need `-allowProvisioningUpdates` once to register the app group.
- Done when: clean build exit 0 for app and extension, all tests pass, simulator QA of Safari -> Share -> Thaw -> appears in Cooling, swipe Edit/Delete on Saved, README updated, QA report `docs/qa/sprint-10-report.md`, one PR to main.
