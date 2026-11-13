# The deck builder: build mode, planned cards and the pull list

**Date:** 2026-11-12. **Status:** approved by the maintainer in the interview, 2026-11-12 (option A and the issue split); issues filed (see "Filed" at the end).
**Builds on:** [`2026-11-09-decks-and-locations-issues-design.md`](2026-11-09-decks-and-locations-issues-design.md), which recorded #260 as a one-line candidate, and the deck work of 1.0 as built on `main` at `59b0bda` (specs 062–073, 079; [ADR 0028](../../adr/0028-decks-are-locations-with-zones.md)). An interview with mock-ups on 2026-11-12.
**Deliverable:** #260 rewritten and new GitHub issues, each one outcome that a Claude Code agent takes through the SDD workflow in one PR. The design-system issue comes first.
**Mock-ups:** [`2026-11-12-deck-builder-mockups/`](2026-11-12-deck-builder-mockups/). Card images in them are placeholders.

## Why

In 1.0 a deck is something a collector reads and fills one card at a time. Every way of getting a card into a deck is a trip away from it: "Add a proxy" in a zone's header, "Add to deck" on a card's page, or a location picker in Move, bulk Move to…, Add by number or a scanner sitting. Nothing lets a collector work on the deck as a whole.

The maintainer builds decks by hand:

- **Pile, then whittle.** He gathers far more cards than fit, cuts down to a prototype and keeps refining. The work is mostly cutting and swapping, less searching and adding.
- **Two ways to start.** A pile of his own cards, or a preconstructed deck that he then refines.
- **Commander starts from a card.** The commander comes first, sometimes a theme, and the pile follows.
- **Two flows over time.** At first he records what his hands are doing at the table (flow one). As more of the collection is in Collector, he expects to plan on screen first and pull the cards afterwards (flow two).
- **Suggestions come later.** He wants AI-backed suggestions eventually. This design only leaves a place for them.

## Decisions

Each is the maintainer's unless it is marked *(my call)*.

### The shape of the work

1. **One builder, which the format adjusts.** Commander and the other constructed formats are the same pile-and-whittle loop with different limits *(my call, not disputed in the interview)*. Commander starts from a card, decides in or out at one copy each, and aims at 100 cards. The other formats decide how many of each, and aim at 60 with a sideboard. The core provides the loop; the collectible's extension provides the target, the row's control and any limit on adding.
2. **Considering is the pile.** Every format already has the zone, the shape panel leaves it out, and copies in it are in the deck. Whittling moves cards between Considering, the format's other zones and out of the deck.
3. **Build mode is a mode of the deck page (option A).** The deck page gains a "Build" action and "Done" leaves, as bulk mode works on the collection. The reading page stays as it is.
4. **Flow one first, flow two second.** Build mode needs no data change and ships first. Planned cards and the pull list follow.

### Build mode

5. **Buttons take the actions.** Every row or card has a visible Cut and a visible move button. A swipe never cuts or keeps.
6. **Three views, one preference.** List, Cards (a grid of card images) and One card (one large image at a time). The choice is one preference for the whole app, as the collection's view is. The grid is built before One card.
7. **One card browses by swiping.** Previous and Next buttons do the same, which keeps the design system's rule that a swipe always has a button equivalent (#343).
8. **A summary stays in view** and is current after every action: the count against the format's target, the owned, proxy and planned split, and on a phone a small curve.
9. **On a phone a zone is a tab,** so one list fills the screen. On a wide screen the zones are columns beside the shape panel.
10. **Cuts go to a place set once per sitting** *(my call)*, shown in build mode with "Change", as the scanner keeps a sitting's destination. Cutting an owned copy moves it there. Cutting a proxy or a planned card removes that slot.
11. **The format decides the row's control** *(my call)*. A format that allows several copies of a card shows a count stepper. A one-copy format shows none.
12. **Every Cut or move offers Undo for the last action** *(my call)*, as bulk mode and Add by number do.
13. **A quick search filters what is on screen.** On a phone it filters the open zone. On a wide screen it filters the whole deck.

### Planned cards

14. **A slot that the deck needs and does not hold is a proxy or planned.** A proxy means a printed stand-in is in the deck. A planned card has no stand-in. The collector says which, and that is the one fact stored.
15. **A planned card reads "To pull" or "To get".** "To pull" when the collector has a free copy of the card, "To get" when they have none. This is worked out from the collection each time and never stored.
16. **A planned slot shrinks on its own when a copy of its card arrives in its zone,** by Move, bulk Move to…, typed entry, a scanner sitting or Add a copy. It shrinks by the number of copies that arrived. A proxy still never changes unless the collector chooses it ([collection and lots](../../architecture/collection-and-lots.md), "A proxy is never owned and changes only by hand").
17. **A planned card names a printing** *(my call)*, as a proxy does, so there is one shape of record. Any printing of the card that the collector owns counts as a match for "To pull" and for decision 16.
18. **Three tags that read without colour** *(my call)*: "Proxy" keeps its dashed outline, "To pull" has a solid outline and "To get" a dotted one. The word carries the meaning.
19. **A planned card never counts as owned,** in Owned, In decks or Free to use, as a proxy never does.

### Adding and starting

20. **Cards are added from inside build mode.** A search covers the collector's free copies and the catalog. A result the collector has free offers "Add my copy" first. A result with no free copy offers "Plan it" first. The other ways (a proxy, a new copy) are behind "More" *(the button order is my call)*.
21. **A deck can start from a pasted list.** This covers preconstructed decks, since the catalog source carries no deck lists. Each line becomes new copies, free copies the collector already owns, or planned cards.
22. **A Commander deck can start from its commander,** and adding is then limited to the commander's colours. This is the extension's contribution.

### The pull list and what is left over

23. **A deck has a pull list:** its "To pull" cards grouped by the place the free copy is in, and its "To get" cards after them. A "To get" line says when the collector owns a copy that another deck holds.
24. **"To get" across all decks is one list.** A wish list for cards wanted for no deck is a separate feature, recorded as a placeholder. When it exists, the "To get" list moves into it.
25. **Suggested cards are a placeholder only.** Nothing here is built for them.

## Approaches

How build mode relates to the deck page:

| | What it is | Trade-off |
| --- | --- | --- |
| **A. A mode you enter** (chosen) | "Build" on the deck page, "Done" to leave | The reading page stays calm at the table and the phone can have its own layout; one extra tap to start |
| B. Always editable | Every deck page row carries Cut and move | No mode, but the reading page is crowded and a stray tap moves real copies |
| C. A separate builder section | Its own navigation | Room to grow, but it duplicates the deck page and splits where a deck lives |

A was chosen because it follows bulk mode, a pattern the app already has, and leaves the deck page as it is.

How a planned card is recorded:

| | What it is | Trade-off |
| --- | --- | --- |
| Derive it from proxies | A planned card is a proxy; "To pull" is a proxy with a free copy | No new data, but a printed stand-in cannot be told from a card not yet fetched, so decision 16 would be impossible |
| **Store planned or proxy** (chosen) | One field on the proxy record | Exact, and it lets planned slots fill themselves; a schema change, a new export version and a third tag |
| A separate wish list model | Planned cards live in a wish list | Larger than the need; it is the placeholder of decision 24 |

## Goals, non-goals, anti-goals

- **Goals:** whittle a pile to a deck without leaving the deck; work beside a physical pile on a phone; plan a deck from the collection and know where to fetch each card; start from a list or a commander.
- **Non-goals:** suggestions; a wish list section; collector-defined zones and homebrew formats (#261); lending (#259); checks beyond spec 079's; prices.
- **Anti-goals:**
  - a swipe that cuts or moves a copy;
  - a proxy that changes without the collector choosing it;
  - a planned card or a proxy that counts as owned;
  - a copy recorded in two places;
  - a format, zone key or collectible named in the core's build mode files (`spec/deck_core_spec.rb`);
  - a view that only works on a wide screen.

## Data notes found in the code

- **`deck_proxies`** has `location_id`, `catalog_entry_id`, `finish` and `quantity`, unique per zone, entry and finish. Decision 14 adds one field. Whether a zone may hold a proxy and a planned card of the same printing and finish decides the unique index; the spec rules on it. Whether the table is renamed is the spec's too.
- **The export is at version 4** and carries `proxies`. Planned cards are collector-owned data, so they raise it to version 5 ([data portability](../../architecture/data-portability.md)).
- **The view preference.** `users.collection_view` is in the export's profile. A build view preference is a new column on `users`, which the Coverage tables must list, and it is the collector's data in the same way.
- **The proxy rule** is written in [collection and lots](../../architecture/collection-and-lots.md) and in spec 068. Decision 16 amends the area doc for planned slots only.
- **Spec 079's check** flags a card with owned copies and proxies in one zone. Its spec did not know planned cards; issue [2]'s spec says how they count.
- **The deck page's seams** (`Catalog::DeckCards`, `Catalog::DeckShape`, `Catalog::DeckChecks`) are how the extension contributes today. The row's control (decision 11), the target count and the colour limit (decision 22) come the same way.

## The issues

Every issue goes on the 2.0 milestone with `theme: locations`, except the two placeholders, which have no milestone. Each uses the roadmap's issue format. Numbers in brackets are this document's order, not GitHub numbers.

**[1] Design system: the deck builder.** Also `design-system`. The README rules and vocabulary (build mode, cut, planned, To pull, To get, pull list), and new component docs, `additions.css` rules and previews at phone and wide widths in both themes: the build mode shell, the plan tags, the deck card tile, the One card view, the three-way view switch, the cuts line, Add cards and the pull list.

**[2] Planned cards.** Depends on [1]. Decisions 14, 15, 17, 18 and 19: the stored field, the tags on the deck page and the Decks list, the counts, adding a planned card where a proxy is added today, turning one into the other, the change of format, and export version 5 with its round trip.

**[3] A planned slot fills itself.** Depends on [2]. Decision 16, on every route a copy takes into a zone, and the area doc's amended rule.

**[4] #260 rewritten: build mode.** Depends on [1]. Decisions 3, 5, 8, 9, 10, 11 and 12 in the List view: enter and leave, the summary, zones as tabs or columns, Cut and move, the cuts place, the stepper and Undo.

**[5] Find a card in build mode.** Depends on [4]. Decision 13.

**[6] Build mode: the cards view.** Depends on [4]. The grid of card images at both widths and the one view preference (decision 6).

**[7] Build mode: one card at a time.** Depends on [6]. Decision 7.

**[8] Add cards from inside build mode.** Depends on [2] and [4]. Decision 20.

**[9] The pull list.** Depends on [2]. Decisions 23 and 24: a deck's list and "To get" across all decks.

**[10] Start a deck from a pasted list.** Depends on [2]. Decision 21.

**[11] Start a Commander deck from its commander.** Depends on [8]. Decision 22.

**[12] Placeholder: a wish list.** No milestone. Decision 24.

**[13] Placeholder: suggested cards in build mode.** No milestone. Decision 25.

Suggested order: [1], then [4] → [5], [6] → [7] for flow one. [2] → [3] may run beside them, then [8], [9] and [10], then [11].

## Left to each issue's spec

- **[2]:** the field's name and values; whether the table is renamed; the unique index; what spec 079's check says about planned cards; what the Decks list and the card page's In decks table show.
- **[3]:** which printing's planned slot shrinks when the zone has planned slots of two printings of one card; what happens when more copies arrive than are planned.
- **[4]:** whether the mode is a parameter or a nested route; what the stepper's plus does when the collector has free copies in several places; what "Cut" does to a row with owned copies and a proxy; the move button's target when a format has more than two zones besides Considering; how the summary stays current (a Turbo Stream or a morph); where the cuts place is kept.
- **[6]:** how the grid handles a card with no image; tile sizes; whether the wide grid keeps the type groups.
- **[7]:** the order cards are shown in; what follows the last card.
- **[8]:** how results are ranked; how many load; which printing "Plan it" names; whether the wide panel replaces the shape panel while it is open.
- **[9]:** what "In the deck" does when the free copy is in a quantity lot; the order of places.
- **[10]:** the accepted list formats; how a line that matches no card is shown; whether the list is previewed before it is applied, as an import is.
- **[11]:** how a colourless or partner commander limits adding; whether the limit can be switched off.

## Filed

To be recorded when the issues are filed.
