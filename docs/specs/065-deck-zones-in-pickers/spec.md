# Feature 065: Deck Zones in Every Location Picker and in the Collection Filter

**Status:** Draft
**Version:** 0.2.0
**Created:** 2026-11-10
**Last Updated:** 2026-11-10
**Depends on:** [spec 062](../062-create-rename-remove-a-deck/spec.md) (decks, zones and the label "Deck › Zone"; merged), [spec 057](../057-deck-design-rules/spec.md) (the grouped picker's rules, decisions 2, 3, 15, 16; merged); builds on [spec 032](../032-lot-in-a-location/spec.md) (a lot in a location), [spec 033](../033-location-on-tiles-and-rows/spec.md) (the place on tiles and rows), [spec 034](../034-location-in-typed-entry/spec.md) (number entry's place), [spec 037](../037-filter-collection-by-location/spec.md) (the location filter), [spec 040](../040-sitting-into-location/spec.md) (the sitting's place) and [spec 041](../041-move-many-lots/spec.md) (bulk Move to…)
**Branch:** `065-deck-zones-in-pickers`
**Issue:** [#252](https://github.com/plainprogrammer/Collector/issues/252)
**ADR:** none: ADR 0028 decided that a picker lists places only "until the pickers and the filter learn zones (#252)"; this spec is that step and changes none of its choices

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.2.0 | 2026-11-10 | From review round 1 (no blocking, four major): the selection after a move under a deck filter (decision 12, AC-6.11), tiles under a deck filter (decision 13), the deck refusal page's bulk shortcut left out on purpose (Non-Goals), the full supersession list, and minor fixes (the gate is "a place or a zone", `Choices` attaches each zone's parent, the predicate is scoped to the account, the plan's list of code paths, the design-system docs that go stale) |
| 0.1.0 | 2026-11-10 | First draft from issue #252, spec 062, ADR 0028 and the design system's `Form` and `FilterSelect` |

## Problem Statement

Spec 062 made a deck a location whose zones hold copies, and showed a zone as "Deck › Zone" wherever a lot's place is shown. It left every place a collector *chooses* a location as a list of places only: a copy reaches a zone today only through an import of a version 4 file. A collector with a deck cannot put a copy into its Main, cannot move copies there, cannot add by number into it, cannot scan into it, and cannot filter the collection to a deck's cards. The deck page ([#253](https://github.com/plainprogrammer/Collector/issues/253)) will rely on "owned copies get in through the existing ways" ([decks and locations issue design](../../superpowers/specs/2026-11-09-decks-and-locations-issues-design.md), issue [6] and [7]).

This spec teaches every picker and the collection filter about zones. The lot form, Move copies, bulk Move to…, number entry and the scanner sitting's place offer "No location", then the account's **Places**, then its **Decks**, whose options read "Deck › Zone", in native `<optgroup>` selects. The collection's location filter offers the same and, for each deck, "<Deck> (all zones)", which includes every zone of that deck. The spec adds no collector-owned data, so the export is unchanged.

> **Terms.** *Place, zone, deck, label ("Deck › Zone"), unplaced ("No location"), lot, bulk mode, selection, sitting* are as in [`collection-and-lots.md`](../../architecture/collection-and-lots.md), spec 062 and [`scanner.md`](../../architecture/scanner.md). A *picker* is a select in which a collector chooses where a copy is or goes: the lot form's Location, Move copies' To, bulk Move to…'s To, number entry's Location and the sitting's Location. The *filter* is the collection page's Location select (spec 037). A *choice* is a place or a zone, the two kinds a copy can be in; a deck's own row is never one.

## Goals

- Every picker offers the account's zones, grouped and named "Deck › Zone", and puts a copy in the one the collector chose.
- The collection filter offers zones, and "<Deck> (all zones)" for a deck, and narrows the grid, the table, the counts and bulk mode to it.
- One place in the code decides what a picker lists, so the five pickers and the filter cannot disagree.
- A lot form, a move or a filter never names another account's place, zone or deck, and never a deck's own row as a lot's place.
- Nothing about a proxy is built or changed: proxies don't exist yet (#254), and a copy that reaches a zone by any of these ways will never change one.

## Non-Goals

- The deck page, owned cards by zone, the shape panel ([#253](https://github.com/plainprogrammer/Collector/issues/253), [#256](https://github.com/plainprogrammer/Collector/issues/256)); proxies and everything that touches them ([#254](https://github.com/plainprogrammer/Collector/issues/254)); changing a deck's format ([#251](https://github.com/plainprogrammer/Collector/issues/251)).
- "Add to deck" from the card page ([#255](https://github.com/plainprogrammer/Collector/issues/255)), "Free to use" and "In decks" ([#50](https://github.com/plainprogrammer/Collector/issues/50)).
- A custom or searchable picker: the selects stay native (spec 057 decision 16).
- Any change to the export format, its version or the import: zones are not new data, a lot in a zone is already exported (spec 062 Story 6).
- Filtering by more than one location, sorting or grouping by location (spec 037 Non-Goals).
- Changing the number-entry list, the sitting or a bulk selection's lifetime.
- A "Move them in bulk mode" button on a deck's removal refusal page (`collection-and-lots.md` says it waits for this filter). The filter can now open a deck in bulk mode, but spec 059's shortcut (`Locations::SelectionsController`) stays places-only here; it is a follow-up for the maintainer to file, and the area doc says so.

## Users and Context

**Primary user:** a signed-in collector with at least one deck, adding, moving or finding copies. **Usage context:** a collector builds a deck by adding or moving cards into its Main or Considering, and later looks at "what is in this deck" through the collection filter; on a phone they scan or type numbers into a zone. A collector with places only sees no change at all.

**Mental model:** "a deck is somewhere I keep cards, and its zones are the shelves". They say "put it in Izzet Tempo's Main".

## Decisions

1. **One definition of what a picker lists: `Location::Choices`.** A plain Ruby object under `app/models/location/`, given an account, reading the account's locations in **one** statement and giving: the places (the locations page's order), the decks (comparison key, then name) each with its zones (in the deck's zone order, `Deck#zones`: by id), whether the account has any choice (a place or a zone: a deck with no zone, which only an import's repair could leave, is not one and its Decks group is never drawn empty), and whether it has a deck. It sets each zone's `parent` from that one read, so a label costs no further query wherever a picker, the filter's sentence, the sitting's line or a refusal names one. Pickers, the filter and their writes use it and `Location.placeable` (a scope: `place` and `deck_zone`, never `deck`), so ADR 0028's rule that every list says which kind it means still holds: this change widens the "places only" list to "places and zones" on purpose, in the area doc and in one scope, and a deck's own row is never in it.
2. **The grouped select** is the design system's (spec 057 decisions 2, 3, 15; `Form` and `FilterSelect`): the leading options outside any group (the pickers: "No location", or "Choose…" then "No location" for a required one; the filter: "All locations", "No location"), then `optgroup` "Places", then `optgroup` "Decks". A group with nothing in it is omitted. With no deck in the account the select is flat as it is today (no optgroup), so a collector with places only sees no change. Inside "Decks" a picker lists, per deck, its zones as "Deck › Zone" (the label, `Location::Placement.label`), decks in comparison-key order, each deck's zones in zone order. The values are the choice's location id.
3. **The gate.** Every picker, the filter, Move to… and the lot form's field show **while the account has a place or a zone** (`Location::Choices#any?`; a deck has zones from the moment it exists, spec 062 AC-1.3, so in practice a place or a deck). They were shown while the account had a place, with the exception of the table's and tiles' place column (a place or a lot in a zone). The place column now follows the same gate, which removes the extra read that rule cost (spec 062 NFR). **Supersedes** spec 062 AC-5.8a: an account with a deck and no place now gets the selects, the filter, Move to… and the form's field.
4. **The filter's value for a whole deck** is `deck:<location id>` (the id of at most 18 digits without leading zeros, as spec 037 decision 1's id): the canonical values are now `""`, `"none"`, an id of a place or a zone, and `deck:<id>`; anything else reads as all. A deck's value matches the lots in any of its zones. The page resolves the value against the account's choices and decks: another account's id, a removed one, a deck's own id without the prefix, a zone's id with the prefix, or a malformed value is all, with 200, as spec 037 decision 7 says for every unknown value. A stored bulk selection applies its value as a plain predicate on the account's lots and never re-resolves it to all (spec 037 decision 7): a removed deck selects nothing. `CollectionFilter::Place.apply` turns `deck:<id>` into a join on the lot's location with `locations.parent_id = <id>` and `locations.account_id = lots.account_id`, applied to a relation of the account's lots, so another account's deck id matches no lot and no unscoped lookup of locations is made. A raw value is parsed only by `Place.parse` and turned into a predicate only by `Place.apply`.
5. **A lot in a zone is under its zone and its deck, and nowhere else.** Under "No location" or a place it is not shown; under a zone only that zone's lots; under "<Deck> (all zones)" every lot in any zone of the deck; under "All locations" every lot. Spec 062 AC-5.8's rule for "No location" and a place stands.
6. **Edit copy's Location is the select, for a lot in a zone too.** The read-only text of spec 062 AC-5.5 was there because a select of places would unplace the lot on save; the select now lists the zone and has it selected, so a save keeps it, and the text and its `c-field__static` rule have no use left. **Supersedes** spec 062 AC-5.5 and the part of decision 6 that says so; the other places spec 062 decision 6 lists (bulk Set condition, removal's Undo, number entry's and the scanner's Undo keep a lot's zone) are unchanged and re-proved. A lot whose zone was chosen in the form and removed with its deck before the save answers 404, as a removed place does (spec 032 AC-6.7).
7. **Move copies and bulk Move to… offer zones as destinations.** Move copies: "No location" first unless the lot is unplaced, then Places, then Decks, the lot's own place or zone left out. Bulk Move to…: "Choose…", "No location" (left out when the filter is "No location"), then Places and Decks; the filter's own place or zone is left out, and a deck filter leaves out nothing (the selected lots sit in several zones, and a lot already in the destination is "already there" as for a place, spec 041 Terms). A lot moved into a zone merges into the lot of its identity there, splits and caps exactly as a move to a place does (`Lot::Move`, `Lot::BulkMove` need no change: a zone is a location with an id). A destination that is a deck's own row, another account's or a removed location is 404.
8. **Number entry's line and the scanner sitting** take a zone like a place. Number entry's field error "That location isn't one of yours any more. Choose again." is shown for an id that is no choice of the account (a deck's own row, another account's, a removed one); the sitting's Set answers 422 with its own sentence for the same. A sitting's place may be a zone; a deck removed under a sitting clears the sitting's place through the foreign key's `on delete set null` as a removed place does (spec 040 decision 7).
9. **Every notice and sentence that names where copies went names the label.** "Added 2 × … to Izzet Tempo › Main.", "Moved … to Izzet Tempo › Main.", "The selected items are already in Izzet Tempo › Main.", the sitting's "Cards you scan now: …, in Izzet Tempo › Main.", and the filter's empty sentence "No cards in your collection are in “Izzet Tempo › Main”." For a deck filter the sentence names the deck: "…are in “Izzet Tempo”."
10. **A deck with many zones, on a phone.** The select stays native and one-line options are clipped by the browser, as for a long place name (spec 040 AC-7.1; `FilterSelect`'s 220px, 300px from a 640px collection). The phone's native picker draws the open list, with its own group headers. Nothing depends on how it draws it, and the "Deck › Zone" text puts the part that tells zones apart last, so the filter's 300px cap shows it (spec 057 decision 4). A before and after screenshot at a phone's width is in the pull request.
11. **A proxy is never touched.** There are no proxies yet (#254); this spec adds no proxy code, field, count, parameter or comment that assumes one beyond saying "a copy that reaches a zone by these ways will never change a proxy" in the area doc, so #254 inherits the rule (issue design decision 8).

12. **The selection after a bulk move under a filter is as spec 041 says.** After Move to… under all locations the lots now holding the moved copies are selected; under any location filter, "No location", a place, a zone or a deck, the selection restarts empty (`BulkSelection#after_move!`), even when the lots still match the filter (a move from one zone of a deck to another under "<Deck> (all zones)"). Nothing of spec 041 changes: a restart empty is always safe, and the bar then reads "0 of N selected".
13. **Tiles under a filter show no place line,** a deck filter's included, as spec 037 decision 3 says (`CollectionGrid#places_of` returns nothing under any location filter). The table under a deck filter shows each row's "Deck › Zone", which is where a collector tells Main from Considering. Spec 037 decision 3 is unchanged.

## User Stories

### Story 1: Put a copy in a zone from the lot form

**As a** collector **I want** "Add a copy" and "Edit copy" to offer my decks' zones **So that** a copy goes where it will be used

- [ ] **AC-1.1** Given an account with places and a deck When the lot form opens (Add a copy, Edit copy) Then Location is a native select: "No location", then an `optgroup` "Places" with the places in the locations page's order, then an `optgroup` "Decks" whose options read "Deck › Zone", decks by comparison key and each deck's zones in zone order; the group labels are exactly "Places" and "Decks"
- [ ] **AC-1.2** Given an account with a deck and no place Then the select is "No location" then "Decks" only (no empty "Places" group), and the form shows the select instead of the hint "Add a location to keep copies in one."
- [ ] **AC-1.3** Given an account with places and no deck Then the select is flat, "No location" then the places, as before
- [ ] **AC-1.4** Given an account with neither a place nor a deck Then the form shows the hint "Add a location to keep copies in one." as before
- [ ] **AC-1.5** Given the form with a zone chosen When it is submitted Then the copies are added to that zone (merging into the lot of the same identity there), 303 to the card page with the notice "Added <n> × <name> (<SET> · <number>) to Izzet Tempo › Main."
- [ ] **AC-1.6** Given a lot in a zone When its "Edit copy" opens Then Location is the select with that zone selected and no read-only text, and saving without touching it keeps the lot in the zone, merging as every edit does; choosing another zone, a place or "No location" moves the lot there (merging into the identity there)
- [ ] **AC-1.7** Given a `location_id` that is a deck's own row, another account's place, zone or deck, a removed location or text that isn't an id When the form is submitted Then the answer is 404 and nothing is written; a request that names no `location_id` on Edit copy keeps the lot's place (spec 032 O3)
- [ ] **AC-1.8** Given any of those forms Then no `account_id`, kind or parent is read from the request (spec 004 AC-12.3)

### Story 2: Move copies into a zone

- [ ] **AC-2.1** Given a lot When "Move copies" opens Then To is "No location" first (unless the lot is unplaced), then Places, then Decks, the lot's own place or zone left out of the list; with no place and no deck the page says "You have no locations yet."
- [ ] **AC-2.2** Given some or all copies moved to a zone When submitted Then they move, merge, split and cap as a move to a place does (spec 032 AC-3.3–AC-3.11), and the notice reads "Moved <n> × <name> (<SET> · <number>) to Izzet Tempo › Main."
- [ ] **AC-2.3** Given a lot in a zone moved to another zone of the same deck or to another deck's zone Then it moves; moved to its own zone it is refused with "Those copies are already there."
- [ ] **AC-2.4** Given a destination that is a deck's own row, another account's location of any kind or a removed one Then the answer is 404 and nothing is changed

### Story 3: Move many lots into a zone

- [ ] **AC-3.1** Given bulk mode with lots selected When "Move to…" opens Then To is "Choose…" (submitting `""`), "No location", then Places, then Decks (zones as "Deck › Zone"); the filter's own place or zone is left out (a deck filter leaves out nothing), "No location" is left out under the "No location" filter, and Move to… is offered while the account has a place or a deck
- [ ] **AC-3.2** Given a selection and a zone When "Move" is submitted Then every copy of every selected lot goes to the zone, lots that reach one identity there merge, a selected lot already in the zone stays and counts as "already there", all or nothing at the cap, 303 to the bulk table with "Moved <n> items to Izzet Tempo › Main." (plus "<m> items were already there." when any were) (spec 041 AC-3.1–AC-3.8)
- [ ] **AC-3.3** Given a destination that is a deck's own row, another account's location or a removed one Then the answer is 404 and no lot changes; a refusal's "The selected items are already in Izzet Tempo › Main." names the label
- [ ] **AC-3.4** Given lots selected under "<Deck> (all zones)" and a place as the destination Then every selected lot, in whichever zone, moves to the place

### Story 4: Add by number into a zone

- [ ] **AC-4.1** Given an account with places or a deck When the number-entry line shows Then its Location is "No location" first, then Places, then Decks as "Deck › Zone", while the account has either, with the chosen value kept after an add (spec 034 decision 2)
- [ ] **AC-4.2** Given a line with a zone chosen When it is added Then the copies are in that zone, the notice reads "Added <n> × <name> (<SET> · <number>, <finish>) in Izzet Tempo › Main to your collection.", the list's line names the zone and its Undo keeps working (spec 062 AC-5.7)
- [ ] **AC-4.3** Given a `location` that is a deck's own row, another account's or a removed location Then the line is refused as typed with "That location isn't one of yours any more. Choose again." on the field and nothing is added
- [ ] **AC-4.4** Given a link whose `location` is a zone the account still has Then the select shows it chosen

### Story 5: Scan into a zone

- [ ] **AC-5.1** Given an account with places or a deck When the scanner's sitting panel shows Then its Location select lists "No location", Places, Decks as above, in every state of the panel (none open, open, ended, after "Set")
- [ ] **AC-5.2** Given a zone chosen with "Set" When cards are added Then each copy goes into that zone, and the answer says "Cards you scan now: <condition>, in Izzet Tempo › Main." and the panel's "in …" line names the label
- [ ] **AC-5.3** Given a value that is a deck's own row, another account's location, a removed one or not a number Then "Set" answers 422 "That location isn't one of yours any more. Choose again." and changes nothing
- [ ] **AC-5.4** Given a sitting whose zone goes with a removed deck Then the sitting is unplaced and the next add is unplaced (spec 040 AC-3.2)
- [ ] **AC-5.5** Given the scanner's files Then they still name no collectible type beyond what they did (`spec/scanner_sitting_core_spec.rb`)

### Story 6: Filter the collection by a zone or a deck

- [ ] **AC-6.1** Given an account with a place or a deck When the collection page shows (grid or table, not empty) Then the filter bar's Location select is "All locations" and "No location" outside any group, then `optgroup` "Places", then `optgroup` "Decks" in which each deck has first "<Deck> (all zones)" (value `deck:<id>`) and then its zones as "Deck › Zone"; with no deck the select is flat; the select keeps its accessible name "Location" and its Filter button
- [ ] **AC-6.2** Given lots in two zones of one deck and in a place When the filter is one zone Then the grid and the table show only that zone's lots, each tile's quantity the copies in that zone, no tile shows a place line, and the count line reads "<matching> of <total> items"
- [ ] **AC-6.3** Given the same lots When the filter is "<Deck> (all zones)" Then both zones' lots show (and no other deck's, no place's), tiles sum the copies in all the deck's zones and show no place line (decision 13), and the table shows each row's "Deck › Zone" in its Location column
- [ ] **AC-6.4** Given a zone or a deck whose lots match nothing When it is chosen Then the page reads "No cards in your collection are in “Izzet Tempo › Main”." (a deck: “Izzet Tempo”) or, with a name filter, `No cards in your collection match "<query>" in “…”.`, with "0 of <total> items"
- [ ] **AC-6.5** Given `location` is another account's id, a removed id, a deck's own id without the prefix, `deck:` with a zone's or a place's id, a malformed value or an id with leading zeros Then the page is the whole collection with 200 and "All locations" selected, and nothing of another account is shown or named
- [ ] **AC-6.6** Given the filter is on Then it is kept by paging, sort headers, the view switch, "Edit many" and the return after Edit copy or Remove, as spec 037 AC-4.1 says for a place; a view saved from a URL doesn't save the location
- [ ] **AC-6.7** Given bulk mode under a zone or a deck filter When the collector selects every matching lot and uses Set condition, Move to… or Remove Then exactly the matching lots change; lots outside the filter whose ids are submitted are ignored; a selection made under one value shows nothing selected under another (spec 037 AC-5.1–AC-5.3)
- [ ] **AC-6.8** Given a stored selection under `deck:<id>` whose deck was removed in another tab When an action runs Then nothing is removed or changed and the answer is "None of the selected items are in your collection any more." (spec 037 AC-5.5, AC-5.8)
- [ ] **AC-6.9** Given a deck's or zone's name containing `<`, `&` or `"` Then every option, sentence and notice shows it as text (spec 037 AC-6.6)
- [ ] **AC-6.10** Given an account with a deck and no place, with lots in its zones or with none Then the table's Location column and the tiles' place line show (the gate of decision 3) as they do for an account with a place, and the statement that used to ask whether a lot is in a zone is no longer made
- [ ] **AC-6.11** Given bulk mode under "<Deck> (all zones)" with lots selected When Move to… sends them to another zone of the same deck Then they move and the selection restarts empty with "Moved <n> items to Izzet Tempo › Sideboard.", as under any location filter (decision 12)

### Story 7: Tiles and rows name a zone

- [ ] **AC-7.1** Given a lot in a zone When a tile, a table row or the phone line shows its place Then it reads "Deck › Zone" and sorts under its deck's name (spec 062 AC-5.4; spec 033), unchanged; this spec adds a spec that proves it again through the pickers' own flows (a copy added into a zone by the form, number entry and the scanner shows "Deck › Zone" on the collection page)

### Story 8: Tenancy, cost and guards

- [ ] **AC-8.1** Given two accounts, each with places and decks When either uses any picker, Move copies, bulk Move to… or the filter Then no option, notice or sentence shows the other account's place, deck or zone, and an id of the other's in any of those requests is refused as the surface refuses an id that isn't the account's (404, the field error, or all), changing nothing
- [ ] **AC-8.2** Given any picker or the filter Then it reads the account's locations in one statement (`Location::Choices`), so the number of statements doesn't grow with the number of places, decks or zones; the collection grid's and table's statements are no more than they were (spec 062's query counts) and the extra read of `place_column?` for an account with no place is gone
- [ ] **AC-8.3** Given `Location::Choices` and its helper Then they and the files that render a picker (the five forms, the filter select, the helper) name no collectible, source, format key or zone key but `considering`: the new files are `app/models/location/choices.rb` and `app/helpers/location_choices_helper.rb`, and `spec/deck_core_spec.rb` lists them and its count of 17 grows by two; `spec/number_entry_core_spec.rb`, `spec/import_apply_core_spec.rb` and `spec/scanner_sitting_core_spec.rb` still pass, and `Location::Name`'s parity spec is unchanged
- [ ] **AC-8.4** Given a lookup of a destination, a choice or a filter value in any of these paths Then it goes through the account (`Current.account` in a request; the selection's account for a stored selection) and `Location.placeable`, and the filter's `deck:` value through the scoped predicate of decision 4, never a bare `Location.find` or an unscoped `Location.where(parent_id:)`, and a deck's own row cannot be returned by a path that writes `lots.location_id` (the bulk move's `update_all` included)
- [ ] **AC-8.5** Given the export, the import preview and the apply Then they are unchanged: the export's `locations` still lists places only and a zone is named by its deck and key in a lot's `location` (spec 062 Story 6), and the round trip of an account with lots in zones put there by these pickers is unchanged

## Functional Requirements

### FR-1: One source for the choices

**Must:** `Location::Choices` and `Location.placeable` as decision 1; a view helper that renders the grouped options from a `Choices` and the leading options a surface needs; every picker and the filter use them. **Must not:** a second list of places in a controller, view or model; a query in a view; a deck's own row in any list.

### FR-2: The pickers

**Must:** the five pickers of Stories 1 to 5, in the order and with the gate of decisions 2 and 3, native selects, working without scripting. **Must not:** a custom list, a script, a changed form field name or a changed request shape (a zone's id travels as the same `location_id` or `location`).

### FR-3: The filter

**Must:** decisions 4 and 5, through `CollectionFilter` and `CollectionFilter::Place` (the one place that turns the value into a predicate), carried by every link and form that carries `location` today. **Must not:** parse a raw filter value anywhere but `Place.parse`, or make a predicate from one anywhere but `Place.apply`; widen another account's reach.

### FR-4: The messages

**Must:** decision 9, the label from `Location#label` or `Lot#place_label`. **Must not:** show a zone's name without its deck.

## Non-Functional Requirements

### Performance

Each picker adds no statement beyond the one read of the account's locations it already made (a deck's zones come in the same read); the table's and grid's counts do not rise; an account with 450 places and 50 decks (the limit counts both together) and their zones renders a picker in one statement (AC-8.2).

### Security

Tenant isolation as AC-8.1; no new parameter is permitted (`params.expect` lists unchanged); option text is escaped (AC-6.9); no `html_safe`. The operator sees no deck, zone or name (hosted-door rule 2); nothing here is visible to an admin page.

### Reliability

A location removed between a form's rendering and its submit answers 404 or the field error as before; a deck removed under a bulk selection or a sitting leaves them safe (AC-6.8, AC-5.4). No lot is ever in a deck's own row.

### Accessibility and design

Native selects with their labels; group labels are real `optgroup` labels; the styling rules exist (`additions.css`, spec 057); the page holds at 360px with no sideways scroll. The pull request carries before and after screenshots of the lot form, the filter and the sitting at 1280px and at a phone's width.

## Error Scenarios

| Scenario | Behaviour |
|----------|-----------|
| A zone is chosen and its deck is removed before the submit | 404 for the forms and Move, the field error for number entry, 422 for the sitting's Set, 404 for the bulk move |
| The filter names a deck that was removed | All locations, 200; a stored selection selects nothing and acts on nothing |
| A deck's format is no longer registered | Its zones are still offered by the labels stored (spec 062 Error Scenarios); nothing here reads the format |
| An account has a deck and no lots | The picker offers its zones; filtering to one shows the empty sentence |
| A deck name or zone name is long | The option is clipped by the browser; the page does not scroll sideways |
| A request carries `account_id`, `kind`, `parent_id` | Ignored, as today |

## Open Questions

None. The spec's recommendations (decisions 3, 6 and 10) are flagged for the maintainer's review at Gate A.

## Out of Scope (Future Considerations)

- Counts or "free to use" beside a zone in a picker; recently used zones; the deck page's own "Add" ([#253](https://github.com/plainprogrammer/Collector/issues/253)).
- Copies that reach a zone changing a proxy: never, by decision 11.

## Supersedes and updates

- **Supersedes** spec 062 AC-5.8a: the gate is a place or a deck, and the place column follows it; decision 3.
- **Supersedes** spec 062 AC-5.5 and decision 6's read-only Location field for a lot in a zone: Edit copy shows the select with the zone chosen; decision 6.
- **Supersedes** spec 062 AC-5.1, AC-5.2 and AC-5.6 where they say the lot form, Move copies, bulk Move to…, number entry, the sitting and the filter list places only and that a zone's id is refused or read as all: they list places and zones, a deck's own id is still refused, and for the filter a zone's id is a value now.
- **Supersedes** spec 062 AC-5.7a's "the To select offers places only … a zone is never a filter value in this spec" and spec 062 decision 1's list of places-only surfaces: they are places and zones from here, a deck's own row never.
- **Supersedes** spec 040's sitting select ("the account's places", decision 3 and AC-3.1 as they list it) for zones too.
- **Supersedes** spec 037 decision 1's three kinds of value and decision 6's list ("the account's locations... never a deck or a zone"): a zone and `deck:<id>` are values; spec 037 AC-1.1's list gains the groups.
- **Supersedes** spec 041 AC-2.1's list of destinations ("places") to places and zones, and spec 034 decision 1's "places only" for number entry's select.
- **Leaves** spec 041 decision 6 and AC-3.13 (the selection after a move) and spec 037 decision 3 (no place line under a filter) as they are (decisions 12, 13).
- **Updates** [`collection-and-lots.md`](../../architecture/collection-and-lots.md) ("Every list of locations says which kind it means", the lot form, Move copies, bulk Move to…, number entry, the filter, the gate, and every sentence that points to #252 as future work: the refusal page's shortcut stays open, now "not built"), [`scanner.md`](../../architecture/scanner.md) (the sitting's Location select) and the design system's `Form`, `FilterSelect`, `DecksIndex` and README ("What is live", the App additions line; `c-field__static` and its rule removed), in the same pull request.

## Notes for the plan

- **Guards that fail until updated:** `spec/deck_core_spec.rb` (its file list and count of 17), `spec/requests/zone_place_label_spec.rb` and the spec 062 examples for AC-5.1, AC-5.2, AC-5.5, AC-5.6, AC-5.8a (written to say "places only"; they change first, to fail against the old code), `spec/number_entry_core_spec.rb`, `spec/import_apply_core_spec.rb` (it lists `Lot::Move`, bulk Move to… files), `spec/scanner_sitting_core_spec.rb`, `spec/models/location/name_parity_spec.rb`, `spec/requests/query_counts_spec.rb`, the account order of `has_many` (untouched).
- **Where the lists live today:** `LotsController#set_locations` and `#chosen_location`, `Lots::MovesController#set_destinations` and `#destination`, `Collections::MovesController` (`destination_for`, `require_locations`, `set_destinations`), `NumberEntry::LineForm#locations` and `#location_record`, `ScannerSitting#account_locations`, `Scanner::SittingsController#update` and `#chosen_message`, `ScannersHelper` (the sitting's "in …" line), `CollectionFilter#locations`, `#places?`, `#place_column?`, `#chosen_location`, `CollectionFilter::Place`, `collections/_location_select`, `collections/_filter_bar`, `collections/_bulk`, `collections/_no_match`, `Lot::BulkMove::NothingToMove`, `CollectionsHelper#moved_message`, `Collections::SelectionsController#offered?` (`places.exists?`: left as it is, Move to… would quietly stop being offered), `table.places?`/`listing.places?` in `collections/_bulk` and `_filter_bar`, `CollectionGrid#places_of`, `BulkSelection#after_move!`, `LotsController#set_zone_label` and `lot_params`, `ScannersHelper` (`.name` of the sitting's place). Comments that say "places only" go stale with the change: `Location.places`'s and the class header, `Lot::BulkMove`'s initializer and `NothingToMove`, `ScannerSitting#account_locations`, and the controllers' own.
- **No migration, no export change, no new dependency.** `BulkSelection#location_filter` is a string column and holds `deck:<id>`.
