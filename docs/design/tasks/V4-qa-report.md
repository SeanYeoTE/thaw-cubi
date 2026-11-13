# V4: s13 QA pass and report

Read [../README.md](../README.md) first for the working rules and build command.

**Owns:** `docs/qa` (new `sprint-13-report.md`), `docs/design/s13-screens.jpg` (new). You may delete `docs/design/s11-screens.jpg` once the new sheet exists.
**Wave:** 2, after V1, V2, V3 and V5 are merged into `main`. **Read-only on app code:** report bugs, don't fix them.

## Why
s12 shipped with no QA report, and nobody looked at the review flow by eye. This pass is the check before calling the redesign done.

## Pass
Run on the iPhone 17 Pro simulator from `main` after the merges. Take a screenshot at each step, at the default size, and repeat the starred steps at AX3.

1. **Onboarding** (`-thawReset`): the payday question, then Continue, then the notification prompt, then Cooling empty state, then Add a want. *
2. **Cooling** (default seed):
   - every filter and sort;
   - swipe Edit and Delete;
   - tap a row to open Item detail;
   - relaunch, and the filter and sort are kept. *
3. **Item detail:**
   - Let go asks first; Cancel does nothing; Confirm shows the Cubi moment, pops, and the want appears on Stats;
   - Decide now opens "Still want it?". *
4. **Payday tab:**
   - default seed (over budget): "S$X over" and the Fits / Over budget sections;
   - check the figures match what the review shows for the same wants. This was finding 3. *
5. **Review** (`-thawFixture thawed`):
   - badge count, then Review;
   - Keep · Wait · Let go on each row;
   - the meter updates;
   - double-tap Done: the decisions apply once (check Stats, and that the Wait want's date moved one payday only);
   - Close with changes: "Discard choices?". *
6. **"Still want it?"**:
   - double-tap Buy on the last want, with no crash;
   - Let go: Stats updates straight away, even while the Cubi moment is showing.
7. **Stats** (`-thawFixture history`):
   - hero (D6 outcome), tiles (tap one), chart (tap a bar, switch the range);
   - filters, tap a row to open Edit. *
8. **Settings:**
   - change each row, switch tabs and come back, and the values are kept;
   - the payday rule screen;
   - the Payday tab countdown follows a changed payday. *
9. **Edit sheet:**
   - decided want: set Status to Cooling and check the "Back to cooling · …" line;
   - Delete has a gap above it. *
10. **Share sheet:** Safari on the simulator, then Share, then Thaw. The form prefills; save, open the app, and the want is there.
11. **iPad simulator:** Cooling, Stats and Settings titles line up with the cards.
12. **Reduce Motion on:** Cubi doesn't move anywhere. **Off:** the proud twinkle and the thawing drip fade are visible.
13. **Notifications** (`xcrun simctl push` with category `thaw.payday`; see V5 step 5 for payloads):
    - warm start: tapping the banner opens the Payday tab with the review on top;
    - cold start, with the app quit: same result;
    - empty queue: "Nothing to review right now";
    - banner "Remind me tonight", then add a want: the reminder is still pending (check with V5's debug log);
    - the payday notification's count matches the Payday tab badge and the review;
    - change the payday in Settings: exactly one payday notification is pending, at the new date;
    - tapping a quick-thaw notification goes where D7 decided.
14. **VoiceOver spot check** on Cooling, the review and Item detail:
    - rows read name, price and status;
    - swipe actions are available as custom actions;
    - Let go confirmation and escape (two-finger scrub) work.

## Report (`docs/qa/sprint-13-report.md`)
Follow the style of `docs/qa/sprint-10-report.md`:
- the environment (simulator, iOS version, commit);
- a table of step, result (pass / fail / not run) and evidence (screenshot file name);
- bugs, with steps to reproduce, severity and which folder owns the fix;
- the full test suite result (`xcodebuild … test`): unit tests, UI tests and audits;
- what wasn't checked.

Mark each of the 14 review findings in `docs/design/README.md` as fixed or still open, with evidence.

## Screenshot sheet
Make `docs/design/s13-screens.jpg`, a collage of the main screens in the same layout as `s11-screens.jpg`: Cooling, Payday (over budget), Payday (ready), Review, Item detail, Stats, Settings, Edit (decided). Add a title and a one-line caption for each screen. Any tool is fine; there's no image library on the dev Mac's Python, so a small Swift/AppKit script works.

## Done when
- Every step has a result and evidence.
- The report is committed with the screenshot sheet.
- Open bugs are listed by owner.
