# Sprint 4: VIPER refactor (frozen)

Goal: move every screen in `Thaw/Features` to a VIPER module with **no behaviour or visual change**. All UX-audit modal rules (`docs/design/ux-audit.md`) must be preserved.

## Module layout
`Thaw/Features/<Name>/` contains `<Name>Contracts.swift`, `<Name>ViewController.swift`, `<Name>Interactor.swift`, `<Name>Presenter.swift`, `<Name>Router.swift`.

Modules: Home, AddWant, ItemDetail, PaydayPreview (PaydayNotification), PaydayReview, StillWantIt, Saved, PaydaySetup.

## Rules
- Contracts: `<Name>ViewProtocol` (AnyObject, show/render methods taking plain view-model structs, no models), `<Name>PresenterProtocol` (view events: viewDidLoad, tapX...), `<Name>InteractorProtocol` (data and domain ops over `WantStore`/`PaydaySettings`/`Reminders`; no UIKit), `<Name>InteractorOutput` where data changes push back, `<Name>RouterProtocol` (navigation/dismissal only).
- View controller: UIKit only, forwards events to presenter, renders view models. No `WantStore` access.
- Presenter: no `import UIKit` (Foundation only). Holds `weak view`, interactor, router. Formats text via `Formatting`. Owns screen logic (validation, discard guards, empty-queue guards, copy).
- Interactor: wraps the store and services. Depends on protocols where tests need fakes (e.g. `WantStoreProtocol` only if needed; otherwise use the real in-memory store).
- Router: `static func createModule(...) -> UIViewController` assembles and wires; instance methods do navigation. It holds `weak var viewController`. Dismissal: dismiss only what the router presented (UX audit rule).
- Reactions to `DataChange` notifications go interactor -> presenter -> view.
- `App/` (`AppDelegate`, `SceneDelegate`, `RootTabBarController`, `ReviewRouter`) builds tabs through `createModule`. `ReviewRouter` stays as the notification entry and calls the PaydayReview/Preview routers.
- Swift 6, default MainActor isolation; presenters/interactors are MainActor classes (no `deinit`). No `print`; use `os.Logger`.
- Keep reusable views in `DesignSystem`/`Shared` untouched.

## Tests
Add `ThawTests/Presenter*Tests.swift` (frontend owns) with fakes for view/router/interactor: at least Home, AddWant (validation), PaydayReview (keep/wait/empty queue), StillWantIt, PaydaySetup. Existing 24 tests must still pass. Test classes touching MainActor types are `@MainActor`.

## Done when
Clean build exit 0, all tests pass, `grep -rn "WantStore" Thaw/Features/*/*ViewController.swift` returns nothing, no `import UIKit` in Presenters, README architecture section updated, commits `[s4-viper-<module>]`, pushed to `refactor/viper`.
