# U5: UI tests and accessibility audit

> **Done.** Shipped in SeanYeoTE/thaw-cubi#19. Kept for history; the code is the source of truth. Fixes found in review: `docs/design/README.md` (s13).

Read [../README.md](../s12-README.md) first for the working rules and build command.

**Owns:** `ThawUITests`, `docs/screenshots`.
**Wave:** phase 1 in wave 1; phase 2 after wave 1 is merged.

## Problem
- **`ThawUITests/PersonaTests.swift`** (added in #17) drives the **old** UI:
  - onboarding "Save ·" (now "Continue · next payday …");
  - the "Saved" tab (now "Stats");
  - the "Next payday" card and "Review now" (both gone; review now starts from the **Payday** tab's "Review" button, with a tab badge);
  - Settings with a Save button (now a grouped list that saves as you change it).

  The tests use `continueAfterFailure = true` and soft guards, so they "pass" while doing the wrong thing.
- **Nothing runs Apple's automated accessibility audit.** s11's contrast and pointer-gesture fixes were checked by reading the code only, and large text sizes and VoiceOver were never exercised.

## Phase 1 (wave 1): the current screens

**1. Make `PersonaTests` drive the redesigned UI**
- Prefer `accessibilityIdentifier`s over labels where they exist: `home.add`, `home.card`, `home.filters`, `home.sort`, `home.empty`, `home.showAll`, `home.noMatches`, `payday.hero`, `payday.review`, `payday.remind`, `payday.row`. Look up the rest in `Thaw/Features/**` and `Thaw/App/RootTabBarController.swift`.
- Use `-thawFixture thawed` for the review persona and `-thawFixture history` for Stats.
- Replace soft guards on the core path with real assertions. "Exploratory" may stay for the screenshot extras.
- Keep the screenshot output (`THAW_SHOT_DIR`), and refresh `docs/screenshots/` from a passing run.

**2. Add `ThawUITests/AccessibilityAuditTests.swift`**
- For each tab (Cooling, Payday, Stats, Settings), plus the Edit sheet and the payday rule screen: navigate there and call `try app.performAccessibilityAudit()`.
- Run each audit at the default text size and again with a large accessibility text size. Launch with `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityL`.
- **Allowed exclusions:** only with a comment saying why, using the audit's issue handler. For example, skip a system control's issue that we can't change. Never blanket-exclude a whole category.
- **Known decisions, don't flag as bugs:**
  - Light mode only (dark mode is out of scope for s12).
  - Decorative `Theme.border` edges on cards are under 3:1 by design; controls use `Theme.controlBorder`.

**3. Report:** every audit finding, grouped by screen and owner (U1, U2, U3, U4 or U6), so the owners can fix them. **Don't fix app code yourself.** You only own the test folder.

## Phase 2 (after U1 to U4 merge)
- Update the personas for the new Payday budget block (U1), the Keep · Wait · Let go review (U2), Item detail's Let go and Decide now (U3), and the new Add/Edit sheet (U4). Use the identifiers listed in each task's report.
- Extend the audit to Item detail, Payday review, Still want it and the Add sheet.
- Run everything, refresh `docs/screenshots/`, and report the remaining findings.

## Running
- UI tests run through the `Thaw` scheme (the `ThawUITests` target is wired in `project.yml` on `main`):

  ```bash
  xcodebuild … -scheme Thaw -only-testing:ThawUITests test
  ```
- Simulator taps can lag. Use `waitForExistence(timeout:)` on every element before tapping, and never a fixed `sleep` for correctness.

## Done when
- **Phase 1:** personas pass against the redesigned UI with real assertions; audit tests exist for the six current screens at two text sizes; the findings report is grouped by owner.
- **Phase 2:** extended to the new screens, all green or with documented exclusions.
