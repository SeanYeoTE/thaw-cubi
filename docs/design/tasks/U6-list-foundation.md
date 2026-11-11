# U6: Shared list foundation and polish

Read [../README.md](../README.md) first for the working rules and build command.

**Owns:** `Thaw/DesignSystem`, `Thaw/Features/Shared` (except `WantStore+Review.swift`), `Thaw/Features/Home`, `Thaw/Features/Saved`, `Thaw/Features/PaydaySetup`. For the `Thaw/Features/Payday` view controller, coordinate with whoever merged U1; it is free once U1 is merged.
**Wave:** 2. Start only after U1 to U4 are merged, because this touches files they used.

## Problem
s11 left the same scaffolding copied into four list screens: `HomeViewController`, `SavedViewController`, `PaydayViewController` and `SettingsViewController`.
- **A drawn large title**, the workaround for the system large title staying blank over a collection view until the first scroll. Each screen does it differently: a list item, a stack in the top cell, or a boundary supplementary view.
- **The same 700 pt column and margin maths** in each `makeLayout` (and `SettingsListStyle.section`).
- **The same cell reset code** (`prepare(_:)` / `configure`), clearing accessibility state before reuse.
- **Wave 1 may add reusable views inside feature folders** that belong in `Thaw/DesignSystem`.

A fix in one place doesn't reach the others, and every new screen copies the pattern again.

## Change
1. **`ThawListScreen`** (name it as you like) in `Thaw/DesignSystem`: a small base class or helper that provides:
   - the drawn large title, one implementation, the boundary-supplementary approach from `SettingsViewController` (it doesn't need a fake item in the data source), with the `.header` trait and Dynamic Type;
   - an optional nav bar trailing items slot (Cooling's sort and + buttons);
   - the 700 pt column inset for list sections, for both the plain and inset-grouped appearance;
   - a cell-reset helper that clears content and accessibility state.
2. **Move the four screens onto it.** No visual change: compare screenshots before and after, pixel-close at the default size and at AX3.
3. **Promote the reusable views wave 1 left in feature folders** (check the U1 to U4 reports) into `Thaw/DesignSystem` where more than one screen uses them, and update their call sites.
4. **Polish carried over from the s11 review:**
   - Settings "Under S$30" becomes "**Timer for wants under** S$30" (copy in `SettingsPresenter`).
   - Delete `PaydayCardView` from `Components.swift` if nothing uses it any more (check with grep).
   - Remove the DEBUG `ComponentGalleryViewController` if nobody uses it, or update it to show every current component.

## Not in scope
- Any behaviour or copy change beyond the polish list.
- Dark mode.

## Tests
- Presenter tests are unchanged. Run them all.
- Add a unit test for the column inset maths (iPhone width and iPad width) if it ends up as a pure function.
- Ask the U5 owner to rerun the UI tests and audit after this merges, or run them yourself if the U5 work is merged.

## Simulator check
- All four tabs, before and after, at the default size and at AX3, on iPhone 17 Pro. One iPad screenshot of Cooling to confirm the 700 pt column.

## Done when
- One title and column implementation, used by all four list screens, with no visual change.
- The polish list is done.
- Tests and build pass.
