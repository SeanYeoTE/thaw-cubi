# Sprint 10 QA report: share sheet, reversible decisions, persistence

Build: clean, exit 0. Tests: 131 pass (up from 75). Simulator: iPhone 17 Pro (iOS 26), fresh install.

| Area | Result |
|---|---|
| Saved screen (collection-view rewrite) | Pass after fixes, see below |
| Swipe a History row reveals Edit (accent) and Delete (red) | Pass |
| Edit -> "Move back to cooling" | Pass: Saved total, streak, rate and history updated at once (S$648 -> S$579); want reappeared in Cooling ("4 wants thaw then") |
| Delete confirmation, Mark as bought/skipped | Covered by presenter and integration tests; not driven on the simulator |
| Share from Safari -> Thaw | Pass: Thaw appears in the share sheet; form opens "From apple.com", name prefilled "AirPods Pro 3 - Apple"; price and reason typed; Cubi moment "Brr. See you on payday."; inbox.json written with the full link |
| Inbox ingest at launch/foreground | Pass: inbox drained to `[]`, want at the top of Cooling with the shared price, reason and link |
| Item detail link row | Pass: "Open link · example.com" (tap to open in Safari not driven) |
| Draft keeps its own freeze date | Pass: "frozen Fri, 6 Nov" for a draft created then |
| Landscape (Saved) | Renders without breakage; screenshots are unrotated so spacing was not judged closely |

## Bug found and fixed during QA
- **Saved large title blank (P2).** The rewrite to a collection view left the system large title empty until the first user scroll (programmatic scroll, `setContentScrollView`, transparent background and early render did not help). Fix: `largeTitleDisplayMode = .never`, blank system title, and Saved draws its own "Saved" heading (display font, header trait) as the first line of the header.

## Open items
- Reduce Motion, AX5 and VoiceOver on the new swipe actions not checked on device.
- The share extension on a physical device needs the app group registered once.
- Sample debug seed contains a cooling and a skipped "Linen overshirt" (debug-only data).
