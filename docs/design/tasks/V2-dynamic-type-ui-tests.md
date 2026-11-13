# V2: Dynamic Type and UI tests

Read [../README.md](../README.md) first for the working rules and build command.

**Owns:** `Thaw/DesignSystem/Theme.swift`, `Thaw/Features/Saved`, `ThawUITests`, `docs/screenshots`.
**Wave:** 1, then a full rerun in wave 2. **Product decision:** D6. Confirm with the user.

Review findings 4 (fonts and Stats), 5, D6, and weak spots in the UI tests.

## 1. Dynamic Type audit failures (must fix)
All 11 audits fail. Almost every issue is **"Dynamic Type font sizes are partially unsupported"** (123 of them). They appear at the default size **and** at AccessibilityL, on buttons ("Review", "Remind me tonight", "Keep", "Wait", "Let go · save S$420"), text fields ("Name", "Price in Singapore dollars") and labels ("Why you froze it", "Frozen 18 Oct").

**Likely cause:** `ThawFont.scaled` in [Theme.swift:60](../../../Thaw/DesignSystem/Theme.swift) caps every font at `maximumPointSize: size * 2.4`.
- Body text at 17 pt stops at about 41 pt.
- iOS's largest accessibility size for body is about 53 pt.
- The audit reports "partially unsupported" when text scales but stops short of the system maximum.

**Check first, don't assume:**
1. Remove the cap for `body` and `money` only, and rerun one audit:

   ```bash
   … -only-testing:ThawUITests/NewScreensAuditTests/testItemDetailAudit test
   ```
2. If the Dynamic Type issues clear, keep the change.
3. If they don't, look for fonts set without `adjustsFontForContentSizeCategory`, or button titles whose configuration font isn't scaled. Commit `ebf86d1` and `b4e76e0` already opted many labels and buttons in.

**Display font:**
- Keep a cap on `display` (the 34–56 pt titles) only if removing it breaks layouts. Large titles can reasonably top out.
- If a cap stays, the audit will still flag those titles. Exclude them in the test **by identifier and issue type**, with a comment explaining the design choice, not for the whole screen.

**After the change, check that nothing else breaks at AX5:** the Cooling rows, the stat tiles, the Payday hero and the Settings value cells. Rows must stack instead of clipping. If a fix belongs in a screen you don't own (Home, Payday, PaydayReview, StillWantIt, AddWant, PaydaySetup), list it in your report for the owner (V1 or V3) or for a follow-up.

## 2. Stats: "Potentially inaccessible text" ×2
- `AccessibilityAuditTests.testStatsAudit` flags two text elements near the filter chips ("All").
- Inspect them with the audit's element output or Accessibility Inspector, and fix them in `Thaw/Features/Saved`. Typical causes:
  - text inside a control that isn't exposed;
  - a label hidden from accessibility while it still shows;
  - text drawn inside the Swift Charts view without an accessibility label.

## 3. D6: Stats hero card
`SavedViewController.heroView` (line 251) now uses `HeroCardView`, a dark card with a larger Cubi (from #20). Show the user before and after screenshots and ask:
- **Keep** (recommended if the audit passes): it matches the Payday hero. Check the contrast of every text colour on the card (WCAG 4.5:1 for text) and record the ratios.
- **Revert:** go back to the light header (Cubi beside "S$648 saved").

## 4. Fix the UI tests
- **Wrong dialog type** (`ThawUITests/ReviewFlowUITests.swift:83`): it queries `app.alerts.buttons["Keep choosing"]`, but `PaydayReviewViewController.showDiscardConfirmation()` uses `preferredStyle: .actionSheet`. Query `app.sheets`, or `descendants(matching: .any)` as the Discard step does.
- **Audits run too early:** `testStatsAudit` and `testSettingsAudit` audit straight after the tab tap. Wait for a known element first: the Stats hero or `stats.*`, and the Settings first row.
- **Soft guards:** `PersonaTests` still uses `sleep(1)` for pacing and `if app.textFields.count > 1` guards. Replace them with `waitForExistence` and real assertions on the core path. Exploratory screenshot steps may stay soft.
- **Hidden rows:** `ReviewFlowUITests` counts `home.card` cells. Off-screen cells aren't queryable, so keep the fixtures small, or scroll and count.
- **Decorative borders:** the README says `Theme.border` card edges are under 3:1 on purpose. If the audit flags them, exclude those issues **by element and type** with that reason. Don't exclude whole categories.

## Wave 2: rerun after V1 and V3 merge
- Run the **full** UI suite (about 16 minutes).
- Every audit should pass, or have only the documented per-element exclusions.
- Refresh `docs/screenshots/` from the passing run.
- Report anything still failing, grouped by owner.

## Done when
- All 11 audits pass with only documented per-element exclusions.
- `ReviewFlowUITests` passes.
- No `sleep` is used for correctness.
- D6 is decided and applied.
- Screenshots at the default size and at AX5 show nothing clipped.
