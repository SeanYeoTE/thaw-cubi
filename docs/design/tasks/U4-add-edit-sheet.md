# U4: Add and Edit sheet

Read [../README.md](../README.md) first for the working rules, copy rules and build command.

**Owns:** `Thaw/Features/AddWant`, `ThawTests/PresenterAddWantTests.swift`, `ThawTests/IntegrationEditTests.swift`.
**Wave:** 1.

**Careful:** the Share extension (`ThawShare/`) reuses this module for "Add to Thaw" from Safari. Don't edit `ThawShare/`, but check that sharing still works after your change (see Simulator check).

## Problem
See the "Stats · tap a row" panel in [../s11-screens.jpg](../s11-screens.jpg). The sheet has:
- **Explainer paragraphs:**
  - Add: "Thaw will read this back to you when it thaws. It joins your Cooling list…" / "Items under S$30…".
  - Edit: "You can change the name, price and reason. Moving the price across S$30…".
- **Three full-width buttons in Edit mode** for decided wants (Move back to cooling, Mark as bought, Delete), all with the same weight, and Delete only told apart by red text.
- **A long reason label:** "Why do you want it? In your words."

## Recommended direction
**Fields:**
- **Name:** placeholder "What do you want?". No separate label, but keep an accessibility label.
- **Price:** "S$" prefix inside the field, decimal pad.
- **Live thaw line, replacing the paragraphs.** One quiet line under the price that updates as you type:
  - **"Thaws on payday · 25 Nov"**;
  - **"Quick thaw · 3 days"** under the timer threshold;
  - in Edit mode for cooling wants, show the *new* date when the price crosses the threshold: "Moves to quick thaw · 14 Nov".
- **Why** (optional): label "Why?", placeholder "In your words. Thaw reads it back when it thaws." That's the only explainer.
- **"From example.com"** caption for shared links: keep it.

**Edit actions for decided wants:**
- Replace the three buttons with one **Status** row: a menu or segmented control showing **Cooling · Bought · Let go**, with the current one selected. Changing it applies on Save.
- **Delete** moves to a plain destructive text button at the bottom, after a gap, with its existing confirmation.
- Edit mode for a **cooling** want has no status row. Delete only.

**Save:** keep "Save" in the nav bar and "Add to Thaw" for Add. Validation messages stay inline: "Add a name for the item." / "Enter a price above S$0."

**Unchanged rules:** `isModalInPresentation` while dirty, "Discard changes?" / "Discard this want?" on Cancel or swipe-down, keyboard avoidance, `accessibilityPerformEscape`.

## Notes for building
- The thaw-date logic must match `WantStore.makeCoolingWant` and `WantStore.edit`: below the threshold means a timer from now, otherwise the next payday. Put the preview maths in the presenter, use the interactor's settings, and test it.
- Status changes map to the existing store calls: `reopen` (cooling), and `setDecision(_:to:)` for bought or skipped.
- Field borders use `Theme.controlBorder` (an s11 accessibility fix). Don't regress it.

## Tests
- Thaw line copy: payday, quick thaw, crossing the threshold in Edit, and empty or invalid prices (no line).
- Status row: only for decided wants; the selected state matches; Save applies the right store call; Cancel with a changed status asks to discard.
- Delete still confirms.
- The share draft still prefills the name and shows "From host".
- `IntegrationEditTests` still pass, or are updated with a reason.

## Simulator check
- Add (empty, invalid, valid, under and over the threshold), Edit a cooling want, Edit a decided want (change the status), Delete.
- **Share sheet:** Safari on the simulator → share → Thaw. The form prefills, then saving and relaunching the app shows the want.
- Screenshots before and after at the default size and at AX3, with the keyboard up.

## Done when
- No explainer paragraphs remain, the live thaw line works, and decided wants use one status control.
- Share still works.
- Tests and build pass.
