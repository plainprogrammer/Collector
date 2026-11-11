# Verification: Feature 064, Change a deck's format

**Spec:** [spec.md](spec.md) v0.2.3 · **Plan:** [plan.md](plan.md) v0.2.0 · **ADR:** [0028](../../adr/0028-decks-are-locations-with-zones.md) (no new ADR) · **Issue:** [#251](https://github.com/plainprogrammer/Collector/issues/251)

Written at plan task 4.2 from the code and the specs as committed (branch `064-change-deck-format`, before the full `bin/ci` and the implementation review). Each line names what proved the criterion: an example (its file under `spec/` and its description, the criterion's number being in the description unless said), or "read" for a statement checked by reading the code or the document. A criterion with no example is under **Gaps**. The full `bin/ci` and the implementation review are the supervisor's (plan, "After the last batch") and are not recorded as done here. Fresh evidence at the time of writing: `bin/rspec spec/models/deck/format_change_spec.rb spec/requests/deck_formats_spec.rb spec/system/decks_spec.rb spec/deck_core_spec.rb` ran 53 examples, 0 failures (seed 3827).

## Criteria

### Story 1: Change a deck's format

- **AC-1.1** `requests/deck_formats_spec.rb` "links each deck to its Change format page and names the deck for a screen reader"; `system/decks_spec.rb` "keeps the three row buttons on one line on a wide screen", "keeps the Decks row and the Change format page inside a 360px frame, a 60-character name included" (no horizontal overflow at 360px; the wide width is `system/decks_spec.rb` "shows Format and Owned at 1280px and the page does not scroll sideways"); "changes the format from the row through the Change format page, which needs no script". That the CSS rule is recorded in `DecksIndex.md`: read.
- **AC-1.2** `requests/deck_formats_spec.rb` "shows the head, the deck's name and format, the select with the current format, the hint and Save and Cancel"; the title, the detail header and the Decks section: read (`app/views/decks/formats/edit.html.erb`); "works without scripting": `system/decks_spec.rb` "changes the format from the row through the Change format page, which needs no script".
- **AC-1.3** `requests/deck_formats_spec.rb` "changes the format, answers 303 to the Decks page with the notice and shows the new format (AC-1.3, AC-1.4)"; `models/deck/format_change_spec.rb` "changes the type and format and nothing else when the formats share their zones", "merges a moved lot into the lot of its identity already in Considering, which survives; a lot alone keeps its id" (a lot that is not merged keeps its id).
- **AC-1.4** `models/deck/format_change_spec.rb` "changes the type and format and nothing else when the formats share their zones"; `requests/deck_formats_spec.rb` "changes the format, answers 303 …" (the notice has no sentence about cards).
- **AC-1.5** `models/deck/format_change_spec.rb` "drops and adds zones from the deck's rows: Commander to Modern keeps Main and Considering and adds Sideboard", "goes back the other way: Modern to Commander drops Sideboard and adds Commander", "rewrites a kept zone's name from the registration, so no unique-index error can happen". The one excepted case (a deck with no Considering row that also holds a zone of another key named like it) is stated in `Deck::FormatChange`'s comment and no example reaches it, as the criterion says no path of the app makes it.
- **AC-1.6** `models/deck/format_change_spec.rb` "does nothing for the format the deck already has, writing no row and moving no timestamp", "reads the format under the write lock: a stale deck object that already has the chosen format changes nothing"; `requests/deck_formats_spec.rb` "says the deck already has the format and writes nothing".
- **AC-1.7** `models/deck/format_change_spec.rb` "changes a deck whose format the instance no longer registers, judging by its zone rows"; `requests/deck_formats_spec.rb` "opens for a deck whose format is no longer registered, shows its stored key and starts the select on the default".
- **AC-1.8** `models/deck/format_change_spec.rb` "exports the new format and zones, and the file has nothing to change"; the round trip against the existing export and import, no new code.

### Story 2: Cards in dropped zones move to Considering

- **AC-2.1** `models/deck/format_change_spec.rb` "moves every lot of a dropped zone into Considering, leaves the others where they are and says how many copies"; `requests/deck_formats_spec.rb` "says how many cards moved into Considering", "says '1 card' for one".
- **AC-2.1a** `models/deck/format_change_spec.rb` "removes an empty dropped zone and moves nothing".
- **AC-2.2** `models/deck/format_change_spec.rb` "merges a moved lot into the lot of its identity already in Considering, which survives; a lot alone keeps its id".
- **AC-2.3** `models/deck/format_change_spec.rb` "makes one lot of two dropped zones' lots of one identity" (a test registration made through `fake_vocabulary`).
- **AC-2.4** `models/deck/format_change_spec.rb` "keys a moved lot by the Considering zone's id, as Lot.key_for builds it, and exports it there".
- **AC-2.5** `models/deck/format_change_spec.rb` "counts the copies that moved, merged ones included, and not those already in Considering".
- **AC-2.6** `models/deck/format_change_spec.rb` "refuses, changing nothing, when a merge would pass 9,999 copies"; `requests/deck_formats_spec.rb` "answers 422 on the page with the alert and the chosen format kept when a merge passes the cap, changing nothing". The sentence and the page: screenshots `change-format-refused-*`.
- **AC-2.7** `models/deck/format_change_spec.rb` "holds as many copies after as before and touches no other lot".
- **AC-2.8** `models/deck/format_change_spec.rb` "leaves everything as it was when a write fails part way, and does not call it a refusal".
- **AC-2.9** `models/deck/format_change_spec.rb` "brings an undo of an earlier bulk removal back without a location once its zone is gone".
- **AC-2.10** `models/deck/format_change_spec.rb` "keeps Considering the same row and keeps the lots in it", "gives a deck with no Considering row one, from the registration, before the lots move into it".

### Story 3: Refusals and isolation

- **AC-3.1** `models/deck/format_change_spec.rb` "refuses a blank, unregistered or foreign-key format with 'Choose a format.' and writes nothing"; `requests/deck_formats_spec.rb` "answers 422 with 'Choose a format.' on the Format field for a value that is not a registered pair, writing nothing", "answers 400 without the deck parameter".
- **AC-3.2** `requests/deck_formats_spec.rb` "ignores an account, a kind, a parent, a zone, a collectible type, a name and a location id".
- **AC-3.3** `requests/deck_formats_spec.rb` "answers 404 for another account's deck, a place and a zone, and changes nothing", "answers 404 for the decks row's own id, which is not a location id".
- **AC-3.4** `requests/deck_formats_spec.rb` "answers 404 for a deck removed in another tab, on the page and on the change".
- **AC-3.5** `requests/deck_formats_spec.rb` "sends the visitor to sign in" (signed out).
- **AC-3.6** `requests/deck_formats_spec.rb` "changes nothing of another account's deck of the same name"; the export and preview of the other account: read (every read goes through `Current.account`; the change writes only the deck's own rows).
- **AC-3.7** read: the admin users, catalog and jobs pages are unchanged code and read no deck, zone, format or count (`docs/architecture/tenancy-and-accounts.md`, "The operator is not the user"); no example asserts it for this feature, see Gaps.

### Functional requirements and non-functional requirements

- **FR-1 (one transaction, no sixth key builder, writes in batches, reads under the lock):** read in `Deck::FormatChange` (the move is `Lot::BulkMove`, `Lot.key_for` rebuilds every key); `models/deck/format_change_spec.rb` "writes the same number of statements for 3 lots and for 30 when none merges" (a characterization, not a first-red example).
- **FR-2 (design system only, works without scripting, 422 and 303):** the system examples above; the request examples' statuses; no hard-coded colour, spacing or font in `additions.css`'s new rule: read. Deck files name no collectible, format or zone key but `considering`: `deck_core_spec.rb` (run, green).
- **NFR query count:** `requests/deck_formats_spec.rb` "costs the same number of queries whatever the deck holds".
- **NFR timing (2 s for 5,000 lots):** `requests/deck_format_change_timing_spec.rb` "moves 5,000 lots out of a dropped zone, 400 merging, in under 2 s" (`:timing`, never gating). Result, run with `SCANNER_TIMING=1`: **197 ms for 5,400 lots → 5,000 lots, 12,500 copies moved** (the bar is 2 s).
- **NFR cost per account, security, reliability:** read: no table, column, job, cache entry or file is added; every lookup goes through `Current.account` and the deck's location id; no stored name is rendered unescaped (the page uses the escaped helpers).

## Gaps

- **AC-3.7** has no example of its own: the criterion is "unchanged code" (no admin page reads a deck, a zone or a format), verified by reading.- **AC-1.5's excepted case** (a deck with no Considering row and a zone of another key named like it) has no example, because no path of the app makes one, as the criterion says.

## Where the code differs from the spec or the ADR

None found in what this task read: the spec, the area docs written at task 4.1 and the code agree.

## Measured bars

| Case | Time | Bar |
|---|---|---|
| A change that moves 5,000 lots (5,400 seeded, 400 merging into lots already in Considering; 12,500 copies moved), `SCANNER_TIMING=1` | 197 ms | 2 s (spec 041 AC-4.4) |

## Visual review

Screenshots (20, in `screenshots/`): each of five pages, wide (1280px window, full page, scaled to 1000px) and phone (a 390px frame; classic scrollbars, so the page has 375px of content width), light and dark: `<shot>-<wide|phone>-<light|dark>.jpg`. Real CSS, headless Firefox, factory data with placeholder printings (cards with no art, set codes like S17), taken from a throwaway system spec (not committed). `data-theme` is set from the shot's name in the page and in the frame, with a 0.7 s pause. Every phone page was measured at 800px frame height: `scrollWidth` equals `clientWidth` (375), so no horizontal overflow; the 60-character deck name (no space) wraps on every phone page. Each shot was looked at.

- `decks-before-*`: the Decks page of four decks (Izzet Tempo, a 60-character name, Krenko and Mono Red Burn) **without** the Change format button. **It is the page's markup with the Change format links deleted from the DOM after it rendered** (`a[href$="/format/edit"]` removed), not the old code, so it uses the new stylesheet: on a phone the two remaining buttons wrap onto lines of their own, where the old stylesheet kept them on one line (spec 062's `decks-phone-*.jpg`).
- `decks-after-*`: the same page with the button: Rename, Change format and Remove on one line at 1280px; on a phone the three wrap onto lines of their own and each row grows taller, with no overflow.
- `change-format-*`: the Change format page of Krenko, a Commander deck: the head "Change format", "Krenko · Commander" under it, the Format select on Commander, the hint, Save and Cancel, Decks current in the header and the tab bar.
- `change-format-refused-*`: the 422 refusal, reached by the real form (Modern chosen on the page, Save pressed): Edgar Markov, a Commander deck whose Commander lot and Considering lot are the same printing with 9,999 copies in Considering, shown again with the alert "Nothing changed. Sol Ring (S17 · 17) would have more than 9,999 copies in one lot." and Modern kept in the select (the set code and number are the factory's).
- `decks-changed-*`: the Decks page after Krenko was changed from Commander to Modern, with the notice "Changed “Krenko” to Modern. 2 cards moved to Considering." and Krenko's row reading Modern.

No defect was found in the shots. Two things to know: the phone frames show a classic scrollbar track at the right edge in the light theme, as spec 062's phone shots do; and the phone rows are tall (about 170px) because three 44px buttons stack, the width rule of spec 062 decision D5, which the maintainer ruled on for two buttons and which a third button extends.

## Implementation review

Pending.
