# Thaw: design status handoff

Last updated: 2026-11-04 by Claude (designer agent). Update this file whenever the design changes.

## Where the design lives

| What | Where | Notes |
| --- | --- | --- |
| Goals mockups (static HTML, for PM/eng) | `design/goals/thaw-goals-mockups.html` | One page, all Goals screens + engineering notes at the bottom. Self-contained; fonts load from Google Fonts. |
| Live design canvas (Claude Design) | https://claude.ai/artifact/JZc6o8YVpEVNfGxm96asLL | Private to Sean. All screens, clickable in Play mode. Goals are the row titled "Goals feature (Sprint 5)". |
| Older exported pages | `design/*.html`, `design/unpacked/*.tpl.html` | Exports of the canvas before Goals. Treat the canvas as the source of truth. |
| Original brief | `handoff-claude-designer-goals.md` | One rule has since changed: see "Product rules" below. |

Both the HTML file and the canvas must stay in sync: change one, change the other.

## Canvas map

Row 1 (core loop): 0 Payday setup · 1 Home · 1b Home AX5 · 2 Share sheet · 3 Item detail · 4 Payday notification · 4b Payday review vs fun money · 5 Still want it? (now with skip hint) · 6 Saved with goals.
Row 2: Identity board, Cubi expression sheet.
Row 3 (Goals): G2 Saved empty · G3a Add/edit goal sheet · G3b Discard confirmation · G4 Goal detail · G7 Month-end notice on Home · G6 Goal complete · G1b Saved at AX5. A blue sticky note lists the click-through flow.

Canvas file names: `Saved, GoalsEmpty, GoalSheet, GoalDiscard, GoalDetail, MonthEnd, GoalComplete, GoalsAX5, Decide` (.dc.html). Each screen keeps its own state; there's no shared data across screens.

## Product rules for Goals (as designed)

- Fun money = monthly amount for wants (sample: S$300). Payday on the 25th. Wants under S$30 use a 2-day timer instead of payday.
- **Changed 2026-11-04 (Sean):** the monthly pending pool = prices of wants skipped that month **plus** fun money left unspent. Example: skipped S$489 + unspent S$111 = **S$600** lands. The brief's "contributions only from unspent fun money, capped" no longer applies. `docs/contracts/sprint-5-goals.md` needs updating to match.
- The pool lands at month end. Earliest deadline fills first; goals with no deadline fill last; overflow flows to the next goal; if all goals are full the remainder stays in Kept.
- Goals are optional and never block thawing or review. Target must be over one month of fun money (S$300).
- Past deadline and unmet: silently extended by one payday cycle, "Extended" tag + a History row, no notification.
- Completed goal: celebration screen (Cubi happy), then archived (not reset). "Later" leaves it at 100% on Saved.

## Sample scenario used on every screen (keep numbers consistent)

- Espresso setup: S$410 of S$900 (Sep +S$250, Oct +S$160), deadline 25 Nov extended to Fri 25 Dec, fills first.
- Japan trip: S$1,262 of S$2,000, due Wed 31 Mar 2027.
- New laptop: S$0 of S$1,800, no deadline.
- November: kept keyboard S$189; skipped overshirt S$69 + grinder S$420 = S$489; unspent fun money S$111.
- Month end (Mon 30 Nov): S$600 lands → Espresso +S$490 (complete), Japan +S$110 (S$1,372).
- Kept since you started: S$2,140.

## Design system (unchanged)

Colours: bg #F2F7F9, surface #FFFFFF, border #DDE7EC, track #E3ECF0, ink #0D2230, ink2 #4F6370, accent/Glacier #08708F, warm #E8875A, ember #C2560F, glow #FBE3D3, Night card #0D2230, frost #D9EEF5 (text on frost #08506A). Display font Bricolage Grotesque ExtraBold; UI in SF. Cubi = ice cube with a chipped top-right corner; only the face and one prop change between moods.

## Open questions

1. Skipped money isn't moved anywhere by the app. Should month end ask "Did you move S$600 to savings?" before it counts toward goals? (Not designed yet.)
2. "Not now" on the empty state hides the goal invite for 30 days. This was assumed, not specified.
3. Goal sheet blocks Save until target > S$300. This was assumed, not specified.
4. Not designed yet: archived list expanded, edit-goal pre-filled state, multiple goals completing in the same month.

## Change log

- 2026-11-04: Goals mockups created (HTML + canvas). Pool rule changed to skipped + unspent fun money. Saved board on the canvas replaced with the goals version (old chart version removed); Decide board gained the skip hint.
