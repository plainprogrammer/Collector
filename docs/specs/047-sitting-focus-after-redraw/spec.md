# Feature 047: Keep Focus and Announce After the Scanner Sitting Panel Redraws

**Status:** Draft
**Version:** 0.2.0
**Created:** 2026-11-06
**Last Updated:** 2026-11-06
**Depends on:** [spec 009](../009-card-scanner-confirm-flow/spec.md) (the sitting panel, Undo, the status line), [spec 040](../040-sitting-into-location/spec.md) (the place and "Set"), [spec 042](../042-sitting-condition/spec.md) (the condition, "Set"'s status sentences)
**Branch:** `182-sitting-focus-after-redraw`
**Issue:** [#182](https://github.com/plainprogrammer/Collector/issues/182)
**Plan:** present (`plan.md`, once written)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.2.0 | 2026-11-06 | Spec review round 1 (Fable, NEEDS REVISION, light; 0 blocking, 2 important, 7 minor): spec 040 no longer listed for the status line (its text never had it; spec 042 wrote it down), a refused add does not redraw (evidence table, AC-4.1), spec 009 AC-4.4 listed, the expected flips of the request examples named (AC-4.2), "next Tab" claim dropped, AC-1.4 and AC-2.1 wording, the controller removes its target after focusing, the heading's focus rule decided (decision 4). |
| 0.1.0 | 2026-11-06 | Written from issue #182 (found by spec 040's implementation review, PR #172). |

---

## Problem Statement

An add, an Undo and a "Set" answer with a Turbo Stream that **replaces** the sitting panel (`#scanner_sitting`) and updates the status line (`#status`, a polite live region); an add that is refused outright (the card is not offered, or the lot is full) updates only the status line. Two things go wrong for a collector who uses a keyboard or a screen reader:

1. **Focus is lost.** The control the collector just used ("Set", or an entry's "Undo") is inside the replaced panel, so the browser drops focus to the page: `document.activeElement` becomes the body and a screen reader loses its place.
2. **One redraw says nothing.** The status line is written after every redraw, with one exception. When "Set" deletes a sitting that holds no card (the collector chose "Not specified" and "No location" on a sitting opened only by choosing them), or clears both choices with no sitting open, the answer *empties* `#status` (spec 042 decision 3, as spec 040 did). The panel changed, and nothing is announced.

**Evidence that the other redraws already announce (2026-11-06, from the current code and request specs):**

| Panel change | Status written today | Source |
|---|---|---|
| "Set" that leaves a sitting | "Cards you scan now: Near mint, in Blue binder." (both choices for an account with locations, the condition alone otherwise; "condition not specified" and "no location" for what is unset) | `Scanner::SittingsController#chosen_message`; spec 042 decision 3 |
| "Set" refused (unknown condition, a location that is gone) | an alert sentence, 422 | `UNKNOWN_CONDITION`, `GONE` |
| Undo | "Removed 1 × Lightning Bolt (MOM · 123, Foil) from your collection." | `Scanner::Sittings::Entries::UndosController`; spec 009 AC-4.1 |
| Undo refused | "That card was already undone." / "That copy has changed in your collection, so it can't be undone here.", 422 | `REFUSED`; spec 009 AC-4.2, AC-4.4 |
| An add | "Added 1 × … to your collection.", or, for a replayed reading key whose entry was undone or changed, a refusal sentence (these redraw the panel); a refused add (not offered, lot full) writes its sentence and does not redraw | `Scanner::Sittings::EntriesController#message_for`; spec 009 AC-1.3, AC-1.5 |
| "Set" deleting an empty sitting, or clearing both with none open | **nothing** (`#status` emptied) | `chosen_message` returns nil |

So the status line needs a sentence in one case; focus needs restoring in two (Set and Undo).

**Outcome (issue #182):** after "Set" or "Undo" redraws the panel, keyboard focus is on the control that was used, or on the panel's heading when that control is gone; and every redraw of the panel writes a sentence in the live region.

## Goals

- After "Set" (accepted or refused), focus is on the new panel's "Set" button.
- After "Undo" (done or refused), focus is on the panel's heading, because the Undo button that held focus is gone.
- Every answer that redraws the panel writes a non-empty sentence in `#status`, so the clearing case announces too.
- System specs prove focus and the status text after Set, Undo and clearing, and request specs prove the redraw names where focus goes.

## Non-Goals

- **Moving focus after an add.** An add's buttons live in the reading's result area, which spec 009 replaces; where focus goes after an add is spec 009's behaviour, unchanged here. The redraw an add causes does not move focus (AC-3.2).
- **Moving focus on a page load, a reload or a Turbo visit.** Only an answer to the collector's own Set or Undo moves focus.
- **Keeping the "Show all" list open across a redraw.** A redraw closes the `<details>` today; a separate issue if it matters.
- **New components.** The heading gains `tabindex="-1"` and the panel a Stimulus hook; the one style added is the heading's focus ring (decision 4).
- **A different message for each way of reaching an empty sitting.** One sentence says what the next scan gets (decision 1).
- **Announcing "Done".** It is a full-page confirmation and a summary, not a redraw of the panel.

## Users and Context

A collector scanning a binder card by card, with a keyboard, a switch device or a screen reader, who sets the sitting's condition and place and undoes mistakes while the camera stays on. They (or a collector using a mouse who tabs afterwards) need to carry on from where they were.

## Decisions

### 1. The clearing case says what the next scan gets, in "Set"'s own sentence (for ruling at approval)

When "Set" deletes an empty sitting, or clears both choices with none open, `#status` says the sentence every other "Set" says, for the state that now holds: "Cards you scan now: condition not specified, no location." (an account with locations) or "Cards you scan now: condition not specified." (an account with none). No new copy is added: the sentence is already in the voice of `docs/design-system/` (sentence case, "you", one plain sentence, no exclamation, states exactly what is true), and "Set" always announces what later scans will get, whichever way the choices fall. One rule replaces the exception.

Alternatives:

- **B. A new sentence "Sitting cleared."** (the issue's example). It names the event but not what the next scan gets, which is what the collector asked "Set" for; it also adds copy for a state that needs no new word ("sitting" is shown to a collector only in the heading and "Done"). It would be the one "Set" answer that does not describe the choices. Not recommended.
- **C. "Choices cleared. Cards you scan now: …"** Two sentences; the status partial's rule is one plain sentence. Rejected.

### 2. Focus goes to the control used, or the heading when it is gone

- "Set" answers (accepted, cleared, or refused with 422): the "Set" button of the redrawn panel. The same button exists in every panel state (a sitting, none open, an empty sitting), so it is always there to focus.
- "Undo" answers (done, or refused): the panel's heading ("This sitting: N cards …"). The Undo button is gone after a done Undo; after a refused one the entry's buttons may have been replaced by "Changed in your collection". One target for both keeps it predictable. A sitting that exists after an Undo always has its heading (Undo never deletes the sitting).
- An add's redraw, the first page render and the reload: no focus move.

### 3. The server names the target; a small Stimulus controller moves focus

`sitting_stream` takes a `focus:` argument ("set" or "heading", nil for an add). The panel partial takes a `focus` local, nil on the page's first render, and renders a `data-controller` and a value naming the target. The controller's `connect()` focuses it and then removes the target attribute, so a reconnect (the element moved, a morph refresh) cannot focus again: "focus moves once" holds by construction. The heading gets `tabindex="-1"` so it can take focus without becoming a Tab stop. Scanner pages send a Content-Security-Policy with nonces (`ScannerPage`): the controller is an importmap module, so no inline script is added. Without JavaScript the form still works, as spec 040 AC-7.1 and spec 042 AC-7.1 require (focus is an enhancement; without script the page behaves as today).

### 4. The focus ring on the heading

The heading is not an interactive element, so the design system's "focus ring on every interactive element" doesn't name it, and `components.css` has no rule for it (the browser would draw its default ring, not the `focus` token). A script-focused element matches `:focus-visible` after a keyboard action and not after a click. One rule is added to `collector/additions.css` in the pattern of its existing focus rules (`outline: 2px solid var(--focus); outline-offset: 2px`) for the sitting heading's `:focus-visible`, documented in `docs/design-system/components/Scanner.md`; verification looks at it in both themes (AC-2.4).

## User Stories

### Story 1: "Set" keeps my place

**As a** collector using a keyboard or a screen reader, **I want** focus on "Set" after it redraws the panel, **so that** I can change a choice and press it again without searching for it.

- [ ] **AC-1.1** Given a sitting holding cards and the keyboard on "Set" (Tab to it) When Enter is pressed with Near mint chosen Then the panel is redrawn with Near mint chosen, `document.activeElement` is the redrawn panel's "Set" button, and `#status` says "Cards you scan now: Near mint, no location." (an account with locations).
- [ ] **AC-1.2** Given no sitting open When Near mint is chosen and "Set" is used Then a sitting opens holding it, the camera and the reading on screen stay, `document.activeElement` is the new panel's "Set" button, and `#status` says "Cards you scan now: Near mint, no location." (or "Cards you scan now: Near mint." for an account with no locations).
- [ ] **AC-1.3** Given a sitting with no entries at all, holding only Near mint When "Not specified" is chosen and "Set" is used Then the sitting is deleted, the panel is the control alone (spec 042 AC-1.1), `document.activeElement` is its "Set" button, and `#status` says "Cards you scan now: condition not specified, no location." (an account with locations) or "Cards you scan now: condition not specified." (an account with none).
- [ ] **AC-1.4** Given no sitting open When "Set" is used with "Not specified" and "No location" Then no sitting opens, `document.activeElement` is the control's "Set" button, and `#status` says the sentence of AC-1.3 that fits the account (with or without locations).
- [ ] **AC-1.5** Given a "Set" the server refuses (a condition outside the scale, or a location that is no longer the account's) When the 422 answer redraws the panel Then the redraw names "Set" as the focus target (request level) and `#status` holds the refusal's alert sentence as today (spec 042 decisions 5, 8).

### Story 2: Undo keeps my place

**As a** collector, **I want** focus on the panel's heading after Undo removes an entry, **so that** the control I used going away doesn't send me back to the top of the page.

- [ ] **AC-2.1** Given a sitting with no condition or place set, two entries and the keyboard on the newest entry's "Undo" When Enter is pressed Then the entry leaves the list, `document.activeElement` is the panel's heading (text "This sitting: 1 card"), and `#status` says "Removed 1 × Lightning Bolt (MOM · 123, Foil) from your collection." (spec 009 AC-4.1).
- [ ] **AC-2.2** Given a sitting with one entry When its "Undo" is used Then the panel says "Everything added in this sitting was undone." (spec 042 decision 3), and `document.activeElement` is the heading ("This sitting: 0 cards").
- [ ] **AC-2.3** Given an entry already undone in another tab, or whose lot was changed so it can't be undone here When its "Undo" is used and answers 422 Then the redraw names the heading as the focus target (request level) and `#status` holds the alert sentence (spec 009 AC-4.2, AC-4.4).
- [ ] **AC-2.4** Given the sitting heading When the collector tabs through the page Then the heading is not a Tab stop (`tabindex="-1"`); and Given a keyboard Undo has focused it Then a focus ring shows on it in light and dark at 1280 px and 390 px (read from screenshots in `verification.md`).

### Story 3: Nothing else moves focus

**As a** collector, **I want** focus to move only when my own Set or Undo redraws the panel, **so that** a page load, an add or a reload doesn't steal it.

- [ ] **AC-3.1** Given a sitting with entries When the scanner page is loaded or reloaded Then no element of the panel is focused by the page (`document.activeElement` is the page body) and the panel carries no focus target.
- [ ] **AC-3.2** Given a sitting When a card is added from a reading Then the answer redraws the panel with no focus target (request level), and the panel's controls are not focused by the redraw.
- [ ] **AC-3.3** Given any Set or Undo that moves focus When it answers Then the camera and the reading on screen are untouched (spec 040 AC-1.2, spec 009 AC-4.1: the page is not reloaded).

### Story 4: Every redraw is announced

**As a** screen reader user, **I want** every change of the panel to say what happened in the live region, **so that** I never hear nothing after pressing a button.

- [ ] **AC-4.1** Given each answer that redraws the panel (an add, a replayed add whose entry was undone or changed, an Undo, an Undo refused, a "Set" accepted, a "Set" refused, a "Set" that deletes an empty sitting, and a "Set" that clears both choices with none open) When it is rendered Then its `#status` update holds a non-empty sentence (request level, one example each). A refused add (not offered, lot full) never redraws the panel and keeps its own sentence, as today.
- [ ] **AC-4.2** Given the "Set" that deletes an empty sitting, or clears both choices with none open When it answers Then `#status` is not emptied: spec 042 decision 3's "the status line is cleared" no longer holds (see Supersedes), and the sentence is decision 1's. The request examples that assert the old clearing (`spec/requests/scanner/sittings_spec.rb`: the `status_cleared?` helper and the examples that use it, and the examples that expect no "Cards you scan now" after a clearing) change with it; they are this spec's expected changes, not regressions.

## Functional Requirements

**FR-1.** Every answer that redraws the sitting panel writes a non-empty sentence in `#status`. **Must not:** empty `#status` while redrawing the panel.

**FR-2.** An answer to "Set" (any outcome) marks the redrawn panel's focus target as the "Set" button; an answer to "Undo" (any outcome) marks it as the heading; an add's answer and the page's first render mark none.

**FR-3.** Focus moves once, when the redrawn panel is connected to the page, and only to a target the panel names. **Must not:** move focus on a page load, a reload, an add, or from any other page.

**FR-4.** The heading is focusable by script (`tabindex="-1"`) and not a Tab stop.

**FR-5.** The behaviour follows the scanner's existing markup and copy (`docs/design-system/components/Scanner.md`, `StatusMessage.md`); no new component, no inline script, no new copy beyond decision 1's reuse, and one `additions.css` rule (decision 4).

## Non-Functional Requirements

- **Accessibility.** The status line stays the page's one live region (`#status`, polite). Focus order is unchanged (the heading is not a Tab stop). A screen-reader check of Set, Undo and clearing is owed to the maintainer after merge (NVDA or VoiceOver; whether the heading and the status together read once or twice is the thing to hear).
- **Security.** The scanner's Content-Security-Policy is unchanged and no inline script is added; the focus target is a fixed word from the server (no user data in the attribute).
- **Performance.** None: one attribute and a few lines of script.
- **Self-hosting and upgrades.** No migration, setting or data change.

## Supersedes

| Spec | What | Where |
|---|---|---|
| [042](../042-sitting-condition/spec.md) | Decision 3's last sentence: "When 'Set' deletes an empty sitting (decision 4), or clears both choices with no sitting open, the status line is cleared, as spec 040 does." Now `#status` says "Cards you scan now: condition not specified, no location." (decision 1). Also AC-7.1's "no script is added": a small script now moves focus; the form works without it | 042 decision 3, AC-7.1 |
| [040](../040-sitting-into-location/spec.md) | AC-7.1's "no script is added". (Spec 040's own text never says the status line is cleared; AC-1.8 only deletes the sitting. The clearing was behaviour that spec 042 decision 3 wrote down "as spec 040 does", so it is superseded under 042.) | 040 AC-7.1 |
| [009](../009-card-scanner-confirm-flow/spec.md) | AC-4.1, AC-4.2 and AC-4.4 gain focus: after Undo, done or refused, the heading takes focus; the announcement is unchanged | 009 AC-4.1, AC-4.2, AC-4.4 |

The index rows for specs 009, 040 and 042 carry this spec under "Superseded by"; the area-doc step for the scanner is the design system's [Scanner](../../design-system/components/Scanner.md) doc, whose lines on "Set" and "Undo" this spec changes (there is no scanner area doc).

## Error Scenarios

| Scenario | Expected |
|---|---|
| JavaScript is off or the controller fails to load | The form and Undo work as today (the panel redraws, the status is written); focus is lost as before |
| The panel is redrawn with focus already elsewhere on the page (the collector clicked away while the answer was in flight) | Focus moves to the target; the answer is the collector's own Set or Undo |
| The focus target is missing from the redrawn panel | Nothing is focused; no error (the "Set" button is in every panel state, and the heading exists whenever Undo can answer) |
| Undo on an entry of a sitting that has ended or of another account | 404 as today (spec 009 AC-3.8); no redraw |

## Open Questions

None. Decision 1's copy is put to the maintainer at approval, with option B named.

## Out of Scope

- Moving focus after an add, the "Show all" list's open state, "Done", and any scanner page other than the sitting panel.
- Number entry's list and the collection's bulk Undo: their own redraws and focus are not part of #182.

## Verification

`docs/specs/047-sitting-focus-after-redraw/verification.md`: an AC table pointing at each example, screenshots of the focused heading (AC-2.4), the owed screen-reader check, and the implementation review under `## Implementation review`.
