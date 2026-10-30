# Thaw

iOS UIKit app for the "Wishlist Cooldown" design. Sprint 1 covers the core flow.

## Screens (sprint 1)

| Screen | File |
|---|---|
| Cooling home (payday card + wants) | `Thaw/Features/Home/HomeViewController.swift` |
| Add a want (sheet) | `Thaw/Features/AddWant/AddWantViewController.swift` |
| Item detail | `Thaw/Features/ItemDetail/ItemDetailViewController.swift` |
| Payday notification (sheet) | `Thaw/Features/Payday/PaydayNotificationViewController.swift` |
| Still want it? (payday review) | `Thaw/Features/StillWantIt/StillWantItViewController.swift` |
| Saved dashboard | `Thaw/Features/Saved/SavedViewController.swift` |

Settings is a placeholder; payday setup is sprint 2.

## Architecture

- Plain UIKit view controllers with a shared `WantStore` (in memory, fixtures seeded). The handover's VIPER-per-screen rule is not applied in sprint 1.
- Design tokens and components live in `Thaw/DesignSystem/`.
- Display type uses Bricolage Grotesque ExtraBold (`Thaw/Resources/Fonts/`, SIL OFL 1.1, licence in `OFL.txt`). Body text uses the system font.
- Local payday notifications are not built yet.

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

Unit tests cover the store, cooling split, rounding and formatting.
