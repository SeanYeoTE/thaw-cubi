# T2: Shared components

> **Done.** Shipped on `feature/s11-ui-standardise` (SeanYeoTE/thaw-cubi#18). Kept for history; the code is the source of truth now.

Read [../../README.md](../../README.md) first for the working rules.

**Owns:** `Thaw/DesignSystem`, `Thaw/Features/Shared`.
**Depends on:** nothing. **Unblocks:** T3, T4, T6.

Build the small pieces that Cooling, Payday and Stats share, so the screens look like one app. **Changes must be additive only.** Existing call sites (`HomeViewController`, `SavedViewController`, `PaydayCardView` users) must compile and look the same until their owners adopt the new pieces.

## Components

### `FilterChipBar` (`Thaw/DesignSystem/FilterChipBar.swift`)
A single-select row of pill chips, for example **All · Payday · Quick thaw** or **All · Let go · Bought**.
- API: `init(titles: [String], selectedIndex: Int)`, `var selectedIndex: Int`, `var onChange: ((Int) -> Void)?`.
- Selected chip: `Theme.accent` fill and white text. Others: `Theme.surface` fill, `Theme.border` outline, `Theme.ink` text. `Theme.Radius.pill`.
- Each chip is at least 44 pt tall. Scrolls horizontally if the chips don't fit; wraps to a vertical stack at accessibility sizes.
- VoiceOver: each chip is a button with the `.selected` trait when on; the bar is an accessibility container.
- Selection haptic: `UISelectionFeedbackGenerator`.

### `SectionHeaderView` (`Thaw/DesignSystem/SectionHeaderView.swift`)
A light list section header: a title on the left and optional trailing detail on the right, for example "This payday" / "S$320" or "November" / "S$120 saved".
- `ThawFont.body(13, weight: .semibold)` in `Theme.inkSecondary`; the trailing text uses the same font. `.header` trait. One line, wrapping at accessibility sizes.
- Usable as a cell's content view (both list screens build cells by hand, see `HomeViewController.configure`).

### `StatChipView` (`Thaw/DesignSystem/StatChipView.swift`)
A compact stat: an SF Symbol, a value and an optional 1-to-2-word caption. Examples: `flame.fill` "3", `percent` "60%", "1.4 mo".
- API: `init(symbol: String?, value: String, caption: String?, spoken: String)`; it is a `UIControl`, so callers can make it tappable to show an explanation.
- `accessibilityLabel = spoken`.

### `EmptyStateView` (`Thaw/DesignSystem/EmptyStateView.swift`)
Cubi (`CubiView`, given mood, size 96), one short line and an optional `PillButton`, centred.
- API: `init(mood: CubiMood, line: String, actionTitle: String?)`, `var onAction: (() -> Void)?`.

### Leaner want row (`Thaw/Features/Shared/WantRowModel.swift`, `WantRowView.swift`)
Add, with defaults so existing callers don't change:
- `leadingSymbol: String? = nil`: a small SF Symbol before the title (`timer`, `calendar`, `checkmark.circle`, `xmark.circle`), tinted by `statusTone`.
- Make `status` optional (`String?`, keep a convenience init that takes a `String`). When `nil`, the row is a single line: symbol · title, then price · trailing on the right. Keep the progress strip.
- Layout must still switch to vertical at accessibility sizes.

### List layout helper (optional, only if it stays small)
`HomeViewController.makeLayout` and `SavedViewController.makeLayout` duplicate the 700 pt column and margin maths. A `WantListStyle.contentInsets(environment:safeArea:)` helper may remove that duplication. Leave it out if it gets fiddly; the owners can adopt it later.

## Not in scope
- Don't change `PaydayCardView`. T3 builds the Payday tab hero inside its own module, and T4 removes the card from Cooling.
- Don't edit any screen module.

## Tests and preview
- No presenter changes, so no presenter tests.
- Add a DEBUG-only gallery screen if it helps you check states (`#if DEBUG`, not linked from the tabs). Otherwise check on a scratch branch and revert.
- Screenshots in the report: each component at the default size and at AX3, with chips selected and unselected.

## Done when
- Build and all existing tests pass.
- Existing screens look identical.
- Report lists each new API with a one-line usage example for T3, T4 and T6.
