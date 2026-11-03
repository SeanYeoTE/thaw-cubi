# Sprint 4 QA report: VIPER regression

Branch `refactor/viper` (working tree, uncommitted refactor). Build: `xcodebuild -scheme Thaw -derivedDataPath .build/dd-qa` on iPhone 17 Pro simulator, **exit 0**. Driven with serve-sim taps and swipes, checked against screenshots. Launch args `-thawReset`, `-thawFixture sprint1`. Unit tests were not re-run.

| Flow | Result | Evidence |
|---|---|---|
| Onboarding (payday setup), scrolls to Save, saves, lands on Home | Pass | Save button reads "Save · next payday Wed, 25 Nov"; Home shows 22 days |
| Home (empty, then populated by fixture) | Pass | Hero card, cooling rows and tab bar render; hero counts "3 wants thaw then · S$678 vs S$300" |
| Add want sheet (open, fill, submit) | Pass | Name, price and reason accepted; sheet closes and "Headphones S$120" appears in Home and the hero count |
| Item detail, tab bar hidden | Pass | Pushed from Home, back chevron shown, no tab bar; "Why you froze it" and the Wait/Decide/Skip actions render |
| Payday preview sheet closes with X | Pass | Opened from the hero card, X dismisses back to Home (with the top-right X, not a back button) |
| Preview "Review now" opens the review | Pass | Opens "Payday review", fun-money meter S$189 kept · S$111 left |
| Review Keep/Wait toggles and confirm | Pass | Toggling updates the meter and the CTA ("Keep 1 · S$69"). Confirm applies it: kept item leaves Cooling; waited items move to Fri, 25 Dec; hero shows 0 wants thaw |
| Decide now (item detail) | Pass | "Still want the mechanical keyboard?" shows reason and fun money; "Skip and keep S$189" removes it from Cooling |
| Saved | Pass | After the skip: S$189 kept, goal S$189 of S$2,000, Skipped 1 of 2, "Mechanical keyboard · S$189" |

## Comparison with docs/qa/sprint-3-report.md
- The Sprint 3 flows (Payday review from the router, preview sheet with Review now / Remind me tonight, tab root presentation) behave as described. Review via "Review now" presents correctly after the `ReviewRouter` and `RootTabBarController` changes.
- Not re-checked here (same gaps as Sprint 3): notification tap on cold launch, "Remind me tonight" action, AX5, Reduce Motion.

## Bugs
No functional regressions found.

- **P3 (wording, not a regression):** On Saved, the Review "Keep" of Linen overshirt (a purchase) is not counted, so after only that Keep the screen shows "Kept since you started S$0" and "Skipped 0 of 1". Here "Kept" means money not spent, while Review "Keep" means buy, so the same word means opposite things. Repro: `-thawReset -thawFixture sprint1`, finish onboarding, tap hero card, Review now, Keep the shirt only, confirm, open Saved.
- **P3:** "Fun money if you buy: S$111 of S$300 left" in Decide now ignores the S$69 already kept in the same payday review (should arguably read S$42). Repro: continue from the above, open Mechanical keyboard, Decide now.
- **P3:** `-thawFixture sprint1` clears settings, so onboarding shows on every fixture launch (by design in `WantStore.launch`; QA needs the extra Save tap).

## Environment note
The simulator shut down once mid-run (system daemons crashed at the same time; no Thaw crash report). It was rebooted and the persisted state reloaded correctly. The X-close step was re-run after the reboot and passed.
