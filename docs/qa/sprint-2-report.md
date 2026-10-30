# Sprint 2 QA report

Simulator: iPhone 17 Pro (iOS 26.0, QA device), driven with serve-sim taps and `simctl` screenshots. Dev checks by the frontend agent on iPhone 17. Contract: `docs/contracts/sprint-2.md`.

| Case | Result |
|---|---|
| TC-S2-1 `-thawReset` shows onboarding; Save lands on Cooling with live days | Pass |
| TC-S2-2 payday rule → next payday in Save button (same date, last working day Mon 30 Nov, twice monthly Sat 31 Oct, fixed wait 7 days Sat 7 Nov) | Pass |
| TC-S2-3 notification prompt on first Save, not at launch (fresh install) | Pass |
| TC-S2-4 Keep/Wait updates meter, text, CTA; over budget turns meter warm ("S$609 kept · S$309 over your fun money") | Pass |
| TC-S2-5 CTA applies decisions: kept want leaves Cooling, waited wants stay with later `thawsAt` | Pass (after B1 fix) |
| TC-S2-6 Cubi: frozen on Home, frozen on Add, thawed on review, proud on Skip | Pass; Reduce Motion cross-fade not checked |
| TC-S2-7 AX5: Home and payday notification stack and scroll; onboarding and review checked by frontend | Partial: Item detail, Add, Saved, Settings at AX5 not checked |
| TC-S2-8 state survives relaunch | Pass |
| TC-S2-9 clean build exit 0; 21 unit tests, 0 failures; no `print`/`NSLog`/debug hooks/brand/location hits | Pass |

## Bugs found and fixed
- B1 (P2) fixture `thawsAt` derived from `frozenOn` was stale (Espresso grinder "thaws 25 Oct"); `Wait` on a past date did not move forward. Fixed in `fe520f5` with tests; rechecked on device.
- B2 (P3) "1 days" on the payday card. Fixed in `1222042`; not re-checked on screen.

## Known issues / not built
- P3: system notification action buttons are registered but not handled ("Review now" does not open the review; "Remind me tonight" does nothing). The in-app payday sheet is a preview.
- P3: Reduce Motion, VoiceOver lines, and AX5 on Item detail, Add, Saved and Settings are unverified.
- P3: a fast swipe that starts on a `ChoiceRowView` may tap it instead of scrolling (seen in the simulator only).
- Cubi "white body on Frost backgrounds" variant not implemented.
- Share sheet capture, Payday review "Saved" celebration beyond skip, and Identity wordmark screen are not built.
- No device date mocking: the countdown reads the real date.
