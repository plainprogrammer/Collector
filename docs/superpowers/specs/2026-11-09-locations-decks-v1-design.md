# Collector: Locations + Decks v1 design

**Status:** Draft design, 2026-11-09. A starting point for `sdd-specify`, not a spec.
**Reviewed against:** `plainprogrammer/collector` main at `fbc6494` (2026-11-09).
**Issues covered:** #49 (Decks as locations), #50 ("Free to use" on the card page), #187 (refusal-page shortcut). Lending and the scanner modes are recorded at the end for later.

## Why this exists

Most of the Locations theme is built: specs 029, 032, 033, 034, 037, 040 and 041. The remaining issues, #49 and #50, both assume decks exist. Nothing deck-shaped is in the codebase, and neither issue has acceptance criteria. So the remaining Locations work actually requires a Decks feature. This document gives that feature a v1 shape that fits the lot and location model already built.

## Decisions (maintainer, 2026-11-09)

1. **Decks are a full 1.0 feature.** A deck has two lists: owned cards and proxied cards. Whether a proxy is a real printed proxy or just a design placeholder doesn't matter here. The two lists are the foundation for the v2 deck analysis tooling.
2. **A lot's location is the only record of where a physical copy is.** Owned cards in a deck are lots whose location sits under that deck. Proxies are stored separately and are never lots.
3. **Zones are child locations of a deck.** Main, Sideboard, Commander and so on are locations of kind `deck_zone` whose parent is the deck's location. "1 copy in the sideboard" is an ordinary move into that zone. ADR 0025 then makes it its own lot, so no quantity is stored twice.
4. **Each format has a fixed set of zones,** defined in code alongside the format rules (see the earlier decision that formats are composable rules in code). Collector-defined zones and homebrew formats are v3 or later.
5. **A proxy references a specific printing** (a catalog entry and a finish), because a real proxy is usually printed from a particular card.
6. **Decks appear wherever locations are listed,** grouped under a "Decks" heading. A dedicated deck-builder workflow comes later.
7. **Lending is v2.** It fits this model as a `loan` kind of location: a lent copy is still owned and still in exactly one place. It is noted here so the `kind` column is designed with it in mind.

## Model

```
locations
  + kind       string, not null, default "place"    # place | deck | deck_zone  (v2: loan)
  + parent_id  integer, null → locations.id         # set only for deck_zone
  + zone       string, null                         # zone key for deck_zone, e.g. "main", "sideboard"

decks
  id, account_id
  location_id  unique, not null → locations.id (kind: deck)
  format       string, not null                     # key of a format defined in code
  timestamps

deck_proxies
  id, account_id
  location_id       not null → locations.id (kind: deck_zone)   # zone carries the deck
  catalog_entry_id  not null
  finish            string, null
  quantity          integer, not null, > 0
  unique (location_id, catalog_entry_id, finish)
  timestamps
```

### Invariants

- **A lot never sits directly in a `deck` location,** only in one of its zones. A deck's owned cards are the lots in its zones.
- **A `deck_zone` always has a `deck` parent, and nothing else has a parent.** There is only one level of nesting.
- **Proxies point at a zone location,** so a proxy's deck is the zone's parent. There is no separate `deck_id` to keep in sync.
- **"Free to use"** is owned copies minus copies in any `deck_zone` location (design system, line 9).
- **Name uniqueness has to change.** Today's index is unique on (account_id, name_key), so every deck's "Main" zone would collide. Scope it by parent instead, for example (account_id, parent_id, name_key), with top-level names still unique per account. A deck's name and a binder's name share that top-level space. That is probably right, but the spec should say so.
- **Removing a deck** removes its zones and proxies. It is refused while lots are in any of its zones, using the existing refusal (spec 032 decision 3). #187's shortcut then applies to the whole deck.

### Display

- In pickers, the location filter (spec 037), tiles and rows (spec 033): show a "Decks" group, and name a zone as "Deck › Zone". Filtering by a deck includes all its zones.
- The card page (#50) shows "Free to use", plus an "In decks" section listing the deck and zone of each copy (spec 004 deferred both).

### Export

Decks, zones and proxies are collector-owned data, so the export format goes to **version 4** in the same PR that adds them (ruling 19, ADR 0023 and ADR 0025 precedent). Proxies are keyed by the catalog source's ids, as lots are.

## Slices (one outcome per PR)

1. **#187: open a location's lots in bulk mode from its refusal page.** This is independent of decks and can go first. It must be a POST (spec 006 FR-1).
2. **Create, rename and remove a deck.** Creating a deck makes a `deck` location, its format's zone locations, and a `decks` row. The deck appears under "Decks" in navigation and pickers. Export version 4 lands here, unless the spec puts it in slice 4 with proxies, so the format rises only once.
3. **Deck page: owned cards by zone.** It uses the existing ways in: Move copies, bulk Move to…, typed entry and scanner sittings all target a zone.
4. **Proxies:** add a printing to a deck zone as a proxy, from search or a card page. Then change its quantity or remove it. The deck page shows owned and proxied cards side by side.
5. **#50: "Free to use" and "In decks" on the card page.**
6. *(Maybe 1.0, maybe v2)* **Fill from collection:** replace a proxy with a free owned copy, moving the lot into the zone and reducing the proxy.

## Open questions for the specs

- **Changing a deck's format** can remove zones. What happens to lots and proxies in a zone the new format doesn't have? Refuse the change, move them to a fallback zone, or something else?
- **Format validation in 1.0.** Earlier decisions made validation advisory and on demand. Is it in a 1.0 slice, or does 1.0 use formats only to define zones?
- **Which formats ship in 1.0,** and is there a "casual" format with just Main and Sideboard as the default?
- **Fill from collection matching** (slice 6): must the owned copy be the proxy's exact printing, or any printing of the same card? Proxies name a printing, but a player usually wants "any copy of this card".
- **Typed entry and scanner sittings into a zone:** check that specs 034 and 040's location pickers need nothing beyond the grouped list.
- **ADR:** zones as child locations, and the move of `kind` and `parent_id` onto locations, probably deserve an ADR that builds on ADR 0025.

## Recorded for later

- **Lending (v2):** a `loan` location kind, likely with a borrower and a date. Copies on loan aren't free to use either.
- **Collector-defined zones and homebrew formats (v3+).**
- **Deck-builder workflow** (post-1.0): a dedicated UI for designing decks, beyond the grouped pickers.
- **Scanner feedback (theme D, worked on separately):** scanning to add cards and scanning to look up or value a card are different modes, and both should be supported, which makes the app a multi-tool. A lookup scan is a visual search with no destination, so the sitting's location, condition and language controls (specs 040, 042 and #58) belong only to the add mode. Consider putting lookup under Search in navigation, and keeping Scan for adding to the collection.
