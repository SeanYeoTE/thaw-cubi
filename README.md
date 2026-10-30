# Thaw

iOS UIKit app for the "Wishlist Cooldown" design. Sprint 1 built the core flow; sprint 2 adds payday setup, the Keep/Wait review, Cubi, Dynamic Type, persistence and local notifications.

## Screens (sprint 1)

| Screen | File |
|---|---|
| Cooling home (payday card + wants) | `Thaw/Features/Home/HomeViewController.swift` |
| Add a want (sheet) | `Thaw/Features/AddWant/AddWantViewController.swift` |
| Item detail | `Thaw/Features/ItemDetail/ItemDetailViewController.swift` |
| Payday notification (sheet) | `Thaw/Features/Payday/PaydayNotificationViewController.swift` |
| Still want it? (payday review) | `Thaw/Features/StillWantIt/StillWantItViewController.swift` |
| Saved dashboard | `Thaw/Features/Saved/SavedViewController.swift` |

| Payday setup (onboarding + Settings tab) | `Thaw/Features/Settings/` |
| Payday review (Keep/Wait vs fun money) | `Thaw/Features/Payday/PaydayReviewViewController.swift` |

Sprint 2 contract: `docs/contracts/sprint-2.md`. QA reports: `docs/qa/`.

## Architecture

- Plain UIKit view controllers with a shared `WantStore` persisted as JSON in Application Support. The handover's VIPER-per-screen rule is not applied.
- Design tokens and components live in `Thaw/DesignSystem/`.
- Display type uses Bricolage Grotesque ExtraBold (`Thaw/Resources/Fonts/`, SIL OFL 1.1, licence in `OFL.txt`). Body text uses the system font.
- Payday rules, fun money and notification scheduling live in `Thaw/Models` and `Thaw/Services`. Notification permission is asked on first Add or first Save of settings, never at launch.
- Cubi (`CubiView`) shows only at Home status, Add success, review header and Skip.
- Fonts scale with Dynamic Type; the app is light mode only.

## Launch arguments

- `-thawReset` clears saved state (shows onboarding).
- `-thawFixture sprint1` seeds the four sample wants.

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
