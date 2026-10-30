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
| Saved tab (empty state) | Pass |

## Not yet checked

- Add a want (form submit and validation): not driven on the simulator yet.
- Skip / Buy / Not sure decisions through the full review queue, and Saved after decisions.
- Dark mode, large text (AX5), and the 2-day timer for items under S$30 beyond the label.
- Payday days count uses the device date, so it reads 26 days today rather than the design's 12.

## Known deviations

- Local payday notifications are not built.
- Plain UIKit controllers, not VIPER per screen.
- Share sheet capture and the Cubi avatar sheet are not built. The add flow is a plain form.
