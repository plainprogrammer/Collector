# Decks and Locations: the issue set for the rest of the build-out

**Date:** 2026-11-09. **Status:** approved by the maintainer, 2026-11-09; issues filed (see "Filed" at the end).
**Builds on:** [`2026-11-09-locations-decks-v1-design.md`](2026-11-09-locations-decks-v1-design.md) (the maintainer's v1 design, 2026-11-09, reviewed against `main` at `fbc6494`), and an interview with mock-ups on 2026-11-09.
**Deliverable:** GitHub issues that Claude Code agents can each take through the SDD workflow (spec, plan, build) as one outcome in one PR. Design-system issues come first, so the patterns and rules are settled before any feature work starts.

## Why

Most of theme C (Locations) is built. The remaining issues, #49 (decks as locations) and #50 ("Free to use"), both assume decks exist, and neither has acceptance criteria. The v1 design gives decks a shape that fits the existing lot and location model. This document adds what the interview settled: what the collector sees, which rules apply, and how the work splits into issues.

The collector's moment is at the table, with a deck in hand. They want to see:

- the deck's cards by zone;
- a mana curve;
- a summary of the deck's structure: counts by top-level card type and how many coloured mana symbols its costs ask for.

All of it comes from the local catalog, with nothing extra typed in.

## Decisions

The v1 design's decisions 1–7 stand: two lists (owned and proxied), a lot's location as the only record of where a copy is, zones as child locations, fixed zones per format in code, proxies naming a printing, decks wherever locations are listed, and lending in v2 as a `loan` kind. The interview added the following. Each is the maintainer's unless it is marked *(my call)*.

### Scope of 1.0

1. **A first piece of deck analysis is in 1.0:** the deck shape panel (curve, types, mana symbols). The v1 design had put analysis in v2. It is MTG-specific, so it lives behind the MTG extension, and the core deck page only provides the place for it.
2. **Formats in 1.0:** Casual (the default), Standard, Pioneer, Modern, Legacy, Vintage, Pauper and Commander.
   - Casual and the six constructed formats have the zones Main, Sideboard and Considering.
   - Commander has Commander, Main and Considering.
3. **Every format has a Considering zone.** It holds cards being thought about.
   - **Changing format.** When a deck changes format, every lot and proxy in a zone the new format lacks moves into Considering. The page then says how many moved. The change isn't refused for holding cards. *(My call:)* it is refused, changing nothing, only when moving them would merge a lot past the 9,999 cap, under the existing all-or-nothing merge rule (collection-and-lots area doc).
   - **Free to use.** Copies in Considering are in the deck, so they are not free to use.
   - **Shape panel.** Considering is left out.
   - **Removing the deck.** Refused while lots are in Considering, as for any zone.
4. **What the shape panel counts:** Main and Commander. Sideboard and Considering are left out. The panel counts owned copies and proxies together and shows them split.
5. **Format rules in 1.0:** only a per-card legality marker in the zone table, taken from the catalog's legalities for the deck's format.
6. **Deferred to an early v2 milestone:** deck-size checks, copy-limit checks (4-of, Commander singleton), and a flag for a card that has both owned copies and proxies in one zone.
7. **Replacing a proxy is in 1.0.** A proxy row offers two actions:
   - **Use my copy.** A choice page lists free copies of that card. Copies of the proxy's own printing and finish come first, under "This printing"; other printings follow under "Other printings". Nothing is preselected.
   - **Add a new copy.** The existing Add a copy form opens with the printing, finish and zone filled in.

   Either action lowers the proxy count by the number of copies used.
8. **A copy that reaches a zone some other way never changes a proxy.** That covers Move, bulk Move to…, typed entry and scanner sittings. Proxies change only by hand.

### What it looks like (chosen from mock-ups)

9. **Decks is its own navigation section.**
   - Wide header: Collection, Decks, Search, Scan, Locations.
   - Phone tab bar: Collection, Decks, Search, Scan, More. Locations stays in More.
   - The Decks page lists each deck with its format, card count, and owned and proxy counts. "New deck" asks for a name and a format.
   - The Locations page lists places only.
10. **Deck page layout (option B).**
    - Zones are in the main column and the shape panel is in a sticky right column. Below 640px of the page container, the panel stacks above the zones *(my call)*.
    - Each zone is one table with one row per card, grouped by top-level type.
    - Columns: Card (name, set · number), Cost (pips), Owned, Proxy, Total.
    - A row with proxies shows its proxy count in a dashed "Proxy" tag, so it reads without colour.
    - Each zone has "Add a proxy" in its header.
11. **The curve (option B).** One column per mana value: 0, 1, 2, 3, 4, 5 and 6+, with lands left out.
    - Owned copies are a solid `ink-muted` fill. Proxies are a hatched `line-strong` fill with an `ink-muted` outline, stacked on top.
    - There's a count above each column, a legend ("Owned 31", "Proxy 9") and the average mana value.
    - The fill is neutral, never `brand`, because brand means an action.
12. **Card types:** a list of counts by top-level type (Lands, Creatures, Instants, Sorceries, Artifacts, Enchantments, Planeswalkers, Battles, and any other top-level type present).
13. **Coloured mana symbols.** A single bar, split by W/U/B/R/G and drawn with the existing `mana-*` fills.
    - Each segment shows its letter and count ("U 28") and has a 1px `line-strong` divider.
    - A caption gives percentages ("Blue 54% · Red 46%").
    - The bar has an `aria-label` that reads the counts.
    - Hybrid and Phyrexian symbols count toward each of their colours *(my call; the spec may refine)*.
14. **The mana-colour rule is reworded.** It changes from "never used anywhere else in the UI" to "used only to show mana: pips, and charts of mana symbols". The reasons, which are inferred because the export states none: keep mana fills apart from the status colours, and the fills are the same in both themes.
15. **Location pickers.** Every location `<select>` uses native `<optgroup>`s.
    - Order: "No location", then Places, then Decks.
    - Zones read "Deck › Zone".
    - The collection filter (spec 037) also offers "Deck (all zones)" for each deck.
16. **Card page (#50).**
    - Stats: Owned, In decks, Free to use. Est. value waits for prices.
    - An "In decks" table with Deck (and format), Zone, Owned and Proxy columns.
    - Proxies never count toward Owned or In decks.
17. **"Add to deck" on the card page (option A).** One page asks for the deck and zone, how many, and what to use:
    - "My copies (N free: …)", which moves free lots into the zone (shown only when copies are free);
    - "A proxy of SET · NUM finish", the printing shown on the page.
18. **The design system stays in this repo as code.** The first export was a starting point, and the project now owns it in code. There are no more re-exports, so [1] retires the "replaced wholesale by re-exporting" note in `CLAUDE.md` and the "Upstream these into the published design system" lines in the README. New patterns go into `collector/additions.css` with a doc in `docs/design-system/components/`. Rules change in `docs/design-system/README.md` itself.

### Data notes found in the code

- **Mana value isn't stored.** `mtg_cards` has `mana_cost`, `type_line`, `colors` and `color_identity`, but `MTG::Scryfall::Mapper` never reads Scryfall's `cmc`. The curve needs a column and a mapper change. The next catalog refresh fills it.
- **Location names are unique per account** (`index_locations_on_account_id_and_name_key`), so every deck's "Main" would collide. The v1 design's invariant applies: scope names by parent, so top-level names (places and decks) share one space per account.
- **Formats belong to the collectible extension** *(my call)*. The core owns decks, zones (by key: `main`, `sideboard`, `considering`, plus any the format declares) and proxies, and never names a format. The MTG extension registers its formats and their zones through a small seam in the core. A deck's `format` stores the format's key, and the format's registration says which collectible it is for. [5]'s ADR records this. [7]'s legality marker and [10]'s panel are the extension's contributions to the deck page.
- **Limits** *(my call)*. The 500 limit (`Location::MAX_PER_ACCOUNT`, the export's `maxItems`) counts top-level locations, places and decks together. Zones don't count. [5] changes the count's query and the format document says so.
- **Import as well as export.** Ruling 19 and the round-trip rule mean the version 4 import must read decks, zones and formats back. A location's identity in a file can no longer be its name's comparison key alone, because every deck has a "Main". Zones are identified by their deck's key and the zone key. This is why [5] is split in two.
- **Export format.** Version 3 is current. Decks and zones are collector-owned data, so they raise the version (ruling 19, the area doc's version rule). *(My call:)* the first deck issue raises it to 4. The proxy issue extends version 4 if no release has shipped version 4 yet, and raises it to 5 otherwise; its spec checks which applies.
- **Roadmap.** Each new candidate is listed in `docs/roadmap.md` theme C, in the same PR that files its issue.

## Goals, non-goals, anti-goals

- **Goals:** decks a collector can build and read at the table; "where is it" and "is it free" answered everywhere; a shape panel drawn from catalog data alone; design-system rules written before features rely on them.
- **Non-goals for 1.0:** deck-size and copy-limit validation; collector-defined zones and homebrew formats; lending; a dedicated deck-builder workflow; digital decks that share copies.
- **Anti-goals:**
  - a proxy that ever counts as owned;
  - a copy recorded in two places;
  - a proxy that changes without the collector choosing it;
  - MTG vocabulary in core models or core copy (the deck page shell, zones and proxies stay collectible-agnostic, and only the shape panel, mana value and legality are MTG);
  - a chart that depends on colour alone.

## The issues

Every 1.0 issue goes on the 1.0 milestone with `theme: locations`, uses the roadmap's issue format (an **Outcome** line, bullets, and the standard footer), and lists its dependencies. "DS" issues also get a new `design-system` label *(my call)*. Numbers in brackets are this document's order, not GitHub numbers.

### Design system first

**[1] Design system: deck rules, navigation and pickers.** README and existing component docs only, plus the CSS that grouped selects need.
- Retire the re-export: `CLAUDE.md`'s "replaced wholesale by re-exporting" and the README's "Upstream these…" lines (decision 18).
- Navigation: Decks becomes a live section (header order, the phone's fifth tab), replacing "Decks and Wishlist don't exist yet".
- Colour: the reworded mana-colour rule (decision 14), and a short "Charts" rule (decisions 11 and 13).
- Vocabulary: zone, proxy, Considering, "Deck › Zone", Free to use (with Considering counted as in deck).
- `FilterSelect` and `Form`: grouped location selects (decision 15).
- `ItemPage` and `ItemPagePhone`: the 1.0 stats and the In decks table (decision 16).
- `Locations`: places only; decks live on their own page.

**[2] Design system: deck components and previews.** Depends on [1].
- New docs, `additions.css` rules and preview HTML (wide and phone, light and dark):
  - `DeckShape`: curve, types, mana symbols;
  - `ProxyTag`;
  - `DeckPage`: layout B, zone tables, type groups, legality marker, phone stacking;
  - `DecksIndex`;
  - `AddToDeck` (a `ChoicePage` variant, decision 17);
  - `UseMyCopy` (decision 7).
- Mock-ups from 2026-11-09 are the starting point.

### Features (1.0)

**[3] #187: open a location's lots in bulk mode from its refusal page.** Unchanged, and independent of everything else here, so it can go any time.

**[4] Store each card's mana value from the catalog.**
- The MTG mapper reads Scryfall's `cmc`, and a migration adds a nullable numeric mana value to `mtg_cards`. It must hold halves for some cards.
- Existing rows fill on the next refresh, and the upgrade notes say so.
- Independent; it unblocks [10].

**[5] #49 rewritten: create, rename and remove a deck.** Depends on [1] and [2].
- Schema: `locations.kind` (place, deck, deck_zone), `parent_id` and `zone`; a `decks` table with `format`.
- Names scoped by parent, and the 500 limit counting top-level locations only.
- The format seam, with MTG's eight formats and their zones, including Considering.
- Removal refused while any zone holds lots.
- The Decks section and its page (`DecksIndex`), with the counts that exist by then: format, cards and owned copies. [8] adds the proxy counts.
- Export **and import** of version 4 (decks, zones, formats; zone identity by deck and zone key), with the round-trip test.
- An ADR for zones as child locations and formats from the extension, building on ADR 0025.

**[5b] Change a deck's format.** Depends on [5].
- Moves lots and proxies from zones the new format lacks into Considering, reporting how many moved.
- Refused, changing nothing, only past the 9,999 merge cap.
- Proxy moves apply once [8] exists. If [8] lands first, this issue covers proxies too; otherwise [8] adds them.

**[6] Deck zones in every location picker and in the collection filter.** Depends on [1] and [5].
- Covers grouped selects in the lot form, Move copies, bulk Move to…, typed entry, the scanner sitting and the collection filter (with "all zones").
- Tiles and rows name a zone "Deck › Zone".

**[7] Deck page: owned cards by zone.** Depends on [2], [5] and [6].
- Layout B without the shape panel. The panel's column is left empty until [10].
- Zone tables of owned lots grouped by type, with the legality marker.
- Owned copies get in through the existing ways [6].

**[8] Proxies: add, change and remove a proxy in a deck zone.** Depends on [7].
- "Add a proxy" from the zone header: choose a printing and finish, then a quantity.
- Change a proxy's quantity, or remove it.
- Proxy and Total columns, and the Proxy tag; proxy counts on the Decks page.
- Removing a deck removes its proxies.
- Export (see the data notes).

**[9] Add to deck from the card page.** Depends on [8]. The decision 17 page: move free copies into a zone, or add a proxy of the shown printing.

**[10] The deck shape panel.** Depends on [4], [7] and [8].
- MTG extension: curve (owned and proxy split), types and coloured mana symbols for Main and Commander.
- Placed in the deck page's right column.

**[11] #50 rewritten: Free to use and In decks on the card page.** Depends on [5] and [8]. It owns the whole card page change, including the Proxy column and the rule that proxies never count toward Owned or In decks.

**[12] Replace a proxy with a copy.** Depends on [8]. Use my copy and Add a new copy (decision 7).

Suggested order: [1] → [2]; [3] and [4] can run alongside them. Then [5] → [6] → [7] → [8], with [5b] any time after [5]. Then [9], [10], [11] and [12] in parallel.

### Later (the 2.0 milestone)

- **[13] Deck checks (early 2.0):** deck size, copy limits (4-of, Commander singleton), and owned plus proxy of one card in one zone. Advisory and on demand, shown on the deck page.
- **[14] Lending:** a `loan` location kind with a borrower and date; lent copies aren't free to use.
- **[15] A deck-builder workflow** beyond the grouped pickers.
- **[16] Collector-defined zones and homebrew formats** (v3+; filed on 2.0 with a note).
- **[17] Scanner: separate "add" and "look up" modes** (theme D), from the v1 design's "recorded for later"; filed with no milestone for the maintainer to place.

## Left to each issue's spec

- **Zones:** zone keys and display names, and the order zones appear in.
- **Proxy fields:** what a proxy's finish allows.
- **Shape panel:** how "6+" and half mana values bucket, which faces of a double-faced card count, and the type-grouping order.
- **Card page:** what "In decks" shows for a deck with only proxies of the card.
- **Pickers:** how a deck with many zones reads in the picker on a phone.
- **Export:** keys and field names for decks, zones and proxies.

## Filed

On 2026-11-09. Roadmap items are in `docs/roadmap.md`, theme C, item 14.

| Here | Issue | Milestone |
| --- | --- | --- |
| [1] | #248 | 1.0 |
| [2] | #249 | 1.0 |
| [3] | #187 (unchanged) | 1.0 |
| [4] | #250 | 1.0 |
| [5] | #49 (rewritten) | 1.0 |
| [5b] | #251 | 1.0 |
| [6] | #252 | 1.0 |
| [7] | #253 | 1.0 |
| [8] | #254 | 1.0 |
| [9] | #255 | 1.0 |
| [10] | #256 | 1.0 |
| [11] | #50 (rewritten) | 1.0 |
| [12] | #257 | 1.0 |
| [13] | #258 | 2.0 |
| [14] | #259 | 2.0 |
| [15] | #260 | 2.0 |
| [16] | #261 | 2.0 |
| [17] | #262 | none (theme D) |
