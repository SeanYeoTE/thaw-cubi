# U3: Item detail

Read [../README.md](../README.md) first for the working rules, copy rules and build command.

**Owns:** `Thaw/Features/ItemDetail`, `ThawTests/PresenterItemDetailTests.swift`.
**Wave:** 1. **Product decision:** D3. Confirm with the user before building.

## Problem
See the Item detail panel in [../s11-screens.jpg](../s11-screens.jpg). Today the screen stacks, top to bottom:
- a nav bar with the title "Item detail", which says nothing;
- the name;
- "S$420 · frozen Thu, 5 Nov";
- a card with "14 days" and "until payday · Wed, 25 Nov" plus a progress bar;
- a card with "Why you froze it" and the quote;
- "Thaws · Payday · Wed, 25 Nov · 9:00 am", which repeats the card above;
- three actions: **Wait one more payday** (secondary), **Decide now** and **Skip it now** (both quiet, and similar).

The date appears three times. It's unclear which action saves money, and "Skip it now" has no confirmation (UX-16).

## Recommended direction (D3)
1. **Nav bar:** no title, or the want's name once you've scrolled past the header. Keep **Edit** on the right (`detail.edit`).
2. **Header:**
   - the name in display type;
   - **S$420** on its own line (money font);
   - one quiet line: "Frozen 5 Nov".
3. **Countdown card** (keep, but trim):
   - big **"14 days"**;
   - caption **"Thaws on payday · 25 Nov"**, or **"Quick thaw · 18 Nov"** for timer wants;
   - progress bar in `Theme.accent`, or `Theme.timer` for quick thaws.
   - Drop the separate "Thaws · …" line.
4. **Why card** (keep): "Why you froze it", then the quote. Use "No reason written." when empty.
5. **Link row** (keep, when present): "Open link · example.com".
6. **Actions, two only:**
   - **Let go · save S$420** (primary). Asks for confirmation (destructive-style alert: "Let go of Espresso grinder?" / "Let go" / "Cancel"), then shows the existing Cubi moment and pops. This fixes UX-16.
   - **Decide now** (secondary). Opens Still want it (U2 owns that screen), where Wait one more payday lives.
   - Remove the standalone **Wait one more payday** button. If the user wants to keep it, make it a quiet third action and give it a short toast ("Waiting till 25 Dec").

## Notes for building
- Presenter copy and logic only; the view stays dumb.
- The pop after a decision and the refresh on `DataChange` already exist (UX-08). Keep them.
- The tab bar stays hidden on this screen (`hidesBottomBarWhenPushed`, UX-14).
- Identifiers: keep the existing ones. Add `detail.letGo`, `detail.decide` and `detail.link` if they're missing.

## Tests (`ThawTests/PresenterItemDetailTests.swift`)
- Payday and quick-thaw captions and their progress tones.
- "Today" / "1 day" / "N days".
- Let go asks first; confirm sets skipped and pops; cancel does nothing.
- Decide now routes.
- The link row appears only when there's a link.
- Wait, if it's kept, moves `thawsAt` and shows the toast text.

## Simulator check
- A payday want, a quick-thaw want, a want with a link, and an empty reason.
- Screenshots before and after at the default size and at AX3.

## Done when
- The date appears once, there are two clear actions, and Let go is confirmed.
- Tests and build pass.
