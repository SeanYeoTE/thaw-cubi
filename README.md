# Thaw

iOS UIKit app (VIPER per screen) for the "Wishlist Cooldown" design. Sprint 1 built the core flow; sprint 2 adds payday setup, the Keep/Wait review, Cubi, Dynamic Type, persistence and local notifications.

## Screens (sprint 1)

| Screen | File |
|---|---|
| Cooling home (payday card + wants) | `Thaw/Features/Home/HomeViewController.swift` |
| Add a want (sheet) | `Thaw/Features/AddWant/AddWantViewController.swift` |
| Item detail | `Thaw/Features/ItemDetail/ItemDetailViewController.swift` |
| Payday notification (sheet) | `Thaw/Features/PaydayPreview/PaydayPreviewViewController.swift` |
| Still want it? (payday review) | `Thaw/Features/StillWantIt/StillWantItViewController.swift` |
| Saved total + history | `Thaw/Features/Saved/SavedViewController.swift` |

| Payday setup (onboarding + Settings tab) | `Thaw/Features/PaydaySetup/PaydaySetupViewController.swift` |
| Payday review (Keep/Wait vs fun money) | `Thaw/Features/PaydayReview/PaydayReviewViewController.swift` |

Sprint 2 contract: `docs/contracts/sprint-2.md`. QA reports: `docs/qa/`.

## Architecture

- VIPER per screen (contract: `docs/contracts/sprint-4-viper.md`). A shared `WantStore` is persisted as JSON in Application Support and reached only through interactors.

### VIPER modules

Home, AddWant, ItemDetail, PaydayPreview, PaydayReview, StillWantIt, Saved, PaydaySetup, each in `Thaw/Features/<Name>/`:

| File | Role |
|---|---|
| `<Name>Contracts.swift` | View, Presenter, Interactor, InteractorOutput and Router protocols plus plain view-model structs |
| `<Name>ViewController.swift` | UIKit only; forwards events to the presenter and renders view models; no `WantStore` access |
| `<Name>Presenter.swift` | Foundation only (no `import UIKit`); screen logic, validation, guards, copy; weak view |
| `<Name>Interactor.swift` | Wraps `WantStore`, `PaydaySettings` and `Reminders`; no UIKit |
| `<Name>Router.swift` | `static func createModule(...) -> UIViewController` wires the module; instance methods navigate and dismiss only what the router presented |

`DataChange` notifications flow interactor -> presenter -> view. `App/` (`SceneDelegate`, `RootTabBarController`, `ReviewRouter`) builds screens through `createModule`; `ReviewRouter` remains the notification entry point. Shared views live in `Thaw/Features/Shared` and `Thaw/DesignSystem`.

### Testing presenters

Presenters are tested without UIKit by injecting fake view, router and interactor objects. Tests are `@MainActor` and live in `ThawTests/Presenter*Tests.swift` (Home, AddWant, PaydayReview, PaydaySetup, StillWantIt), with shared helpers in `PresenterTestSupport.swift`.
- Design tokens and components live in `Thaw/DesignSystem/`.
- Display type uses Bricolage Grotesque ExtraBold (`Thaw/Resources/Fonts/`, SIL OFL 1.1, licence in `OFL.txt`). Body text uses the system font.
- Payday rules, fun money and notification scheduling live in `Thaw/Models` and `Thaw/Services`. Notification permission is asked on first Add or first Save of settings, never at launch.
- Cubi (`CubiView`) shows at Home status, Add success, review header, Skip and the top of Saved. On Saved the presenter picks the mood from the progress stats: frozen with nothing decided, proud during a payday streak, snoozing once the streak is broken.
- Fonts scale with Dynamic Type; the app is light mode only.

## Launch arguments

- `-thawReset` clears saved state (shows onboarding).
- `-thawFixture sprint1` seeds the four sample wants.
- `-thawFixture history` seeds decided wants across three months and default settings (skips onboarding).
- Debug builds seed sample wants and default settings on the very first launch (no saved state file). Use `-thawReset` for a clean start.

## Setup

1. Install Xcode 26 at `/Applications/Xcode.app`.
2. `brew install xcodegen`, then run `xcodegen generate` after editing `project.yml`.
3. Open `Thaw.xcodeproj`, scheme `Thaw`.

## Build and test

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Thaw.xcodeproj -scheme Thaw -sdk iphonesimulator -derivedDataPath .build/dd build
xcodebuild -project Thaw.xcodeproj -scheme Thaw -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath .build/dd test
```

Unit tests (21) cover payday rules, fun money, persistence, the store and formatting. Notification scheduling is compile-checked only.
