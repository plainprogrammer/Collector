# Verification: Spec 065, Deck Zones in Every Location Picker and in the Collection Filter

Branch `065-deck-zones-in-pickers`, issue [#252](https://github.com/plainprogrammer/Collector/issues/252). Spec v0.2.0 (Gate A) and plan v0.3.0 (Gate B), both approved by the coordinator under the maintainer's delegation on 2026-11-10.

## Evidence

- `bin/rspec --dry-run` on the branch at `a8e61d52`: 3,727 examples (the whole suite, counted, not run). Every file the branch changed was run, serially, by the implementer of its batch; the last combined run (batch "review fixes") was 463 examples, 0 failures, across the changed files plus `spec/models/location`, `spec/models/collection_filter`, the lot, bulk move, number entry, scanner, filter and query-count request specs, and `spec/system/deck_zone_pickers_spec.rb`, `lot_edit_zone_spec.rb` and `card_page_spec.rb` in headless Firefox.
- `bin/rubocop` on the changed Ruby: no offenses. `bin/yard doc`: no warnings.
- The full `bin/ci` is run once, in the coordinator's slot, before the push; its result is quoted in the PR, not here.

## Acceptance criteria

Each criterion and the example that proves it (the examples that could not fail first are named after the table).

| AC | Proof |
|---|---|
| 1.1 | `lots_spec` "lists No location, Places, then Decks as Deck › Zone, on the new and the edit form"; `location_choices_helper_spec` "groups Places then Decks…" |
| 1.2, 1.3, 1.4 | `lots_spec` "offers the select to an account with a deck and no place", "is flat for an account with places and no deck, and keeps the hint for one with neither" |
| 1.5 | `lots_spec` "adds copies to the zone chosen and names it in the notice" (and a twin lot in the zone absorbing them) |
| 1.6 | `lots_spec` "shows the select with the zone chosen", "moves a lot in a zone to a place, another zone or none through Edit copy's select", "answers 404 when the zone's deck is removed before the save"; `spec/system/lot_edit_zone_spec.rb` |
| 1.7, 1.8 | `lots_spec` "refuses a deck's own id and another account's place, zone and deck", "permits only quantity, finish, condition, price paid and location"; `location_spec` `.find_placeable!` |
| 2.1–2.4 | `lot_moves_spec` (the To list for a lot in a place and in a zone; a move into a zone, merging; a zone to a zone of the same deck and to another deck's; the lot's own zone refused; a deck's own id and another account's zone 404) |
| 3.1–3.4 | `bulk_move_spec` (the grouped To list, the filter's own zone left out, a move into a zone with merge, cap and "already there", 404s, the label in the notice and the refusal); `collection_deck_filter_spec` (a deck filter leaves nothing out; lots selected under a deck's value moved to a place); `lot/bulk_move_spec` |
| 4.1–4.4 | `number_entries_spec` (the grouped list, an add into a zone, its list line and Undo, a deck's own id and another account's zone refused as typed, the link's `location` kept); `number_entry/line_form_spec` |
| 5.1–5.5 | `scanner/sittings_spec` (the grouped control in each panel state incl. the ended summary, Set to a zone and the sentence, refusals incl. "012", a removed deck unplaces the sitting and the next add is unplaced); `scanner_sitting_core_spec` |
| 6.1–6.11 | `collection_deck_filter_spec` (the select, flat without a deck, one zone, a whole deck, empty sentences, unresolvable values read as all, links keep the value, deck-only account shows the select and column, escaping, bulk Set condition / Remove / Move under a deck, a changed value shows nothing selected, an orphaned stored value acts on nothing, a move within the deck restarts the selection empty); `collection_filter/place_spec`; `collection_location_select_spec`; `collection_places_spec`; `spec/system/deck_zone_pickers_spec.rb` (choose a zone, Filter, then "all zones") |
| 7.1 | `deck_zone_pickers_spec` "shows a copy put into a zone by the lot form, number entry and the scanner as Deck › Zone"; `zone_place_label_spec` (spec 062's, unchanged) |
| 8.1 | `deck_zone_pickers_spec` tenancy examples (every picker's page names nothing of another account; every write path refuses another account's ids; the filter reads them as all) |
| 8.2 | `location/choices_spec` "reads the account's locations in one statement"; `query_counts_spec` (decks add no statement; a deck-only account's counts equal an account with a place) |
| 8.3 | `deck_core_spec` (the two new files and, added by the review, the four picker views) with `number_entry_core_spec`, `import_apply_core_spec`, `scanner_sitting_core_spec` and `models/location/name_parity_spec` unchanged and green |
| 8.4 | `location_spec` `.placeable` / `.find_placeable!`; `collection_filter/place_spec` (a wider relation, another account's deck id matches nothing); the foreign-id 404 examples of each write path |
| 8.5 | `deck_zone_pickers_spec` "keeps the export's locations to places and writes a lot in a zone by deck and key" |

## Examples that could not fail first

Written test-first, but they passed on arrival, so they are characterisations or regression proofs, named so in their commit bodies:

- Task 6.1's `deck_zone_pickers_spec` (AC-7.1, AC-8.1, AC-8.5): the behaviour exists after Phases 2 to 5, so these are regression proofs added last.
- The query-count examples of `query_counts_spec` (AC-8.2): the old filter also made one read of the account's locations, so equal counts held before the change too.
- The 404s for a deck's own id and another account's location on the lot form, Move copies and bulk move, the flat select with no deck, the hint with neither place nor deck, and the removed-deck race: the old places-only lookups already refused them. The "12abc" case on the lot form passed because id 12 did not exist; the `"#{id}abc"` case on Move copies failed first on its merits.
- The sitting's refusals of a deck's own id, another account's zone and "12abc", the sitting unplaced when its deck is removed (the foreign key already did it), and number entry's Undo leaving a lot in its zone (spec 062 AC-5.7, re-proved).
- AC-6.8's example: a whole-deck selection can only be orphaned by removing an empty deck (a deck holding lots can't be removed), so it shows the stored-value rule, not a removal of lots (commented there).

## Deviations from the plan (all recorded in the commits)

- `Location.find_placeable!` and `Location::ID_TEXT` were added (plan review round 1: `find("12abc")` casts to 12); `CollectionFilter::Place::ID` is now `Location::ID_TEXT`. The sitting's lookup guards with `ID_TEXT` and keeps `placeable.find_by`; number entry reads `Choices#find`. So "writes name their location through `find_placeable!`" is true of the lot form, Move copies and bulk Move to…; the area doc says exactly that.
- `_sitting.html.erb` already had a local called `choices` (the heading words); it is now `words`.
- The plan's bulk-removal and ghost-deck examples passed on arrival; they were reshaped to send the header toggle with "every matching lot", which is the real form, so they fail without the feature.
- The browser pass found that Move copies' page head overflowed sideways at 360px for a 60-character name with no space, for a place too (since spec 032). The spec's Error Scenarios row promises no sideways scroll, so it was fixed in this branch: `.c-pagehead__stats { overflow-wrap:anywhere; }` at the end of `additions.css`, and the system example uses the 60-character name.
- AC-6.6's return after Edit copy had no place example to mirror; it is written from the table's Edit copy link.

## Screenshots

`docs/specs/065-deck-zones-in-pickers/screenshots/` (48 JPEGs, 1.3 MB): the lot form's Location field, the collection filter bar and the scanner sitting panel, at 1280px and in a 390px frame, light and dark, "before" and "after", plus "-options" shots with the select drawn expanded so its groups read as text (headless Firefox does not capture an open native select). Factory data and placeholder printings. "Before" is emulated, not built from `main`: a throwaway spec stubbed `Location::Choices#decks` to `[]`, so the pickers list places only, as they did. What the shots show: the grouped lists as designed ("No location", Places, Decks with "Deck › Zone"; the filter's "<Deck> (all zones)" first in each deck's group); no sideways scroll at 390px; light shots light and dark shots dark. Seen and accepted: at the filter's 220px phone cap a long zone label is clipped by the browser (spec decision 10; 300px from 640px), a tile's place line ellipsises "Commander night › Comma…" (spec 033, unchanged), and the expanded "-options" filter bar distorts the row beside it (an artefact of the `size` trick, not of the page). The scanner shots show "The card catalog hasn't been loaded yet" because the factory data has no refresh. Console errors were not read (headless Selenium cannot read the console in this setup).

## Left open for the maintainer

- [#302](https://github.com/plainprogrammer/Collector/issues/302): the deck removal refusal page's "Move them in bulk mode" shortcut (the filter now knows decks; spec 059's shortcut stays places-only here). Filed by the coordinator.

## Implementation review

SPEC-ALIGNED

Mode B, read-only, Opus, on the branch at the Phase 6.3 commit (`80331fab`), against spec v0.2.0 and plan v0.3.0. No blocking and no major findings: every write path takes its location from the account (`find_placeable!`, the sitting's `placeable.find_by` behind `Location::ID_TEXT`, number entry's `Choices#find`, bulk move's `destination_for`) and none can put a deck's own row in `lots.location_id`, `Lot::BulkMove`'s `update_all` included; the stored `deck:<id>` selection goes through `Place.apply` whose subquery is tied to the lot's account; "12abc" and "012" are refused everywhere; one statement reads the account's locations and the zones' parents are set from it; no stale `zone_label`, `@destinations`, `places?`, `.locations` or scanner `locations:` remained; every gate is `Choices#any?` / `choices?`; decisions 1 to 13 are honoured; docs agree with code. Eight minor findings, all taken in the follow-up commits `e1de9b42` to `a8e61d52`: the Move copies page head's overflow (fixed, see above), missing proofs for a zone to zone move and for merging into a zone (AC-2.3, AC-1.5, AC-2.2), the AC-6.5 value list, AC-6.8's orphan comment, AC-8.2's deck-only count, small gaps (AC-5.3 "012", AC-5.4 next add unplaced, AC-6.6, AC-6.9, AC-3.1's exact list), comment wrapping and `Choices#find` using `ID_TEXT`, and the picker views joining `deck_core_spec`'s guard.
