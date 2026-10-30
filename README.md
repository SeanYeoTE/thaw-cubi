# Thaw

iOS UIKit app for the "Wishlist Cooldown" design. Sprint 1 covers the core flow.

## Setup

1. Install Xcode 26 at `/Applications/Xcode.app`.
2. `brew install xcodegen`, then run `xcodegen generate` after editing `project.yml`.
3. Open `Thaw.xcodeproj`, scheme `Thaw`.

## Build

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Thaw.xcodeproj -scheme Thaw -sdk iphonesimulator -derivedDataPath .build/dd build
```
