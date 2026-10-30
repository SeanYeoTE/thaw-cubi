# Sprint 1 QA report

Simulator: iPhone 17 Pro (iOS 26.0), driven with serve-sim taps and `simctl` screenshots, checked by eye.

| Case | Result |
|---|---|
| Clean build (`build`) | Pass |
| Unit tests (`test`, 5 cases) | Pass |
| Home: payday card, four want cards, accent "+" | Pass, matches design |
| Item detail from a want card | Pass, matches design |
| Payday notification sheet from payday card | Pass, matches design |
| Still want it? review, first item | Pass, fun-money maths matches design (S$300 − S$189 = S$111) |
| Add a want: sheet, submit, new card and payday totals update (S$678 → S$723) | Pass |
| Payday review queue: skip, buy, not sure, skip; Saved shows 2 of 3 skipped, S$465 kept | Pass |
| Dark mode | Pass after pinning light (design is light only) |
| Large text (AX5) | Fail (P2): text uses fixed point sizes, no Dynamic Type scaling |

## Known issues

- P2: Dynamic Type not supported. Fonts are fixed size, so AX5 does not enlarge text.
- Payday days count uses the device date, so it reads 26 days today rather than the design's 12.
- The 2-day timer is shown as a label only; no timer runs.

## Known deviations

- Local payday notifications are not built.
- Plain UIKit controllers, not VIPER per screen.
- Share sheet capture and the Cubi avatar sheet are not built. The add flow is a plain form.
