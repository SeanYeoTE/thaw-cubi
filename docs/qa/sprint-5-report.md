# Sprint 5 QA report: Goals

Branch `feature/s5-goals` (working tree). Build: `xcodebuild -scheme Thaw -derivedDataPath .build/dd-qa` on iPhone 17 Pro simulator, **exit 0**. Driven with serve-sim taps, swipes and typing; every step checked against a screenshot. Launch args `-thawReset`, `-thawFixture sprint1`. Compared with `docs/design/goals/thaw-goals-mockups.html` and `docs/contracts/sprint-5-goals.md`. Source not edited; unit tests not re-run. Simulated date was 4 Nov 2026.

## Results

| Item | Result | Evidence |
|---|---|---|
| Saved empty state: Cubi calm, "Saving for something bigger?", "Add a goal" / "Not now", existing "Kept since you started", Skipped and Payday pattern kept | Pass | Matches mockup 2 (see P3 on title weight) |
| "Not now" hides the invite, persists across relaunch | Pass | Relaunch without reset still hides the card |
| Add goal opens "New goal" sheet with X, Save, Name, Target, Deadline | Pass | Matches mockup 3a |
| Save disabled with empty form and with target S$300; hint turns red at S$300; enabled at S$3000 | Pass | Strictly greater than fun money enforced |
| Deadline toggle shows Date row, defaults to next payday, past dates disabled in picker | Pass | |
| X after editing shows "Discard changes?" with "Discard changes" | Pass | Tapping outside keeps editing, form intact (see P3 on no explicit "Keep editing") |
| X with no edits (Edit goal) closes without a prompt | Pass | |
| Create 3 goals (25 Nov / 30 Nov / none) | Pass | Order: earliest deadline, later deadline, no-deadline last |
| "Fills first" tag on first card only; moves when first goal is deleted/archived | Pass | Also correct for a single no-deadline goal |
| No-deadline card: "No deadline" tag + "Fills after dated goals" | Pass | |
| Pending pool line: S$300 pending at start; S$324 after skipping a S$24 want; S$204 after review kept a S$120 want (24 + 180) | Pass | Matches pool rule (skipped + unspent) |
| Pool line hidden with no goals | Pass | |
| Goal detail: header meter, due date and "to go", History "Goal created", Archive, Delete | Pass | Matches mockup 4 minus Contributions (none yet) |
| Edit goal from detail (prefilled, titled "Edit goal") | Pass | |
| Delete: destructive confirm, goal removed, list re-ordered | Pass | |
| Archive: goal leaves list, "Finished goals (1)" collapsed section, expands to show it | Pass | |
| Home (Cooling) with fixture; hero, rows, tab bar | Pass | |
| Add want sheet: fill, submit, appears in list and hero count | Pass | |
| Decide now shows "Skipping adds S$24 to this month's pool" only with an active goal | Pass | Hint absent check without goals not run |
| Skip from Decide now updates Saved (Kept S$24, 1 of 1, pending S$324) | Pass | |
| Payday preview, Review now, Keep/Wait, confirm | Pass | Kept items leave, waited move to Fri 25 Dec, hero 0 wants |
| AX5 (accessibility-extra-extra-extra-large): Saved cards, pool card, editor, detail | Pass | Cards stack vertically, tags on their own line, percentage below amount, screen scrolls |
| Not exercised | n/a | Month-end landing, Home "landed" notice, goal-complete screen, overdue extension and "Extended" tag/History need a date change; not reachable by UI today. Left to unit tests |

## Bugs

- **P3: Tag pill stretches full width.** After a relayout (delete/archive of the first goal, or adding goals), "Fills first" and "No deadline" pills render stretched to the card edge and left-aligned text, next to the name. Repro: `-thawReset`, finish onboarding, add goals Espresso (deadline) and New laptop (no deadline), archive Espresso; New laptop's "Fills first" pill is wide. Re-expanding "Finished goals" relaid it correctly, so it is a layout/hugging issue in the card header.
- **P3: No "Goals" section header or labelled "+ Add goal" row.** The mockup shows a "Goals" header with a "+ Add goal" action; the build only has an icon-only "+" at top right (VoiceOver label "Add a goal" is set). Discoverability is weak once "Not now" was tapped.
- **P3: Copy and format differences from the mockup.** Pool line reads "Lands in goals at month end" (mockup: "Lands in goals Mon, 30 Nov"); deadlines read "Due 30 Nov 2026" on cards and "25 Nov 2026" in the editor (mockup: "Due Fri, 25 Dec" / "Wed, 25 Nov 2026"); editor lacks the pace hint "At your recent pace… this fills in about 3 months"; AX5 amount line does not show "of S$900 · 46%" combined.
- **P3: Empty-state title weight.** "Saving for something bigger?" renders as regular grey text beside Cubi; the mockup has it as a heading.
- **P3: Discard sheet has no visible "Keep editing" button.** On iPhone it appears as a popover anchored to X; dismissed by tapping outside. Acceptable per iOS 26 behaviour, noted for the ux-audit modal rule.
- **P3 (existing):** `-thawFixture` clears settings, so onboarding appears on every fixture launch.

No P0, P1 or P2 bugs found.
