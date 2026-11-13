# V3: Cubi, title and Edit sheet polish

Read [../README.md](../README.md) first for the working rules and build command.

**Owns:**
- `Thaw/DesignSystem/CubiMotion.swift`, `Thaw/DesignSystem/CubiView.swift`, `ThawTests/CubiMotionTests.swift`;
- `Thaw/DesignSystem/ThawListScreen.swift`, `ThawTests/ThawColumnTests.swift`;
- `Thaw/Features/AddWant`, `ThawTests/PresenterAddWantTests.swift`.

**Wave:** 1.

Review findings 6, 7, 8 and 9.

## 1. Cubi idle fades never show (must fix)
`Thaw/DesignSystem/CubiMotion.swift`:
- The `loop()` helper (line 94) sets `isAdditive = true` on **every** property animation in a loop, including the opacity fades.
- An additive opacity animation adds to the layer's opacity of 1. A fade from 1 to 0.45 becomes 2 to 1.45, which Core Animation clamps to 1.
- So the proud star twinkle and the fade half of the thawing drip never show.
- `ThawTests/CubiMotionTests.swift:31` asserts `isAdditive` for every animation, so the test enforces the bug.

**Fix:**
- Make only the transform and position animations additive. Opacity animations use absolute values.
- Update the test to check that translation is additive, opacity is not, and every idle loop repeats forever (`repeatCount = .infinity`).

**Check on the simulator:**
- the proud Cubi on Stats (default seed, which has a streak) visibly twinkles;
- the thawing drip fades;
- with Reduce Motion on, nothing moves;
- switching Reduce Motion while the screen is visible stops or starts the loops.

## 2. Title misaligned on wide screens (should fix)
`ThawListTitleView` in `Thaw/DesignSystem/ThawListScreen.swift` (around line 64):
- The title is `ThawColumn.maxWidth - 2 * Theme.Spacing.screen` (660 pt) wide and centred.
- Cooling and Stats sections use the full 700 pt column (`ThawColumn.insets`), so on iPad and in landscape the title sits 20 pt inside the cards.
- Settings is right because inset-grouped cards add their own 20 pt.
- This regressed in U6, which was meant to make no visual change.

**Fix:** pass the list appearance into the title view, with 700 pt for plain lists and 660 pt for inset-grouped ones. Or work the width out from the same `ThawColumn` helper the sections use.

**Test:** extend `ThawColumnTests` so the title's leading edge equals the section's leading edge for plain and inset-grouped lists, at iPhone, landscape and iPad widths.

**Check:** iPad simulator screenshots of Cooling, Stats and Settings, before and after.

## 3. Reopening a decided want shows no thaw line (should fix)
`Thaw/Features/AddWant/AddWantPresenter.swift`, `thawLine(for:)` (line 123):
- It returns `nil` for any decided want, even when the Status control is set to **Cooling**.
- `WantStore.reopen` keeps the original `thawsAt` (an s10 decision, still correct). A want whose date has passed therefore comes straight back as ready to review, and the sheet never says so.

**Fix:** keep the store behaviour. When Status is Cooling on a decided want, show one line:
- **"Back to cooling · ready to review now"** if `thawsAt` has passed;
- otherwise **"Back to cooling · thaws on payday · 25 Nov"** or **"… quick thaw · 14 Nov"**, using the same rules as the other thaw lines.

If the price also changes across the timer threshold in the same edit, `store.edit` runs before `reopen` and doesn't recompute for decided wants, so the date stays the old one. Show that date. Don't invent a new one.

**Tests:**
- decided want set to Cooling with a past `thawsAt`;
- decided want set to Cooling with a future `thawsAt`;
- decided want left as Bought or Let go (no line);
- Save order: fields saved, then `reopen`. Make the fake interactor record one ordered list of calls.

## 4. Gap above Delete (should fix)
- `AddWantViewController.swift:133` sets `stack.setCustomSpacing(40, after: errorLabel)`.
- `errorLabel` is hidden unless there's an error, and `UIStackView` drops custom spacing after hidden views, so Delete sits at normal spacing.
- **Fix:** put the spacing after the last visible view before Delete (the status row or the reason field), or always keep a spacer view.
- **Check:** screenshots of the Edit sheet for a cooling want and a decided want, with and without an error showing.

## Also from the review (low, optional, if time allows)
- **VoiceOver announcements in the Add sheet:**
  - announce the thaw line when it changes, debounced to the end of typing;
  - announce the inline error after a failed Save (`UIAccessibility.post(notification: .announcement, …)`).
- **Duplicate "Status":** the visible "Status" caption and the status button's label are both read out. Hide the caption from VoiceOver.

## Done when
- The Cubi fades show and Reduce Motion is respected.
- Titles line up with the cards on iPad.
- The reopen thaw line works.
- The Delete gap is present.
- Tests and build pass, with before and after screenshots, including iPad and AX3.
